#!/usr/bin/env python3
"""Writes an initramfs in the kernel's newc cpio format without being root.

  mkinitramfs.py OUT.cpio TREE [--links busybox.links] [--gzip]

TREE is copied as it is, owned by root. /dev/console and /dev/null are added
as device nodes - the kernel opens /dev/console for init before anything can
mount devtmpfs - and every line of a busybox.links file becomes a symbolic
link to /bin/busybox.
"""
import gzip, os, stat, sys

def header(ino, mode, nlink, size, name, rmajor=0, rminor=0):
    name_bytes = name.encode() + b"\0"
    fields = (ino, mode, 0, 0, nlink, 0, size, 0, 0, rmajor, rminor, len(name_bytes), 0)
    out = b"070701" + b"".join(b"%08X" % f for f in fields) + name_bytes
    return out + b"\0" * (-len(out) % 4)

def entry(ino, mode, name, data=b"", nlink=1, rmajor=0, rminor=0):
    return header(ino, mode, nlink, len(data), name, rmajor, rminor) + data + b"\0" * (-len(data) % 4)

def main():
    args = sys.argv[1:]
    compress = "--gzip" in args
    if compress:
        args.remove("--gzip")
    links = None
    if "--links" in args:
        at = args.index("--links")
        links = args[at + 1]
        del args[at:at + 2]
    target, tree = args

    out, ino, seen = [], 1, set()
    def add(mode, name, data=b"", **kw):
        nonlocal ino
        if name in seen:
            return
        seen.add(name)
        out.append(entry(ino, mode, name, data, **kw))
        ino += 1

    for base, dirs, files in os.walk(tree):
        dirs.sort()
        rel = os.path.relpath(base, tree)
        if rel != ".":
            add(stat.S_IFDIR | 0o755, rel.replace(os.sep, "/"), nlink=2)
        for f in sorted(files):
            path = os.path.join(base, f)
            name = os.path.normpath(os.path.join(rel, f)).replace(os.sep, "/")
            if os.path.islink(path):
                add(stat.S_IFLNK | 0o777, name, os.readlink(path).encode())
            else:
                # NTFS has no mode bits worth copying: what is in bin, sbin
                # or called init is a program, the rest is not
                runs = name == "init" or name.split("/")[0] in ("bin", "sbin") or "/bin/" in name
                with open(path, "rb") as fh:
                    add(stat.S_IFREG | (0o755 if runs else 0o644), name, fh.read())

    for d in ("dev", "proc", "sys", "tmp", "root", "bin", "sbin", "usr", "usr/bin", "usr/sbin", "etc", "mnt"):
        add(stat.S_IFDIR | 0o755, d, nlink=2)
    add(stat.S_IFCHR | 0o600, "dev/console", rmajor=5, rminor=1)
    add(stat.S_IFCHR | 0o666, "dev/null", rmajor=1, rminor=3)
    if links:
        for line in open(links):
            name = line.strip().lstrip("/")
            if name and name != "bin/busybox":
                add(stat.S_IFLNK | 0o777, name, b"/bin/busybox")

    out.append(entry(0, 0, "TRAILER!!!"))
    image = b"".join(out)
    image += b"\0" * (-len(image) % 512)
    with open(target, "wb") as fh:
        fh.write(gzip.compress(image, 9, mtime=0) if compress else image)
    print(f"{target}: {len(seen)} entries, {os.path.getsize(target)} bytes")

main()

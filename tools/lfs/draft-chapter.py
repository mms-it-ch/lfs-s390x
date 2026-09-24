#!/usr/bin/env python3
"""Drafts a chapter script out of the LFS book: a shell function for every
section, holding what the book tells the reader to type, and a step line for
each. What the book has the reader do to TEST a package is kept as comment -
under qemu-user the test suites are days, and what they would find out is how
well qemu emulates, not how well the package was built.

  draft-chapter.py BOOK.html CHAPTER SOURCES-DIR > draft.sh

A draft: the result is read, corrected where the architecture or the missing
terminal asks for it (marked "s390x:" or "unattended:"), and kept. The
corrections are not made here, so that they can be seen where they apply.
"""
import html, os, re, sys

book, chapter, sources = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(book, encoding="utf-8").read()
tarballs = sorted(f for f in os.listdir(sources) if re.search(r"\.tar\.|\.tgz$", f))

TEST = re.compile(
    r"^\s*(?:[A-Z_]+=\S+\s+)*(?:make|ninja|unshare -m ninja)\b[^\n]*\b"
    r"(?:check|test|tests|test_harness|check-root|check_local)\b"
    r"|su (?:-s \S+ )?tester|^chown -R tester|Timed out|\^FAIL:|test_summary|grep -c \^PASS"
    r"|tests/run\.sh|from pty import spawn|ulimit -s -H|group(?:add|del)[^\n]*dummy",
    re.M)

# Where the name of the section is not the beginning of the name of the tarball
NAMES = {"tcl": "tcl8", "expect": "expect5", "libelf from elfutils": "elfutils",
         "sqlite": "sqlite-autoconf", "flit-core": "flit_core", "d-bus": "dbus",
         "systemd": "systemd-2", "xz": "xz-", "man-pages": "man-pages", "m4": "m4-",
         "file": "file-", "make": "make-", "tar": "tar-", "sed": "sed-", "gcc": "gcc-",
         "bc": "bc-", "less": "less-", "perl": "perl-", "patch": "patch-"}


def tarball(title):
    name = re.sub(r"^\d+\.\d+\.\s*", "", title)
    name = re.sub(r"[-\s]v?\d[\w.]*$", "", name).strip().lower()
    prefix = NAMES.get(name, name)
    found = [f for f in tarballs if f.lower().startswith(prefix)]
    # The documentation of Tcl, Python and SQLite comes in tarballs of its own
    sources_first = [f for f in found if not re.search(r"html|doc", f)]
    return (sources_first or found or [""])[0]


pieces = re.split(r'(<h[12][^>]*class="(?:title|sect1)"[^>]*>.*?</h[12]>)', text, flags=re.S)
title, steps = "", []
print("#!/bin/bash")
print(f"# DRAFT of chapter {chapter}, written by tools/lfs/draft-chapter.py out of the book.")
print("set -e\n. /sources/scripts/common.sh\n")
for piece in pieces:
    if piece.startswith("<h"):
        title = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", piece))).strip()
        continue
    if title.split(".")[0].strip() != chapter:
        continue
    blocks = [html.unescape(re.sub(r"<[^>]+>", "", c)).rstrip()
              for c in re.findall(r'<pre class="userinput">(.*?)</pre>', piece, flags=re.S)]
    if not blocks:
        continue
    number = title.split(" ")[0].rstrip(".")
    name = re.sub(r"^\d+\.\d+\.\s*", "", title)
    short = re.sub(r"[^a-z0-9]+", "-", re.sub(r"[-\s]v?\d[\w.]*$", "", name).lower()).strip("-")
    function = "p_" + short.replace("-", "_")
    print(f"# {title}")
    print(f"{function}() {{")
    for block in blocks:
        lines = block.split("\n")
        if TEST.search(block):
            print("    # the book's test:")
            for line in lines:
                print("    #   " + line)
        else:
            # A here-document ends at the left margin, so nothing of one is indented
            inside, end = False, None
            for line in lines:
                if inside:
                    print(line)
                    if line.strip() == end:
                        inside = False
                    continue
                print("    " + line if line.strip() else "")
                m = re.search(r"<<\s*\"?(\w+)\"?\s*$", line)
                if m:
                    inside, end = True, m.group(1)
    print("}\n")
    steps.append((f"{number}-{short}", tarball(title), function))

for name, ball, function in steps:
    print(f"step {name:<28} '{ball}' {function}")

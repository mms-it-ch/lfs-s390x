#!/usr/bin/env python3
"""Writes a 3390 volume, formatted the way Linux formats one, with a file
system already on it - without a running Linux to do the formatting.

  mkdasd.py OUT.ckd FILESYSTEM.img [--volser LFS001] [--cyls N]

The volume is in the "Linux disk layout" (dasdfmt -d ldl): every track holds
twelve records of 4096 bytes and no keys, which the dasd_eckd driver numbers
through as blocks. Block 2 is the volume label, "LNX1", and the one partition
- /dev/dasda1 - is everything behind it (block/partitions/ibm.c,
find_lnx1_partitions). FILESYSTEM.img, made with mkfs.ext4 -d, is copied
there block for block.

The file is a Hercules CKD image, uncompressed (dasdutil.c, create_ckd_file):
a device header of 512 bytes and then the tracks, each one a home address,
record zero, the records with their count fields, eight bytes of X'FF', and
padding to the track size of the device - 56832 bytes for a 3390.
"""
import argparse, struct, sys, os

HEADS, TRACK_SIZE, DEVICE_TYPE = 15, 56832, 0x90
BLOCK, PER_TRACK = 4096, 12
LABEL_BLOCK = 2
MODELS = (1113, 2226, 3339, 10017, 32760, 65520)      # 3390-1, -2, -3, -9, -27, -54


def main():
    p = argparse.ArgumentParser()
    p.add_argument("out")
    p.add_argument("filesystem")
    p.add_argument("--volser", default="LFS001")
    p.add_argument("--cyls", type=int, default=0)
    a = p.parse_args()

    size = os.path.getsize(a.filesystem)
    if size % BLOCK:
        sys.exit(f"{a.filesystem} is not a whole number of {BLOCK} byte blocks")
    first = LABEL_BLOCK + 1
    needed = first + size // BLOCK
    per_cylinder = HEADS * PER_TRACK
    cyls = a.cyls or next((m for m in MODELS if m * per_cylinder >= needed), 0)
    if cyls * per_cylinder < needed:
        sys.exit(f"{needed} blocks do not fit on {cyls or MODELS[-1]} cylinders")
    blocks = cyls * per_cylinder

    label = bytearray(BLOCK)
    label[0:4] = "LNX1".encode("cp037")
    label[4:10] = a.volser.upper().ljust(6)[:6].encode("cp037")
    label[79] = 0xF2                                  # ldl_version, EBCDIC "2"
    label[80:88] = struct.pack(">Q", blocks)          # formatted_blocks

    header = bytearray(512)
    header[0:8] = b"CKD_P370"
    header[8:12] = struct.pack("<I", HEADS)
    header[12:16] = struct.pack("<I", TRACK_SIZE)
    header[16] = DEVICE_TYPE
    header[17] = 0                                    # the only file
    header[18:20] = struct.pack("<H", 0)              # and so the last

    empty = bytes(BLOCK)
    with open(a.filesystem, "rb") as fs, open(a.out, "wb") as out:
        out.write(header)
        block = 0
        for cyl in range(cyls):
            for head in range(HEADS):
                track = bytearray(struct.pack(">BHH", 0, cyl, head))
                track += struct.pack(">HHBBH", cyl, head, 0, 0, 8) + bytes(8)
                for record in range(1, PER_TRACK + 1):
                    if block == LABEL_BLOCK:
                        data = label
                    elif block >= first:
                        data = fs.read(BLOCK) or empty
                        if len(data) < BLOCK:
                            data = data.ljust(BLOCK, b"\0")
                    else:
                        data = empty
                    track += struct.pack(">HHBBH", cyl, head, record, 0, BLOCK) + data
                    block += 1
                track += b"\xff" * 8
                out.write(track.ljust(TRACK_SIZE, b"\0"))
    print(f"{a.out}: 3390 with {cyls} cylinders, volume {a.volser}, "
          f"{blocks} blocks of {BLOCK}, file system of {size // BLOCK} blocks from block {first}")


main()

#!/usr/bin/env python3
"""Writes the .ins file of a list-directed IPL of Linux, as a distribution's
generic.ins has it, and the two small files it needs beside kernel and initrd.

  mkins.py DIR NAME KERNEL INITRD "command line"      INITRD may be ""

  DIR/NAME.ins          kernel at 0, initrd at 32 MB, and into the kernel's
                        parameter area (asm/setup.h, PARMAREA X'10400'):
  DIR/NAME.prm          the command line, at X'10480'
  DIR/NAME.addrsize     where the initrd is and how long, two doublewords at X'10408'

Hercules loads nothing from outside the directory of the .ins file, so kernel
and initrd are copied beside it.
"""
import os, shutil, struct, sys

INITRD_AT = 0x02000000

def main():
    where, name, kernel, initrd, cmdline = sys.argv[1:6]
    os.makedirs(where, exist_ok=True)
    k, i = f"{name}.kernel", f"{name}.initrd"
    shutil.copyfile(kernel, os.path.join(where, k))
    if initrd:
        shutil.copyfile(initrd, os.path.join(where, i))
    if os.path.getsize(kernel) > INITRD_AT:
        sys.exit("the kernel reaches into the initrd")
    if len(cmdline) > 895:
        sys.exit("command line too long for the legacy parameter area")
    with open(os.path.join(where, f"{name}.prm"), "wb") as fh:
        fh.write(cmdline.encode("ascii") + b"\0")
    if initrd:
        with open(os.path.join(where, f"{name}.addrsize"), "wb") as fh:
            fh.write(struct.pack(">QQ", INITRD_AT, os.path.getsize(initrd)))
    with open(os.path.join(where, f"{name}.ins"), "w", newline="\n") as fh:
        fh.write("* lfs-s390x - list-directed IPL, written by tools/mkins.py\n")
        fh.write(f"{k} 0x00000000\n{name}.prm 0x00010480\n")
        if initrd:
            fh.write(f"{i} 0x{INITRD_AT:08x}\n{name}.addrsize 0x00010408\n")
    print(f"{where}/{name}.ins")

main()

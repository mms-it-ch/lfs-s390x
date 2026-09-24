#!/bin/bash
# What the build host (WSL Ubuntu) has and lacks.
for p in bison flex bc libssl-dev libelf-dev cpio make gcc xz-utils wget curl rsync kmod libncurses-dev texinfo m4 gawk patch python3 git; do
    if dpkg -s "$p" >/dev/null 2>&1; then echo "have    $p"; else echo "MISSING $p"; fi
done

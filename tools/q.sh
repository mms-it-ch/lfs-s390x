#!/bin/bash
# scratch: run a command line on the Linux side, in the work tree
cd ${LFS_WORK:-$HOME/lfs-s390x} && eval "$@"

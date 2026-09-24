# Sourced by the chapter scripts: where things are, and how one package is
# built - unpacked afresh, built by a shell function with the book's commands
# in it, logged, and remembered as done so that a run can be taken up again.

# Unset means the host side; inside the chroot it is set, and empty
export LFS=${LFS-/mnt/lfs}
export LFS_TGT=s390x-lfs-linux-gnu
export LC_ALL=POSIX
export CONFIG_SHELL=/bin/bash          # /bin/sh is dash here, the book wants bash
export MAKEFLAGS=-j$(nproc)

SRC=$LFS/sources
# Beside the tarballs, as the book has it: its commands reach a patch as ../name
WORK=$LFS/sources
LOGS=$LFS/sources/logs
STAMPS=$LFS/sources/stamps

# The machine the system is compiled for. z10 is what the kernel of stage 0 is
# built for as well; both emulators offer more, and offer it less well tried.
LFS_ARCH=${LFS_ARCH:-z10}

# step NAME TARBALL FUNCTION - TARBALL may be a glob, "" for nothing to unpack
step() {
    local name=$1 tarball=$2 fn=$3 rc
    mkdir -p "$WORK" "$LOGS" "$STAMPS"
    if [ -f "$STAMPS/$name" ]; then
        return 0
    fi
    printf '== %-28s ' "$name"
    local started=$SECONDS
    rm -rf "${WORK:?}/$name" && mkdir -p "$WORK/$name"
    if [ -n "$tarball" ]; then
        tar -xf $SRC/$tarball -C "$WORK/$name" --strip-components=1 || return 1
    fi
    # In a subshell of its own and not part of a condition, so that set -e
    # means what it says
    set +e
    ( set -e; cd "$WORK/$name"; $fn ) > "$LOGS/$name.log" 2>&1
    rc=$?
    set -e
    if [ $rc -ne 0 ]; then
        echo "FAILED after $((SECONDS - started)) s - $LOGS/$name.log"
        tail -25 "$LOGS/$name.log"
        exit 1
    fi
    rm -rf "${WORK:?}/$name"
    touch "$STAMPS/$name"
    echo "$((SECONDS - started)) s"
}

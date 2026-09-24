#!/bin/bash
# Run as root in WSL: what the kernel and busybox builds need on the host.
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends bison flex libelf-dev cpio libncurses-dev texinfo m4

# lfs-s390x

[Linux From Scratch](https://www.linuxfromscratch.org/lfs/) 13.1 (systemd)
for s390x: a Linux system built from source for the z/Architecture, chapter
by chapter as the book has it, and booted by IPL on Hercules - from an `.ins`
file first and then, as a real machine is loaded, by zipl from a 3390 DASD.

The book is written for x86. What differs here: the target triplet is
`s390x-lfs-linux-gnu`, there is no GRUB (the kernel is loaded by a
list-directed IPL from an `.ins` file, later by zipl from a 3390), the console
is the service processor's line-mode console, and the disk is an ECKD DASD.
Everything is compiled on an x86 machine: the cross toolchain of chapters 5
and 6 in WSL, and chapters 7 to 11 in a chroot whose s390x programs run under
`qemu-s390x` through binfmt_misc - a day and a half of machine time, most of
it `configure`.

**What you need:** Windows with WSL 2 and an Ubuntu 24.04 distribution in
it (`tools/host-packages.sh` installs what the build needs there,
`qemu-user-static` among it) and a Hercules
([SDL Hyperion](https://github.com/SDL-Hercules-390/hyperion)) on the
Windows side, named by `$env:HERCULES` or on the path.

**The ready-made system** is in `build/`, as far as GitHub takes it:
`lfs.ins` with the kernel and the command line it names (`lfs.kernel`,
`lfs.prm`) and the kernel's `lfs.map` are in the repository, so a Hercules
with the machine of `run/lfs.cnf` boots the kernel from them at once
(`.\run\hercules.ps1 -NoBuild -Name lfs -Machine lfs`). The 3390 volume
with the system on it, `lfs.ckd` (2.8 GB, 3390-3, with zipl's IPL records
on it), is too large for git: it is published compressed as an asset of
the release [system-2026-09-24](https://github.com/mms-it-ch/lfs-s390x/releases/tag/system-2026-09-24)
of this repository; put it into `build/` uncompressed, and
`.\run\hercules.ps1 -NoBuild -Name lfs-dasd -Machine lfs` loads the system
from the disk itself, `ipl 120`. The login is `root`, the password `lfs`.

License: MIT (see `LICENSE`). The build commands follow the LFS book, whose
commands are MIT as well.

## Milestones

| | | |
|---|---|---|
| S0 | The kernel of LFS 13.1 (Linux 7.1.8), cross-compiled, with a busybox initramfs, boots to a shell from an `.ins` file | **done**, 19.09.2026 - in 0.7 s of the kernel's own time |
| S1 | LFS chapters 5 and 6: cross toolchain and temporary tools for `s390x-lfs-linux-gnu`, in WSL | **done**, 20.09.2026 |
| S2 | LFS chapters 7 and 8: the final system, built in a chroot under `qemu-s390x` (binfmt) in WSL | **done**, 21.09.2026 - 81 packages, 23 hours |
| S3 | The LFS root on a 3390 volume, systemd reaches a login | **done**, 22.09.2026 - login after 60 s on Hercules, root logs in, `systemctl --failed` lists nothing |
| S4 | zipl on the volume: IPL from DASD instead of the `.ins` file | **done**, 22.09.2026 - zipl 2.38.0 from s390-tools, built in the chroot and run on the system itself; `ipl 120` loads stage 0, 1, 1b, 2 and the kernel from the 3390 |
| S5 | Acceptance: the system's own gcc compiles and runs a program | **done**, 22.09.2026 - `gcc -O2 h.c`, the program runs, `RC=0` |
| S6 | The book's own kernel: 10.3 built in the chroot, with modules; `/etc/shells` | **done**, 24.09.2026 - see "Towards the book's own system" |

## Building and running

Everything is built on the Linux side of WSL (Ubuntu 24.04) in `~/lfs-s390x`
(`$LFS_WORK`) - NTFS is too slow and folds case. Only scripts, configuration
and the boot files (`build/`) live here. From the repository's directory
(WSL starts in it, as `/mnt/c/...`):

```powershell
# stage 0: a cross-built kernel and busybox, booted from an .ins file
wsl -d Ubuntu -u root -- bash tools/host-packages.sh
wsl -d Ubuntu -- bash tools/fetch-stage0.sh
wsl -d Ubuntu -- bash tools/unpack-stage0.sh
wsl -d Ubuntu -- bash tools/build-kernel.sh stage0
wsl -d Ubuntu -- bash tools/build-busybox.sh
.\run\hercules.ps1                       # puts build\stage0.ins together, boots it

# the book: sources, chapter 4, chapters 5 and 6 as the builder, 7 to 11 as root
wsl -d Ubuntu -- bash tools/fetch-lfs.sh
wsl -d Ubuntu -u root -- bash tools/lfs/prepare.sh $env:USERNAME
wsl -d Ubuntu -- env -i HOME=/home/$env:USERNAME TERM=dumb PATH=/usr/bin:/bin bash tools/lfs/ch5-6.sh
wsl -d Ubuntu -u root -- bash tools/lfs/rest.sh $env:USERNAME   # a day and a half; logs and stamps in $LFS/sources

# the system onto a 3390, zipl written onto it, and the IPL from the volume
wsl -d Ubuntu -u root -- bash tools/mklfs.sh
.\run\hercules.ps1 -NoBuild -Name lfs-zipl -Machine lfs -Seconds 600
.\run\hercules.ps1 -NoBuild -Name lfs-dasd -Machine lfs -Seconds 400
```

`rest.sh` runs chapters 7, 8 and 9 to 11 one after the other and can be
taken up where it stopped: every package leaves a stamp in
`$LFS/sources/stamps` and a log in `$LFS/sources/logs`. Hercules takes a
line beginning with `.` in its `.rc` file as input for the guest's console,
which is how `lfs-zipl.rc` logs in and runs zipl without a panel; what Linux
said ends up in `build\hercules.log`. The login is `root`, the password
`lfs`.

## Layout

| | |
|---|---|
| `config/stage0.config` | Laid over `tinyconfig`: z10, uncompressed, no KASLR, SCLP consoles, initramfs, DASD (ECKD, FBA), ext4 - the kernel of stage 0 |
| `config/lfs.config` | The same, and what the book's 10.3 asks of a kernel for systemd, plus this machine's devices - laid over `defconfig` in the chroot for the system's own kernel, with modules |
| `tools/build-kernel.sh` | Cross-builds a kernel; image, `System.map`, `vmlinux` to `$LFS_WORK/out/NAME` |
| `tools/build-busybox.sh` | busybox 1.37.0 as one static s390x program |
| `tools/mkinitramfs.py` | Writes a newc cpio with device nodes and the busybox links, without being root |
| `tools/mkins.py` | The `.ins` of a distribution's `generic.ins`: kernel at 0, initrd at 32 MB, command line at X'10480', initrd address and size at X'10408' |
| `tools/mkstage0.sh` | Puts `build/stage0.*` together; the run scripts call it |
| `tools/fetch-lfs.sh` | The book's `wget-list`, checked against its `md5sums`, and the one-page book itself; GNU packages from ftp.gnu.org rather than wherever ftpmirror.gnu.org points that day |
| `tools/book-commands.py` | Prints what the book tells the reader to type, section by section - what the chapter scripts were written from |
| `tools/lfs/common.sh` | `step NAME TARBALL FUNCTION`: unpack beside the tarballs (the book reaches a patch as `../name`), build in a subshell with `set -e`, log to `$LFS/sources/logs`, remember in `$LFS/sources/stamps` - so a run can be taken up where it stopped |
| `tools/lfs/prepare.sh` | Chapter 4, as root: `/mnt/lfs` and its limited layout, owned by who builds. No `lib64`: on s390x the dynamic linker is `/lib/ld64.so.1` |
| `tools/lfs/ch5-6.sh` | Chapters 5 and 6. Not the book's: `LFS_TGT=s390x-lfs-linux-gnu`, `--with-arch=z10` for gcc, `lib64` to `lib` in `gcc/config/s390/t-linux64`, `ARCH=s390` for the kernel headers |
| `tools/lfs/chroot.sh` | 7.2 to 7.4, as root: mounts, and a chapter script (or a shell) inside the chroot. The s390x programs in there run through the binfmt_misc entry of `qemu-s390x`, whose `F` flag makes a copy of qemu inside the tree unnecessary |
| `tools/lfs/rest.sh` | Chapters 7 to 11 in the chroot, one after the other, watching drive C: meanwhile |
| `tools/lfs/ch7.sh` `ch8.sh` | Chapters 7 and 8, inside the chroot. `ch8.sh` was drafted by `draft-chapter.py` out of the book and then corrected by hand; every correction is marked `s390x:` or `unattended:`, the book's test suites are kept as comments |
| `tools/lfs/ch9-11.sh` | Chapters 9 to 11 for this machine: a channel-to-channel adapter as the network, no virtual console, `TERM=dumb` for PID 1 and the getty on the line-mode console, the udev hardware database compiled at build time, systemd's timeouts raised per unit type, `/dev/dasda1` in `fstab`, the kernel of 10.3, `/etc/zipl.conf` |
| `tools/lfs/resume-kernel.sh` | 10.3 taken up again after an interrupted `make`, in the tree the step left behind |
| `tools/lfs/s390-tools.sh` | s390-tools 2.38.0 in the chroot, the seven directories that need only the C library: libutil, libvtoc, libdasd, zipl, dasdfmt, fdasd, dasdview |
| `tools/mkdasd.py` `tools/mklfs.sh` | A 3390 in the Linux disk layout with an ext4 image on it; the finished tree onto such a volume, and its `.ins` |
| `run/linux.cnf` `stage0.rc` `stage1.rc` | The machine of stage 0 and 1: one z/Architecture processor, 512 MB, no devices; boot from the `.ins` |
| `run/lfs.cnf` `lfs.rc` `lfs-zipl.rc` `lfs-dasd.rc` | The machine of the LFS system (1 GB, the 3390 at 0120); boot from the `.ins`; boot, log in, run zipl and power off; IPL from the volume |
| `run/hercules.ps1` | Runs one of those machines in Hercules without a panel |
| `initramfs/stage0/init` | What runs as process 1 in stage 0 |
| `patches/` | What this project adds to the book's patches: gawk 5.4.1, see below |

## What S0 found out

- busybox 1.37.0 does not build for anything but x86 with its SHA
  acceleration on, nor `tc` against current kernel headers.
- `/dev/ttyS0` does not exist on s390: the line-mode console is
  `/dev/sclp_line0`, the VT220 one `/dev/ttysclp0`.
- Linux talks code page 500 on the line-mode console; Hercules reads and
  writes 037. The two differ in exactly five characters, `[ ] | ! ^`, so a
  `[` comes out as a blank and a `]` as `!`, and a `|` typed at the console
  does not reach the shell as one. Cosmetic until somebody needs a pipe.

## What S1 found out

- **`df` inside WSL says nothing about drive C:.** The distribution's disk is
  a file on C: that grows as it is written to, and `df` shows its virtual
  size - 932 GB free on a drive that had none. On 19.09.2026, twenty-three
  minutes into gcc pass 2, C: was full: every call into the file system
  answered with an I/O error, `wsl` could not even start a process
  (`getpwnam(...) failed 5`), and both builds ended with exit 126. After
  room had been made the journal replayed cleanly, all 94 tarballs still had
  their checksums and the cross compiler still built programs that ran; the
  stamps took the build up again at 6.18. `tools/lfs/rest.sh` now watches
  `df /mnt/c` once a minute and stops the build below 4 GB, and big files
  (the 3390-9 volume is 8.5 GB) can go to another drive: `tools/mklfs.sh D:/...`.
- `ftpmirror.gnu.org` redirects to a mirror of its choosing; that night every
  third one answered 404 or not at all. `tools/fetch-lfs.sh` asks ftp.gnu.org
  itself, and the book's md5sums say whether it is the same file.
- What the book does for x86_64 has a counterpart on s390x in each case:
  gcc's `t-linux64` with its `lib64` exists under `config/s390` as well; glibc
  puts everything into `/usr/lib` once `libc_cv_slibdir` is given, the dynamic
  linker `ld64.so.1` included, so `/lib/ld64.so.1` is found through the
  `lib -> usr/lib` link and no `lib64` is needed at all.
- A DASD is not used until it is set online. Without `dasd=0.0.0120` on the
  command line the kernel waits for `/dev/dasda1` for ever and says nothing
  about a device it can see perfectly well.

## What S2 found out

- **The chroot works without a copy of qemu inside it**: the binfmt_misc entry
  Ubuntu registers for `qemu-s390x` has the `F` flag, so the kernel keeps the
  interpreter open from outside the tree.
- **What is slow under qemu-user is `configure`, not the compiler.** Every one
  of its thousand questions starts a gcc that has to be translated first, one
  after the other, on one core: gettext 7108 seconds (most of it in its eight
  configure scripts), perl 2713, bison 1169 - while the load average stays
  near one. Chapters 7 and 8 are a matter of a day or two, not of hours.
- **zlib 1.3.2 does not build for anything below a z13 on s390x.** It has a
  CRC-32 for the vector facility, chosen at run time; `configure` finds the
  flags that unit needs ("vx vector extension (march=z13) ... Yes") and never
  writes `VGFMAFLAG` into the Makefile, so the unit is compiled with the
  compiler's default and ends in "`__builtin_s390_vec_unpackl` requires
  `-mvx`". Every distribution builds for a z13 or later and never sees it.
  `make VGFMAFLAG="-mzarch -march=z13"`.
  Fixed upstream the day after the release: commit `60ab906` of 18.02.2026
  ("Add setting of VGFMAFLAG to configure for s390x") adds the two `sed`
  lines that write it, so the next release will not need the argument.
- WSL stops the distribution some time after the last `wsl.exe` has gone. A
  build that has died leaves a stopped distribution behind, which looks like
  more of an accident than it is.
- **gawk 5.4.1 answers `"0"` for an array element that was never assigned -
  the second time it is asked.** `{ m = $2; print m P[m] "!" }` prints `A!`
  for the first line with an `A` and `A0!` for every one after it; 5.2.1 is
  right, and an x86 build of 5.4.1 is as wrong as the s390x one - as long as
  it is built without MPFR. In `NODE`, `vname` (`sub.nodep.name`) then lies
  over `stfmt` (`sub.val.idx`); `elem_new_reset()` clears `vname`, and with
  it turns `STFMT_UNUSED` (-1) into 0, "formatted with CONVFMT" - so the
  empty string counts as stale and the number, 0, is formatted anew. With
  MPFR the number union is 32 bytes wide and pushes `stfmt` out of the way,
  which is why the distributions never saw it and why chapter 8's gawk, which
  has MPFR, was never affected: the one without it is chapter 7's, and that
  one configures Python. `patches/gawk-5.4.1-unassigned_element-1.patch`
  puts `stfmt` back where an element becomes a scalar; it matters at 6.9 and
  is harmless at 8.31.
  Known upstream: LFS itself found it on 12.07.2026 (gcc's `optc-gen.awk`
  wrote `0Wunused-...` for `-Wunused-...`; the book's answer was to move
  gawk before gcc), and gawk-5.4-stable has had the fix since 14.07. -
  padding in `awk.h`, "a hack, pending a total refactoring of the NODE
  structure", due in 5.4.2 as "Gawk should now once again work correctly
  when compiled without the GMP and MPFR libraries".
  Why it matters here and nowhere else: autoconf's `config.status` writes
  `config.h` with exactly that idiom, `print prefix "define", macro P[macro]
  D[macro]`, and a macro that stands in the template twice comes out as
  `#define WORDS_BIGENDIAN0 1`. `WORDS_BIGENDIAN` is such a macro, and is set
  on big-endian machines only - where every package configured by that awk
  would then quietly have built itself for a little-endian one. Python was the
  one to refuse (`dtoa.c`: "doubles and ints have incompatible endianness");
  gettext, bison and mpdecimal had gone through and were built again.
- **Chapter 8 in figures:** 81 packages, 23 hours, 1.3 GB of system. The tree
  is copied without `/sources` and `/tools` into an ext4 image and that into a
  3390-3 by `tools/mklfs.sh`.

## What S3 found out

- **systemd's first boot compiles the udev hardware database**, and
  `systemd-udevd.service` waits for it (`After=systemd-hwdb-update.service`).
  On Hercules that took a minute, during which the getty units gave up on
  their devices ("Timed out waiting for device dev-sclp_line0.device") and
  the system came up without a login. Distributions ship `hwdb.bin` compiled
  and `/etc/.updated` written; `ch9-11.sh` does the same (`systemd-hwdb
  update`, `/usr/lib/systemd/systemd-update-done`), and the login came.
- **An emulated machine is slow, and systemd's timeouts are for a fast one.**
  At a few million instructions a second the 90 second timeouts killed
  `tmp.mount`, `systemd-sysctl` and `journald` and restarted them, for ever.
  `systemd-sysctl` and its kind carry `TimeoutSec=90s` of their own, which
  `DefaultTimeoutStartSec` does not reach; a drop-in for the whole type does
  (`/etc/systemd/system/service.d/slow-machine.conf` with
  `TimeoutStartSec`/`TimeoutStopSec`, and `mount.d/` and `socket.d/` with
  `TimeoutSec=`, the one name a mount and a socket have - `TimeoutStartSec`
  in `[Mount]` is "Unknown key, ignoring" at every boot), and udev's own
  patience with a worker (`event_timeout` in `udev.conf`) as much.
- A guest that is killed rather than powered off leaves ext4 with a journal
  to replay and journald with "corrupted or uncleanly shut down";
  `systemctl poweroff` on the console first.
- Typing at the console: the reply goes to the line-mode getty, and a login
  there gets `Login timed out after 60 seconds` when the password arrives
  late - on a slow machine `root` and `lfs` may need to be typed a minute
  apart.
- `norandmaps` on the kernel's command line (`mklfs.sh`): no address space
  layout randomisation. Not for the kernel's sake - for a dynamically
  translating emulator, whose translated code carries the addresses it was
  made under, so that every process having its C library at an address of
  its own means translating the library again for every process. Hercules
  does not care either way.

## Network: a channel-to-channel adapter

The machine's network is a CTC adapter - `0E20.2 CTCI <guest> <gateway>` in a
Hercules configuration, which on Windows needs the TunTap driver; the guest
is 192.168.50.2 and the other end 192.168.50.1.

- **The kernel side is two subchannels and a group.** The ctcm driver
  (`CONFIG_CTCM`, `CONFIG_CCWGROUP`) recognises the 3088 model 08 as a
  parallel CTC/A and waits to be told which two devices belong together:
  `echo 0.0.0e20,0.0.0e21 > /sys/bus/ccwgroup/drivers/ctcm/group` and then
  `online`. `ch9-11.sh` step `9.3-ctc` puts that into a oneshot unit before
  `systemd-networkd`, conditional on the read subchannel existing - on a
  machine without the adapter, grouping devices that are not there hung the
  boot for two minutes before failing.
- **The interface is called `slce20`**: the driver makes it as `ctc0` and
  udev renames it after the channel it hangs on ("renamed from ctc0" in the
  log), "slc" and the device number. The first `.network` file matched `ctc0`
  and the interface stood there without an address ("Network is
  unreachable"). `10-ctc.network` matches `slce20`, gives it 192.168.50.2 with
  the peer 192.168.50.1 and a default route over it (`GatewayOnLink`), and
  names 1.1.1.1 as the resolver; `/etc/resolv.conf` says the same and
  systemd-resolved stays off.
- No wget or curl in a base LFS; bash's `/dev/tcp` is the client:
  `HEAD / HTTP/1.0` to www.linuxfromscratch.org comes back with the server's
  301.

## The console

The console showed two kinds of noise: systemd's status lines -
`[***  ] Job ... running`, redrawn in place with a carriage return, which the
line-mode console shows as a line each - and, around the login prompt, a
second banner from a getty on `ttysclp0` with systemd's terminal reset and
size probe as garbage. Both come from the same thing: nobody had told PID 1
that the console is a typewriter. `TERM=dumb` on the kernel's command line
(`zipl_conf` in `ch9-11.sh`, `mklfs.sh`) is PID 1's TERM and stops the
ephemeral lines and the escape sequences; the second getty is what systemd's
getty generator adds on s390 for the VT220 flavour of the same SCLP console,
and `9.6-console` masks it - what is typed reaches `sclp_line0` only. The
progress line systemd repeats once a second while a job takes long stays,
as a line each: that is what it does on a dumb terminal.

## What S4 found out

- **zipl runs where a distribution runs it: on the system itself.** It asks
  the DASD driver for the disk's geometry (`BIODASDINFO`) and ext4 for the
  blocks the kernel and the boot map lie in (`FIBMAP`), and writes stage 0
  and 1 into record 1 of track 0 - a PSW and a chain of CCWs that seek,
  search and read stage 1b, which reads stage 2, which reads the boot map.
  Built in the chroot (`s390-tools.sh`, seven directories of the package),
  configured by `ch9-11.sh` (`/etc/zipl.conf`, `/boot/parmfile`), run on
  Hercules by `lfs-zipl.rc`.
- Hercules takes a line beginning with `.` in its `.rc` file as input for the
  guest's console (`HHC00160I SCP command`), which is how a login and a
  command are typed without a panel - after a pause long enough for the
  prompt, which came after 112 seconds on Hercules and not the 100 the first
  attempt allowed; the poweroff was typed as a user name. With the kernel of
  10.3, 31 MB with modules, the prompt comes at about 220 s, and
  `lfs-zipl.rc` waits 280.

## Towards the book's own system: 9.9 and 10.3

What was still not the book's, looked at with the whole of chapter 8 built:
no test suite has run (the book's `make check` stands as a comment in every
package, because under qemu-user the suites are days and would be testing
qemu), the kernel was cross-built from `tinyconfig` without modules, and
`/etc/shells` was missing. The last two are the book's now:

- **9.9** writes `/etc/shells` (`sh` and `bash`).
- **10.3 builds the kernel in the chroot** with the system's own gcc 16.2,
  from `make defconfig` with `config/lfs.config` laid over it by
  `merge_config.sh` - the fragment the cross-built kernel was made from,
  with `CONFIG_MODULES=y` this time, z10 instead of the defconfig's z13,
  100 Hz instead of 1000, four CPUs, no DWARF - and `olddefconfig` for the
  rest. 1299 options built in, 638 modules; the book's list for systemd is
  all there, the strong stack protector included, which the host's gcc 13
  could not give the cross-built one. `make`, `make modules_install`, the
  three files into `/boot`, the documentation into
  `/usr/share/doc/linux-7.1.8`. Under qemu-user it was nine and a half
  hours for 4662 objects, interrupted once - `tools/lfs/resume-kernel.sh`
  takes a build up again in the tree the step left behind.
- `mklfs.sh` takes the tree's kernel when there is one, for the volume and
  for the `.ins`, and falls back to the cross-built one. With it: login, 18
  modules loaded by udev on their own (pkey, s390_trng, aes_s390, vfio_ccw
  ...), the network as before, no failed unit.

What remains not the book's: the test suites, and the two patches the
book does not have (gawk, zlib - both fixed upstream since).

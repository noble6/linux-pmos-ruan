#!/bin/bash
# Test boot.img + vendor_boot.img for mainline on ruan.
#
#   mkimg.sh <stock boot.img> <stock vendor_boot.img>
#
# Takes the header values (and boot.img's AVB footer) from a ROM's images
# and replaces the kernel, the dtb and the command line. The initramfs is
# built into the Image; both ramdisks are empty. Output in $O/ruan/img.
#
#   O=<build dir>  default ../out-ml
#   CMDLINE        appended to the kernel command line
set -euo pipefail
K=$(cd "$(dirname "$0")/.." && pwd)
O=$(realpath -m "${O:-$K/../out-ml}")
BOOT=$(realpath "$1")
VBOOT=$(realpath "$2")
W=$O/ruan/img
rm -rf $W && mkdir -p $W/empty

(cd $W/empty && find . | cpio -o -H newc --quiet -R 0:0) > $W/empty.cpio

# dtb: the bootloader applies ruan's overlay from the stock dtbo partition
# on top of it. Point every label the overlay uses at /dtbo-sink (it finds
# its targets by phandle), so it applies and nothing it adds is probed.
cp $O/arch/arm64/boot/dts/qcom/sm7435-xiaomi-ruan.dtb $W/ruan.dtb
max=$(dtc -q -I dtb -O dts $W/ruan.dtb | grep -oE 'phandle = <0x[0-9a-f]+>' | grep -oE '0x[0-9a-f]+' |
	while read p; do echo $((p)); done | sort -n | tail -1)
fdtput -t x $W/ruan.dtb /dtbo-sink phandle $(printf '%x' $((${max:-0} + 1)))
fdtput -c $W/ruan.dtb /__symbols__ 2>/dev/null || true
for l in $(cat $K/ruan/dtbo-labels.txt); do
	fdtput -t s $W/ruan.dtb /__symbols__ $l /dtbo-sink
done

# vendor_boot: stock header values, our dtb and cmdline, empty ramdisk
python3 -I - "$VBOOT" "$W" "${CMDLINE:-}" <<'EOP'
import shlex, subprocess, sys
vboot, w, extra = sys.argv[1:]
args = shlex.split(subprocess.run(['unpack_bootimg', '--boot_img', vboot,
                                   '--out', w + '/vb', '--format', 'mkbootimg'],
                                  capture_output=True, text=True, check=True).stdout)
cmdline = 'console=tty0 fbcon=font:TER16x32 loglevel=8 ignore_loglevel printk.time=1 ' \
          'clk_ignore_unused pd_ignore_unused rdinit=/init'
if extra:
    cmdline += ' ' + extra
out = []
i = 0
while i < len(args):
    a = args[i]
    if a == '--dtb':
        out += [a, w + '/ruan.dtb']; i += 2; continue
    if a == '--vendor_ramdisk_fragment':
        out += [a, w + '/empty.cpio']; i += 2; continue
    if a == '--vendor_cmdline':
        out += [a, cmdline]; i += 2; continue
    out.append(a); i += 1
subprocess.run(['mkbootimg'] + out + ['--vendor_boot', w + '/vendor_boot.img'], check=True)
EOP

# boot: our kernel and an empty ramdisk
mkdir $W/b
(cd $W/b && magiskboot unpack $BOOT >/dev/null 2>&1 && cp $O/arch/arm64/boot/Image kernel \
	&& cp $W/empty.cpio ramdisk.cpio && magiskboot repack $BOOT $W/boot.img >/dev/null 2>&1)

ls -la $W/boot.img $W/vendor_boot.img
echo "kernel $(cat $O/include/config/kernel.release)"

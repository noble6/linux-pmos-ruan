#!/bin/bash
# Build mainline for ruan: arm64 defconfig + ruan/ruan.config, with a
# busybox test initramfs built in.
#
#   O=<build dir>  default ../out-ml
set -euo pipefail
K=$(cd "$(dirname "$0")/.." && pwd)
O=$(realpath -m "${O:-$K/../out-ml}")
mkdir -p $O/ruan

# static busybox from Alpine
BB=$O/ruan/busybox
if [ ! -f $BB ]; then
	A=https://dl-cdn.alpinelinux.org/alpine/v3.22/main/aarch64
	apk=$(curl -fs $A/ | grep -oE 'busybox-static-[0-9][^"]*\.apk' | head -1)
	mkdir -p $O/ruan/apk
	curl -fs $A/$apk | tar -xz -C $O/ruan/apk 2>/dev/null || true
	cp $O/ruan/apk/bin/busybox.static $BB
fi
cat > $O/ruan/initramfs.list <<EOL
dir /bin 755 0 0
dir /dev 755 0 0
dir /proc 755 0 0
dir /sys 755 0 0
nod /dev/console 600 0 0 c 5 1
file /bin/busybox $BB 755 0 0
file /init $K/ruan/initramfs/init 755 0 0
EOL

cd $K
M="make O=$O ARCH=arm64 LLVM=1 -j$(nproc)"
$M defconfig
echo "CONFIG_INITRAMFS_SOURCE=\"$O/ruan/initramfs.list\"" | cat ruan/ruan.config - > $O/ruan/ruan.config
scripts/kconfig/merge_config.sh -m -O $O $O/.config $O/ruan/ruan.config >/dev/null
$M olddefconfig
$M Image qcom/sm7435-xiaomi-ruan.dtb

# Mainline Linux on ruan

Xiaomi Redmi Pad Pro 5G / POCO Pad 5G (SM7435, "parrot"), toward
postmarketOS.

Mainline has no SM7435 support yet. Its closest relative upstream is
SM4450 (Qualcomm's "Ravelin", which shares parrot's downstream tree).
Xiaomi's GPL 5.10 sources have the parrot clock, pinctrl and interconnect
drivers to port from.

## Status

| Part | State |
|---|---|
| CPUs, GIC, timer, PSCI | in the DT, untested |
| Watchdog (left running by the bootloader) | qcom-wdt built in, untested |
| Screen | bootloader splash as simple-framebuffer, untested |
| Everything else | not started |

## Files

- `arch/arm64/boot/dts/qcom/sm7435.dtsi`, `sm7435-xiaomi-ruan.dts`
- `ruan/ruan.config`: added on top of arm64 defconfig (no modules)
- `ruan/initramfs/init`: busybox test init, prints `ruan: alive Ns` to
  the kernel log every 5 s
- `ruan/dtbo-labels.txt`: labels ruan's stock dtbo overlay resolves

## Building

Needs clang/lld, dtc and fdtput, mkbootimg/unpack_bootimg and magiskboot.

```
ruan/build.sh
ruan/mkimg.sh <ROM boot.img> <ROM vendor_boot.img>
```

Images land in `../out-ml/ruan/img`. The ROM images only supply header
values; any recent ruan ROM works.

## Testing

```
fastboot flash boot_a boot.img
fastboot flash vendor_boot_a vendor_boot.img
fastboot --set-active=a
fastboot reboot
```

Only boot and vendor_boot change; dtbo, system, vendor and userdata are
left alone. The bootloader still applies the stock dtbo overlay: every
label it uses points at the disabled `/dtbo-sink` node.

To go back to Android, hold Volume Down for fastboot and flash the ROM's
boot.img and vendor_boot.img to `boot_a` and `vendor_boot_a`.

After repeated failed boots the bootloader switches to the other slot;
`fastboot --set-active=a` before each test.

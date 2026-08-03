# AGENTS.md

TWRP / OrangeFox recovery device tree for the itel P55 5G (P661N), MediaTek Dimensity 6080 (MT6833).

## This is not a standalone project

It is a device tree for a full Android 12.1 recovery source tree. It **cannot be built in this repo**. It is cloned into `device/itel/P661N` inside a full recovery tree (minimal-manifest-twrp `twrp-12.1` for TWRP, or OrangeFox `sync` for OFOX) and built there. Do not attempt a local AOSP build — use the GitHub Actions workflows (`.github/workflows/twrp.yml`, `.github/workflows/ofox.yml`, both `workflow_dispatch`-only).

## Branches

- `twrp-12.1` — TWRP build. Patches + bare vendorsetup.sh (applies haptics patch only).
- `fox_12.1` — OrangeFox build. Adds `OF_*`/`FOX_*` settings in BoardConfig.mk/vendorsetup.sh, flashlight kernel modules in `recovery/root/lib/modules/`, and a second (flashlight) patch.
- README's `-b android-12.1` clone command is stale; no such branch exists.

## Build

```sh
. build/envsetup.sh; lunch twrp_P661N-eng   # lunch combo from AndroidProducts.mk
export ALLOW_MISSING_DEPENDENCIES=true
m vendorbootimage                            # TWRP (README says vendorbootimage)
mka adbd vendorbootimage                     # OrangeFox (ofox.yml); make clean first
```

- Build target is always `vendorboot`: this device has **no recovery partition** — recovery is packed into `vendor_boot` (recovery-as-vendor-boot, Virtual A/B). See `TW_HAS_NO_RECOVERY_PARTITION`, `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE`, `BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT`, `TARGET_NO_RECOVERY`.
- **No kernel build**: `TARGET_NO_KERNEL=true`; kernel comes from prebuilt `prebuilt/dtb.img` + prebuilt `.ko` modules in `recovery/root/lib/modules/` (loaded via `TW_LOAD_VENDOR_BOOT_MODULES`).
- Both branches are `eng`/debug (logcat, `TARGET_USES_LOGD`).

## Patches

`patches/*.patch` modify the **recovery source** (`bootable/recovery`), not this repo. They are applied automatically to the workspace root (`patch -p1 -N`) by `vendorsetup.sh`, which is sourced during `envsetup`/`lunch`. If you change these patches, update vendorsetup.sh's `patch_files` list too.

## Don't break

- Crypto/FBE chain: `system.prop` forces Trustonic TEE keymaster/gatekeeper (`ro.hardware.kmsetkey=trustonic`, `ro.hardware.gatekeeper=trustonic`, `keymaster_ver=4.1`); BoardConfig.mk sets fscrypt policy v2 + FBE metadata decrypt. This is what makes `decrypt /data` work.
- fstab uses `/dev/block/by-name/tranfs` as `/cache` (no cache partition); system/vendor/product/system_ext are erofs, userdata f2fs.
- `bootctrl/` (MTK UFS boot control HAL) and `create_pl_dev/` (DM devices for MTK preloader raw partitions so update_engine can flash preloader) are device-specific additions required for Virtual A/B on this platform. Both are only built when `TARGET_DEVICE == P661N` (Android.mk guard).
- `OF_FLASH_LIGHT_*`/`OF_FL_PATH1` and the vendorsetup `FOX_*` exports are MTK-specific paths verified on-device; keep them consistent across BoardConfig.mk, system.prop, and recovery/root files.
- Battery metering: the MTK `mt6359p` gauge + Transsion layer re-derives SOC from a broken ZCV when booted with `shutdown_time:0` (any hard reboot into recovery), corrupting the persisted SOC. To match system behavior, recovery ships the stock GM30 FG daemon: launcher `recovery/root/vendor/bin/fuelgauged` (source: `fuelgauged/fuelgauged.c`) + `recovery/root/vendor/lib64/{libfgauge_gm30.so,libmtk_drvb.so,mt6833/libmtk_drvb.so}`, started by `init.custom.rc` which mounts `/dev/block/by-name/nvcfg` at `/mnt/vendor/nvcfg` first. Keep the launcher path, the nvcfg mount, and the service in sync.

## Sanity checks

- `TARGET_OTA_ASSERT_DEVICE := P661N`, `TARGET_BOARD_PLATFORM := mt6833` must stay matched to the actual device.
- Partition sizes (boot 40 MiB, vendor_boot 64 MiB, super ~9.1 GiB) and `BOARD_BOOT_HEADER_VERSION := 4` are fixed by the stock firmware — don't change without a reason.

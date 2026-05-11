#!/bin/bash
#
#	This file is part of the OrangeFox Recovery Project
# 	Copyright (C) 2020-2026 The OrangeFox Recovery Project
#
#	OrangeFox is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	any later version.
#
#	OrangeFox is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
# 	This software is released under GPL version 3 or any later version.
#	See <http://www.gnu.org/licenses/>.
#
# 	Please maintain this if you use this script or any part of it
#
	export LC_ALL="C.UTF-8"
	export ALLOW_MISSING_DEPENDENCIES=true

#OFR build settings & info
	export TARGET_DEVICE_ALT="P661N"
	export FOX_RECOVERY_SYSTEM_PARTITION="/dev/block/mapper/system"
	export FOX_RECOVERY_VENDOR_PARTITION="/dev/block/mapper/vendor"
	export FOX_VENDOR_BOOT_RECOVERY_FULL_REFLASH=1
	export FOX_VENDOR_BOOT_RECOVERY=1
	export FOX_DELETE_MAGISK_ADDON=1
	export FOX_DELETE_AROMAFM=1
	export FOX_ENABLE_APP_MANAGER=1
	export FOX_SETTINGS_ROOT_DIRECTORY=/persist/OFRP
	export FOX_RESET_SETTINGS=1
    export OF_DISABLE_MIUI_SPECIFIC_FEATURES=1

	#OFR binary files
	export FOX_USE_BASH_SHELL=1
	export FOX_USE_NANO_EDITOR=1
	export FOX_USE_TAR_BINARY=1
	export FOX_USE_SED_BINARY=1
	export FOX_USE_XZ_UTILS=1
	export FOX_ASH_IS_BASH=1
	export OF_ENABLE_LPTOOLS=1

	#OTA
	export FOX_AB_DEVICE=1
	export FOX_VIRTUAL_AB_DEVICE=1
	export OF_SUPPORT_VBMETA_AVB2_PATCHING=1

device_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(cd "${device_dir}/../../.." && pwd)"
patch_files=(
	"${device_dir}/patches/0001-Add-regulator-vibrator-haptics-support.patch"
	"${device_dir}/patches/0002-Support-direct-file-flashlight-paths.patch"
)

if ! command -v patch >/dev/null 2>&1; then
	echo "[P661N] Missing required command: patch"
else
	for patch_file in "${patch_files[@]}"; do
		patch_name="$(basename "${patch_file}")"
		if [ ! -f "${patch_file}" ]; then
			echo "[P661N] Missing patch: ${patch_file}"
		elif (
			cd "${workspace_root}" &&
			patch -p1 -N --dry-run --silent < "${patch_file}" >/dev/null 2>&1
		); then
			if (
				cd "${workspace_root}" &&
				patch -p1 -N --silent < "${patch_file}" >/dev/null 2>&1
			); then
				echo "[P661N] Applied patch: ${patch_name}"
			else
				echo "[P661N] Failed to apply patch: ${patch_name}"
			fi
		else
			echo "[P661N] Patch already applied or not applicable: ${patch_name}"
		fi
	done
fi

unset device_dir workspace_root patch_files patch_file patch_name

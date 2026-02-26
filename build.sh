#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

version="21.3-Omega"
source_img_name="CoreELEC-Amlogic-ng.arm-${version}-Generic"
source_img_file="${source_img_name}.img.gz"
source_img_url="https://github.com/CoreELEC/CoreELEC/releases/download/${version}/${source_img_file}"
target_img_prefix="CoreELEC-Amlogic-ng.arm-${version}"
target_img_name="${target_img_prefix}-E900V22C-$(date +%Y.%m.%d)"
common_files="common-files"
kodi_userdata="${mount_point}/.kodi/userdata"
mksquash_opts="-comp lzo -Xalgorithm lzo1x_999 -Xcompression-level 9 -b 524288 -no-xattrs"

# Prepare Image
wget -q --show-progress ${source_img_url} -O ${source_img_file} || exit 1
gzip -d ${source_img_file} || exit 1
LOOP=$(losetup --find --show -P "${source_img_name}.img")

# Modify boot partition
mkdir -p /mnt/ce_boot
mount "${LOOP}p1" /mnt/ce_boot
install -m 0644 "${common_files}/e900v22c.dtb" /mnt/ce_boot/dtb.img
unsquashfs -d /tmp/ce_system /mnt/ce_boot/SYSTEM
install -m 0664 "${common_files}/wifi_dummy.conf" /tmp/ce_system/usr/lib/modules-load.d/wifi_dummy.conf
mkdir -p /tmp/ce_system/usr/lib/systemd/system/multi-user.target.wants
ln -s ../sprd_sdio-firmware-aml.service /tmp/ce_system/usr/lib/systemd/system/multi-user.target.wants/sprd_sdio-firmware-aml.service
install -m 0775 "${common_files}/fs-resize" /tmp/ce_system/usr/lib/libreelec/fs-resize
install -m 0664 "${common_files}/rc_maps.cfg" /tmp/ce_system/usr/config/rc_maps.cfg
mkdir -p /tmp/ce_system/usr/config/rc_keymaps
install -m 0664 "${common_files}/e900v22c.rc_keymap" /tmp/ce_system/usr/config/rc_keymaps/e900v22c
mkdir -p /tmp/ce_system/usr/config/hwdb.d
install -m 0664 "${common_files}/keymap.hwdb" /tmp/ce_system/usr/config/hwdb.d/keymap.hwdb
mksquashfs /tmp/ce_system SYSTEM ${mksquash_opts}
mv SYSTEM /mnt/ce_boot/SYSTEM
sh -c "md5sum /mnt/ce_boot/SYSTEM | awk '{print \$1}' > /mnt/ce_boot/SYSTEM.md5"
umount /mnt/ce_boot

# Modify data partition
mkdir -p /mnt/ce_data
mount "${LOOP}p2" /mnt/ce_data
mkdir -p -m 0755 "/mnt/ce_data/${kodi_userdata_prefix}/keymaps"
install -m 0644 "${common_files}/advancedsettings.xml" "/mnt/ce_data/${kodi_userdata_prefix}/advancedsettings.xml"
install -m 0644 "${common_files}/backspace.xml" "/mnt/ce_data/${kodi_userdata_prefix}/keymaps/backspace.xml"
umount /mnt/ce_data

# Output Image
losetup -d "${LOOP}"
mv "${source_img_name}.img" "${target_img_name}.img"
gzip -9 -c "${target_img_name}.img"
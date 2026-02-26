#!/bin/sh

if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

version="21.3-Omega"
source_img_name="CoreELEC-Amlogic-ng.arm-${version}-Generic"
source_img_file="${source_img_name}.img.gz"
source_img_url="https://github.com/CoreELEC/CoreELEC/releases/download/${version}/${source_img_file}"
target_img_prefix="CoreELEC-Amlogic-ng.arm-${version}"
target_img_name="${target_img_prefix}-E900V22C-$(date +%Y.%m.%d)"
mount_point="target"
common_files="common-files"
system_root="SYSTEM-root"
modules_load_path="${system_root}/usr/lib/modules-load.d"
systemd_path="${system_root}/usr/lib/systemd/system"
libreelec_path="${system_root}/usr/lib/libreelec"
config_path="${system_root}/usr/config"
kodi_userdata="${mount_point}/.kodi/userdata"

# Prepare functions
mount_partition() {
  img=$1
  offset=$2
  mount_point=$3
  mount -o loop,offset=${offset} ${img} ${mount_point}
}
unmount_partition() {
  mount_point=$1
  umount -d ${mount_point}
}
copy_with_permissions() {
  src=$1
  dest=$2
  mode=$3
  cp ${src} ${dest}
  chown root:root ${dest}
  chmod ${mode} ${dest}
}

# Prepare Image
curl -sSL "${source_img_url}" -o "${source_img_file}"
gzip -d ${source_img_file}
mkdir ${mount_point}

# Modify boot partition
mount_partition ${source_img_name}.img 4194304 ${mount_point}
cp ${common_files}/e900v22c.dtb ${mount_point}/dtb.img
unsquashfs -d ${system_root} ${mount_point}/SYSTEM
copy_with_permissions ${common_files}/wifi_dummy.conf ${modules_load_path}/wifi_dummy.conf 0664
copy_with_permissions ${common_files}/sprd_sdio-firmware-aml.service ${systemd_path}/sprd_sdio-firmware-aml.service 0664
ln -s ../sprd_sdio-firmware-aml.service ${systemd_path}/multi-user.target.wants/sprd_sdio-firmware-aml.service
copy_with_permissions ${common_files}/fs-resize ${libreelec_path}/fs-resize 0775
copy_with_permissions ${common_files}/rc_maps.cfg ${config_path}/rc_maps.cfg 0664
copy_with_permissions ${common_files}/e900v22c.rc_keymap ${config_path}/rc_keymaps/e900v22c 0664
copy_with_permissions ${common_files}/keymap.hwdb ${config_path}/hwdb.d/keymap.hwdb 0664
mksquashfs ${system_root} SYSTEM -comp lzo -Xalgorithm lzo1x_999 -Xcompression-level 9 -b 524288 -no-xattrs
rm ${mount_point}/SYSTEM.md5
dd if=/dev/zero of=${mount_point}/SYSTEM bs=4M || true
sync
rm ${mount_point}/SYSTEM
mv SYSTEM ${mount_point}/SYSTEM
md5sum ${mount_point}/SYSTEM > target/SYSTEM.md5
rm -rf ${system_root}
unmount_partition ${mount_point}

# Modify data partition
mount_partition ${source_img_name}.img 541065216 ${mount_point}
mkdir -p -m 0755 ${kodi_userdata}/keymaps
copy_with_permissions ${common_files}/advancedsettings.xml ${kodi_userdata}/advancedsettings.xml 0644
copy_with_permissions ${common_files}/backspace.xml ${kodi_userdata}/keymaps/backspace.xml 0644
unmount_partition ${mount_point}
rm -rf ${mount_point}

# Output Image
mv ${source_img_name}.img ${target_img_name}.img
gzip ${target_img_name}.img
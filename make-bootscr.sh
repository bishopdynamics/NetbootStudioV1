#!/usr/bin/env bash

TARGET_PATH="/opt/tftp-root/tftp-bin"

echo ""
echo " turning boot.cmd into boot.scr.uimg for booting arm64 clients using u-boot"
#mkimage -A arm -O linux -T script -C none -n boot.cmd -d boot.cmd boot.scr.uimg
mkimage -A arm -O linux -T script -C none -d boot.cmd boot.scr.uimg


echo "deploying it to ${TARGET_PATH}/boot.scr.uimg"
if [ -f "${TARGET_PATH}/boot.scr.uimg" ]; then
	rm "${TARGET_PATH}/boot.scr.uimg"
fi

cp boot.scr.uimg "${TARGET_PATH}/boot.scr.uimg"

echo "done"

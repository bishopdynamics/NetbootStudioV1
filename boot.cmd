
# shellcheck disable=SC2034,SC2154,SC2086,SC1090,SC2128  # var-unused, var-referenced-but-not-defined, double-quote-glob-splitting, dont-track-source-scripts, expanding-array-without-index

# this is to redirect arm64 devices using uboot to use the correct bootfile
# it must be compiled into boot.scr.uimg using make-bootscr.sh
# you must then place boot.scr.uimg at the tftp root, in our case /opt/tftp-root/tftp-bin/boot.scr.uimg

echo ""
echo "#######################################################################"
echo "               Start of NetbootStudio boot.scr.uimg"
echo ""

# - vendor=rockchip
# - arch=arm
# - board=evb_rk3399
# - board_name=evb_rk3399
# - cpu=armv8
# - soc=rk3399

# we could look for image specific to vendor and board, next try generic for cpu, then just try arm64 generic
# 	for now, the standard arm64 ipxe binary works fine for everything we are doing
# setenv board_specific_bootfile /ipxe/ipxe-${cpu}-${vendor}-${board}.efi
# setenv cpu_type_bootfile /ipxe/ipxe-${cpu}-efi.efi
setenv generic_bootfile /ipxe/ipxe-arm64-efi.efi
setenv bootfile ${generic_bootfile}

# dump a bunch of vars for fun
echo "arch: ${arch}"
echo "board: ${board}"
echo "cpu: ${cpu}"
echo "soc: ${soc}"
echo "fdtfile: ${fdtfile}"
echo "ethaddr: ${ethaddr}"
echo "bootfile: ${bootfile}"

# a lot more could be done here, but all that is needed is to set the bootfile

echo ""
echo "               End of NetbootStudio boot.scr.uimg"
echo "#######################################################################"

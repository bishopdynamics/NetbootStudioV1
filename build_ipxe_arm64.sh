#!/bin/bash
# Netboot Studio artifact build script for arm64 target

#    This file is part of Netboot Studio, a system for managing netboot clients
#    Copyright (C) 2019 James Bishop (jamesbishop2006@gmail.com)

#   build ipxe binary for arm64

# common functions
source ./common.sh

# sudo apt install build-essential git sed grep mtools perl genisoimage liblzma-dev syslinux binutils unzip isolinux
DEPENDENCIES="make git sed grep mformat perl genisoimage unzip wget awk md5sum"
check_deps "$DEPENDENCIES"
###################################################################################################################
#######################  constants
###################################################################################################################
#IPXE_URL="git://git.ipxe.org/ipxe.git"
IPXE_URL="https://github.com/ipxe/ipxe"


if [ -z "$1" ]; then
  IPXE_COMMIT="988d2c1" # Dec 31, 2020, latest as of initial testing with arm64 on 2021-09-28
else
  IPXE_COMMIT="$1"
fi
MAKE_ARGS="-j6" # assuming we are using our fancy 6-core buildvm

# list of ipxe targets to build

BUILD_TARGET="bin-arm64-efi/ipxe.efi"

CURRENT_DIR=$(pwd)
# warning, does not like the spaces in the full path
MENU_FILE="${CURRENT_DIR}/netboot-studio-stage1-textonly.ipxe"
BUILD_DIR="${CURRENT_DIR}/dist" # where binaries end up at end of this build
BUILD_VERSIONS_DIR="${CURRENT_DIR}/dist-versions" # where we store things with commit ID for archival purposes
BUILD_VDIR="${BUILD_VERSIONS_DIR}/${IPXE_COMMIT}" # this particular commit folder


###################################################################################################################
#######################  setup workspce
###################################################################################################################

announce "Preparing to build commit: ${IPXE_COMMIT}"

# check for existing build for this commit
if [ -d "$BUILD_VDIR" ]; then
  echo "A build already exists for commit ${IPXE_COMMIT} at ${BUILD_VDIR}"
  exit
fi
# temp workspace for build
WORKSPACE=$(mktemp -d)
cd_to "${WORKSPACE}"

###################################################################################################################
#######################  We are now in temp workspace, and will stay here until build is complete
###################################################################################################################

###################################################################################################################
#######################  Prepare to build iPXE binaries
###################################################################################################################
announce "preparing to build ipxe binaries"
# clone ipxe, then checkout the configured commit id
echo "cloning ipxe git repo"
do_cmd git clone "$IPXE_URL"
cd_to ipxe/src
echo "checking out commit: $IPXE_COMMIT"
do_cmd git checkout "$IPXE_COMMIT"


function enable_build_option {
  # apparently this is the right way to do this: http://ipxe.org/gsoc/nfs
  local OPTION_NAME="$1"
  local FILE_NAME="$2"
  echo "Enabling option: $OPTION_NAME in $FILE_NAME"
  echo "#define ${OPTION_NAME}" >> "config/local/${FILE_NAME}"
}


function disable_build_option {
  # apparently this is the right way to do this: http://ipxe.org/gsoc/nfs
  local OPTION_NAME="$1"
  local FILE_NAME="$2"
  echo "Disabling option: $OPTION_NAME in $FILE_NAME"
  echo "#undef ${OPTION_NAME}" >> "config/local/${FILE_NAME}"
}


announce "applying build options"



# These options are needed because uboot does not support interrupts
# https://ericdraken.com/cluster-computer-gotchas/#interrupts
disable_build_option "NAP_PCBIOS" "nap.h"
disable_build_option "NAP_EFIX86" "nap.h"
disable_build_option "NAP_EFIARM" "nap.h"
enable_build_option "NAP_NULL" "nap.h"

# i hate ipv6
disable_build_option "NET_PROTO_IPV6" "general.h"

# this is pretty much all the general options we can enable on arm64
enable_build_option "DOWNLOAD_PROTO_HTTPS" "general.h"
enable_build_option "DOWNLOAD_PROTO_NFS" "general.h"
enable_build_option "PCI_CMD" "general.h"
enable_build_option "IMAGE_PNG" "general.h"
enable_build_option "CONSOLE_CMD" "general.h"
enable_build_option "IPSTAT_CMD" "general.h"
enable_build_option "PING_CMD" "general.h"
enable_build_option "NSLOOKUP_CMD" "general.h"
enable_build_option "TIME_CMD" "general.h"
enable_build_option "REBOOT_CMD" "general.h"
enable_build_option "POWEROFF_CMD" "general.h"
enable_build_option "VLAN_CMD" "general.h"
enable_build_option "LOTEST_CMD" "general.h"
enable_build_option "PROFSTAT_CMD" "general.h"
enable_build_option "IMAGE_EFI" "general.h"

enable_build_option "CONSOLE_FRAMEBUFFER" "console.h"


# we dont need usb support within the ipxe
disable_build_option  "USB_HCD_XHCI" "usb.h"
disable_build_option  "USB_HCD_EHCI" "usb.h"
disable_build_option  "USB_HCD_UHCI" "usb.h"
disable_build_option  "USB_KEYBOARD" "usb.h"
disable_build_option  "USB_BLOCK" "usb.h"
disable_build_option  "USB_EFI" "usb.h"

# shorten the ipxe watchdog timer reset from 5 minutes to 1 minute
# iPXE then has one minute to hand off execution control to the kernel
# sed -i -E 's|^#define\s+WATCHDOG_TIMEOUT_SECS.+$|#define WATCHDOG_TIMEOUT_SECS 60|' "interface/efi/efi_watchdog.c"

###################################################################################################################
#######################  actually build ipxe binaries and place them in BUILD_DIR/
###################################################################################################################
rm -r "${BUILD_DIR}" 2>/dev/null
do_cmd mkdir "${BUILD_DIR}"
announce "building all targets"
do_cmd make ${MAKE_ARGS} "$BUILD_TARGET" "EMBED=${MENU_FILE}" "CROSS_COMPILE=aarch64-linux-gnu-" "ARCH=arm64"




###################################################################################################################
#######################  wrap it all up ready for deploy.sh
###################################################################################################################


announce_step "grabbing all the files"
# clear build dir only after successful build

mkdir -p "$BUILD_DIR"
# put all the built files where we want them
do_cmd cp "${WORKSPACE}/ipxe/src/${BUILD_TARGET}" "${BUILD_DIR}/ipxe-arm64-efi.efi"


announce_step "calculating md5sums"
cd_to "$BUILD_DIR"
echo "" > "checksums.txt"
for FILE_NAME in $(ls -1); do
  if [ "$FILE_NAME" == "checksums.txt" ]; then
    continue
  fi
  THIS_SUM=$(md5sum "$FILE_NAME" |awk '{print $1}')
  echo "$FILE_NAME $THIS_SUM" >> "checksums.txt"
done

do_cmd mkdir -p "${BUILD_VDIR}"
do_cmd cp ./* "${BUILD_VDIR}/"

cd_to "$CURRENT_DIR"
announce "done building images"

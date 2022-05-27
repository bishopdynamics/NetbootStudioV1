#!/bin/bash
# Netboot Studio artifact build script

#    This file is part of Netboot Studio, a system for managing netboot clients
#    Copyright (C) 2019 James Bishop (jamesbishop2006@gmail.com)

#   build ipxe binaries

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
WIMBOOT_URL="http://git.ipxe.org/releases/wimboot/wimboot-latest.zip"

if [ -z "$1" ]; then
  #IPXE_COMMIT="13a6d17" # Nov 29, 2020
  IPXE_COMMIT="988d2c1" # Dec 31, 2020, latest release as of 2021-09-28
else
  IPXE_COMMIT="$1"
fi
MAKE_ARGS="-j4"

# list of ipxe targets to build
# wont build:
#   bin-i386-efi/ipxe.iso
#   bin-x86_64-efi/ipxe.iso
# but both will build .usb, which can be substitued in most cases
BUILD_TARGET_LIST="
bin-x86_64-pcbios/ipxe.pxe
bin-x86_64-pcbios/ipxe.iso
bin-x86_64-pcbios/ipxe.usb
bin-x86_64-efi/ipxe.efi
bin-x86_64-efi/ipxe.usb
bin-i386-efi/ipxe.efi
bin-i386-efi/ipxe.usb
bin-i386-pcbios/ipxe.pxe
bin-i386-pcbios/ipxe.usb
bin-i386-pcbios/ipxe.iso
"

CURRENT_DIR=$(pwd)
# warning, does not like the spaces in the full path
MENU_FILE="${CURRENT_DIR}/netboot-studio-stage1.ipxe"
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

# fix for stupid PIE GCC bug: http://lists.ipxe.org/pipermail/ipxe-devel/2018-January/006008.html
echo  "CFLAGS   += -fno-pie" >> arch/x86/Makefile.pcbios || exit 1
echo  "LDFLAGS  += -no-pie" >> arch/x86/Makefile.pcbios || exit 1


function enable_build_option {
  # apparently this is the right way to do this: http://ipxe.org/gsoc/nfs
  local OPTION_NAME="$1"
  local FILE_NAME="$2"
  echo "Applying option: $OPTION_NAME in $FILE_NAME"
  echo "#define ${OPTION_NAME}" >> "config/local/${FILE_NAME}"
}


announce "applying build options"

enable_build_option "DOWNLOAD_PROTO_HTTPS" "general.h"
enable_build_option "DOWNLOAD_PROTO_NFS" "general.h"
enable_build_option "PCI_CMD" "general.h"
enable_build_option "IMAGE_PNG" "general.h"
enable_build_option "CONSOLE_CMD" "general.h"
enable_build_option "IPSTAT_CMD" "general.h"
enable_build_option "PING_CMD" "general.h"
enable_build_option "NSLOOKUP_CMD" "general.h"

enable_build_option "CONSOLE_FRAMEBUFFER" "console.h"

###################################################################################################################
#######################  actually build ipxe binaries and place them in BUILD_DIR/
###################################################################################################################
rm -r "${BUILD_DIR}" 2>/dev/null
do_cmd mkdir "${BUILD_DIR}"
announce "building all targets"
announce_step "Building target: bin-x86_64-efi/ipxe-nomenu.usb"
do_cmd make ${MAKE_ARGS} bin-x86_64-efi/ipxe.usb
# copy this built file into build_dir cuz it will get overwritten
do_cmd cp "${WORKSPACE}/ipxe/src/bin-x86_64-efi/ipxe.usb" "${BUILD_DIR}/ipxe-64bit-efi-nomenu.usb"
for TARGET in $BUILD_TARGET_LIST; do
    announce_step "Building target: $TARGET"
    do_cmd make ${MAKE_ARGS} "$TARGET" "EMBED=${MENU_FILE}"
done
# for nomenu.usb


###################################################################################################################
#######################  fetch prebuilt wimboot binary
###################################################################################################################
announce_step "fetching latest wimboot"
cd_to "${WORKSPACE}"
wget "$WIMBOOT_URL"
unzip wimboot-latest.zip
WIMBOOT_FOLDER=$(find . -type d -name 'wimboot-*')
cd_to "${WIMBOOT_FOLDER}"
do_cmd cp "wimboot" "${WORKSPACE}/wimboot"
cd_to "${WORKSPACE}"

###################################################################################################################
#######################  wrap it all up ready for deploy.sh
###################################################################################################################

# BUILD_TARGET_LIST="
# bin-x86_64-pcbios/ipxe.pxe
# bin-x86_64-pcbios/ipxe.iso
# bin-x86_64-pcbios/ipxe.usb
# bin-x86_64-efi/ipxe.efi
# bin-x86_64-efi/ipxe.usb
# bin-i386-efi/ipxe.efi
# bin-i386-efi/ipxe.usb
# bin-i386-pcbios/ipxe.pxe
# bin-i386-pcbios/ipxe.usb
# bin-i386-pcbios/ipxe.iso
# "

announce_step "grabbing all the files"
# clear build dir only after successful build

mkdir -p "$BUILD_DIR"
# put all the built files where we want them
do_cmd cp "${WORKSPACE}/wimboot" "${BUILD_DIR}/wimboot"
do_cmd cp "${WORKSPACE}/ipxe/src/bin-x86_64-pcbios/ipxe.pxe" "${BUILD_DIR}/ipxe-64bit-bios.pxe"
do_cmd cp "${WORKSPACE}/ipxe/src/bin-x86_64-pcbios/ipxe.iso" "${BUILD_DIR}/ipxe-64bit-bios.iso"
do_cmd cp "${WORKSPACE}/ipxe/src/bin-x86_64-pcbios/ipxe.usb" "${BUILD_DIR}/ipxe-64bit-bios.usb"
do_cmd cp "${WORKSPACE}/ipxe/src/bin-x86_64-efi/ipxe.efi" "${BUILD_DIR}/ipxe-64bit-efi.efi"
do_cmd cp "${WORKSPACE}/ipxe/src/bin-x86_64-efi/ipxe.usb" "${BUILD_DIR}/ipxe-64bit-efi.usb"
do_cmd cp "${WORKSPACE}/ipxe/src/bin-i386-efi/ipxe.efi" "${BUILD_DIR}/ipxe-32bit-efi.efi"
do_cmd cp "${WORKSPACE}/ipxe/src/bin-i386-efi/ipxe.usb" "${BUILD_DIR}/ipxe-32bit-efi.usb"
do_cmd cp "${WORKSPACE}/ipxe/src/bin-i386-pcbios/ipxe.pxe" "${BUILD_DIR}/ipxe-32bit-bios.pxe"
do_cmd cp "${WORKSPACE}/ipxe/src/bin-i386-pcbios/ipxe.iso" "${BUILD_DIR}/ipxe-32bit-bios.iso"
do_cmd cp "${WORKSPACE}/ipxe/src/bin-i386-pcbios/ipxe.usb" "${BUILD_DIR}/ipxe-32bit-bios.usb"
# nomenu file was copied earlier
do_cmd cp "${CURRENT_DIR}/VERSION" "${BUILD_DIR}/"

announce_step "calculating md5sums"
cd_to "$BUILD_DIR"
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

#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

##
# System requirements installed manually before running this script:
# sudo apt install flex bison libssl-dev rsync tree tr awk sed
# See also https://www.coursera.org/learn/linux-system-programming-introduction-to-buildroot/discussions/weeks/2/threads/3KHudRXOEe6qcgp0u5G9Fw
##

# Fail immediately if any errors occur
set -e
# Fail if we use an uninitialised variable
set -u

## Config & default values
ARCH=arm64
BUSYBOX_REPO=https://git.busybox.net/busybox
BUSYBOX_VERSION=1_33_1
CROSS_COMPILE=aarch64-none-linux-gnu-
FINDER_APP_DIR=$(realpath "$(dirname "$0")")
KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
OUTDIR=/tmp/aeld

## Enforce English messages (as suggested by GitHub Copilot)
LANG=C
LC_ALL=C

## Output directory
if [ $# -lt 1 ]; then
	echo "Using default directory '${OUTDIR}' for output"
else
	OUTDIR=$(realpath "$1")
	echo "Using passed directory '${OUTDIR}' for output"
fi
mkdir -p "${OUTDIR}"
cd "${OUTDIR}"

## Linux kernel repository
linux_dir="${OUTDIR}/linux-stable"
if [ ! -d "${linux_dir}" ]; then
    printf "Cloning Linux kernel git repository for stable version %s to '%s'...\n" "${KERNEL_VERSION}" "${linux_dir}"
	time git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
else
    printf "SKIP: Linux kernel git repository already exists at '%s'\n" "${linux_dir}"
fi

## Build Linux kernel
linux_kernel_img_file="${linux_dir}/arch/${ARCH}/boot/Image"
if [ ! -e "${linux_kernel_img_file}" ]; then
    cd "${linux_dir}"
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    printf "\n\n### Cleaning the kernel build tree - removing the .config file with any existing configurations...\n"
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper

    printf "\n\n### Configuring Linux kernel for our 'virt' arm dev board we will simulate in QEMU...\n"
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig

    printf "\n\n### Building Linux kernel image for booting with QEMU...\n"
    time make -j4 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all

    printf "\n\n### Building Linux kernel modules...\n"
    time make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules

    printf "\n\n### Building device tree blob...\n"
    time make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs

    cd "${OUTDIR}"
else
    printf "SKIP: Linux kernel Image file already exists at '%s'\n" "${linux_kernel_img_file}"
fi
printf "\n\n"

## Copy the kernel image to outdir
printf "Copying Linux kernel Image file to '%s'\n" "${OUTDIR}"
cp "${linux_kernel_img_file}" "${OUTDIR}"

## Create rootfs directory
cd "${OUTDIR}"
rootfs_dir="${OUTDIR}/rootfs"
printf "\nCreating the staging directory for the root filesystem at '%s'\n" "${rootfs_dir}"
if [ -d "${rootfs_dir}" ]; then
	printf "WARNING: Deleting rootfs directory at '%s' and starting over\n" "${rootfs_dir}"
    sudo rm -rf "${rootfs_dir}"
fi
mkdir -p "${rootfs_dir}"
cd "${rootfs_dir}"
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log
printf "Created rootfs folder structure as follows:\n"
# Attention:
# tree is not available in autograding docker image which leads to a failed full_test.sh! :(
if command -v tree &> /dev/null; then
    tree "${rootfs_dir}"
else
    find "${rootfs_dir}"
fi
printf "\n\n"

## Build & install busybox in rootfs
cd "${OUTDIR}"
busybox_dir="${OUTDIR}/busybox"
if [ ! -d "${busybox_dir}" ]; then
    printf "Cloning busybox repository...\n"
    time git clone ${BUSYBOX_REPO}
    cd "${busybox_dir}"
    git checkout ${BUSYBOX_VERSION}
else
    cd "${busybox_dir}"
    printf "SKIP: Busybox repository already exists at '%s'\n" "${busybox_dir}"
fi
if [ ! -e "${busybox_dir}/.config" ]; then
    printf "Building busybox...\n"
    make distclean
    make defconfig
    time make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
else
    printf "SKIP: Busybox seems to be already built at '%s'\n" "${busybox_dir}"
fi
printf "Installing busybox to rootfs...\n"
cd "${busybox_dir}"
time make CONFIG_PREFIX="${rootfs_dir}" ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install
printf "\n\n"

## Dependencies of busybox binary
cd "${OUTDIR}"
busybox_bin="${rootfs_dir}/bin/busybox"
busybox_prog_interpr_filename=$(
    ${CROSS_COMPILE}readelf -a "${busybox_bin}" |
    grep "program interpreter" |
    awk -F: '{print $2}' |
    tr -d '[]' |
    sed 's/\/lib\///g' |
    sed 's/^[[:space:]]*//' || true  # Avoid exit code 1
)
if [ -z "${busybox_prog_interpr_filename}" ]; then
    printf "ERROR: Could not find program interpreter dependency for busybox binary '%s'\n" "${busybox_bin}"
    exit 1
fi
printf "Program interpreter dependency of busybox: %s\n" "${busybox_prog_interpr_filename}"
_cnt=$(
    find "$(realpath "$(${CROSS_COMPILE}gcc -print-sysroot)")" -name "${busybox_prog_interpr_filename}" |
    wc -l || true
)
if [ "${_cnt}" -eq 0 ]; then
    printf "ERROR: Could not find %s in sysroot of %s\n" "${busybox_prog_interpr_filename}" "${CROSS_COMPILE}gcc"
    exit 1
fi
busybox_prog_interpr_path=$(
    find "$(realpath "$(${CROSS_COMPILE}gcc -print-sysroot)")" -name "${busybox_prog_interpr_filename}"
)
# Array creation via mapfile as suggested by GitHub Copilot
mapfile -t busybox_shared_libs_filenames < <(
    ${CROSS_COMPILE}readelf -a "${busybox_bin}" |
    grep "Shared library" |
    awk -F: '{print $2}' |
    tr -d '[]' |
    sed 's/^[[:space:]]*//' || true  # Avoid exit code 1
)
if [ "${#busybox_shared_libs_filenames[@]}" -eq 0 ]; then
    printf "ERROR: Could not find any shared library dependencies for busybox binary '%s'\n" "${busybox_bin}"
    exit 1
fi
printf "Shared library dependencies of busybox:\n"
printf "%s\n" "${busybox_shared_libs_filenames[@]}"
busybox_shared_libs_paths=()
for _shared_lib in "${busybox_shared_libs_filenames[@]}"; do
    _cnt=$(
        find "$(realpath "$(${CROSS_COMPILE}gcc -print-sysroot)")" -name "${_shared_lib}" |
        wc -l || true  # Avoid exit code 1
    )
    if [ "${_cnt}" -eq 0 ]; then
        printf "ERROR: Could not find %s in sysroot of %s\n" "${_shared_lib}" "${CROSS_COMPILE}gcc"
        exit 1
    fi
    busybox_shared_libs_paths+=("$(
        find "$(realpath "$(${CROSS_COMPILE}gcc -print-sysroot)")" -name "${_shared_lib}"
    )")
done
printf "\nAdding library dependencies of busybox to rootfs...\n"
rootfs_lib_dir="${rootfs_dir}/lib"
rootfs_lib64_dir="${rootfs_dir}/lib64"
printf "Copying '%s' to '%s'\n" "${busybox_prog_interpr_path}" "${rootfs_lib_dir}"
cp "${busybox_prog_interpr_path}" "${rootfs_lib_dir}"
for _shared_lib in "${busybox_shared_libs_paths[@]}"; do
    printf "Copying '%s' to '%s'\n" "${_shared_lib}" "${rootfs_lib64_dir}"
    cp "${_shared_lib}" "${rootfs_lib64_dir}"
done
printf "\n"
# Attention:
# tree is not available in autograding docker image which leads to a failed full_test.sh! :(
if command -v tree &> /dev/null; then
    tree "${rootfs_lib_dir}"
else
    find "${rootfs_lib_dir}"
fi
printf "\n"
# Attention:
# tree is not available in autograding docker image which leads to a failed full_test.sh! :(
if command -v tree &> /dev/null; then
    tree "${rootfs_lib64_dir}"
else
    find "${rootfs_lib64_dir}"
fi
printf "\n\n"

## Add device nodes for /dev/null & /dev/console in rootfs
printf "Adding device nodes for /dev/null & /dev/console to rootfs...\n"
sudo mknod -m 666 "${rootfs_dir}/dev/null" c 1 3
sudo mknod -m 600 "${rootfs_dir}/dev/console" c 5 1
# Attention:
# tree is not available in autograding docker image which leads to a failed full_test.sh! :(
if command -v tree &> /dev/null; then
    tree "${rootfs_dir}/dev/"
else
    find "${rootfs_dir}/dev/"
fi
printf "\n\n"

## Cross-compile & add writer application to rootfs
printf "Cross-compiling writer application...\n"
cd "${FINDER_APP_DIR}"
make clean
make CROSS_COMPILE=${CROSS_COMPILE} writer
printf "\nAdding finder & writer applications to rootfs home directory...\n"
rootfs_home_dir="${rootfs_dir}/home"
cp writer "${rootfs_home_dir}"
cp finder.sh "${rootfs_home_dir}"
cp finder-test.sh "${rootfs_home_dir}"
cp autorun-qemu.sh "${rootfs_home_dir}"
mkdir "${rootfs_home_dir}/conf"
cp conf/username.txt "${rootfs_home_dir}/conf"
cp conf/assignment.txt "${rootfs_home_dir}/conf"

## Correct path to assignment.txt in finder-test.sh
sed -i 's|../conf/assignment.txt|./conf/assignment.txt|g' "${rootfs_home_dir}/finder-test.sh"
printf "\n\n"

## Create initramfs (as shown in course material)
printf "Changing the owner of the rootfs directory content to root for initramfs creation...\n"
cd "${rootfs_dir}"
sudo chown -R root:root ./*
printf "\nCreating initramfs...\n"
if [ -e "${OUTDIR}/initramfs.cpio.gz" ]; then
    printf "WARNING: Removing existing initramfs.cpio.gz file at '%s'\n" "${OUTDIR}/initramfs.cpio.gz"
    rm -f "${OUTDIR}/initramfs.cpio.gz"
fi
find . | cpio -H newc -ov --owner root:root > "${OUTDIR}/initramfs.cpio"
cd "${OUTDIR}"
gzip -f "${OUTDIR}/initramfs.cpio"
printf "\n\n"

printf "Done! :)\n"

# Reminder: sudo apt install qemu-system-arm

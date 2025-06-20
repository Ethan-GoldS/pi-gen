#!/bin/bash
set -e

trap 'echo "Error detected, performing cleanup before exit"' ERR

cd /pi-gen

# Configure git and ensure build directory is set as safe
git config --global --add safe.directory /pi-gen

echo "Setting up QEMU and ARM emulation support"
# Install QEMU if not already installed
if [ ! -f "/usr/bin/qemu-arm-static" ]; then
  echo "Installing QEMU user static"
  apt-get update
  apt-get install -y qemu-user-static binfmt-support
fi

# Use Docker's approach for multiarch support inside the container
echo "Checking for /proc/sys/fs/binfmt_misc"
if [ ! -d "/proc/sys/fs/binfmt_misc" ]; then
  echo "Mounting binfmt_misc filesystem"
  mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null || echo "Could not mount binfmt_misc, continuing anyway"
fi

# Register ARM binary format if missing and if we have write access
if [ -f "/proc/sys/fs/binfmt_misc/register" ] && [ -w "/proc/sys/fs/binfmt_misc/register" ]; then
  echo "Registering ARM binary format"
  echo ":arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:CF" > /proc/sys/fs/binfmt_misc/register 2>/dev/null || echo "Could not register ARM binary format, continuing anyway"
fi

echo "Running build script..."
time ./build.sh 2>&1 | tee /pi-gen/deploy/build.log
build_exit_code=${PIPESTATUS[0]}

echo "Build script completed with status $build_exit_code"

# Force unmount any stuck mounts
echo "Cleaning up mount points..."
umount -f /pi-gen/work/*/rootfs/dev/pts 2>/dev/null || true
umount -f /pi-gen/work/*/rootfs/dev 2>/dev/null || true
umount -f /pi-gen/work/*/rootfs/proc 2>/dev/null || true
umount -f /pi-gen/work/*/rootfs/sys 2>/dev/null || true

# Create images directory
mkdir -p /pi-gen/deploy/images

# Copy all image files to deploy directory
echo "Copying image files to deploy directory..."
find /pi-gen/work -name '*.img*' -o -name '*.zip' -o -name '*.tar.xz' -o -name '*.gz' | xargs -I{} cp -v {} /pi-gen/deploy/images/ 2>/dev/null || echo "No standard image files found"

# Additionally copy any large files that might be images with different extensions
echo "Looking for other large files that might be images..."
find /pi-gen/work -type f -size +100M | xargs -I{} cp -v {} /pi-gen/deploy/images/ 2>/dev/null || echo "No large files found"

# Create a detailed build report
echo "Creating build report and manifest..."
echo "Build completed at $(date)" > /pi-gen/deploy/build-report.txt
echo -e "\nPotential image files:" >> /pi-gen/deploy/build-report.txt
ls -la /pi-gen/deploy/images/ >> /pi-gen/deploy/build-report.txt 2>&1
echo -e "\nLarge files in work directory:" >> /pi-gen/deploy/build-report.txt
find /pi-gen/work -type f -size +5M -exec ls -lh {} \; | sort -hr >> /pi-gen/deploy/build-report.txt

# Always create a marker file even if the build failed
if [ ! -s "/pi-gen/deploy/images" ] || [ ! "$(ls -A /pi-gen/deploy/images 2>/dev/null)" ]; then
  echo "No image files found in build output" > /pi-gen/deploy/build-failed-no-images.txt
fi

exit $build_exit_code

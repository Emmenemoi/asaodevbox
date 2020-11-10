#!/usr/bin/env bash

echo "Output directory : ${OUTPUT_DIR:="/asaodevbox"}"

COPY_RSA="${COPY_RSA:-false}"

mkdir -p livecd/iso tmp2

UBUNTU_ISO=ubuntu-20.04.1-live-server-amd64.iso
UBUNTU_ISO_PATH=/tmp/$UBUNTU_ISO
if [ ! -f $UBUNTU_ISO_PATH ]; then
	echo "No install iso present in tmp"
	UBUNTU_ISO_PATH=livecd/$UBUNTU_ISO
fi
if [ ! -f $UBUNTU_ISO_PATH ]; then
    UBUNTU_ISO_PATH=livecd/$UBUNTU_ISO
	echo "No install iso present. Download to $UBUNTU_ISO_PATH"
    wget -q https://releases.ubuntu.com/20.04/$UBUNTU_ISO -O $UBUNTU_ISO_PATH
fi

mount $UBUNTU_ISO_PATH livecd/iso -o loop,ro

echo "Prepare AsaoDevBox.img"
dd if=/dev/zero of="${OUTPUT_DIR}"/AsaoDevBox.img bs=1M count=0 seek=2048 status=progress
echo "Make partition into AsaoDevBox.img"
parted -s "${OUTPUT_DIR}"/AsaoDevBox.img mklabel gpt
parted -s -a optimal "${OUTPUT_DIR}"/AsaoDevBox.img unit mib mkpart ESP fat32 1 1g name 1 AsaoDevBox set 1 esp on
#because cloud-init look for TYPE=vfat or iso9660 or LABEL=CIDATA or LABEL=cidata
parted -s -a optimal "${OUTPUT_DIR}"/AsaoDevBox.img unit mib mkpart primary fat32 1g 1100 name 2 cidata
parted -s -a optimal "${OUTPUT_DIR}"/AsaoDevBox.img unit mib mkpart primary fat32 1100 100% name 3 asao-user-data
losetup -f -P "${OUTPUT_DIR}"/AsaoDevBox.img
sleep 2
until [ -e /dev/disk/by-partlabel/AsaoDevBox ]; do sleep 1; done

mkfs.vfat -F 32 -n AsaoDevBox /dev/disk/by-partlabel/AsaoDevBox
mount /dev/disk/by-partlabel/AsaoDevBox tmp2
echo "Copy ubuntu iso to AsaoDevBox.img"
cp -r livecd/iso/. tmp2/
sed \
  '/set timeout=5/ amenuentry "AutoInstall AsaoDevBox Server" {\n\tset gfxpayload=keep\n\tlinux /casper/vmlinuz quiet autoinstall ---\n\tinitrd /casper/initrd\n}' \
  -i tmp2/boot/grub/grub.cfg
cd tmp2
find . -path ./isolinux -prune -o -type f -not -name md5sum.txt -print0 | xargs -0 md5sum | tee md5sum.txt
cd ..
umount tmp2
echo "Copy cidata to AsaoDevBox.img"
mkfs.vfat -F 32 -n cidata /dev/disk/by-partlabel/cidata
mount /dev/disk/by-partlabel/cidata tmp2
for i in user-data meta-data extra-user-data; do
  if [ -e "$i" ]; then
    cp "$i" tmp2/
  fi
done
umount tmp2
echo "Copy userdata to AsaoDevBox.img"
mkfs.vfat -F 32 -n asao-user-data /dev/disk/by-partlabel/asao-user-data
mount /dev/disk/by-partlabel/asao-user-data tmp2
if [ $COPY_RSA ]; then
	if [ "x${SUDO_USER}" == "x" ]; then
	  if [ -f ~/.ssh/id_rsa.pub ]; then
		cp ~/.ssh/id_rsa.pub tmp2/
	  fi
	else
	  cp /home/${SUDO_USER}/.ssh/id_rsa.pub tmp2/
	fi
fi
umount tmp2/
losetup -d $(losetup -j "${OUTPUT_DIR}"/AsaoDevBox.img | cut -d: -f1)
umount livecd/iso

echo "Done!"

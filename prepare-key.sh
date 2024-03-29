#!/usr/bin/env bash

OUTPUT_DIR=${OUTPUT_DIR:="/asaodevbox/tmp"}
echo "Output directory : ${OUTPUT_DIR}"

COPY_RSA=${COPY_RSA:-}

rm -rf livecd/iso/* tmp2/*
mkdir -p livecd/iso tmp2
chmod 775 livecd/iso tmp2 tmp

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

echo "mount $UBUNTU_ISO_PATH livecd/iso ro"
mount $UBUNTU_ISO_PATH livecd/iso -o loop,ro

echo "Prepare AsaoDevBox.img"
touch "${OUTPUT_DIR}/AsaoDevBox.img"
dd if=/dev/zero of="${OUTPUT_DIR}/AsaoDevBox.img" bs=1M count=0 seek=2048 status=progress
echo "Make partition into AsaoDevBox.img"
parted -s "${OUTPUT_DIR}"/AsaoDevBox.img mklabel gpt
parted -s -a optimal "${OUTPUT_DIR}"/AsaoDevBox.img unit mib mkpart ESP fat32 1 1600 name 1 AsaoDevBox set 1 esp on
#because cloud-init look for TYPE=vfat or iso9660 or LABEL=CIDATA or LABEL=cidata
parted -s -a optimal "${OUTPUT_DIR}"/AsaoDevBox.img unit mib mkpart primary fat32 1600 1800 name 2 cidata
parted -s -a optimal "${OUTPUT_DIR}"/AsaoDevBox.img unit mib mkpart primary fat32 1800 100% name 3 asao-user-data
echo "mount ${OUTPUT_DIR}/AsaoDevBox.img"
losetup -v --partscan -f "${OUTPUT_DIR}"/AsaoDevBox.img
sleep 2

LOOPDEV="$(losetup -a | grep ${OUTPUT_DIR}/AsaoDevBox.img | cut -d ":" -f1)"

#LOOPDEV="/dev/disk/by-partlabel/AsaoDevBox"
echo "Wait $LOOPDEV ready"
until [ -e $LOOPDEV ]; do 
sleep 1; 
ls -lh $LOOPDEV
done

read -p "Are you sure to use $LOOPDEV as img destination ? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

ASAODEVBOXDEV="${LOOPDEV}p1"
CIDATADEV="${LOOPDEV}p2"
USERDATADEV="${LOOPDEV}p3"

#mkfs.vfat -F 32 -n asaodevbox ${ASAODEVBOXDEV}
mkfs.vfat -F 32 -n asaodevbox ${ASAODEVBOXDEV}
mount ${ASAODEVBOXDEV} tmp2
echo "Copy ubuntu iso $UBUNTU_ISO_PATH to AsaoDevBox.img at ${ASAODEVBOXDEV}"
# PB WITH SYMLINKS IN FAT32 during cp
cp -aR livecd/iso/EFI tmp2/
cp -aR livecd/iso/boot tmp2/
mkdir -p tmp2/casper
cp -aR livecd/iso/casper/initrd tmp2/casper/
cp -aR livecd/iso/casper/vmlinuz tmp2/casper/
cp $UBUNTU_ISO_PATH tmp2/
#dd bs=1M if=$UBUNTU_ISO_PATH of=${ASAODEVBOXDEV}
#hdparm -r0 ${ASAODEVBOXDEV}
#mount -o rw ${ASAODEVBOXDEV} tmp2

#sed \
#  '/set timeout=5/ amenuentry "AutoInstall AsaoDevBox Server" {\n\tset gfxpayload=keep\n\tlinux /casper/vmlinuz quiet autoinstall ---\n\tinitrd /casper/initrd\n}' \
#  -i tmp2/boot/grub/grub.cfg

sed '/set timeout=5/ r extra-grub.cfg' -i tmp2/boot/grub/grub.cfg
cd tmp2
find . -path ./isolinux -prune -o -type f -not -name md5sum.txt -print0 | xargs -0 md5sum | tee md5sum.txt
cd ..
cp -r prepare-microk8s tmp2/
umount tmp2
echo "Copy cidata to AsaoDevBox.img"
mkfs.vfat -F 32 -n cidata ${CIDATADEV}
mount ${CIDATADEV} tmp2
for i in user-data meta-data extra-user-data; do
  if [ -e "$i" ]; then
    cp "$i" tmp2/
  fi
done
umount tmp2
echo "Copy userdata to AsaoDevBox.img"
mkfs.vfat -F 32 -n asao-user-data ${USERDATADEV}
mount ${USERDATADEV} tmp2
echo "Copy prepare-microk8s to userdata of AsaoDevBox.img"
cp -r prepare-microk8s tmp2/
if [ -z "$COPY_RSA" ]; then
	echo "Don't copy rsa key to asao-user-data"
	touch tmp2/id_rsa.pub.sample
else
	if [ "x${SUDO_USER}" == "x" ]; then
	  if [ -f ~/.ssh/id_rsa.pub ]; then
		cp ~/.ssh/id_rsa.pub tmp2/
	  fi
	else
	  cp /home/${SUDO_USER}/.ssh/id_rsa.pub tmp2/
	fi
fi
cp anydesk.conf.sample tmp2/
umount tmp2/
losetup -d ${LOOPDEV}
umount livecd/iso

echo "Done!"

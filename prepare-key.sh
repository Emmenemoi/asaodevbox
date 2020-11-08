#!/usr/bin/env bash

echo "Output directory : ${OUTPUT_DIR:="/asaodevbox"}"

mkdir -p livecd/iso tmp{,2}
if [ ! -f livecd/ubuntu-20.04.1-live-server-amd64.iso ]; then
  echo "No install iso present. Download"
  wget https://releases.ubuntu.com/20.04/ubuntu-20.04.1-live-server-amd64.iso -O livecd/ubuntu-20.04.1-live-server-amd64.iso
fi
archivemount livecd/ubuntu-20.04.1-live-server-amd64.iso livecd/iso

echo "Prepare AsaoDevBox.img"
dd if=/dev/zero of="${OUTPUT_DIR}"/AsaoDevBox.img bs=1M count=0 seek=2048 status=progress
echo "Make partition into AsaoDevBox.img"
parted -s "${OUTPUT_DIR}"/AsaoDevBox.img mklabel gpt
parted -s -a optimal "${OUTPUT_DIR}"/AsaoDevBox.img unit mib mkpart ESP fat32 1 1g name 1 AsaoDevBox set 1 esp on
#because cloud-init look for TYPE=vfat or iso9660 or LABEL=CIDATA or LABEL=cidata
parted -s -a optimal "${OUTPUT_DIR}"/AsaoDevBox.img unit mib mkpart primary fat32 1g 1100 name 2 cidata
parted -s -a optimal "${OUTPUT_DIR}"/AsaoDevBox.img unit mib mkpart primary fat32 1100 100% name 3 asao-user-data
partfs -o dev="${OUTPUT_DIR}"/AsaoDevBox.img tmp

mkfs.vfat tmp/p1
mount tmp/p1 tmp2
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
mkfs.vfat -F 32 -n cidata tmp/p2
mount tmp/p2 tmp2
for i in user-data meta-data extra-user-data; do
  if [ -e "$i" ]; then
    cp "$i" tmp2/
  fi
done
umount tmp2
echo "Copy userdata to AsaoDevBox.img"
mkfs.vfat -F 32 -n asao-user-data tmp/p3
mount tmp/p3 tmp2
if [ "x${SUDO_USER}" == "x" ]; then
  cp ~/.ssh/id_rsa.pub tmp2/
else
  cp /home/${SUDO_USER}/.ssh/id_rsa.pub tmp2/
fi
umount tmp2/
fusermount -u tmp

echo "Done!"

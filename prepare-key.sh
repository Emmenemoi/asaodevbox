#!/usr/bin/env bash

if [ $(id -u) -ne 0 ]; then
  sudo "$0"
  exit
fi

ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime
apt update && apt install -y wget parted dosfstools udev cmake libfdisk1 libfdisk-dev libfuse2 libfuse-dev build-essential git fuse
git clone https://github.com/braincorp/partfs.git
cd partfs/
make
cd ..

mkdir -p livecd/{ubuntu,iso,squashfs} tmp{,2}
cd livecd/
if [ ! -f ubuntu-20.04.1-live-server-amd64.iso ]; then
	echo "No install iso present. Download"
  wget https://releases.ubuntu.com/20.04/ubuntu-20.04.1-live-server-amd64.iso
fi
mount ubuntu-20.04.1-live-server-amd64.iso ubuntu -o loop,ro
echo "Prepare iso partition"
cp -a ubuntu/. iso/
umount livecd/ubuntu
sed \
  '/set timeout=5/ amenuentry "AutoInstall AsaoDevBox Server" {\n\tset gfxpayload=keep\n\tlinux /casper/vmlinuz quiet autoinstall ---\n\tinitrd /casper/initrd\n}' \
  -i iso/boot/grub/grub.cfg
cd iso
find . -path ./isolinux -prune -o -type f -not -name md5sum.txt -print0 | xargs -0 md5sum | tee md5sum.txt
cd ../..

echo "Prepare AsaoDevBox.img"
dd if=/dev/zero of=/asaodevbox/AsaoDevBox.img bs=1M count=0 seek=2048 status=progress
echo "Format AsaoDevBox.img"
parted -s AsaoDevBox.img mklabel gpt
parted -s -a optimal AsaoDevBox.img unit mib mkpart ESP fat32 1 1g name 1 AsaoDevBox set 1 esp on
#because cloud-init look for TYPE=vfat or iso9660 or LABEL=CIDATA or LABEL=cidata
parted -s -a optimal AsaoDevBox.img unit mib mkpart primary fat32 1g 1100 name 2 cidata
parted -s -a optimal AsaoDevBox.img unit mib mkpart primary fat32 1100 100% name 3 asao-user-data
partfs/build/bin/partfs -o dev=AsaoDevBox.img tmp

#losetup -f -P AsaoDevBox.img
echo "Wait mount AsaoDevBox.img"
#until [ -e /dev/disk/by-partlabel/AsaoDevBox ]; do sleep 1; done
mkfs.vfat tmp/p1
mount tmp/p1 tmp2
echo "Copy ubuntu iso to AsaoDevBox.img"
cp -r livecd/iso/. tmp2/
umount tmp2
mkfs.vfat -F 32 -n cidata tmp/p2
mount tmp/p2 tmp2
echo "Copy cidata to AsaoDevBox.img"
for i in user-data meta-data extra-user-data; do
  if [ -e "$i" ]; then
    cp "$i" tmp2/
  fi
done
umount tmp2
mkfs.vfat -F 32 -n asao-user-data tmp/p3
mount tmp/p3 tmp2
echo "Copy userdata to AsaoDevBox.img"
if [ "x${SUDO_USER}" == "x" ]; then
  cp ~/.ssh/id_rsa.pub tmp2/
else
  cp /home/${SUDO_USER}/.ssh/id_rsa.pub tmp2/
fi
umount tmp2/
#losetup -d $(losetup -j AsaoDevBox.img | cut -d: -f1)
fusermount -u tmp

if [ $# -eq 1 ]; then
	echo "Write AsaoDevBox.img to key"
  dd if=AsaoDevBox.img of="$1" bs=1M status=progress
fi

echo "Done!"

#sudo cp AsaoDevBox.img /var/lib/libvirt/images/ISO/AsaoDevBox.img
#sudo rm -f /var/lib/libvirt/images/Ubuntu.img; sudo virt-install --name asaodevbox --hvm --boot uefi --vcpus=4 --ram 8192 --machine q35 --disk path=/var/lib/libvirt/images/"${NAME}".img,size=10 --disk /var/lib/libvirt/images/ISO/AsaoDevBox.img,bus=usb --network network:default,model=virtio --graphics spice --video qxl --channel spicevmc --rng /dev/random --noautoconsole --console pty,target_type=serial --os-type=linux

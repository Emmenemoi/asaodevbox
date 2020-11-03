#!/usr/bin/env bash

if [ ! -d /mnt/test ]; then
  mkdir /mnt/test
fi

#sudo apt install -y squashfs-tools schroot genisoimage syslinux-utils
mkdir -p livecd/{iso,squashfs}
cd livecd/
if [ ! -f ubuntu-20.04.1-live-server-amd64.iso ]; then
    wget https://releases.ubuntu.com/20.04/ubuntu-20.04.1-live-server-amd64.iso
fi
sudo mount ubuntu-20.04.1-live-server-amd64.iso /mnt/test -o loop
cp -a /mnt/test/. iso/
sudo umount /mnt/test
sudo sed \
  '/set timeout=5/ amenuentry "AutoInstall AsaoDevBox Server" {\n\tset gfxpayload=keep\n\tlinux /casper/vmlinuz quiet autoinstall ---\n\tinitrd /casper/initrd\n}' \
  -i iso/boot/grub/grub.cfg
cd iso
sudo bash -c "find . -path ./isolinux -prune -o -type f -not -name md5sum.txt -print0 | xargs -0 md5sum | tee md5sum.txt"
cd ../..

dd if=/dev/zero of=AsaoDevBox.img bs=1M count=0 seek=2048
parted -s AsaoDevBox.img mklabel gpt
parted -s -a optimal AsaoDevBox.img unit mib mkpart ESP fat32 1 1g name 1 AsaoDevBox set 1 esp on
#because cloud-init look for TYPE=vfat or iso9660 or LABEL=CIDATA or LABEL=cidata
parted -s -a optimal AsaoDevBox.img unit mib mkpart primary fat32 1g 1100 name 2 cidata
parted -s -a optimal AsaoDevBox.img unit mib mkpart primary fat32 1100 100% name 3 asao-user-data
sudo losetup -f -P AsaoDevBox.img
until [ -e /dev/disk/by-partlabel/AsaoDevBox ]; do sleep 1; done
sudo mkfs.vfat /dev/disk/by-partlabel/AsaoDevBox
sudo mount /dev/disk/by-partlabel/AsaoDevBox /mnt/test
sudo cp -r livecd/iso/. /mnt/test/
sudo umount /mnt/test
sudo mkfs.vfat -F 32 -n cidata /dev/disk/by-partlabel/cidata
sudo mount /dev/disk/by-partlabel/cidata /mnt/test
for i in user-data meta-data extra-user-data; do
  if [ -e "$i" ]; then
    sudo cp "$i" /mnt/test/
  fi
done
sudo umount /mnt/test
sudo mkfs.vfat -F 32 -n asao-user-data /dev/disk/by-partlabel/asao-user-data
sudo mount /dev/disk/by-partlabel/asao-user-data /mnt/test
sudo cp ~/.ssh/id_rsa.pub /mnt/test/
sudo umount /mnt/test
sudo losetup -d $(losetup -j AsaoDevBox.img | cut -d: -f1)

#sudo cp AsaoDevBox.img /var/lib/libvirt/images/ISO/AsaoDevBox.img
#sudo rm -f /var/lib/libvirt/images/Ubuntu.img; sudo virt-install --name asaodevbox --hvm --boot uefi --vcpus=4 --ram 8192 --machine q35 --disk path=/var/lib/libvirt/images/"${NAME}".img,size=10 --disk /var/lib/libvirt/images/ISO/AsaoDevBox.img,bus=usb --network network:default,model=virtio --graphics spice --video qxl --channel spicevmc --rng /dev/random --noautoconsole --console pty,target_type=serial --os-type=linux
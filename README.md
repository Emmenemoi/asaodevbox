# asaodevbox
Automatic kubernetes developement server provisioning from OSX or Linux

# General principle
- The developer prepares an Installer Device
- The developer inserts the Installer Device on the AsaoDevBox
- Auto provisioning the AsaoDevBox if no bootable device, with crypted root partition, with 0 interaction, including microk8s install (optional: specific channel indicated in extra-user-data)
- An external install script is run for deployment of the developement environment to kube on first boot
- Generated developement configuration is saved on the User Partition (kubectl config, logs, etc)
- The developer copy the necessary files on his developement machine
- AsaoDevBox needs to have the Installer Device plugged to be bootable (root decrypted)
- If a file named "reset" is present on the Installer Device, re-provision the device from scratch automatically. Normal boot if not present.

If the AsaoDevBox needs to "travels" safely, just unplug the "Installer Device" from the box.

# Files description

- user-data: default cloud-init file for unattended install to be included in the iso partition

- prepare-key.sh:
  - Script to prerpare the device for auto-installation (on USB key or SD card)
    => format and prepare the device with 3 partitions:
      - Ubuntu 20 iso: install prepared for 0 interactivity
      - default user-data
      - User partition: copy custom user files: extra-user-data, anydesk.conf, developer rsa-keys, post-install.sh script file (locally or DL)

# user-data:

Default cloud-init file that will merge the data with "extra-user-data" file preset on the Installer Device part 3 if any -> possible to assign fixed IP or default wifi SSID/PWD

# extra-user-data

- network: put your static network configuration (sample in extra-user-data.sample)

# User partition files:

- extra-user-data (optional): user-data cloud-init to be merged with 
- rsa_id (optional): developer RSA private key used to access the distant private git repos.
- rsa_id.pub: developer RSA public key. Will also be used to access the AsaoDevBox
- keyfile (optional): keyfile used to encrypt root partition
- post-install.sh (optional): post install script for kube deployement on first boot
- anydesk.conf (optional): contains Anydesk license and password (sample in anydesk.conf.sample)
- reset (optional): file forcing auto provisionning if present

## testing:
Create iso seed for unattended boot with :
genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data

Using virtualbox:
Boot a VM in UEFI mode with "Ubuntu Server 20.20 install" iso + generateed seed.iso

Validate "unattended install"


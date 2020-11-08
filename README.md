# asaodevbox
Automatic kubernetes developement server provisioning from OSX or Linux

# Prerequisite

You need functional docker installation, fuse module loaded on linux. For Mac OS X, you should use [osxfuse](https://osxfuse.github.io/).

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

- network: put your static network configuration (sample in extra-user-data.sample) (Don't work for now, you should put it in user-data file)

# User partition files:

- extra-user-data (optional): user-data cloud-init to be merged with 
- rsa_id (optional): developer RSA private key used to access the distant private git repos.
- rsa_id.pub: developer RSA public key. Will also be used to access the AsaoDevBox
- keyfile (optional): keyfile used to encrypt root partition
- post-install.sh (optional): post install script for kube deployement on first boot
- anydesk.conf (optional): contains Anydesk license and password (sample in anydesk.conf.sample)
- reset (optional): file forcing auto provisionning if present

# testing:

Run docker command to generate your install disk image which will named AsaoDevBox.img:

```bash
docker build -t asaodevbox .
docker run --rm -v /dev:/dev -v `pwd`:/asaodevbox -v "${HOME}"/.ssh:/root/.ssh --privileged --workdir /asaodevbox -ti asaodevbox
```

You can also add an environment varible in parameter to specify where the image disk should be write:

```bash
docker run --rm -v /dev:/dev -v `pwd`:/asaodevbox -v "${HOME}"/.ssh:/root/.ssh --privileged --workdir /asaodevbox -e OUTPUT_DIR=/tmp -ti asaodevbox
```

The image disk is named AsaoDevBox.img and can be write on a micrSD or USB drive with tools like [etcher](https://www.balena.io/etcher/).

Plug your install device and start your AsaoDevBox.

After some minutes, you can extract you install device and get your kube-config file, the install device is not mounted in normal run.

Validate "unattended install"

To reinstall your box, simply put a file named reset in asao-user-data partition and reboot.

If your system can't boot, plug a keyboard and press the required key at boot time for boot menu and select your boot device ([F8] on Zotac).
FROM ubuntu:20.04

WORKDIR /asaodevbox
ADD prepare-key.sh user-data meta-data /asaodevbox/
RUN ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && apt update && apt install -y wget parted dosfstools udev
CMD ["./prepare-key.sh"]
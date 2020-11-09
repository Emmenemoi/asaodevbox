FROM ubuntu:20.04 as build

ADD prepare-key.sh user-data meta-data /asaodevbox/
#WORKDIR /asaodevbox
#RUN su root -c "./prepare-key.sh"
RUN ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt update && apt install -y cmake libfdisk1 libfdisk-dev libfuse2 libfuse-dev build-essential git && \
    cd / && git clone https://github.com/braincorp/partfs.git && cd partfs/ && make


FROM ubuntu:20.04

WORKDIR /asaodevbox
COPY --from=build /asaodevbox .
COPY --from=build /partfs/build/bin/partfs /usr/local/bin/
RUN ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && apt update && apt install -y wget parted dosfstools udev fuse archivemount
CMD ["./prepare-key.sh"]
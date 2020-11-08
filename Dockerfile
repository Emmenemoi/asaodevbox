FROM ubuntu:20.04 as build

ADD prepare-key.sh /asaodevbox/
WORKDIR /asaodevbox
RUN bash -c "sudo ./prepare-key.sh"

FROM alpine:latest

WORKDIR /asaodevbox
COPY --from=build /asaodevbox .
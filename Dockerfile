FROM ubuntu:20.04 as build

ADD prepare-key.sh /asaodevbox/
WORKDIR /asaodevbox
RUN bash -c "./prepare-key.sh"

FROM alpine:latest

WORKDIR /asaodevbox
COPY --from=build /asaodevbox .
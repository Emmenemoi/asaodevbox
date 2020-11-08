FROM ubuntu:20.04 as build

ADD prepare-key.sh /asaodevbox/
WORKDIR /asaodevbox
USER root
RUN bash -c "./prepare-key.sh"
USER jenkins

FROM alpine:latest

WORKDIR /asaodevbox
COPY --from=build /asaodevbox .
FROM ubuntu:latest

VOLUME [ "/toolkit_tarballs" ]

ENV IS_IN_CONTAINER 1

RUN apt-get update \
 && apt-get -qy install git python3 wget ca-certificates xz-utils

COPY . /source/WireGuard

ENTRYPOINT exec /source/WireGuard/build.sh

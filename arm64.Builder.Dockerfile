FROM rockylinux/rockylinux:latest-arm64
MAINTAINER Yves Schumann <y.schumann@yetnet.ch>

COPY qemu-aarch64-static /usr/bin/

RUN dnf update -y \
 && dnf upgrade -y \
 && dnf module enable -y \
        php:7.4 \
 && dnf install -y \
        ca-certificates \
        chrony \
        epel-release \
        file \
        gcc \
        git \
        make \
        mc \
        openssh-server \
        php-devel \
        tar \
        unzip \
        wget \
        dnf-utils \
 && dnf clean all

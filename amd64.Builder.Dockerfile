FROM rockylinux/rockylinux:latest-amd64
MAINTAINER Yves Schumann <y.schumann@yetnet.ch>

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

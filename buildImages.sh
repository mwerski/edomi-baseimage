#!/usr/bin/env bash
# ===========================================================================
#
# Created: 2020-01-05 Y. Schumann
#
# Helper script to build and push Edomi baseimage
#
# ===========================================================================

# Store path from where script was called, determine own location
# and source helper content from there
callDir=$(pwd)
ownLocation="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${ownLocation}
. ./include/helpers_console.sh
_init

helpMe() {
    echo "
    Helper script to build Edomi baseimages.

    Usage:
    ${0} [options]
    Optional parameters:
    -a .. Also build ARM images beside AMD64
    -i <version>
       .. Version to tag the image with
    -p .. Push image to DockerHub
    -h .. Show this help
    "
}


PUSH_IMAGE=''
BUILD_ARM_IMAGES=false
PLATFORM='linux/amd64'
IMAGE_VERSION=latest

while getopts ai:ph? option; do
    case ${option} in
        a) BUILD_ARM_IMAGES=true;;
        i) IMAGE_VERSION="${OPTARG}";;
        p) PUSH_IMAGE=--push;;
        h|?) helpMe && exit 0;;
        *) die 90 "invalid option \"${OPTARG}\"";;
    esac
done

if ${BUILD_ARM_IMAGES} ; then
    PLATFORM=${PLATFORM},linux/arm64
    info "Building AMD64 and ARM64"
else
    info "Building AMD64 only"
fi

info "Building Edomi builder image"
docker buildx \
    build \
    -f Builder_Dockerfile \
    "--platform=${PLATFORM}" \
    "--tag=starwarsfan/edomi-baseimage-builder:${IMAGE_VERSION}" \
    ${PUSH_IMAGE} \
    .
info " -> Done"

info "Building Edomi base image"
docker buildx \
    build \
    "--platform=${PLATFORM}" \
    "--tag=starwarsfan/edomi-baseimage:${IMAGE_VERSION}" \
    --build-arg "IMAGE_VERSION=${IMAGE_VERSION}" \
    ${PUSH_IMAGE} \
    .
info " -> Done"

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
    Helper script to build Edomi baseimage.

    Usage:
    ${0} [options]
    Optional parameters:
    -a  Also build ARM images beside AMD64
    -p  Publish image on DockerHub
    -h  Show this help
    "
}

pullRocky() {
    if [[ $PULL_ROCKYLINUX_IMAGE ]] ; then
        info "Pulling ${ROCKYLINUX_VERSION}"
        docker pull "${ROCKYLINUX_VERSION}"
        info " -> Done"
    else
        info "Skipping pull of ${ROCKYLINUX_VERSION}"
    fi
}

getDigests() {
    info "Determining amd64 and arm64 image digests"
    docker manifest inspect rockylinux/rockylinux:latest > /tmp/rockyLinuxManifest.json
    DIGEST_AMD64=$(jq -j '.manifests[] | select(.platform.architecture == "amd64") | .digest' /tmp/rockyLinuxManifest.json)
    DIGEST_ARM64=$(jq -j '.manifests[] | select(.platform.architecture == "arm64") | .digest' /tmp/rockyLinuxManifest.json)
    info " -> amd64: ${DIGEST_AMD64}"
    info " -> arm64: ${DIGEST_ARM64}"
#    rm -f /tmp/rockyLinuxManifest.json
}

tagRockyImages() {
    info "Taging rocky linux images"
    docker pull "${ROCKYLINUX_VERSION}@${DIGEST_AMD64}"
    docker pull "${ROCKYLINUX_VERSION}@${DIGEST_ARM64}"
    docker tag "${ROCKYLINUX_VERSION}@${DIGEST_AMD64}" "${ROCKYLINUX_VERSION}-amd64"
    docker tag "${ROCKYLINUX_VERSION}@${DIGEST_ARM64}" "${ROCKYLINUX_VERSION}-arm64"
    info " -> Done"
}

buildBaseimage() {
    local _arch=$1
    info "Building starwarsfan/edomi-baseimage-builder:latest-${_arch}"
    docker build -f "${_arch}.Builder.Dockerfile" -t "starwarsfan/edomi-baseimage-builder:latest-${_arch}" .
    info " -> Done"
    if ${PUBLISH_IMAGE} ; then
        info "Pushing starwarsfan/edomi-baseimage-builder:latest-${_arch}"
        docker push "starwarsfan/edomi-baseimage-builder:latest-${_arch}"
        info " -> Done"
    fi

    info "Building starwarsfan/edomi-baseimage:latest-${_arch}"
    docker build -f "${_arch}.Dockerfile" -t "starwarsfan/edomi-baseimage:latest-${_arch}" .
    info " -> Done"
    if ${PUBLISH_IMAGE} ; then
        info "Pushing starwarsfan/edomi-baseimage:latest-${_arch}"
        docker push "starwarsfan/edomi-baseimage:latest-${_arch}"
        info " -> Done"
    fi
}

PUBLISH_IMAGE=false
BUILD_ARM_IMAGES=false
PULL_ROCKYLINUX_IMAGE=true
ROCKYLINUX_VERSION=rockylinux/rockylinux:latest
DIGEST_AMD64=''
DIGEST_ARM64=''

while getopts aph? option; do
    case ${option} in
        a) BUILD_ARM_IMAGES=true;;
        p) PUBLISH_IMAGE=true;;
        h|?) helpMe && exit 0;;
        *) die 90 "invalid option \"${OPTARG}\"";;
    esac
done

info "Disabling buildkit etc. pp."
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0
info " -> Done"

pullRocky
getDigests
tagRockyImages
buildBaseimage amd64
if ${BUILD_ARM_IMAGES} ; then
    buildBaseimage arm64
fi

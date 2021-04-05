#!/bin/bash
VERSIONS=(6.2 7.0)
ARCHS=(
    "apollolake"
    "armada38x"
    "avoton"
    "braswell"
    "broadwell"
    "broadwellnk"
    "bromolow"
    "cedarview"
    "denverton"
    "geminilake"
    "kvmx64"
    "monaco"
    "rtd1296"
    "x64"
)

set -e

# Check that we are running as root
if [ `id -u` -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Download all necessary tarballs before calling into the docker containers.
echo "Downloading environment tarballs"
for ver in ${VERSIONS[@]}; do
    url_base="https://sourceforge.net/projects/dsgpl/files/toolkit/DSM$ver"
    pushd toolkit_tarballs/
    if [ ! -f base_env-$ver.txz ]; then
        wget -q --show-progress "$url_base/base_env-$ver.txz"
    fi
    for arch in ${ARCHS[@]}; do
        if [ ! -f ds.$arch-$ver.dev.txz ]; then
            wget -q --show-progress "$url_base/ds.$arch-$ver.dev.txz"
        fi
        if [ ! -f ds.$arch-$ver.env.txz ]; then
            wget -q --show-progress "$url_base/ds.$arch-$ver.env.txz"
        fi
    done
    popd
done

# Ensure that we are using an up to date docker image
docker build -t synobuild .

for ver in ${VERSIONS[@]}; do
    # Create release directory if needed
    mkdir -p target/$ver

    for arch in ${ARCHS[@]}; do
        echo "Building '$arch'"

        # Remove old artifact directory
        if [ -d artifacts/ ]; then
            rm -rf artifacts/
        fi

        docker run \
            --rm \
            --privileged \
            --env PACKAGE_ARCH=$arch \
            --env DSM_VER=$ver \
            -v $(pwd)/artifacts:/result_spk \
            -v $(pwd)/toolkit_tarballs:/toolkit_tarballs \
            synobuild

        mv artifacts/WireGuard-*/* target/$ver/
    done
done

# Clean up artifact directory
if [ -d artifacts/ ]; then
    rm -rf artifacts/
fi

# Change permissions of the target directory to match the local user if called
# using sudo
if [ ! -z ${SUDO_USER+x} ]; then
    chown "$SUDO_USER:$SUDO_USER" -R target/
fi

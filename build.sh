#!/bin/bash
if [ -z ${IS_IN_CONTAINER+x} ]; then
    echo "This script expect to be run inside a docker container" 1>&2
    exit 1
fi

if [ -z ${PACKAGE_ARCH+x} ]; then
    echo "PACKAGE_ARCH is undefined. Please find and set you package arch:" 1>&2
    echo "https://www.synology.com/en-global/knowledgebase/DSM/tutorial/Compatibility_Peripherals/What_kind_of_CPU_does_my_NAS_have" 1>&2
    exit 2
fi

if [ -z ${DSM_VER+x} ]; then
    echo "DSM_VER is undefined. This should a version number like 6.2" 1>&2
    exit 3
fi

# Ensure that we are working directly in the root file system. Though this
# should always be the case in containers.
cd /

# Make the script quit if there are errors
set -e

# Fetch Synology toolchain
if [ ! -d /pkgscripts-ng ]; then
    git clone https://github.com/SynologyOpenSource/pkgscripts-ng
fi

# Install the toolchain for the given package arch and DSM version
build_env="/build_env/ds.$PACKAGE_ARCH-$DSM_VER"
if [ ! -d "$build_env" ]; then
    pkgscripts-ng/EnvDeploy -p $PACKAGE_ARCH -v $DSM_VER

    # Ensure the installed toolchain has support for CA signed certificates.
    # Without this wget on https:// will fail
    cp /etc/ssl/certs/ca-certificates.crt "$build_env/etc/ssl/certs/"
fi

# Disable quit if errors to allow printing of logfiles
set +e

# By default we patch WireGuard to always use include its own memneq
# implemenation. This is required on most NASes, but some of them come with
# built in memneq support. Unless HAS_MEMNEQ is defined we set it for models
# that support it here.
if [ -z ${HAS_MEMNEQ+x} ]; then
    if [[ "$PACKAGE_ARCH" =~ ^apollolake|denverton|rtd1296$ ]]; then
        export HAS_MEMNEQ=1
    fi
fi

# Build packages
#   -p              package arch
#   -v              DSM version
#   -S              no signing
#   --build-opt=-J  prevent parallel building (required)
#   --print-log     save build logs
#   -c WireGuard    project path in /source
pkgscripts-ng/PkgCreate.py \
    -p $PACKAGE_ARCH \
    -v $DSM_VER \
    -S \
    --build-opt=-J \
    --print-log \
    -c WireGuard

# Save package builder exit code. This allows us to print the logfiles and give
# a non-zero exit code on errors.
pkg_status=$?

echo "Build log"
echo "========="
cat "$build_env/logs.build"
echo

echo "Install log"
echo "==========="
cat "$build_env/logs.install"
echo

exit $pkg_status

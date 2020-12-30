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

export WIREGUARD_VERSION=$(wget -q https://git.zx2c4.com/wireguard-linux-compat/refs/ -O - | grep -oP '\/wireguard-linux-compat\/tag\/\?h=v\K[.0-9]*' | head -n 1)
export WIREGUARD_TOOLS_VERSION=$(wget -q https://git.zx2c4.com/wireguard-tools/refs/ -O - | grep -oP '\/wireguard-tools\/tag\/\?h=v\K[.0-9]*' | head -n 1)
export LIBMNL_VERSION=$(wget -q 'https://netfilter.org/projects/libmnl/files/?C=M;O=D' -O - | grep -oP 'a href="libmnl-\K[0-9.]*' | head -n 1 | sed 's/.\{1\}$//')

echo "WireGuard version:        $WIREGUARD_VERSION"
echo "WireGuard tools version:  $WIREGUARD_TOOLS_VERSION"
echo "libmnl version:           $LIBMNL_VERSION"
echo

# Fetch Synology toolchain
if [[ ! -d /pkgscripts-ng ]] || [ -z "$(ls -A /pkgscripts-ng)" ]; then
    git clone https://github.com/SynologyOpenSource/pkgscripts-ng
else
    echo "Existing pkgscripts-ng repo found. Pulling latest from origin."
    cd /pkgscripts-ng
    git pull origin
    cd /
fi

# Temporary workaround for some architectures that are not part properly set as
# 64 bit: https://github.com/SynologyOpenSource/pkgscripts-ng/pull/26/
# NOTE: This fix breaks your workflow if you save the pkgscripts-ng repo state
#       across runs
if [[ "$PACKAGE_ARCH" =~ ^geminilake|purley|v1000$ ]]; then
    sed -i 's/\(local all64BitPlatforms\)=".*"/\1="PURLEY V1000 GEMINILAKE"/' /pkgscripts-ng/include/platforms
fi

# Temporary add support for 7.0 (until the official repo is updated)
grep -q '^AvailablePlatform_7_0=' /pkgscripts-ng/include/toolkit.config || \
    echo 'AvailablePlatform_7_0="6281 alpine alpine4k apollolake armada370 armada375 armada37xx armada38x armadaxp avoton braswell broadwell broadwellnk bromolow cedarview comcerto2k denverton dockerx64 evansport geminilake grantley hi3535 kvmx64 monaco purley qoriq rtd1296 v1000 x64"' >> /pkgscripts-ng/include/toolkit.config

# Install the toolchain for the given package arch and DSM version
build_env="/build_env/ds.$PACKAGE_ARCH-$DSM_VER"

if [ ! -d "$build_env" ]; then
    if [ -f "/toolkit_tarballs/base_env-$DSM_VER.txz" ] && [ -f "/toolkit_tarballs/ds.$PACKAGE_ARCH-$DSM_VER.env.txz" ] && [ -f "/toolkit_tarballs/ds.$PACKAGE_ARCH-$DSM_VER.dev.txz" ]; then
        pkgscripts-ng/EnvDeploy -p $PACKAGE_ARCH -v $DSM_VER -t /toolkit_tarballs
    else
        pkgscripts-ng/EnvDeploy -p $PACKAGE_ARCH -v $DSM_VER
    fi

    # Ensure the installed toolchain has support for CA signed certificates.
    # Without this wget on https:// will fail
    cp /etc/ssl/certs/ca-certificates.crt "$build_env/etc/ssl/certs/"
fi

# Disable quit if errors to allow printing of logfiles
set +e

# By default we patch WireGuard to always use include its own memneq
# implementation. This is required on most NASes, but some of them come with
# built in memneq support. Unless HAS_MEMNEQ is defined we set it for models
# that support it here.
if [ -z ${HAS_MEMNEQ+x} ]; then
    if [[ "$PACKAGE_ARCH" =~ ^geminilake|apollolake|denverton|broadwellnk|kvmx64|rtd1296$ ]]; then
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

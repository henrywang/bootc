#!/bin/bash
set -xeuo pipefail

# Go root folder
cd ..

# Get OS data.
source /etc/os-release

TEMPDIR=$(mktemp -d)
trap 'rm -rf -- "$TEMPDIR"' EXIT

CONTAINERFILE="${TEMPDIR}/Containerfile"

case "${ID}-${VERSION_ID}" in
    "rhel-9.6")
        BASE_IMAGE=images.paas.redhat.com/bootc/rhel-bootc:latest-9.6
        ;;
    "rhel-10.0")
        BASE_IMAGE=images.paas.redhat.com/bootc/rhel-bootc:latest-10.0
        ;;
    "centos-9")
        BASE_IMAGE=quay.io/centos-bootc/centos-bootc:stream9
        ;;
    "centos-10")
        BASE_IMAGE=quay.io/centos-bootc/centos-bootc:stream10
        ;;
    "fedora-40")
        BASE_IMAGE=quay.io/fedora/fedora-bootc:40
        ;;
    "fedora-41")
        BASE_IMAGE=quay.io/fedora/fedora-bootc:41
        ;;
    "fedora-42")
        BASE_IMAGE=quay.io/fedora/fedora-bootc:42
        ;;
    *)
        echo "unsupported distro: ${ID}-${VERSION_ID}"
        exit 1
        ;;
esac

tee "$CONTAINERFILE" >/dev/null <<EOF
FROM "$BASE_IMAGE"

ARG bootc_rpm
RUN dnf install -y "\$bootc_rpm" && \
    dnf -y clean all

# Required by bootc-integration-tests install-alongside
RUN cat <<TEST01EOF >> /usr/lib/bootc/install/50-test-kargs.toml
[install]
kargs = ["localtestkarg=somevalue", "otherlocalkarg=42"]
TEST01EOF

RUN cat <<TEST02EOF >> /usr/lib/bootc/kargs.d/10-test.toml
kargs = ["kargsd-test=1", "kargsd-othertest=2"]
TEST02EOF

RUN cat <<TEST03EOF >> /usr/lib/bootc/kargs.d/20-test2.toml
kargs = ["testing-kargsd=3"]
TEST03EOF

EOF

sudo podman build --tls-verify=false --retry=5 --retry-delay=10s --build-arg "bootc_rpm=https://download.copr.fedorainfracloud.org/results/rhcontainerbot/bootc/fedora-41-x86_64/08429153-bootc/bootc-202412202003.g161bc313bf-1.fc41.x86_64.rpm" -t localhost/bootc -f "$CONTAINERFILE" "$TEMPDIR"

sudo cargo build --release -p tests-integration

sudo install -m 0755 target/release/tests-integration /usr/bin/bootc-integration-tests

sudo bootc-integration-tests host-privileged localhost/bootc

sudo bootc-integration-tests install-alongside localhost/bootc

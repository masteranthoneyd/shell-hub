#!/bin/bash

set -eo pipefail

# Set global variables
BUILD_DIR="/tmp/build"
APT_SOURCES_FILE="/etc/apt/sources.list.d/ubuntu.sources"
MUSL_HOME="/opt/musl-toolchain"
UPX_VERSION="4.2.2"
UPX_ARCHIVE="upx-${UPX_VERSION}-amd64_linux.tar.xz"

# Proxy settings
USE_PROXY=true
HP_URL=""
HSP_URL=""

# Colors for output
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET_COLOR="\033[0m"

# Development
INSTALL_JAVA=true
GRAALVM_NATIVE_SUPPORT=true
JAVA_VERSION="23.0.1-graal"
MAVEN_VERSION="3.9.9"

# skip apt interactive
function my_apt {
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical
    export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    command /usr/bin/apt --yes --option Dpkg::Options::=--force-confold --option Dpkg::Options::=--force-confdef "$@"
}

# Check if the script is run as root
check_root() {
    if [[ $(id -u) -ne 0 ]]; then
        printf "Error: Please run the script as root.\n" >&2
        exit 1
    fi
}

# High-order function to conditionally use proxy
use_proxy_if_enabled() {
    local command="$1"

    if [[ "${USE_PROXY}" == true ]]; then
        export http_proxy="${HP_URL}"
        export https_proxy="${HSP_URL}"
    fi

    # Execute the command
    eval "$command"

    # Restore the original proxy settings after execution
    unset http_proxy
    unset https_proxy
}

update_sources() {
    cat <<EOF > "$APT_SOURCES_FILE"
Types: deb
URIs: http://mirrors.aliyun.com/ubuntu/
Suites: noble noble-updates noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

    printf "${GREEN}Sources file updated.${RESET_COLOR}\n"
    # Update and upgrade system packages
    my_apt update && my_apt upgrade
}

# Install common tools
install_common_tools() {
    my_apt install curl wget zip unzip bash vim software-properties-common screenfetch
}

# Check if SDKMAN is installed
is_sdkman_installed() {
    if [[ -z "$(command -v sdk)" ]]; then
        return 1  # Not installed
    else
        return 0  # Installed
    fi
}

# Install SDKMAN
install_sdkman() {
    if ! is_sdkman_installed; then
        printf "${GREEN}Installing SDKMAN...${RESET_COLOR}\n"
        use_proxy_if_enabled "curl -s https://get.sdkman.io | bash"
        source "/root/.sdkman/bin/sdkman-init.sh"
    else
        printf "${YELLOW}SDKMAN is already installed.${RESET_COLOR}\n"
    fi
}

install_java() {
    if [[ "${INSTALL_JAVA}" == true ]]; then
      sdk install java ${JAVA_VERSION}
      sdk install maven ${MAVEN_VERSION}
    fi
}

# Check if MUSL is installed
is_musl_installed() {
    if [[ -x "${MUSL_HOME}/bin/musl-gcc" ]]; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

# Install MUSL and ZLIB
install_musl_zlib() {
    if ! is_musl_installed; then
        printf "${GREEN}Installing MUSL and ZLIB...${RESET_COLOR}\n"

        use_proxy_if_enabled "curl -O https://musl.libc.org/releases/musl-1.2.5.tar.gz"
        use_proxy_if_enabled "curl -O https://zlib.net/fossils/zlib-1.3.1.tar.gz"

        # Install MUSL
        tar -xzvf musl-1.2.5.tar.gz
        pushd musl-1.2.5
        ./configure --prefix="${MUSL_HOME}" --static
        make
        make install
        popd

        ln -s "${MUSL_HOME}/bin/musl-gcc" "${MUSL_HOME}/bin/x86_64-linux-musl-gcc"
        export PATH="${MUSL_HOME}/bin:$PATH"

        # Install ZLIB
        tar -xzvf zlib-1.3.1.tar.gz
        pushd zlib-1.3.1
        CC=musl-gcc ./configure --prefix="${MUSL_HOME}" --static
        make
        make install
        popd
    else
        printf "${YELLOW}MUSL and ZLIB are already installed.${RESET_COLOR}\n"
    fi
}

# Check if UPX is installed
is_upx_installed() {
    if [[ -x "/usr/bin/upx" ]]; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

# Install UPX
install_upx() {
    if ! is_upx_installed; then
        printf "${GREEN}Installing UPX...${RESET_COLOR}\n"
        use_proxy_if_enabled "wget -q https://github.com/upx/upx/releases/download/v${UPX_VERSION}/${UPX_ARCHIVE}"
        tar -xJf "${UPX_ARCHIVE}"
        mv "upx-${UPX_VERSION}-amd64_linux/upx" /usr/bin
    else
        printf "${YELLOW}UPX is already installed.${RESET_COLOR}\n"
    fi
}

graalvm_native_support() {
    if [[ "${GRAALVM_NATIVE_SUPPORT}" == true ]]; then
        my_apt install build-essential libz-dev zlib1g-dev
        install_musl_zlib
        install_upx
    fi
}

# Clean up the build directory and system caches
cleanup() {

    printf "${GREEN}Cleanup temp resources...${RESET_COLOR}\n"
    # Remove the build temporary directory
    rm -rf "${BUILD_DIR}"

    # Clean APT cache
    my_apt clean

    # Remove unnecessary dependencies
    my_apt autoremove

    # Clear /tmp directory
    rm -rf /tmp/*

    # Clear log files (optional)
    find /var/log -type f -exec truncate -s 0 {} \;
}

# Main execution function
main() {
    check_root  # Check if the script is run as root

    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"

    update_sources
    install_common_tools
    install_sdkman
    install_java
    graalvm_native_support

    # Switch to root directory and clean up the build directory
    cd /
    cleanup
}

# Execute main function
main

screenfetch
printf "${GREEN}
        #  DDDDDDDDDDDDD
        #  D::::::::::::DDD
        #  D:::::::::::::::DD
        #  DDD:::::DDDDD:::::D
        #    D:::::D    D:::::D    ooooooooooo   nnnn  nnnnnnnn        eeeeeeeeeeee
        #    D:::::D     D:::::D oo:::::::::::oo n:::nn::::::::nn    ee::::::::::::ee
        #    D:::::D     D:::::Do:::::::::::::::on::::::::::::::nn  e::::::eeeee:::::ee
        #    D:::::D     D:::::Do:::::ooooo:::::onn:::::::::::::::ne::::::e     e:::::e
        #    D:::::D     D:::::Do::::o     o::::o  n:::::nnnn:::::ne:::::::eeeee::::::e
        #    D:::::D     D:::::Do::::o     o::::o  n::::n    n::::ne:::::::::::::::::e
        #    D:::::D     D:::::Do::::o     o::::o  n::::n    n::::ne::::::eeeeeeeeeee
        #    D:::::D    D:::::D o::::o     o::::o  n::::n    n::::ne:::::::e
        #  DDD:::::DDDDD:::::D  o:::::ooooo:::::o  n::::n    n::::ne::::::::e
        #  D:::::::::::::::DD   o:::::::::::::::o  n::::n    n::::n e::::::::eeeeeeee
        #  D::::::::::::DDD      oo:::::::::::oo   n::::n    n::::n  ee:::::::::::::e
        #  DDDDDDDDDDDDD           ooooooooooo     nnnnnn    nnnnnn    eeeeeeeeeeeeee
        ${RESET_COLOR}
"

exec "$SHELL"



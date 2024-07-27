#!/bin/bash

# Variables
OPENWRT_PACKAGES_URL="https://github.com/openwrt/packages"
OPENWRT_BRANCH="openwrt-23.05"
MIRROR_URL="raw.githubusercontent.com/sbwml/r4s_build_script/master"
PATCHES_DIR="package/libs/openssl/patches"

# Function to clone repositories if not already present
clone_repo() {
    local repo_url=$1
    local target_dir=$2
    local branch=$3
    if [ ! -d "$target_dir" ]; then
        echo "Cloning $repo_url into $target_dir..."
        if git clone "$repo_url" "$target_dir" -b "$branch" --depth=1; then
            echo "Cloned $repo_url successfully."
        else
            echo "Failed to clone $repo_url."
            exit 1
        fi
    else
        echo "$target_dir already exists, skipping clone."
    fi
}

# Function to replace dependencies
replace_dependency() {
    local dep_name=$1
    local repo_url=$2
    echo "Replacing $dep_name..."
    rm -rf "package/libs/$dep_name"
    if git clone "$repo_url" "package/libs/$dep_name"; then
        echo "$dep_name replaced successfully."
    else
        echo "Failed to replace $dep_name."
        exit 1
    fi
}

# Clone openwrt packages if not already present
clone_repo $OPENWRT_PACKAGES_URL "openwrt_packages" $OPENWRT_BRANCH

# Replace curl package
echo "Replacing curl package..."
rm -rf feeds/packages/net/curl
cp -a openwrt_packages/net/curl feeds/packages/net/curl
echo "Curl package replaced successfully."

# Enable openssl & nghttp3 & ngtcp2
echo "Enabling OpenSSL, nghttp3, and ngtcp2..."
sed -i 's/default LIBCURL_MBEDTLS/default LIBCURL_OPENSSL/g' feeds/packages/net/curl/Config.in
sed -i -E '/LIBCURL_NG(HTTP3|TCP2)/,/default n/s/default n/default y/' feeds/packages/net/curl/Config.in
sed -i '/config LIBCURL_OPENSSL_QUIC/,+3 s/default n/default y/' feeds/packages/net/curl/Config.in
echo "OpenSSL, nghttp3, and ngtcp2 enabled successfully."

# Replace dependencies
replace_dependency "ngtcp2" "http://github.com/sbwml/package_libs_ngtcp2"
replace_dependency "nghttp3" "http://github.com/sbwml/package_libs_nghttp3"
replace_dependency "openssl" "http://github.com/openwrt/openwrt -b $OPENWRT_BRANCH --depth=1"

# Download OpenSSL QUIC patches
echo "Downloading OpenSSL QUIC patches..."
mkdir -p $PATCHES_DIR
cd $PATCHES_DIR && rm -rf * && cd -

patches=(
    "0001-QUIC-Add-support-for-BoringSSL-QUIC-APIs.patch"
    "0002-QUIC-New-method-to-get-QUIC-secret-length.patch"
    "0003-QUIC-Make-temp-secret-names-less-confusing.patch"
    "0004-QUIC-Move-QUIC-transport-params-to-encrypted-extensi.patch"
    "0005-QUIC-Use-proper-secrets-for-handshake.patch"
    "0006-QUIC-Handle-partial-handshake-messages.patch"
    "0007-QUIC-Fix-quic_transport-constructors-parsers.patch"
    "0008-QUIC-Reset-init-state-in-SSL_process_quic_post_hands.patch"
    "0009-QUIC-Don-t-process-an-incomplete-message.patch"
    "0010-QUIC-Quick-fix-s2c-to-c2s-for-early-secret.patch"
    "0011-QUIC-Add-client-early-traffic-secret-storage.patch"
    "0012-QUIC-Add-OPENSSL_NO_QUIC-wrapper.patch"
    "0013-QUIC-Correctly-disable-middlebox-compat.patch"
    "0014-QUIC-Move-QUIC-code-out-of-tls13_change_cipher_state.patch"
    "0015-QUIC-Tweeks-to-quic_change_cipher_state.patch"
    "0016-QUIC-Add-support-for-more-secrets.patch"
    "0017-QUIC-Fix-resumption-secret.patch"
    "0018-QUIC-Handle-EndOfEarlyData-and-MaxEarlyData.patch"
    "0019-QUIC-Fall-through-for-0RTT.patch"
    "0020-QUIC-Some-cleanup-for-the-main-QUIC-changes.patch"
    "0021-QUIC-Prevent-KeyUpdate-for-QUIC.patch"
    "0022-QUIC-Test-KeyUpdate-rejection.patch"
    "0023-QUIC-Buffer-all-provided-quic-data.patch"
    "0024-QUIC-Enforce-consistent-encryption-level-for-handsha.patch"
    "0025-QUIC-add-v1-quic_transport_parameters.patch"
    "0026-QUIC-return-success-when-no-post-handshake-data.patch"
    "0027-QUIC-__owur-makes-no-sense-for-void-return-values.patch"
    "0028-QUIC-remove-SSL_R_BAD_DATA_LENGTH-unused.patch"
    "0029-QUIC-SSLerr-ERR_raise-ERR_LIB_SSL.patch"
    "0030-QUIC-Add-compile-run-time-checking-for-QUIC.patch"
    "0031-QUIC-Add-early-data-support.patch"
    "0032-QUIC-Make-SSL_provide_quic_data-accept-0-length-data.patch"
    "0033-QUIC-Process-multiple-post-handshake-messages-in-a-s.patch"
    "0034-QUIC-Fix-CI.patch"
    "0035-QUIC-Break-up-header-body-processing.patch"
    "0036-QUIC-Don-t-muck-with-FIPS-checksums.patch"
    "0037-QUIC-Update-RFC-references.patch"
    "0038-QUIC-revert-white-space-change.patch"
    "0039-QUIC-use-SSL_IS_QUIC-in-more-places.patch"
    "0040-QUIC-Error-when-non-empty-session_id-in-CH.patch"
    "0041-QUIC-Update-SSL_clear-to-clear-quic-data.patch"
    "0042-QUIC-Better-SSL_clear.patch"
    "0043-QUIC-Fix-extension-test.patch"
    "0044-QUIC-Update-metadata-version.patch"
)

for patch in "${patches[@]}"; do
    if wget -P $PATCHES_DIR "https://$MIRROR_URL/openwrt/patch/openssl/quic/$patch"; then
        echo "Downloaded $patch successfully."
    else
        echo "Failed to download $patch."
        exit 1
    fi
done

# Patch openssl/Makefile
OPENSSL_MAKEFILE="package/libs/openssl/Makefile"
if [ -f "$OPENSSL_MAKEFILE" ]; then
    echo "Patching $OPENSSL_MAKEFILE..."
    if sed -i 's/OPENSSL_TARGET:=linux-$(call qstrip,$(CONFIG_ARCH))-openwrt/OPENSSL_TARGET:=linux-$(call qstrip,$(CONFIG_ARCH))/g' $OPENSSL_MAKEFILE; then
        echo "Patched $OPENSSL_MAKEFILE successfully."
    else
        echo "Failed to patch $OPENSSL_MAKEFILE."
        exit 1
    fi
else
    echo "$OPENSSL_MAKEFILE not found."
    exit 1
fi

echo "All dependencies and patches are prepared successfully."

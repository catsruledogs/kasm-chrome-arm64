bash
#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --disable-search-engine-choice-screen --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"
CHROME_VERSION=$1

# Normalize architecture names
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

echo "Detected architecture: ${ARCH}"

if [[ "${ARCH}" != "amd64" && "${ARCH}" != "arm64" ]]; then
    echo "Unsupported architecture: ${ARCH}"
    exit 1
fi

# Determine the package architecture used by Google's repositories.
# Debian uses arm64/amd64.
# RPM uses aarch64/x86_64.
if [ "${ARCH}" == "arm64" ]; then
    DEB_ARCH="arm64"
    RPM_ARCH="aarch64"
else
    DEB_ARCH="amd64"
    RPM_ARCH="x86_64"
fi

###############################################################################
# Install Google Chrome
###############################################################################

if [[ "${DISTRO}" == @(centos|oracle8|rockylinux9|rockylinux8|oracle9|rhel9|almalinux9|almalinux8) ]]; then

    if [ -n "${CHROME_VERSION}" ]; then
        wget \
            "https://dl.google.com/linux/chrome/rpm/stable/${RPM_ARCH}/google-chrome-stable-${CHROME_VERSION}.${RPM_ARCH}.rpm" \
            -O chrome.rpm
    else
        if [ "${ARCH}" == "arm64" ]; then
            wget \
                "https://dl.google.com/linux/direct/google-chrome-stable_current_aarch64.rpm" \
                -O chrome.rpm
        else
            wget \
                "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm" \
                -O chrome.rpm
        fi
    fi

    if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|rhel9|almalinux9|almalinux8) ]]; then
        dnf localinstall -y chrome.rpm

        if [ -z "${SKIP_CLEAN+x}" ]; then
            dnf clean all
        fi
    else
        yum localinstall -y chrome.rpm

        if [ -z "${SKIP_CLEAN+x}" ]; then
            yum clean all
        fi
    fi

    rm -f chrome.rpm

elif [ "${DISTRO}" == "opensuse" ]; then

    if [ "${ARCH}" == "arm64" ]; then
        CHROME_RPM_ARCH="aarch64"
    else
        CHROME_RPM_ARCH="x86_64"
    fi

    zypper ar \
        "https://dl.google.com/linux/chrome/rpm/stable/${CHROME_RPM_ARCH}" \
        Google-Chrome

    wget https://dl.google.com/linux/linux_signing_key.pub
    rpm --import linux_signing_key.pub
    rm linux_signing_key.pub

    zypper install -yn google-chrome-stable

    if [ -z "${SKIP_CLEAN+x}" ]; then
        zypper clean --all
    fi

else

    ###########################################################################
    # Debian / Ubuntu
    ###########################################################################

    apt-get update

    if [ -n "${CHROME_VERSION}" ]; then
        wget \
            "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}_${DEB_ARCH}.deb" \
            -O chrome.deb
    else
        if [ "${ARCH}" == "arm64" ]; then
            echo "Downloading official Google Chrome ARM64 package"

            wget \
                "https://dl.google.com/linux/direct/google-chrome-stable_current_arm64.deb" \
                -O chrome.deb
        else
            echo "Downloading official Google Chrome AMD64 package"

            wget \
                "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
                -O chrome.deb
        fi
    fi

    apt-get install -y ./chrome.deb

    rm -f chrome.deb

    if [ -z "${SKIP_CLEAN+x}" ]; then
        apt-get autoclean
        rm -rf /var/lib/apt/lists/*
        rm -rf /var/tmp/*
    fi

fi

###############################################################################
# Configure Chrome desktop integration
###############################################################################

sed -i 's/-stable//g' /usr/share/applications/google-chrome.desktop

cp /usr/share/applications/google-chrome.desktop "$HOME/Desktop/"
chown 1000:1000 "$HOME/Desktop/google-chrome.desktop"
chmod +x "$HOME/Desktop/google-chrome.desktop"

###############################################################################
# Kasm Chrome wrapper
###############################################################################

mv /usr/bin/google-chrome /usr/bin/google-chrome-orig

cat >/usr/bin/google-chrome <<'EOL'
#!/usr/bin/env bash

CHROME_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --disable-search-engine-choice-screen --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"

supports_vulkan() {

    # Needs the CLI tool
    command -v vulkaninfo >/dev/null 2>&1 || return 1

    # Look for any non-CPU device
    DISPLAY= vulkaninfo --summary 2>/dev/null |
        grep -qE 'PHYSICAL_DEVICE_TYPE_(INTEGRATED_GPU|DISCRETE_GPU|VIRTUAL_GPU)'
}

if ! pgrep chrome > /dev/null; then
    rm -f "$HOME/.config/google-chrome/Singleton"*
fi

# These files may not exist on first launch.
# Only modify them when they exist.
if [ -f "$HOME/.config/google-chrome/Default/Preferences" ]; then
    sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' \
        "$HOME/.config/google-chrome/Default/Preferences"

    sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' \
        "$HOME/.config/google-chrome/Default/Preferences"
fi

VULKAN_FLAGS=""

if supports_vulkan; then
    VULKAN_FLAGS="--use-angle=vulkan"
    echo "vulkan supported"
fi

if [ -f /opt/VirtualGL/bin/vglrun ] \
    && [ -n "${KASM_EGL_CARD}" ] \
    && [ -n "${KASM_RENDERD}" ] \
    && [ -O "${KASM_RENDERD}" ] \
    && [ -O "${KASM_EGL_CARD}" ]; then

    echo "Starting Chrome with GPU Acceleration on EGL device ${KASM_EGL_CARD}"

    vglrun \
        -d "${KASM_EGL_CARD}" \
        /opt/google/chrome/google-chrome \
        ${CHROME_ARGS} \
        ${VULKAN_FLAGS} \
        "$@"

else

    echo "Starting Chrome"

    /opt/google/chrome/google-chrome \
        ${CHROME_ARGS} \
        ${VULKAN_FLAGS} \
        "$@"

fi
EOL

chmod +x /usr/bin/google-chrome

# Kasm also expects the "chrome" command.
cp /usr/bin/google-chrome /usr/bin/chrome

###############################################################################
# Default browser / MIME associations
###############################################################################

if [[ "${DISTRO}" == @(centos|oracle8|rockylinux9|rockylinux8|oracle9|rhel9|almalinux9|almalinux8|opensuse) ]]; then

    cat >> "$HOME/.config/mimeapps.list" <<'EOF'
[Default Applications]
x-scheme-handler/http=google-chrome.desktop
x-scheme-handler/https=google-chrome.desktop
x-scheme-handler/ftp=google-chrome.desktop
x-scheme-handler/chrome=google-chrome.desktop
text/html=google-chrome.desktop
application/x-extension-htm=google-chrome.desktop
application/x-extension-html=google-chrome.desktop
application/x-extension-shtml=google-chrome.desktop
application/xhtml+xml=google-chrome.desktop
application/x-extension-xhtml=google-chrome.desktop
application/x-extension-xht=google-chrome.desktop
EOF

else

    sed -i 's|@exec -a "$0" "$HERE/google-chrome" "$@"||g' \
        /usr/bin/x-www-browser

    cat >>/usr/bin/x-www-browser <<'EOL'
exec -a "$0" "$HERE/chrome" "$@"
EOL

fi

###############################################################################
# Chrome managed policies
###############################################################################

mkdir -p /etc/opt/chrome/policies/managed/

cat >/etc/opt/chrome/policies/managed/default_managed_policy.json <<'EOL'
{
    "CommandLineFlagSecurityWarningsEnabled": false,
    "DefaultBrowserSettingEnabled": false,
    "PrivacySandboxPromptEnabled": false
}
EOL

###############################################################################
# Cleanup
###############################################################################

chown -R 1000:0 "$HOME"

find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;

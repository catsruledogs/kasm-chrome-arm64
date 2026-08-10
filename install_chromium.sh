#!/usr/bin/env bash

set -euxo pipefail

CHROMIUM_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --disable-search-engine-choice-screen'"

echo "========================================"
echo "Installing ARM64 Chromium"
echo "========================================"

ARCH="$(dpkg --print-architecture)"

echo "Architecture: ${ARCH}"

if [ "${ARCH}" != "arm64" ]; then
    echo "ERROR: This image must be built on ARM64."
    exit 1
fi

apt-get update

apt-get install -y \
    chromium \
    chromium-common \
    chromium-sandbox \
    ca-certificates \
    wget \
    curl \
    procps \
    xdg-utils

apt-get clean

rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/*

echo "Chromium executable:"
command -v chromium || true

chromium --version || true

# --------------------------------------------------
# Chromium desktop entry
# --------------------------------------------------

if [ -f /usr/share/applications/chromium.desktop ]; then
    cp \
        /usr/share/applications/chromium.desktop \
        "${HOME}/Desktop/chromium.desktop"

    chown 1000:1000 \
        "${HOME}/Desktop/chromium.desktop"

    chmod +x \
        "${HOME}/Desktop/chromium.desktop"
fi

# --------------------------------------------------
# Chromium launcher
# --------------------------------------------------

cat > /usr/bin/chromium-kasm <<'EOF'
#!/usr/bin/env bash

set -e

CHROMIUM_ARGS=(
    "--password-store=basic"
    "--no-sandbox"
    "--ignore-gpu-blocklist"
    "--user-data-dir=${HOME}/.config/chromium"
    "--no-first-run"
    "--disable-search-engine-choice-screen"
    "--simulate-outdated-no-au=Tue, 31 Dec 2099 23:59:59 GMT"
)

supports_vulkan() {
    command -v vulkaninfo >/dev/null 2>&1 || return 1

    DISPLAY= vulkaninfo --summary 2>/dev/null |
        grep -qE 'PHYSICAL_DEVICE_TYPE_(INTEGRATED_GPU|DISCRETE_GPU|VIRTUAL_GPU)'
}

VULKAN_FLAGS=()

if supports_vulkan; then
    echo "Vulkan supported"
    VULKAN_FLAGS+=(--use-angle=vulkan)
fi

if [ -f /opt/VirtualGL/bin/vglrun ] \
    && [ -n "${KASM_EGL_CARD:-}" ] \
    && [ -n "${KASM_RENDERD:-}" ] \
    && [ -O "${KASM_RENDERD}" ] \
    && [ -O "${KASM_EGL_CARD}" ]; then

    echo "Starting Chromium with GPU acceleration"

    exec vglrun \
        -d "${KASM_EGL_CARD}" \
        /usr/bin/chromium \
        "${CHROMIUM_ARGS[@]}" \
        "${VULKAN_FLAGS[@]}" \
        "$@"

else

    echo "Starting Chromium"

    exec /usr/bin/chromium \
        "${CHROMIUM_ARGS[@]}" \
        "${VULKAN_FLAGS[@]}" \
        "$@"

fi
EOF

chmod +x /usr/bin/chromium-kasm

ln -sf /usr/bin/chromium-kasm /usr/bin/chromium-browser-kasm

# --------------------------------------------------
# Policies
# --------------------------------------------------

mkdir -p /etc/opt/chrome/policies/managed

cat > /etc/opt/chrome/policies/managed/default_managed_policy.json <<'EOF'
{
    "CommandLineFlagSecurityWarningsEnabled": false,
    "DefaultBrowserSettingEnabled": false,
    "PrivacySandboxPromptEnabled": false
}
EOF

# --------------------------------------------------
# MIME handlers
# --------------------------------------------------

cat >> "${HOME}/.config/mimeapps.list" <<'EOF'

[Default Applications]
x-scheme-handler/http=chromium.desktop
x-scheme-handler/https=chromium.desktop
x-scheme-handler/ftp=chromium.desktop
text/html=chromium.desktop
application/xhtml+xml=chromium.desktop
EOF

# --------------------------------------------------
# Ownership
# --------------------------------------------------

chown -R 1000:0 "${HOME}"

echo "========================================"
echo "ARM64 Chromium installation complete"
echo "========================================"

chromium --version

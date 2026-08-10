ARG BASE_TAG="develop"
ARG BASE_IMAGE="core-ubuntu-jammy"

FROM kasmweb/${BASE_IMAGE}:${BASE_TAG}

USER root

ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
ENV INST_SCRIPTS=${STARTUPDIR}/install

WORKDIR ${HOME}

# --------------------------------------------------
# Chromium ARM64
# --------------------------------------------------

COPY install_chromium.sh ${INST_SCRIPTS}/chromium/install_chromium.sh

RUN chmod +x ${INST_SCRIPTS}/chromium/install_chromium.sh \
    && bash ${INST_SCRIPTS}/chromium/install_chromium.sh \
    && rm -rf ${INST_SCRIPTS}/chromium

# --------------------------------------------------
# Desktop configuration
# --------------------------------------------------

RUN apt-get update \
    && apt-get install -y unzip \
    && rm -rf /var/lib/apt/lists/*

RUN cp ${HOME}/.config/xfce4/xfconf/single-application-xfce-perchannel-xml/* \
    ${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/

RUN cp /usr/share/backgrounds/bg_kasm.png \
    /usr/share/backgrounds/bg_default.png

RUN apt-get remove -y xfce4-panel

# --------------------------------------------------
# Security
# --------------------------------------------------

COPY ./src/common/chrome-managed-policies/urlblocklist.json \
    /etc/opt/chrome/policies/managed/urlblocklist.json

# --------------------------------------------------
# Startup
# --------------------------------------------------

COPY custom_startup.sh ${STARTUPDIR}/custom_startup.sh

RUN chmod +x ${STARTUPDIR}/custom_startup.sh

# --------------------------------------------------
# Restricted file chooser
# --------------------------------------------------

ENV KASM_RESTRICTED_FILE_CHOOSER=1

COPY ./src/ubuntu/install/gtk/ \
    ${INST_SCRIPTS}/gtk/

RUN bash ${INST_SCRIPTS}/gtk/install_restricted_file_chooser.sh \
    && rm -rf ${INST_SCRIPTS}/gtk

# --------------------------------------------------
# Prevent file-manager breakout
# --------------------------------------------------

COPY ./src/ubuntu/install/close_browser_breakout_via_file_manager/ \
    ${INST_SCRIPTS}/close_browser_breakout_via_file_manager/

RUN bash ${INST_SCRIPTS}/close_browser_breakout_via_file_manager/replace_thunar_with_empty_script.sh \
    && rm -rf ${INST_SCRIPTS}/close_browser_breakout_via_file_manager

# --------------------------------------------------
# Permissions
# --------------------------------------------------

RUN chown 1000:0 ${HOME}

RUN ${STARTUPDIR}/set_user_permission.sh ${HOME}

ENV HOME=/home/kasm-user

WORKDIR ${HOME}

RUN mkdir -p ${HOME} \
    && chown -R 1000:0 ${HOME}

USER 1000

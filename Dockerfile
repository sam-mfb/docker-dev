# check=skip=SecretsUsedInArgOrEnv
ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE} AS sam-dev

ARG DEBIAN_FRONTEND=noninteractive
ARG DD=/opt/docker-dev
# Every install step runs through this. --strict makes any failure fail the build.
ARG INSTALL="bash ${DD}/install/install.sh --strict --user devuser"

# Restore the man pages and docs that the minimal Ubuntu image strips out.
RUN apt-get update && apt-get install -y unminimize && yes | unminimize

# The dev user, with passwordless sudo. UID 1002 matches the host user on WSL.
RUN apt-get install -y sudo \
    && useradd -ms /bin/bash -u 1002 -G sudo devuser \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/nopasswd \
    && echo 'Defaults env_keep += "http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY"' > /etc/sudoers.d/proxy \
    && chmod 0440 /etc/sudoers.d/*
# /workspace is a named volume. Docker seeds an empty volume from this
# directory, so it comes up owned by devuser. /host-mnt holds run.sh -m mounts.
RUN mkdir -p /workspace /host-mnt && chown devuser:devuser /workspace

# Each group is copied just before it runs, so editing one group's files
# rebuilds that group and the ones after it, not the ones before. Groups that
# change least come first. Changing versions.env rebuilds everything.
COPY install/install.sh install/lib.sh install/versions.env ${DD}/install/
COPY install/steps/base ${DD}/install/steps/base
RUN ${INSTALL} --only base

COPY install/steps/languages ${DD}/install/steps/languages
COPY InstallPSMods.ps1 ${DD}/
RUN ${INSTALL} --only languages

COPY install/steps/docker ${DD}/install/steps/docker
RUN ${INSTALL} --only docker

COPY install/steps/cloud ${DD}/install/steps/cloud
RUN ${INSTALL} --only cloud

COPY install/steps/desktop ${DD}/install/steps/desktop
COPY mfb-root-certificate.crt ${DD}/
RUN ${INSTALL} --only desktop

COPY install/steps/terminal ${DD}/install/steps/terminal
COPY dotfiles ${DD}/dotfiles
COPY tmux_dev.sh ${DD}/
RUN ${INSTALL} --only terminal

COPY install/steps/forwarders ${DD}/install/steps/forwarders
COPY setup-gcf-client.sh ${DD}/
RUN ${INSTALL} --only forwarders

COPY install/steps/ai ${DD}/install/steps/ai
COPY update-claude-meta.sh ${DD}/
RUN ${INSTALL} --only ai

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# The install steps write these to ~/.docker-dev/env.d for shells. They are
# repeated here for processes that start without a shell, such as `docker exec`
# of a single command.
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color \
    PATH=/home/devuser/.local/bin:/home/devuser/.cargo/bin:/home/devuser/.opencode/bin:/home/devuser/.dotnet:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/devuser/.dotnet/tools \
    DOTNET_ROOT=/home/devuser/.dotnet \
    GIT_CREDENTIAL_FORWARDER_SERVER=host.docker.internal:38274 \
    OAUTH2_FORWARDER_SERVER=host.docker.internal:48272 \
    BROWSER=o2f-browser \
    DISPLAY=:99 \
    VNC_RESOLUTION=1280x1024x24 \
    VNC_PORT=5900 \
    NOVNC_PORT=6080

USER devuser
WORKDIR /home/devuser
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]

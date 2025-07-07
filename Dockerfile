# check=skip=SecretsUsedInArgOrEnv
FROM mcr.microsoft.com/playwright:v1.45.3-noble AS ts-dev-align

ARG D2_VERSION=0.6.9
ARG NPM_VERSION=10.8.2
ARG NVM_VERSION=0.40.3
ARG NODE_LTS_NAME=iron
ARG GCF_PORT=38274
ARG O2F_PORT=48272
ARG PWSH_VERSION=7.5.1
ARG DOCKER_COMPOSE_VERSION=2.33.0
ARG DOCKER_SWITCH_VERSION=1.0.5

RUN yes | unminimize

RUN apt-get update
RUN apt-get -y install nano vim-gtk3 xclip tmux git fzf ripgrep curl python3 python3-setuptools ssh sqlite3 sudo locales ca-certificates gnupg lsb-release libnss3-tools upower uuid-runtime build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev dbus-x11 libsecret-1-0 libsecret-1-dev libsecret-tools gnome-keyring xdg-utils gstreamer1.0-gl gstreamer1.0-plugins-ugly jq

# Install docker cli
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update
RUN apt-get -y install docker-ce-cli
# Make buildx the default builder
RUN docker buildx install
# Give container user access to docker socket (which will be bound at container run time)
RUN touch /var/run/docker.sock
RUN chgrp sudo /var/run/docker.sock
# Install docker compose v2
RUN curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
RUN chmod +x /usr/libexec/docker/cli-plugins/docker-compose
RUN curl -fL https://github.com/docker/compose-switch/releases/download/v${DOCKER_SWITCH_VERSION}/docker-compose-linux-amd64 -o /usr/local/bin/compose-switch
RUN chmod +x /usr/local/bin/compose-switch
RUN update-alternatives --install /usr/local/bin/docker-compose docker-compose /usr/local/bin/compose-switch 99

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

#setup dev user
RUN useradd -ms /bin/bash -u 1002 -G sudo devuser
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
WORKDIR /home/devuser
USER devuser
ENV TERM="xterm-256color"
COPY dotfiles/tmux.conf .tmux.conf
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash .git-completion.bash
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh .git-prompt.sh
COPY dotfiles/bashrc .bashrc
COPY dotfiles/gitconfig .gitconfig

# Package to allow easy tmux/vim navigation
RUN git clone https://github.com/christoomey/vim-tmux-navigator.git .vim/pack/plugins/start/vim-tmux-navigator
RUN sudo chown -R devuser /home/devuser

# used by dbus/chrome
RUN sudo mkdir /run/user/1002
RUN sudo chmod 700 /run/user/1002
RUN sudo chown devuser /run/user/1002

## add mfb crt to chromium
COPY /mfb-root-certificate.crt /home/devuser/server.crt
RUN mkdir -p /home/devuser/.pki/nssdb
RUN certutil -N --empty-password -d sql:/home/devuser/.pki/nssdb 
RUN certutil -A -d sql:/home/devuser/.pki/nssdb -t "C,," -n server -i server.crt

# Add public keys for well known repos
RUN mkdir -p -m 0700 ~/.ssh
RUN ssh-keyscan github.com >> ~/.ssh/known_hosts
RUN ssh-keyscan ssh.dev.azure.com >> ~/.ssh/known_hosts
COPY dotfiles/sshconfig .ssh/config

# install nvm with a specified version of node; could use a node base image, but this is
# more flexible
SHELL ["/bin/bash", "--login", "-c"]
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash \
    && . ~/.nvm/nvm.sh \
    && nvm install lts/${NODE_LTS_NAME}
RUN npm install -g npm@${NPM_VERSION}

## install git credential forwarder
RUN npm install -g git-credential-forwarder
COPY setup-gcf-client.sh ./setup-gcf-client.sh
RUN sudo chmod 755 ./setup-gcf-client.sh
RUN ./setup-gcf-client.sh
ENV GIT_CREDENTIAL_FORWARDER_SERVER=host.docker.internal:${GCF_PORT}

## install oauth2 forwarder
RUN npm install -g oauth2-forwarder
## use this file via `source ~/.browser_env` if VS code clobbers BROWSER
COPY dotfiles/browser_env ./.browser_env
ENV OAUTH2_FORWARDER_SERVER=host.docker.internal:${O2F_PORT}
ENV BROWSER=o2f-browser

## tmux script
COPY tmux_dev.sh ./tmux_dev.sh
RUN sudo chmod 755 ./tmux_dev.sh

## setup coc
COPY dotfiles/vimrc-coc-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-coc .vimrc
RUN mkdir -pv /home/devuser/.config/coc
RUN . ~/.nvm/nvm.sh && vim +'CocInstall -sync coc-css coc-eslint coc-html coc-json coc-prettier coc-spell-checker coc-tsserver coc-yaml coc-snippets coc-powershell' +qa
RUN . ~/.nvm/nvm.sh && vim +'CocUpdateSync' +qa
COPY dotfiles/coc-settings.json .vim/coc-settings.json
RUN sudo chown devuser .vim/coc-settings.json
COPY dotfiles/popup_scroll.vim .vim/autoload/popup_scroll.vim

# install powershell
RUN sudo mkdir -p /opt/microsoft/powershell/7
RUN arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/x64/) && \
    sudo curl -sSL "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${arch}.tar.gz" -o /opt/microsoft/powershell.tar.gz
RUN sudo tar zxf /opt/microsoft/powershell.tar.gz -C /opt/microsoft/powershell/7
RUN sudo chmod +x /opt/microsoft/powershell/7/pwsh
RUN sudo ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
COPY InstallPSMods.ps1 /opt/microsoft/powershell/InstallPSMods.ps1

# install GitHub CLI
RUN sudo mkdir -p -m 755 /etc/apt/keyrings
RUN out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg && \
    cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
RUN sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
RUN sudo apt update
RUN sudo apt install -y gh

# install azure cli
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
RUN az extension add --name azure-devops

# install Claude
RUN npm install -g @anthropic-ai/claude-code
ARG ANTHROPIC_API_KEY
ENV ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
COPY dotfiles/claude.json .claude.json
RUN mkdir .claude
COPY dotfiles/claude.settings.json .claude/settings.json
RUN sudo chown devuser .claude.json
## Uncomment if using API KEY
## COPY add_anthropic_key.sh add_anthropic_key.sh
## RUN sudo chmod +x add_anthropic_key.sh
## RUN ./add_anthropic_key.sh

RUN npm install -g @microsoft/rush
ARG GIT_REPO
ENV ALIGN_REPO=${GIT_REPO}

ENTRYPOINT ["bash"]

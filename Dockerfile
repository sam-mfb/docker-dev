ARG D2_VERSION=0.6.3

FROM mcr.microsoft.com/playwright:v1.37.1-jammy as base 
ARG DEBIAN_FRONTEND=noninteractive
ARG D2_VERSION
RUN yes | unminimize
RUN apt-get update
# cairo, pango, and graphics libraries needed to support node-canvas building
RUN apt-get -y install vim-nox tmux git fzf ripgrep curl python3 ssh sqlite3 sudo locales ca-certificates gnupg lsb-release libnss3-tools upower uuid-runtime build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev  
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
RUN curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
RUN chmod +x /usr/libexec/docker/cli-plugins/docker-compose
RUN curl -fL https://github.com/docker/compose-switch/releases/download/v1.0.5/docker-compose-linux-amd64 -o /usr/local/bin/compose-switch
RUN chmod +x /usr/local/bin/compose-switch
RUN update-alternatives --install /usr/local/bin/docker-compose docker-compose /usr/local/bin/compose-switch 99
# install packer for image building
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
RUN apt update && apt install packer
# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
# install azure cli
RUN apt-get update
RUN apt-get -y install pip
RUN pip install azure-cli
# install powershell
RUN mkdir -p /opt/microsoft/powershell/7
RUN arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/x64/) && \
    curl -sSL "https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/powershell-7.4.1-linux-${arch}.tar.gz" -o /opt/microsoft/powershell.tar.gz
RUN tar zxf /opt/microsoft/powershell.tar.gz -C /opt/microsoft/powershell/7
RUN chmod +x /opt/microsoft/powershell/7/pwsh
RUN ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
COPY InstallPSMods.ps1 /opt/microsoft/powershell/InstallPSMods.ps1
#setup dev user
RUN useradd -ms /bin/bash -u 1002 -G sudo devuser
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
WORKDIR /home/devuser
ENV TERM="xterm-256color"
COPY dotfiles/tmux.conf .tmux.conf
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash .git-completion.bash
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh .git-prompt.sh
COPY dotfiles/bashrc .bashrc
COPY .gitconfig .gitconfig
# Package to allow easy tmux/vim navigation
RUN git clone https://github.com/christoomey/vim-tmux-navigator.git .vim/pack/plugins/start/vim-tmux-navigator
RUN chown -R devuser /home/devuser
# used by dbus/chrome
RUN mkdir /run/user/1002
RUN sudo chmod 700 /run/user/1002
RUN sudo chown devuser /run/user/1002
USER devuser
# install D2 (https://d2lang.com/)
RUN curl -fsSL https://d2lang.com/install.sh | sh -s -- --version v${D2_VERSION} 
ENV PATH /home/devuser/.local/lib/d2/d2-v${D2_VERSION}/bin:$PATH
RUN d2 --help
# install powershell modules
RUN pwsh /opt/microsoft/powershell/InstallPSMods.ps1
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
RUN az extension add --name azure-devops
## install dotnet
## No arm64 version yet...so we have to install from binaries rather than from the repo
RUN wget https://dot.net/v1/dotnet-install.sh
RUN mkdir -p $HOME/dotnet 
# install latest
RUN bash ./dotnet-install.sh --install-dir $HOME/dotnet
# install 7 runtime to run GCM
RUN bash ./dotnet-install.sh --install-dir $HOME/dotnet --runtime dotnet --version 7.0.13 
RUN export PATH=$PATH:$HOME/dotnet:$HOME/.dotnet/tools
RUN export DOTNET_ROOT=$HOME/dotnet
RUN $HOME/dotnet/dotnet tool install -g git-credential-manager
RUN DOTNET_ROOT=$HOME/dotnet $HOME/.dotnet/tools/git-credential-manager configure
RUN git config --global credential.credentialStore cache
RUN git config --global credential.cacheOptions "--timeout 36000"
RUN git config --global credential.msauthFlow devicecode
RUN git config --global credential.azreposCredentialType oauth
ENTRYPOINT bash

# .NET Core Development Image

FROM base as dotnet-dev
# Compile and install sqlite interop and extension (to get arm64 compatability
# NB: You will have to modify the csproj that uses System.Data.SQLite.Core to remove that
# ProjectReference and instead add this to the root of the csproj file:
# <ItemGroup>
#   <Reference Include="..\..\sqlite-source\bin\NetStandard21\ReleaseNetStandard21\bin\netstandard2.1\System.Data.SQLite.dll" />
# </ItemGroup>
# This ensure that the extension lib called by dotnet matches the interop lib compiled here
COPY ./sqlite-netFx-source-1.0.116.0.zip sqlite-netFx-source-1.0.116.0.zip
COPY ./sqlite-csproj.fragment sqlite-csproj.fragment
RUN unzip ./sqlite-netFx-source-1.0.116.0.zip -d sqlite-source
RUN bash ./sqlite-source/Setup/compile-interop-assembly-release.sh
WORKDIR /home/devuser/sqlite-source/System.Data.SQLite
RUN $HOME/dotnet/dotnet build -c Release System.Data.SQLite.NetStandard21.csproj
WORKDIR /home/devuser
RUN sudo cp ./sqlite-source/bin/2013/Release/bin/SQLite.Interop.dll /usr/lib/libSQLite.Interop.dll
COPY dotfiles/vimrc-omni-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-omni .vimrc
# pre-install the Omnisharp-Roslyn engine
RUN .vim/plugged/omnisharp-vim/installer/omnisharp-manager.sh -l .cache/omnisharp-vim/omnisharp-roslyn

# Coc Development Image

FROM base AS coc-dev
SHELL ["/bin/bash", "--login", "-c"]
# install nvm with a specified version of node; could use a node base image, but this is
# more flexible
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && . ~/.nvm/nvm.sh \
    && nvm install lts/hydrogen
RUN . ~/.nvm/nvm.sh && npm install -g npm@9.8.1
COPY dotfiles/vimrc-coc-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-coc .vimrc
RUN mkdir -pv /home/devuser/.config/coc
RUN . ~/.nvm/nvm.sh && vim +'CocInstall -sync coc-css coc-eslint coc-html coc-json coc-prettier coc-spell-checker coc-tsserver coc-yaml coc-snippets coc-powershell' +qa
RUN . ~/.nvm/nvm.sh && vim +'CocUpdateSync' +qa
COPY dotfiles/coc-settings.json .vim/coc-settings.json
RUN sudo chown devuser .vim/coc-settings.json
COPY dotfiles/popup_scroll.vim .vim/autoload/popup_scroll.vim
WORKDIR /home/devuser

# Coc Image preconfigured for Align Typescript development

FROM coc-dev AS ts-dev-align
# deps for webkit browser
RUN sudo apt-get update && sudo apt-get install -y gstreamer1.0-gl gstreamer1.0-plugins-ugly
RUN . ~/.nvm/nvm.sh && npm install -g @microsoft/rush
ARG GIT_REPO
ENV ALIGN_REPO=${GIT_REPO}

# Coc Image preconfigured for Align PowerShell development

FROM coc-dev AS pwsh-dev-align

# Swift build SwiftLint

FROM swiftlang/swift:nightly-5.6-focal AS swiftlint-build
RUN apt-get update
RUN apt-get install -y clang libblocksruntime0 libcurl4-openssl-dev libxml2-dev git
RUN git clone https://github.com/realm/SwiftLint.git
WORKDIR SwiftLint
RUN git checkout 0.46.5 
ARG SWIFT_FLAGS="-c release"
RUN swift build $SWIFT_FLAGS
RUN mkdir -p /executables
RUN mv $(swift build $SWIFT_FLAGS --show-bin-path)/swiftlint /executables

# Swift linux development

FROM swiftlang/swift:nightly-5.6-focal AS swift-base
COPY --from=swiftlint-build /executables/swiftlint /usr/bin/swiftlint
RUN apt-get update
RUN apt-get -y install software-properties-common git python3
RUN add-apt-repository ppa:jonathonf/vim
RUN apt-get update
RUN apt-get -y install vim-common=2:8.2.2815-0york0~20.04 vim-runtime=2:8.2.2815-0york0~20.04 vim=2:8.2.2815-0york0~20.04
RUN apt-get -y install tmux fzf ripgrep curl ssh sqlite3 sudo locales
# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
RUN useradd -ms /bin/bash -u 1002 -G sudo devuser
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
WORKDIR /home/devuser
ENV TERM="xterm-256color"
COPY dotfiles/tmux.conf .tmux.conf
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash .git-completion.bash
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh .git-prompt.sh
COPY dotfiles/bashrc .bashrc
COPY .gitconfig .gitconfig
# Package to allow easy tmux/vim navigation
RUN git clone https://github.com/christoomey/vim-tmux-navigator.git .vim/pack/plugins/start/vim-tmux-navigator
RUN chown -R devuser /home/devuser
USER devuser
RUN mkdir -p -m 0700 ~/.ssh
# Add public keys for well known repos
RUN ssh-keyscan github.com >> ~/.ssh/known_hosts
RUN ssh-keyscan ssh.dev.azure.com >> ~/.ssh/known_hosts
ENTRYPOINT bash
SHELL ["/bin/bash", "--login", "-c"]
# install nvm with a specified version of node; could use a node base image, but this is
# more flexible
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash \
    && . ~/.nvm/nvm.sh \
    && nvm install lts/hydrogen
COPY dotfiles/vimrc-swift-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-swift .vimrc
RUN mkdir -pv /home/devuser/.config/coc
RUN . ~/.nvm/nvm.sh && vim +'CocInstall -sync coc-css coc-eslint coc-html coc-json coc-prettier coc-spell-checker coc-yaml coc-sourcekit' +qa
RUN . ~/.nvm/nvm.sh && vim +'CocUpdateSync' +qa
COPY dotfiles/coc-settings.swift.json .vim/coc-settings.json
COPY dotfiles/popup_scroll.vim .vim/autoload/popup_scroll.vim
COPY dotfiles/swiftlint.yml .swiftlint.yml

## LISP development

FROM debian:bullseye-slim as lisp-dev
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get -y install vim-nox tmux git fzf ripgrep curl python3 ssh sqlite3 sudo locales sbcl
# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
#setup dev user
RUN useradd -ms /bin/bash -u 1002 -G sudo devuser
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
WORKDIR /home/devuser
ENV TERM="xterm-256color"
COPY dotfiles/tmux.conf .tmux.conf
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash .git-completion.bash
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh .git-prompt.sh
COPY dotfiles/bashrc .bashrc
COPY .gitconfig .gitconfig
## don't setup dbus (used in .bashrc)
ENV NO_DBUS_CONFIG="true"
# Package to allow easy tmux/vim navigation
RUN git clone https://github.com/christoomey/vim-tmux-navigator.git .vim/pack/plugins/start/vim-tmux-navigator
RUN chown -R devuser /home/devuser
USER devuser
# Add public keys for well known repos
RUN mkdir -p -m 0700 ~/.ssh
RUN ssh-keyscan github.com >> ~/.ssh/known_hosts
RUN ssh-keyscan ssh.dev.azure.com >> ~/.ssh/known_hosts
COPY dotfiles/sshconfig .ssh/config
# Install slimv
RUN git clone https://github.com/kovisoft/slimv.git ~/.vim/pack/plugins/start/slimv
RUN vim +'helptags ~/.vim/pack/plugins/start/slimv/doc' +q
ENTRYPOINT bash

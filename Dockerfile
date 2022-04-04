FROM mcr.microsoft.com/dotnet/sdk:5.0-bullseye-slim AS base
RUN apt-get update
RUN apt-get -y install vim-nox tmux git fzf ripgrep curl python3 ssh sqlite3 sudo locales ca-certificates gnupg lsb-release
# Install docker cli
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update
RUN apt-get -y install docker-ce-cli
# Make buildx the default builder
RUN docker buildx install
# Give container user access to docker socket (which will be bound at container run time)
RUN touch /var/run/docker.sock
RUN chown root:sudo /var/run/docker.sock
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

## Vim-doge build image

FROM node:16-bullseye-slim AS vim-doge-build
RUN apt-get update
RUN apt-get install -y git vim make g++ python3
RUN git clone https://github.com/kkoomen/vim-doge.git
WORKDIR vim-doge
RUN mkdir bin
RUN npm install
RUN npm run build

# .NET Core Development Image

FROM base AS dotnet-dev
COPY dotfiles/vimrc-omni-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-omni .vimrc
# pre-install the Omnisharp-Roslyn engine
RUN .vim/plugged/omnisharp-vim/installer/omnisharp-manager.sh -l .cache/omnisharp-vim/omnisharp-roslyn
ARG GIT_REPO
ARG CLONE_DIR
# mount the ssh-agent port as the current user for purposes of cloning private repos
RUN --mount=type=ssh,uid=1002 git clone ${GIT_REPO} ${CLONE_DIR}
WORKDIR /home/devuser/${CLONE_DIR}
RUN dotnet restore

# TypeScript Development Image

FROM base AS ts-dev
SHELL ["/bin/bash", "--login", "-c"]
# install nvm with a specified version of node; could use a node base image, but this is
# more flexible
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
&& . ~/.nvm/nvm.sh \
&& nvm install lts/gallium
COPY dotfiles/vimrc-coc-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-coc .vimrc
RUN mkdir -pv /home/devuser/.config/coc
RUN . ~/.nvm/nvm.sh && vim +'CocInstall -sync coc-css coc-eslint coc-html coc-json coc-prettier coc-spell-checker coc-tsserver coc-yaml' +qa
RUN . ~/.nvm/nvm.sh && vim +'CocUpdateSync' +qa
COPY dotfiles/coc-settings.json .vim/coc-settings.json
COPY dotfiles/popup_scroll.vim .vim/autoload/popup_scroll.vim
RUN rm -rf /home/devuser/.vim/plugged/vim-doge
COPY --chown=devuser --from=vim-doge-build /vim-doge /home/devuser/.vim/plugged/vim-doge
WORKDIR /home/devuser

# TS Image preconfigured for Align

FROM ts-dev AS ts-dev-align
ARG GIT_REPO
ARG CLONE_DIR
# mount the ssh-agent port as the current user for purposes of cloning private repos
RUN --mount=type=ssh,uid=1002 git clone ${GIT_REPO} ${CLONE_DIR}
RUN . ~/.nvm/nvm.sh && npm install -g @microsoft/rush
WORKDIR /home/devuser/${CLONE_DIR}
RUN rush install
# needed to work around a quirk in our repo where rush install generates a non-ignored script file
RUN git reset --hard
VOLUME /home/devuser/$CLONE_DIR

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
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
&& . ~/.nvm/nvm.sh \
&& nvm install lts/gallium
COPY dotfiles/vimrc-swift-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-swift .vimrc
RUN mkdir -pv /home/devuser/.config/coc
RUN . ~/.nvm/nvm.sh && vim +'CocInstall -sync coc-css coc-eslint coc-html coc-json coc-prettier coc-spell-checker coc-yaml coc-sourcekit' +qa
RUN . ~/.nvm/nvm.sh && vim +'CocUpdateSync' +qa
COPY dotfiles/coc-settings.swift.json .vim/coc-settings.json
COPY dotfiles/popup_scroll.vim .vim/autoload/popup_scroll.vim
COPY dotfiles/swiftlint.yml .swiftlint.yml

FROM mcr.microsoft.com/dotnet/sdk:5.0-bullseye-slim AS base
RUN apt-get update
RUN apt-get -y install vim-nox tmux git fzf ripgrep curl python3 ssh
RUN useradd -ms /bin/bash -u 1002 devuser
WORKDIR /home/devuser
ENV TERM="xterm-256color"
COPY dotfiles/tmux.conf .tmux.conf
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash .git-completion.bash
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh .git-prompt.sh
COPY dotfiles/bashrc .bashrc
COPY .gitconfig .gitconfig
RUN git clone https://github.com/christoomey/vim-tmux-navigator.git .vim/pack/plugins/start/vim-tmux-navigator
RUN chown -R devuser /home/devuser
USER devuser
RUN mkdir -p -m 0700 ~/.ssh
RUN ssh-keyscan ssh.dev.azure.com >> ~/.ssh/known_hosts
ENTRYPOINT bash

FROM base AS dotnet-dev
COPY dotfiles/vimrc-omni-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-omni .vimrc
RUN .vim/plugged/omnisharp-vim/installer/omnisharp-manager.sh -l .cache/omnisharp-vim/omnisharp-roslyn
ARG GIT_REPO
ARG CLONE_DIR
RUN --mount=type=ssh,uid=1002 git clone ${GIT_REPO} ${CLONE_DIR}
WORKDIR /home/devuser/${CLONE_DIR}
RUN dotnet restore

FROM base AS ts-dev
SHELL ["/bin/bash", "--login", "-c"]
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
&& . ~/.nvm/nvm.sh \
&& nvm install v16.13.1
COPY dotfiles/vimrc-coc-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-coc .vimrc
RUN mkdir -pv /home/devuser/.config/coc
RUN . ~/.nvm/nvm.sh && vim +'CocInstall -sync coc-css coc-eslint coc-html coc-json coc-prettier coc-spell-checker coc-tsserver coc-yaml' +qa
RUN . ~/.nvm/nvm.sh && vim +'CocUpdateSync' +qa
COPY dotfiles/coc-settings.json .vim/coc-settings.json
RUN . ~/.nvm/nvm.sh && npm install -g @microsoft/rush
ARG GIT_REPO
ARG CLONE_DIR
RUN --mount=type=ssh,uid=1002 git clone ${GIT_REPO} ${CLONE_DIR}
WORKDIR /home/devuser/${CLONE_DIR}
RUN rush install
RUN git reset --hard

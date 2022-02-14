FROM mcr.microsoft.com/dotnet/sdk:5.0-bullseye-slim AS base
RUN apt-get update
RUN apt-get -y install vim-nox tmux git fzf ripgrep curl python3
RUN useradd -ms /bin/bash sam
WORKDIR /home/sam
ENV TERM="xterm-256color"
COPY dotfiles/tmux.conf .tmux.conf
RUN chown -R sam /home/sam
USER sam
ENTRYPOINT bash

FROM base AS dotnet
COPY dotfiles/vimrc-omni-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-omni .vimrc
RUN .vim/plugged/omnisharp-vim/installer/omnisharp-manager.sh -l .cache/omnisharp-vim/omnisharp-roslyn

FROM base AS ts
COPY dotfiles/vimrc-coc-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-coc .vimrc
COPY vim/coc-settings.json .vim/coc-settings.json

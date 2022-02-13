FROM mcr.microsoft.com/dotnet/sdk:5.0-bullseye-slim as dotnet
RUN apt-get update
RUN apt-get -y install vim-nox tmux git fzf ripgrep curl python3
RUN useradd -ms /bin/bash sam
WORKDIR /home/sam
RUN chown -R sam /home/sam
USER sam
COPY dotfiles/vimrc-omni-install .vimrc
COPY dotfiles/tmux.conf .tmux.conf
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-omni .vimrc
COPY omnisharp-manager.sh .vim/plugged/omnisharp-vim/installer/
ENV TERM="xterm-256color"
ENTRYPOINT bash

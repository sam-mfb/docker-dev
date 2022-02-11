FROM ubuntu as linux_base
ENTRYPOINT bash

FROM linux_base as dotnet
RUN apt-get update
RUN apt-get -y install vim tmux git
RUN useradd -ms /bin/bash sam
USER sam
WORKDIR /home/sam
COPY dotfiles/vimrc-omni .vimrc
COPY dotfiles/tmux.conf .tmux.conf

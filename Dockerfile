FROM mcr.microsoft.com/dotnet/sdk:5.0-bullseye-slim AS base
RUN apt-get update
RUN apt-get -y install vim-nox tmux git fzf ripgrep curl python3 ssh
RUN useradd -ms /bin/bash sam
WORKDIR /home/sam
ENV TERM="xterm-256color"
COPY dotfiles/tmux.conf .tmux.conf
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash .git-completion.bash
ADD https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh .git-prompt.sh
COPY dotfiles/bashrc .bashrc
RUN git clone https://github.com/christoomey/vim-tmux-navigator.git .vim/pack/plugins/start/vim-tmux-navigator
RUN chown -R sam /home/sam
USER sam
ENTRYPOINT bash

FROM base AS dotnet
COPY dotfiles/vimrc-omni-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-omni .vimrc
RUN .vim/plugged/omnisharp-vim/installer/omnisharp-manager.sh -l .cache/omnisharp-vim/omnisharp-roslyn

FROM base AS ts
SHELL ["/bin/bash", "--login", "-c"]
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
&& . ~/.nvm/nvm.sh \
&& nvm install lts/gallium \
&& nvm install lts/fermium
COPY dotfiles/vimrc-coc-install .vimrc
RUN vim +'PlugInstall --sync' +qa
COPY dotfiles/vimrc-coc .vimrc
RUN mkdir -pv /home/sam/.config/coc
RUN . ~/.nvm/nvm.sh && vim +'CocInstall -sync coc-css coc-eslint coc-html coc-json coc-prettier coc-spell-checker coc-tsserver coc-yaml' +qa
RUN . ~/.nvm/nvm.sh && vim +'CocUpdateSync' +qa
COPY vim/coc-settings.json .vim/coc-settings.json

FROM ubuntu as linux_base
ENTRYPOINT bash

FROM linux_base as dotnet
RUN apt-get update
RUN apt-get -y install vim tmux git


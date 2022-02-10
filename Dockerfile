FROM ubuntu as linux_base
ENTRYPOINT bash

FROM linux_base as dotnet


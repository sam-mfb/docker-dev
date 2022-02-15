#/bin/sh

docker build --ssh default --pull --target ts -t align-ts-dev .
docker run --rm -p 3000:3000 --mount type=bind,src=${HOME}/.ssh,target=/home/sam/.ssh -it align-ts-dev

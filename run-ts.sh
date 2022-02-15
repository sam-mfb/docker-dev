#/bin/sh

if [[ "$(docker images -q align-ts-dev 2> /dev/null)" == "" ]]; then
    echo "Building align-ts-dev image..."
    docker build --ssh default --pull --target ts -t align-ts-dev .
fi
echo "Running align-ts-dev container..."
docker run -p 3000:3000 --mount type=bind,src=${HOME}/.ssh,target=/home/sam/.ssh -it align-ts-dev

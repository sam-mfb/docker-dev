#/bin/bash

run_func () {
# flags to easily delete image and container
local OPTIND o a
while getopts ":krx" option; do
    case $option in
        k)
            echo "Deleting container..."
            docker container rm ${CONTAINER_NAME}
            exit;;
        r)
            echo "Deleting image..."
            docker rmi ${IMAGE_TAG}
            exit;;
        x)
            echo "Deleting image and container..."
            docker container rm ${CONTAINER_NAME}
            docker rmi ${IMAGE_TAG}
            exit;;
    esac
done

# build image if not built already
if [[ "$(docker images -q ${IMAGE_TAG} 2> /dev/null)" == "" ]]; then
    echo "Building image..."
    docker build --ssh default --pull --build-arg GIT_REPO=${GIT_REPO} --build-arg CLONE_DIR=${CLONE_DIR} --target ${IMAGE_TARGET} -t ${IMAGE_TAG} .
fi

# run container if not created, otherwise attach to existing
if [[ "$(docker container ls -qa --filter name=${CONTAINER_NAME} 2> /dev/null)" == "" ]]; then
    echo "Creating and running container..."
    docker run -p ${HOST_PORTS}:${CONTAINER_PORTS} --mount type=bind,src=${HOME}/.ssh,target=${DOCKER_USER_HOME}/.ssh --mount type=bind,src=/var/run/docker.sock,target=/var/run/docker.sock --detach-keys='ctrl-z,z' --name ${CONTAINER_NAME} -h ${HOSTNAME} -it ${IMAGE_TAG}
else
    echo "Starting and attaching to existing container..."
    docker start --detach-keys='ctrl-z,z' -i ${CONTAINER_NAME}
fi
}

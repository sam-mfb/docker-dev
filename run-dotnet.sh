#/bin/sh

IMAGE_TARGET="align-services-dev"
IMAGE_TAG="align-services-dev"
CONTAINER_NAME="align-services-dev-active"
HOST_PORTS="12000-12050"
CONTAINER_PORTS="12000-12050"

# flags to easily delete image and container
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
    docker build --ssh default --pull --target ${IMAGE_TARGET} -t ${IMAGE_TAG} .
fi

# run container if not created, otherwise attach to existing
if [[ "$(docker container ls -qa --filter name=${CONTAINER_NAME} 2> /dev/null)" == "" ]]; then
    echo "Creating and running container..."
    docker run -p ${HOST_PORTS}:${CONTAINER_PORTS} --mount type=bind,src=${HOME}/.ssh,target=/home/sam/.ssh --detach-keys='ctrl-z,z' --name ${CONTAINER_NAME} -it ${IMAGE_TAG}
else
    echo "Starting and attaching to existing container..."
    docker start --detach-keys='ctrl-z,z' -i ${CONTAINER_NAME}
fi

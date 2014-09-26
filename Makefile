
DOCKER_IMAGE="rsmmr/llvm35"

all:

# Note, building the Docker image needs the default image size increased.
# On Fedora: add "--storage-opt dm.basesize=30G" to /etc/sysconfig/docker.

docker-build:
	docker build -t ${DOCKER_IMAGE} .

docker-run:
	docker run -i -t ${DOCKER_IMAGE} /bin/bash


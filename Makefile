
IMAGE="rsmmr/clang:6.0"

all:

# Note, building the Docker image needs the default image size increased.
# On Fedora: add "--storage-opt dm.basesize=30G" to /etc/sysconfig/docker.

docker-build:
	docker build -t ${IMAGE} .

docker-run:
	docker run -i -t ${IMAGE}

docker-push:
	docker push ${IMAGE}

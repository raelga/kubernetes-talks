VERSION=0.1
REPOSITORY?=raelga/hello-world-nginx
TAG=v$(VERSION)

all: build push

build:
	@echo "Building image:"
	docker build -t $(REPOSITORY):$(TAG) -f Dockerfile ctx

push:
	@echo "Pushing image:"
	docker push $(REPOSITORY):$(TAG)

run:
	@echo "Running container:"
	docker run --rm -p 8080:8080 $(REPOSITORY):$(TAG)

bg:
	@echo "Running container in the background:"
	docker run --name hello --rm -d -p 8080:8080 $(REPOSITORY):$(TAG)

logs:
	@echo "Showing container logs:"
	docker logs -f hello

exec:
	@echo "Accessing container shell:"
	docker exec -ti hello /bin/sh

stop:
	@echo "Stopping container:"
	-docker stop hello

clean: stop
	@echo "Removing image:"
	-docker rmi $(REPOSITORY):$(TAG)

health:
	@echo "Checking container health:"
	docker inspect --format='{{.State.Health.Status}}' hello

test:
	@echo "Testing application:"
	curl -f http://localhost:8080 || echo "Application not responding"

shell: exec

help:
	@echo "Available targets:"
	@echo "  build    - Build the Docker image"
	@echo "  run      - Run container in foreground"
	@echo "  bg       - Run container in background"
	@echo "  logs     - Show container logs"
	@echo "  exec     - Access container shell"
	@echo "  shell    - Alias for exec"
	@echo "  health   - Check container health status"
	@echo "  test     - Test if application is responding"
	@echo "  push     - Push image to registry"
	@echo "  stop     - Stop the container"
	@echo "  clean    - Stop container and remove image"
	@echo "  all      - Build and push image"
	@echo "  help     - Show this help message"

.PHONY: all build run bg logs exec shell health test push stop clean help
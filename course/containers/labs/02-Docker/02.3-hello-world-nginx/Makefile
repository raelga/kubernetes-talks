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
.PHONY: all build test-all test lint vet

all: test-all build

build:
	docker build --no-cache -t raelga/k8s-deployment-strategies:latest .

test-all: vet lint test

test:
	go test -v -parallel=4 ./...

lint:
	@go get golang.org/x/lint
	go list ./... | xargs -n1 golint

vet:
	go vet ./...

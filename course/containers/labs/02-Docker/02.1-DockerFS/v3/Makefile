build:
	docker build . -t hello-world:v3

run:
	docker run --rm hello-world:v3

stop:
	docker stop $(docker ps -a --filter ancestor=hello-world:v3 -q)
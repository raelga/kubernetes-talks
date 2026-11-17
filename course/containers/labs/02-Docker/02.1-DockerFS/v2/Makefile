build:
	docker build . -t hello-world:v2

run:
	docker run --rm hello-world:v2

stop:
	docker stop $(docker ps -a --filter ancestor=hello-world:v2 -q)
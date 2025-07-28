build:
	docker build . -t hello-world:v1

run:
	docker run hello-world:v1

stop:
	docker stop $(docker ps -a --filter ancestor=hello-world:v1 -q)
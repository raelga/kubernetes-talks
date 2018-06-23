build:
	docker build . -t hello-world:v1

run:
	docker run -p 9999:9999 -d hello-world:v1 

stop:
	docker stop $(docker ps -a --filter ancestor=hello-world:v1 -q)
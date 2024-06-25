build:
	docker build . -t hello-world-go:v1

run:
	docker run -p 9999:9999 -d hello-world-go:v1

stop:
	docker stop $(docker ps -a --filter ancestor=hello-world-go:v1 -q)
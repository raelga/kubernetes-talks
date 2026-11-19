IMAGE      ?= isolation-demo:v1
HOST_PORT  ?= 8888

build:
	docker build . -t $(IMAGE)

# Copies the static binary out of the image and runs it on the host, no container.
host: app-host
	./app-host

app-host: build
	docker create --name isolation-extract $(IMAGE) >/dev/null
	docker cp isolation-extract:/app/app ./app-host
	docker rm isolation-extract >/dev/null
	chmod +x app-host

run:
	docker run -d -p $(HOST_PORT):9999 $(IMAGE)

stop:
	docker stop $$(docker ps -a --filter ancestor=$(IMAGE) -q)

clean:
	rm -f app-host

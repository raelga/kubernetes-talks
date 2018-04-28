default: build run

present:
	present 
docker-build:
	docker build -t gotalks-slides .

docker-shell:
	docker run -it --rm -v "$(CURDIR)/slides:/go/slides" -P gotalks-slides sh

docker-present:
	docker run -it --rm -v "$(CURDIR)/slides:/go/slides" -P gotalks-slides
default: docker-build docker-present

present:
	present

docker-build:
	docker build -t kubernetes-slides .

docker-live:
	docker run -it --rm -v "$(CURDIR)/:/slides" -p 3999:3999 kubernetes-slides

docker-shell:
	docker run -it --rm -p 3999:3999 kubernetes-slides sh

docker-present:
	docker run -it --rm -p 3999:3999 kubernetes-slides

docker-push:
	docker tag kubernetes-slides:latest raelga/kslides:latest
	docker push raelga/kslides:latest

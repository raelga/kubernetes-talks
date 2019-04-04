GCP_PROJECT := barcelona-cloud
GCP_DEPLOYMENT := traefik-docker-host
GCP_DEPLOYMENT_CFG := host/traefik-docker-host.yaml
GCP_ZONE = europe-west1-b

# For interactive prompt

SHELL = /bin/bash

# Help

help:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null \
		| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' \
		| egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | sort -r


host-create:
	gcloud deployment-manager deployments \
		create $(GCP_DEPLOYMENT) \
		--config $(GCP_DEPLOYMENT_CFG) \
		--project $(GCP_PROJECT)

host-update:
	gcloud deployment-manager deployments \
		update $(GCP_DEPLOYMENT) \
		--config $(GCP_DEPLOYMENT_CFG) \
		--project $(GCP_PROJECT) \
		--preview
	@echo -n "Ready to update, are you sure? Ctrl+C to cancel " \
		&& read ans
	gcloud deployment-manager deployments \
		update $(GCP_DEPLOYMENT) \
		--project $(GCP_PROJECT)

host-delete:
	gcloud deployment-manager deployments \
		delete $(GCP_DEPLOYMENT) \
		--project $(GCP_PROJECT)

host-ssh:
	gcloud compute ssh traefik-docker-host \
		--zone $(GCP_ZONE) \
		--project $(GCP_PROJECT)

docker-run-traefik-v1.7:
	docker run \
		--rm -p 80:80 -p 444:443 -p 8080:8080 \
		-v $(CURDIR)/traefik-v1.7/context/etc/traefik:/etc/traefik \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--name traefik-v1.7 \
		traefik:v1.7-alpine

docker-run-traefik-v1.7-as-daemon:
	docker run -d --restart always \
		-p 80:80 -p 444:443 -p 8080:8080 \
		-v $(CURDIR)/traefik-v1.7/context/etc/traefik:/etc/traefik \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--name traefik-v1.7 \
		traefik:v1.7

docker-run-traefik-v2.0:
	docker run \
		--rm -p 20080:80 -p 20433:443 -p 28080:8080 \
		-v $(CURDIR)/traefik-v2.0/context/etc/traefik:/etc/traefik \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--name traefik-v2.0 \
		traefik:v2.0-alpine --providers.docker

docker-run-traefik-v2.0-as-daemon:
	docker run -d --restart always \
		-p 20080:80 -p 20433:443 -p 28080:8080 \
		-v $(CURDIR)/traefik-v2.0/context/etc/traefik:/etc/traefik \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--name traefik-v2.0 \
		traefik:v2.0

docker-run-nginx:
	docker run --rm nginx

docker-run-nginx-with-name:
	docker run --rm -d --name nginx nginx

docker-run-nginx-with-custom-host:
	docker run --rm -d \
		--label 'traefik.frontend.rule=Host:nginx.rael.io' \
		--label 'traefik.http.routers.nginx-custom.rule=Host(`nginx.rael.io`)' \
		nginx

docker-run-nginx-with-custom-host-and-secret:
	docker run --rm -d \
		--label 'traefik.http.routers.nginx-custom-with-secret.rule=Host(`nginx.rael.io`) && Path(`/secret`)' \
		--label "traefik.http.routers.nginx-custom-with-secret.middlewares=file.secured" \
		nginx

docker-run-whoami-secured:
	docker run --rm -d \
		--label 'traefik.http.routers.whoami.rule=Host(`whoami.rael.io`)' \
		--label "traefik.http.routers.whoami.middlewares=file.secured" \
		containous/whoami

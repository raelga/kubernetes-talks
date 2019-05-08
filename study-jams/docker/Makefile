
MAKEFLAGS += --no-print-directory

TAG ?= $(shell git rev-parse --verify --short HEAD)
#IMAGES = $(subst /,\:,$(subst /Dockerfile,,$(DOCKERFILES)))

DOCKERFILES = $(shell find . -type f -name Dockerfile | sed -n "s@./\(.*\)/Dockerfile@\1@p")
IMAGES = $(subst /Dockerfile,,$(DOCKERFILES))

# Help

help:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null \
		| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' \
		| egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | sort

$(addprefix docker-build-,$(IMAGES)): docker-build-%:
	docker build -t $*:$(TAG) $*

$(addprefix docker-push-,$(IMAGES)): docker-push-%:
	docker push $*:$(TAG)

$(addprefix docker-run-,$(IMAGES)): docker-run-%:
	docker run -ti $*:$(TAG)

$(addprefix docker-tag-latest-,$(IMAGES)): docker-tag-latest-%:
	docker tag $*:$(TAG) $*:latest

$(addprefix docker-push-latest-,$(IMAGES)): docker-push-latest-%:
	docker push $*:latest

$(addprefix docker-run-latest-,$(IMAGES)): docker-run-latest-%:
	docker run -ti $*:latest

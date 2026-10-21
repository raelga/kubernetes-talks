# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Set IMAGE explicitly to a registry/repository:tag you control. No target deploys.
PLATFORMS ?= linux/amd64,linux/arm64
.DEFAULT_GOAL := help

.PHONY: help require-image build publish
help:
	@printf '%s\n' 'make build IMAGE=registry/repository:tag     Build a local image' 'make publish IMAGE=registry/repository:tag   Buildx + push amd64/arm64 (explicit opt-in)'

require-image:
	@test -n "$(IMAGE)" || { printf '%s\n' 'IMAGE is required; choose a registry/repository:tag you control.' >&2; exit 1; }

build: require-image
	docker build --tag "$(IMAGE)" .

publish: require-image
	docker buildx build --platform "$(PLATFORMS)" --tag "$(IMAGE)" --push .

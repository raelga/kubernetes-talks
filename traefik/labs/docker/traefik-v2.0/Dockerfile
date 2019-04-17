FROM traefik:alpine

COPY traefik.toml /etc/traefik.toml
COPY kubernetes.toml /etc/kubernetes.toml

RUN apk update && apk add bash vim

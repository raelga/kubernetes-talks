FROM golang:alpine

RUN apk --update add git openssh && \
    rm -rf /var/lib/apt/lists/* && \
    rm /var/cache/apk/*

RUN go get golang.org/x/tools/cmd/present

COPY 101/kubernetes-101.slide /slides/101/
COPY 101/images /slides/101/images
COPY 101/yml /slides/101/yml

COPY clouds/kubernetes-clouds.slide /slides/clouds/
COPY clouds/images /slides/clouds/images

COPY traefik/traefik.slide /slides/traefik/
COPY traefik/images /slides/traefik/images

COPY providers/do/digital-ocean.slide /slides/providers/do/
COPY providers/do/images /slides/providers/do/images

EXPOSE 3999
WORKDIR /slides

CMD ["present", "-http=0.0.0.0:3999", "-play=false" ]

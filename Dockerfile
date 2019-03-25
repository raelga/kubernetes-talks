FROM golang:alpine

RUN apk --update add git openssh && \
    rm -rf /var/lib/apt/lists/* && \
    rm /var/cache/apk/*

RUN go get golang.org/x/tools/cmd/present

COPY 101 /slides/101
COPY clouds /slides/clouds
COPY traefik /slides/traefik

EXPOSE 3999
WORKDIR /slides

CMD ["present", "-http=0.0.0.0:3999", "-play=false" ]
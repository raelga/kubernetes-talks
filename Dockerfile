FROM golang:alpine

RUN apk --update add git openssh && \
    rm -rf /var/lib/apt/lists/* && \
    rm /var/cache/apk/*

RUN go get golang.org/x/tools/cmd/present

EXPOSE 3999

CMD [ "present", "slides/" ]
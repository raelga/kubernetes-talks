FROM alpine:latest
RUN apk update \
      && apk add curl bind-tools jq coreutils bash \
      && rm -rf /var/cache/apk/*

CMD [ "/bin/bash" ]

FROM golang:1.8.3 as builder
WORKDIR /go/src/app
COPY app.go  .
RUN CGO_ENABLED=0 GOOS=linux go build -a -o app .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /go/src/app/app .
CMD ["./app"]
EXPOSE 9999
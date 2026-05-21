FROM golang:1.22 AS builder
WORKDIR /go/src/app
COPY go.mod .
COPY app.go .
RUN CGO_ENABLED=0 GOOS=linux go build -a -o app .

FROM alpine:3.20
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /go/src/app/app .
USER appuser
CMD ["./app"]
EXPOSE 8080

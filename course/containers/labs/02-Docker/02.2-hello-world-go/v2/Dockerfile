FROM golang:1.8.3 as builder
WORKDIR /go/src/app
COPY app.go  .
RUN CGO_ENABLED=0 GOOS=linux go build -a -o app .

FROM alpine:3.19
RUN apk --no-cache add ca-certificates && \
    addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /go/src/app/app .
RUN chown appuser:appgroup /app/app
USER appuser
CMD ["./app"]
EXPOSE 9999
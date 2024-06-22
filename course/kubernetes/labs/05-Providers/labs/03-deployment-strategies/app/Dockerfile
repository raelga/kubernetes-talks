FROM golang:1.17 AS build

WORKDIR /src

# Download Go modules
COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app .

FROM scratch
COPY --from=build /src/app /app
EXPOSE 8080 8086 9101
CMD ["/app"]

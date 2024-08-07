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

FROM golang:1.13.0
ENV GO111MODULE=on
WORKDIR /app
RUN go mod init guestbook
RUN go get github.com/codegangsta/negroni github.com/xyproto/simpleredis/v2 github.com/gorilla/mux@v1.8.0
ADD ./main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

FROM scratch
WORKDIR /app
COPY --from=0 /app/main .
COPY ./public/index.html public/index.html
COPY ./public/script.js public/script.js
COPY ./public/style.css public/style.css
COPY ./public/upc.png public/upc.png
CMD ["/app/main"]
EXPOSE 3000

package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func HelloWorld(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	fmt.Fprintf(w, "Hello World from %s\n", hostname)
}

func HealthCheck(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "OK\n")
}

func main() {
	http.HandleFunc("/", HelloWorld)
	http.HandleFunc("/health", HealthCheck)

	log.Println("Listening at :8080...")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatal("Server ended, reason: ", err)
	}
}

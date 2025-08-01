package main

import (
	"fmt"
	"log"
	"net/http"
)

// HelloWorld - Simple Hello World response
func HelloWorld(w http.ResponseWriter, r *http.Request) {
	log.Print(r)
	fmt.Fprintf(w, "Hello World")
}

func HealthCheck(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "OK")
}

func main() {
	http.HandleFunc("/", HelloWorld)
	http.HandleFunc("/health", HealthCheck)

	log.Println("Listening at :9999...")
	err := http.ListenAndServe(":9999", nil)

	if err != nil {
		log.Fatal("Server ended, reason: ", err)
	}
}

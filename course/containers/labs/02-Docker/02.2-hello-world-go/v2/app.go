package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

// HelloWorld - Simple Hello World response
func HelloWorld(w http.ResponseWriter, r *http.Request) {
	log.Print(r)
	hostname, _ := os.Hostname()
	fmt.Fprintf(w, "Hello World from %s", hostname)
}

func main() {
	http.HandleFunc("/", HelloWorld)

	log.Println("Listeing at :9999...")
	err := http.ListenAndServe(":9999", nil)

	if err != nil {
		log.Fatal("Server ended, reason: ", err)
	}
}

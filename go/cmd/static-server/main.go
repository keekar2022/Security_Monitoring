package main

import (
	"flag"
	"log"
	"net/http"
	"os"
)

func main() {
	port := flag.String("port", "8080", "Port to listen on")
	dir := flag.String("dir", ".", "Directory to serve")
	flag.Parse()
	if *dir == "" {
		*dir = "."
	}
	if _, err := os.Stat(*dir); err != nil {
		log.Fatalf("directory %q not found: %v", *dir, err)
	}
	addr := ":" + *port
	log.Printf("static server listening on %s serving %s", addr, *dir)
	log.Fatal(http.ListenAndServe(addr, http.FileServer(http.Dir(*dir))))
}

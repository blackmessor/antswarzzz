package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/antswarzzz/server/internal/api"
	"github.com/antswarzzz/server/internal/database"
	"github.com/antswarzzz/server/internal/tick"
)

func main() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// Database connection
	dbHost := env("DB_HOST", "mariadb")
	dbPort := env("DB_PORT", "3306")
	dbUser := env("DB_USER", "antswarzzz_app")
	dbPass := env("DB_PASSWORD", "antswarzzz_app_dev")
	dbName := env("DB_NAME", "antswarzzz")

	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&charset=utf8mb4&collation=utf8mb4_unicode_ci",
		dbUser, dbPass, dbHost, dbPort, dbName)

	log.Printf("Connecting to MariaDB at %s:%s...", dbHost, dbPort)
	db, err := database.New(dsn)
	if err != nil {
		log.Fatalf("Database connection failed: %v", err)
	}
	defer db.Close()
	log.Println("Database ready")

	// Tick engine
	engine := tick.NewEngine(db)
	engine.Start()
	defer engine.Stop()

	// HTTP router
	mux := http.NewServeMux()
	handler := api.NewHandler(db, engine)
	handler.Register(mux)

	// Health check
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"service":"antswarzzz-server"}`)
	})

	port := env("PORT", "8080")
	srv := &http.Server{
		Addr:    ":" + port,
		Handler: mux,
	}

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		log.Println("Shutting down...")
		srv.Close()
	}()

	log.Printf("Antswarzzz server listening on :%s", port)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("Server error: %v", err)
	}
	log.Println("Server stopped")
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
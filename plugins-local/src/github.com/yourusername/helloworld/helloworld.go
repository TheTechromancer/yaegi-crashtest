package helloworld

import (
	"context"
	"net/http"
)

type Config struct{}

func CreateConfig() *Config {
	return &Config{}
}

type HelloWorld struct {
	next http.Handler
	name string
}

func New(ctx context.Context, next http.Handler, config *Config, name string) (http.Handler, error) {
	return &HelloWorld{next: next, name: name}, nil
}

func (h *HelloWorld) ServeHTTP(rw http.ResponseWriter, req *http.Request) {
	rw.Header().Set("X-Hello-World", "Hello from Yaegi!")
	h.next.ServeHTTP(rw, req)
}

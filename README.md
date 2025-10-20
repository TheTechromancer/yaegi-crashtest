### Step-by-Step Guide: Creating, Debugging, and Testing a Simple Hello-World Traefik Yaegi Extension

This guide walks you through building a basic "hello-world" middleware plugin for Traefik using Yaegi. The plugin will add a custom HTTP header (`X-Hello-World: Hello from Yaegi!`) to responses as a simple demonstration. We'll focus on local development without requiring a remote Git repository, using Traefik's local mode. This is based on Traefik v3+ (as of 2025), where Yaegi plugins are supported for middleware and providers, but we'll stick to middleware here.

Yaegi interprets your Go code at runtime, allowing dynamic extensions without compiling binaries. Note that while Yaegi is compatible with full Go syntax, it's slower than compiled Go for intensive tasks.

### Step 1: Set Up Your Environment
1. **Install Go**: If not already, download from https://go.dev/dl/ (v1.21+).
2. **Download Traefik Binary**: Grab the latest from https://github.com/traefik/traefik/releases (e.g., `traefik_v3.1.4_linux_amd64.tar.gz`). Extract it:
   ```
   wget https://github.com/traefik/traefik/releases/download/v3.1.4/traefik_v3.1.4_linux_amd64.tar.gz
   tar -zxvf traefik_v3.1.4_linux_amd64.tar.gz
   chmod +x traefik
   ```
3. **Install Yaegi CLI** (for debugging): `go install github.com/traefik/yaegi/cmd/yaegi@latest`.
4. **Start a Simple Backend**: In a separate terminal, run a dummy server (e.g., using Python): `python3 -m http.server 8080`. This will serve as your "upstream" service at http://localhost:8080.

### Step 2: Create the Plugin Files
Create everything in a new directory (e.g., `traefik-hello`):
```
mkdir traefik-hello && cd traefik-hello
mkdir -p plugins-local/src/github.com/yourusername/helloworld
```

1. In `plugins-local/src/github.com/yourusername/helloworld/go.mod`:
   ```
   module github.com/yourusername/helloworld

   go 1.21
   ```

2. In `plugins-local/src/github.com/yourusername/helloworld/.traefik.yml` (manifest for validation):
   ```yaml
   displayName: Hello World Plugin
   type: middleware
   import: github.com/yourusername/helloworld
   summary: Adds a hello-world header to responses.
   testData: {}
   ```

3. In `plugins-local/src/github.com/yourusername/helloworld/helloworld.go` (the plugin code):
   ```go
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
   ```

### Step 3: Configure Traefik
1. In the root (`traefik-hello/traefik.yml`—static config):
   ```yaml
   entryPoints:
     web:
       address: :80

   providers:
     file:
       filename: dynamic.yml

   experimental:
     localPlugins:
       helloworld:
         moduleName: github.com/yourusername/helloworld

   log:
     level: DEBUG
   ```

2. In the root (`traefik-hello/dynamic.yml`—dynamic config to apply the plugin):
   ```yaml
   http:
     routers:
       my-router:
         rule: Host(`localhost`)
         service: my-service
         middlewares:
           - hello-middleware

     services:
       my-service:
         loadBalancer:
           servers:
             - url: http://backend:8080

     middlewares:
       hello-middleware:
         plugin:
           helloworld: {}
   ```

### Step 4: Run and Test the Plugin
1. Start Traefik (from the `traefik-hello` dir, assuming the binary is there):
   ```
   ./traefik --configFile=traefik.yml
   ```
   - It loads the plugin from `./plugins-local/` automatically.
   - Logs should show something like "Loading local plugin helloworld" and no errors.

2. Test it: In another terminal, `curl -i http://localhost`.
   - Look for `X-Hello-World: Hello from Yaegi!` in the headers.
   - If the backend is running, you'll also see its response body (e.g., directory listing from the Python server).

3. Verify the middleware is working: The response should include the `X-Hello-World: Hello from Yaegi!` header.

### Step 5: Debug the Plugin
- **Edit and Reload**: Change the header value in `helloworld.go` (e.g., to "Debug Test!"), save, then restart Traefik (Ctrl+C and rerun the command). Retest with curl.
- **Add Logs**: In `helloworld.go`, add `import "log"` and `log.Println("Debug: Handling request")` in `ServeHTTP`. Restart Traefik—logs will appear in its output.
- **Simulate with Yaegi CLI**:
  ```
  yaegi plugins-local/src/github.com/yourusername/helloworld/helloworld.go
  ```
  - For interactive testing: Run `yaegi`, then paste code snippets like:
    ```
    import "net/http/httptest"
    config := CreateConfig()
    handler, _ := New(context.Background(), http.HandlerFunc(func(w http.ResponseWriter, r *http.Request){}), config, "test")
    req := httptest.NewRequest("GET", "/", nil)
    rw := httptest.NewRecorder()
    handler.ServeHTTP(rw, req)
    rw.Header().Get("X-Hello-World")
    ```
    - This outputs "Hello from Yaegi!" (or your modified value).

### Step 6: Write and Run a Unit Test
1. In `plugins-local/src/github.com/yourusername/helloworld/helloworld_test.go`:
   ```go
   package helloworld

   import (
       "context"
       "net/http"
       "net/http/httptest"
       "testing"
   )

   func TestHelloWorld_ServeHTTP(t *testing.T) {
       config := CreateConfig()
       next := http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {})
       handler, err := New(context.Background(), next, config, "helloworld")
       if err != nil {
           t.Fatal(err)
       }
       recorder := httptest.NewRecorder()
       req := httptest.NewRequest(http.MethodGet, "http://localhost", nil)
       handler.ServeHTTP(recorder, req)
       if got := recorder.Header().Get("X-Hello-World"); got != "Hello from Yaegi!" {
           t.Errorf("Expected header 'Hello from Yaegi!', got %q", got)
       }
   }
   ```

2. Run the test (from the plugin dir):
   ```
   cd plugins-local/src/github.com/yourusername/helloworld
   go test ./...
   ```
   - It should pass with "ok".

### Step 7: Integration Testing with Docker Compose
For automated testing, use Docker Compose:

1. Create `compose.yml`:
   ```yaml
   services:
     traefik:
       image: traefik:v3.1
       ports:
         - "80:80"
       volumes:
         - ./traefik.yml:/etc/traefik/traefik.yml:ro
         - ./dynamic.yml:/etc/traefik/dynamic.yml:ro
         - ./plugins-local:/plugins-local:ro
       command: --configFile=/etc/traefik/traefik.yml
       depends_on:
         - backend
       networks:
         - test-network

     backend:
       image: python:3.11-alpine
       volumes:
         - ./test-content:/app
       working_dir: /app
       command: python3 -m http.server 8080
       networks:
         - test-network

   networks:
     test-network:
       driver: bridge
   ```

2. Create a simple test script `test.sh`:
   ```bash
   #!/bin/bash
   set -e
   
   cleanup() {
       docker-compose down -v
   }
   trap cleanup EXIT
   
   echo "Starting services..."
   docker-compose up -d
   
   echo "Waiting for services..."
   sleep 10
   
   echo "Testing middleware..."
   response=$(curl -s -i http://localhost)
   
   if echo "$response" | grep -q "X-Hello-World: Hello from Yaegi!"; then
       echo "✓ Header added"
   else
       echo "✗ Header missing"
       exit 1
   fi
   
   echo "Test passed"
   ```

3. Run the test: `./test.sh`
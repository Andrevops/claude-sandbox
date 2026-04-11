.PHONY: install uninstall build rebuild status

OS := $(shell uname -s)

install:
	@bash install.sh

uninstall:
	@bash install.sh --uninstall

build:
ifeq ($(OS),Darwin)
	@echo "Building claude-sandbox image..."
	docker build -t claude-sandbox:latest -f Dockerfile.macos .
	@echo "Done. Packages installed from packages.txt"
else
	@echo "Skipped: image build is only needed on macOS."
	@echo "On Linux/WSL2, host binaries are mounted directly into the container."
endif

rebuild:
ifeq ($(OS),Darwin)
	@echo "Rebuilding claude-sandbox image from scratch..."
	docker build --no-cache -t claude-sandbox:latest -f Dockerfile.macos .
	@echo "Done. Packages installed from packages.txt"
else
	@echo "Skipped: image build is only needed on macOS."
endif

status:
	@echo "=== Platform ==="
	@echo "OS: $(OS)"
ifeq ($(OS),Darwin)
	@echo ""
	@echo "=== Image ==="
	@docker image inspect claude-sandbox:latest --format 'Built: {{.Created}}  Size: {{.Size}}' 2>/dev/null || echo "Not built yet. Run: make build"
endif
	@echo ""
	@echo "=== Running containers ==="
	@docker ps --filter "label=claude-sandbox" --format "table {{.Names}}\t{{.Status}}\t{{.Label \"claude-sandbox.dir\"}}" 2>/dev/null || echo "None"

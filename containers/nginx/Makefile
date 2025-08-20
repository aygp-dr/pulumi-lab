# Mock nginx container Makefile
.PHONY: build run stop clean size help

IMAGE_NAME := pulumi-lab-mock-nginx
CONTAINER_NAME := mock-nginx
PORT := 8080

# Default target
help:
	@echo "Mock nginx Container Management"
	@echo "================================"
	@echo "Available targets:"
	@echo "  make build   - Build the Docker image"
	@echo "  make run     - Run the container (builds if needed)"
	@echo "  make stop    - Stop and remove the container"
	@echo "  make clean   - Remove container and image"
	@echo "  make size    - Show image size and layer info"
	@echo "  make logs    - Show container logs"
	@echo "  make shell   - Open shell in running container"

# Build the Docker image with size optimization
build:
	@echo "Building mock nginx image..."
	docker build -t $(IMAGE_NAME):latest .
	@echo "Build complete!"
	@$(MAKE) size

# Run the container
run: build
	@echo "Starting mock nginx container..."
	@docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	docker run -d \
		--name $(CONTAINER_NAME) \
		-p $(PORT):80 \
		--restart unless-stopped \
		$(IMAGE_NAME):latest
	@echo "Container started!"
	@echo "Access the mock service at: http://localhost:$(PORT)"

# Stop and remove the container
stop:
	@echo "Stopping container..."
	@docker stop $(CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(CONTAINER_NAME) 2>/dev/null || true
	@echo "Container stopped and removed."

# Clean up everything
clean: stop
	@echo "Removing image..."
	@docker rmi $(IMAGE_NAME):latest 2>/dev/null || true
	@echo "Cleanup complete."

# Check image size and details
size:
	@echo "=== Image Size Analysis ==="
	@docker images $(IMAGE_NAME):latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
	@echo ""
	@echo "=== Layer Details ==="
	@docker history $(IMAGE_NAME):latest --format "table {{.CreatedBy}}\t{{.Size}}" | head -10
	@echo ""
	@echo "=== Size Comparison ==="
	@docker images nginx:alpine --format "Base nginx:alpine: {{.Size}}"
	@docker images $(IMAGE_NAME):latest --format "Mock nginx image: {{.Size}}"

# View container logs
logs:
	@docker logs -f $(CONTAINER_NAME)

# Open shell in running container
shell:
	@docker exec -it $(CONTAINER_NAME) /bin/sh

# Test the service
test:
	@echo "Testing mock service..."
	@curl -s http://localhost:$(PORT) | grep -q "Pulumi Lab" && echo "✓ Service is responding" || echo "✗ Service not responding"
	@echo "Service URL: http://localhost:$(PORT)"
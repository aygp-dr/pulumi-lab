.PHONY: help install test clean localstack-start localstack-stop setup-hy

help:
	@echo "Available targets:"
	@echo "  install         - Install dependencies with uv"
	@echo "  setup-hy        - Set up Hy language environment"
	@echo "  localstack-start - Start LocalStack for AWS testing"
	@echo "  localstack-stop  - Stop LocalStack"
	@echo "  test            - Run tests"
	@echo "  clean           - Clean build artifacts"

install:
	uv pip install -e .
	cd experiments/001-github-provider && npm install

setup-hy:
	uv pip install hy
	@echo "Hy language support installed"

localstack-start:
	@echo "Starting LocalStack for AWS service emulation..."
	@if command -v docker >/dev/null 2>&1; then \
		docker run -d \
			--name localstack \
			-p 4566:4566 \
			-p 4571:4571 \
			-e SERVICES=s3,ec2,iam,lambda \
			-e DEBUG=1 \
			-e DATA_DIR=/tmp/localstack/data \
			-v /tmp/localstack:/tmp/localstack \
			-v /var/run/docker.sock:/var/run/docker.sock \
			localstack/localstack:latest; \
		echo "LocalStack started on port 4566"; \
		echo "Configure Pulumi to use LocalStack:"; \
		echo "  export AWS_ENDPOINT=http://localhost:4566"; \
		echo "  export AWS_ACCESS_KEY_ID=test"; \
		echo "  export AWS_SECRET_ACCESS_KEY=test"; \
	else \
		echo "Docker not found. LocalStack requires Docker."; \
		echo "Install Docker or use Podman with appropriate configuration."; \
		exit 1; \
	fi

localstack-stop:
	@echo "Stopping LocalStack..."
	@docker stop localstack 2>/dev/null || true
	@docker rm localstack 2>/dev/null || true
	@echo "LocalStack stopped"

test:
	@echo "Running Pulumi preview in dry-run mode..."
	@for dir in experiments/*/; do \
		if [ -f "$$dir/Pulumi.yaml" ]; then \
			echo "Testing $$dir..."; \
			cd "$$dir" && pulumi preview --non-interactive || true; \
		fi \
	done

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type d -name ".pulumi" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "Pulumi.*.yaml" -delete

# Documentation publishing
README.md: README.org
	emacs -Q --batch -l org $< -f org-md-export-to-markdown

%/README.md: %/README.org
	cd $* && emacs -Q --batch -l org README.org -f org-md-export-to-markdown

.venv: pyproject.toml
	uv sync
	touch .venv

setup: .venv
.PHONY: help install test clean localstack-start localstack-stop setup-hy ci

help:
	@echo "Available targets:"
	@echo "  install         - Install dependencies with uv"
	@echo "  setup-hy        - Set up Hy language environment"
	@echo "  test            - Run tests"
	@echo "  ci              - Test CI workflow locally"
	@echo "  clean           - Clean build artifacts"
	@echo ""
	@echo "AWS Emulation (FreeBSD):"
	@echo "  minio-start     - Start Minio S3 storage (LocalStack alternative)"
	@echo "  minio-stop      - Stop Minio"
	@echo "  minio-test      - Test Minio S3 connection"
	@echo "  minio-env       - Show Minio environment variables"
	@echo ""
	@echo "AWS Emulation (requires Docker daemon - not available on FreeBSD):"
	@echo "  localstack-start - Start LocalStack (needs Docker)"
	@echo "  localstack-stop  - Stop LocalStack"
	@echo ""
	@echo "FreeBSD-specific:"
	@echo "  freebsd-setup   - Install Pulumi on FreeBSD"
	@echo "  freebsd-test    - Test Pulumi installation"

install:
	uv pip install -e .
	cd experiments/001-github-provider && npm install

setup-hy:
	uv pip install hy
	@echo "Hy language support installed"

localstack-start:
	@echo "Starting LocalStack for AWS service emulation..."
	@if command -v docker >/dev/null 2>&1; then \
		if ! docker ps >/dev/null 2>&1; then \
			echo "Docker daemon not running. Start with: sudo service docker start"; \
			exit 1; \
		fi; \
		docker run -d \
			--name localstack \
			-p 4566:4566 \
			-p 4571:4571 \
			-e SERVICES=s3,ec2,iam,lambda,dynamodb,sqs,sns \
			-e DEBUG=1 \
			-e DATA_DIR=/tmp/localstack/data \
			-v /tmp/localstack:/tmp/localstack \
			localstack/localstack:latest; \
		echo "LocalStack started on port 4566"; \
		echo "Waiting for LocalStack to be ready..."; \
		sleep 5; \
		echo "Configure Pulumi to use LocalStack:"; \
		echo "  export AWS_ENDPOINT=http://localhost:4566"; \
		echo "  export AWS_ACCESS_KEY_ID=test"; \
		echo "  export AWS_SECRET_ACCESS_KEY=test"; \
		echo "  export AWS_REGION=us-east-1"; \
		echo ""; \
		echo "Or use: gmake localstack-env"; \
	else \
		echo "Docker not found. LocalStack requires Docker."; \
		echo "Install with: sudo pkg install docker"; \
		echo "Enable with: sudo sysrc docker_enable=YES"; \
		echo "Start with: sudo service docker start"; \
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

# Directory creation pattern rule
%/:
	mkdir -p $@

# Documentation resources (non-phony targets)
resources/hy-syntax.html: | resources/
	curl -o $@ https://hylang.org/hy/doc/v1.0.0/syntax

resources/hy-tutorial.html: | resources/
	curl -o $@ https://hylang.org/hy/doc/v1.0.0/tutorial

resources/pulumi-aws-docs.html: | resources/
	curl -o $@ https://www.pulumi.com/registry/packages/aws/

resources/pulumi-concepts.html: | resources/
	curl -o $@ https://www.pulumi.com/docs/concepts/

# Aggregate target for all documentation
fetch-docs: resources/hy-syntax.html resources/hy-tutorial.html resources/pulumi-aws-docs.html resources/pulumi-concepts.html
	@echo "Documentation fetched to resources/"

# Clean documentation
clean-docs:
	rm -rf resources/

# Test CI workflow locally
ci:
	@echo "Testing CI workflow locally..."
	@echo ""
	@echo "1. Checking Python version:"
	@python --version || python3 --version
	@echo ""
	@echo "2. Checking pip:"
	@pip --version || pip3 --version
	@echo ""
	@echo "3. Checking Hy installation:"
	@hy --version || echo "❌ Hy not installed - run: pip install hy==1.0.0"
	@echo ""
	@echo "4. Testing Hy syntax:"
	@hy -c "(print \"✅ Hy is working!\")" || echo "❌ Hy test failed"
	@echo ""
	@echo "5. Checking Hy files exist:"
	@find experiments -name "*.hy" -type f | head -5 | while read f; do echo "  ✓ $$f"; done
	@echo ""
	@echo "6. Testing GitHub imports:"
	@cd experiments/002-github-teams-hy && \
		hy -c "(import pulumi) (import pulumi_github :as github) (print \"✅ GitHub imports work\")" || \
		echo "❌ GitHub imports failed - run: pip install pulumi pulumi-github"
	@echo ""
	@echo "7. Checking GitHub token:"
	@if [ -n "$$GITHUB_TOKEN" ]; then \
		echo "✅ GITHUB_TOKEN is set"; \
	else \
		echo "⚠️ GITHUB_TOKEN not set - some experiments may fail"; \
	fi

# FreeBSD-specific targets
.PHONY: freebsd-setup freebsd-test localstack-env minio-start minio-stop minio-test

freebsd-setup:
	@echo "Setting up Pulumi on FreeBSD..."
	@if ! kldstat | grep -q linux; then \
		echo "Linux compatibility not loaded. Run: sudo kldload linux64"; \
		exit 1; \
	fi
	@if [ ! -f ~/.local/bin/pulumi ]; then \
		echo "Pulumi not installed. Downloading..."; \
		cd /tmp && \
		curl -LO https://get.pulumi.com/releases/sdk/pulumi-v3.145.0-linux-x64.tar.gz && \
		tar -xzf pulumi-v3.145.0-linux-x64.tar.gz && \
		mkdir -p ~/.local/bin && \
		cp pulumi/* ~/.local/bin/ && \
		echo "Pulumi installed to ~/.local/bin/"; \
	else \
		echo "Pulumi already installed at ~/.local/bin/pulumi"; \
	fi
	@echo "Add to PATH: export PATH=\$$HOME/.local/bin:\$$PATH"

freebsd-test:
	@./scripts/test-pulumi-freebsd.sh

localstack-env:
	@echo "# LocalStack environment variables"
	@echo "export AWS_ENDPOINT=http://localhost:4566"
	@echo "export AWS_ACCESS_KEY_ID=test"
	@echo "export AWS_SECRET_ACCESS_KEY=test"
	@echo "export AWS_REGION=us-east-1"
	@echo ""
	@echo "# Run: eval \$$(gmake localstack-env)"

docker-setup:
	@echo "Docker setup for FreeBSD:"
	@echo "1. Install: sudo pkg install docker"
	@echo "2. Enable: sudo sysrc docker_enable=YES"
	@echo "3. Start: sudo service docker start"
	@echo "4. Add user: sudo pw groupmod docker -m \$$USER"
	@echo "5. Logout and login again"
	@echo ""
	@echo "NOTE: Docker daemon doesn't run natively on FreeBSD!"
	@echo "Use Minio instead: gmake minio-start"
	@echo ""
	@docker version 2>/dev/null || echo "Docker client installed, but no daemon available"

# Minio targets for S3 emulation (LocalStack alternative on FreeBSD)
minio-start:
	@echo "Starting Minio S3-compatible storage..."
	@if command -v minio >/dev/null 2>&1; then \
		./scripts/start-minio.sh; \
	else \
		echo "Minio not installed. Install with: sudo pkg install minio"; \
		exit 1; \
	fi

minio-stop:
	@echo "Stopping Minio..."
	@pkill minio 2>/dev/null || echo "Minio not running"
	@echo "Minio stopped"

minio-test:
	@echo "Testing Minio S3 connection..."
	@if pgrep minio >/dev/null 2>&1; then \
		AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin \
		aws --endpoint-url=http://localhost:9000 s3 ls || echo "Connection failed"; \
	else \
		echo "Minio not running. Start with: gmake minio-start"; \
	fi

minio-env:
	@echo "# Minio S3 environment variables"
	@echo "export AWS_ENDPOINT=http://localhost:9000"
	@echo "export AWS_ACCESS_KEY_ID=minioadmin"
	@echo "export AWS_SECRET_ACCESS_KEY=minioadmin"
	@echo "export AWS_REGION=us-east-1"
	@echo ""
	@echo "# Run: eval \$$(gmake minio-env)"
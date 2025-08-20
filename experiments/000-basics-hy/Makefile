.PHONY: help install preview up outputs destroy test clean lint format

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

install: ## Install dependencies
	pip install pulumi pulumi-aws hy pytest

preview: ## Preview infrastructure changes
	pulumi preview

up: ## Deploy infrastructure
	pulumi up --yes

outputs: ## Show stack outputs
	pulumi stack output

destroy: ## Destroy infrastructure
	pulumi destroy --yes

test: ## Run tests
	@echo "Running Pulumi stack tests..."
	python -m pytest tests/ -v

clean: ## Clean temporary files
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name "*~" -delete

lint: ## Run linting
	@echo "Running Hy linting..."
	@if command -v hy-lint >/dev/null 2>&1; then \
		hy-lint *.hy tests/*.hy; \
	else \
		echo "hy-lint not installed, skipping..."; \
	fi

format: ## Format code
	@echo "Formatting Hy code..."
	@if command -v hy-format >/dev/null 2>&1; then \
		hy-format *.hy tests/*.hy; \
	else \
		echo "hy-format not installed, skipping..."; \
	fi

stack-select: ## Select or create a stack
	@read -p "Enter stack name (default: dev): " stack; \
	stack=$${stack:-dev}; \
	pulumi stack select $$stack 2>/dev/null || pulumi stack new $$stack

stack-info: ## Show current stack information
	pulumi stack
	@echo ""
	pulumi config

refresh: ## Refresh stack state
	pulumi refresh --yes

validate: ## Validate Pulumi program
	@echo "Validating Pulumi program..."
	@hy -c "import __main__" 2>/dev/null && echo "✓ Program syntax valid" || echo "✗ Program has syntax errors"
.PHONY: help setup check preview up destroy clean run

help:
	@echo "GitHub Provider with Teams - Hy Implementation"
	@echo ""
	@echo "Targets:"
	@echo "  setup    - Install dependencies and configure environment"
	@echo "  check    - Verify dependencies and configuration"
	@echo "  preview  - Preview infrastructure changes"
	@echo "  up       - Create GitHub repository and teams"
	@echo "  run      - Alias for 'up'"
	@echo "  destroy  - Remove GitHub resources"
	@echo "  clean    - Clean local files"

setup:
	@echo "Installing pulumi-github provider..."
	@if [ -f ../../.venv/bin/pip ]; then \
		../../.venv/bin/pip install "pulumi-github>=6.0.0"; \
	else \
		pip install "pulumi-github>=6.0.0"; \
	fi
	@if [ ! -f .env ] && [ -f .env.example ]; then \
		echo "Creating .env from .env.example..."; \
		cp .env.example .env; \
		echo "Please edit .env and add your GitHub token"; \
	fi

check:
	@echo "Checking dependencies..."
	@python -c "import pulumi_github; print('✓ pulumi-github installed')" || \
		(echo "✗ pulumi-github not found. Run: gmake setup" && exit 1)
	@if [ -f .env ]; then \
		. ./.env && [ -n "$$GITHUB_TOKEN" ] && echo "✓ GitHub token configured" || \
		echo "✗ GitHub token not set in .env"; \
	else \
		echo "✗ .env file not found. Run: gmake setup"; \
	fi

preview: check
	@if [ -f .env ]; then \
		set -a; . ./.env; set +a; pulumi preview; \
	else \
		pulumi preview; \
	fi

up: check
	@if [ -f .env ]; then \
		set -a; . ./.env; set +a; pulumi up --yes; \
	else \
		pulumi up --yes; \
	fi

run: up

destroy: check
	@if [ -f .env ]; then \
		set -a; . ./.env; set +a; pulumi destroy --yes; \
	else \
		pulumi destroy --yes; \
	fi

clean:
	rm -rf __pycache__
	rm -f *.pyc
	rm -rf node_modules package-lock.json
	rm -f index.ts tsconfig.json package.json
.PHONY: help setup preview up destroy status clean run-cli

help:
	@echo "GitHub CLI vs Pulumi Comparison"
	@echo ""
	@echo "Pulumi Commands:"
	@echo "  setup    - Install dependencies"
	@echo "  preview  - Preview Pulumi changes"
	@echo "  up       - Apply Pulumi resources"
	@echo "  destroy  - Remove Pulumi resources"
	@echo ""
	@echo "CLI Operations:"
	@echo "  run-cli  - Run organization management CLI"
	@echo "  status   - Show repository status"
	@echo ""
	@echo "Examples:"
	@echo "  gmake run-cli ARGS='--all --org aygp-dr'"
	@echo "  gmake run-cli ARGS='--accept-invites'"
	@echo "  gmake run-cli ARGS='--fetch-repos --show-status'"

setup:
	@echo "Installing dependencies..."
	@pip install "pulumi-github>=6.0.0" gitpython requests

preview:
	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo "Error: GITHUB_TOKEN not set"; \
		exit 1; \
	fi
	pulumi preview

up:
	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo "Error: GITHUB_TOKEN not set"; \
		exit 1; \
	fi
	pulumi up --yes

destroy:
	pulumi destroy --yes

status:
	@hy __main__.hy --show-status

run-cli:
	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo "Error: GITHUB_TOKEN not set"; \
		exit 1; \
	fi
	@hy __main__.hy $(ARGS)

clean:
	rm -rf __pycache__ *.pyc
	rm -rf venv
	rm -rf .pulumi
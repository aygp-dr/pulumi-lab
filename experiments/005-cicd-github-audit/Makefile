.PHONY: help setup test audit-user audit-org test-ci clean

help:
	@echo "GitHub Repository Audit - CI/CD"
	@echo ""
	@echo "Setup:"
	@echo "  setup       - Install dependencies"
	@echo "  test        - Test Pulumi availability"
	@echo ""
	@echo "Audit Commands:"
	@echo "  audit-user  - Audit user repositories (default: current user)"
	@echo "  audit-org   - Audit organization repositories"
	@echo ""
	@echo "CI Testing:"
	@echo "  test-ci     - Simulate CI environment locally"
	@echo ""
	@echo "Examples:"
	@echo "  gmake audit-user USER=aygp-dr"
	@echo "  gmake audit-org ORG=aygp-dr"

setup:
	@echo "Installing dependencies..."
	pip install -r requirements.txt

test:
	@echo "Testing Pulumi availability..."
	@python test_pulumi.py

audit-user:
	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo "Error: GITHUB_TOKEN not set"; \
		exit 1; \
	fi
	@USER=$${USER:-$$(git config user.name)}; \
	echo "Auditing user: $$USER"; \
	python audit_repos.py --user $$USER --format markdown

audit-org:
	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo "Error: GITHUB_TOKEN not set"; \
		exit 1; \
	fi
	@if [ -z "$$ORG" ]; then \
		echo "Error: ORG variable not set"; \
		echo "Usage: gmake audit-org ORG=your-org"; \
		exit 1; \
	fi
	python audit_repos.py --org $$ORG --format markdown

test-ci:
	@echo "=== Simulating CI Environment ==="
	@echo "1. Checking Pulumi..."
	@which pulumi > /dev/null && pulumi version || echo "Pulumi not found - would be installed in CI"
	@echo ""
	@echo "2. Checking Python dependencies..."
	@pip list | grep -E "pulumi|requests" || echo "Dependencies would be installed in CI"
	@echo ""
	@echo "3. Testing token availability..."
	@if [ -n "$$GITHUB_TOKEN" ]; then \
		echo "✓ GITHUB_TOKEN is set"; \
	else \
		echo "✗ GITHUB_TOKEN not set"; \
	fi
	@echo ""
	@echo "4. Running Pulumi test..."
	@python test_pulumi.py
	@echo ""
	@echo "5. Running sample audit..."
	@if [ -n "$$GITHUB_TOKEN" ]; then \
		python audit_repos.py --user $${USER:-aygp-dr} --format json | python -m json.tool | head -20; \
	fi

clean:
	rm -rf __pycache__ *.pyc
	rm -rf venv
	rm -f audit_report.*
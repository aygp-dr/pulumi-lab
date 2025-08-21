.PHONY: help preview up destroy outputs clean

help:
	@echo "GitHub Full Management with Hy"
	@echo ""
	@echo "Targets:"
	@echo "  preview  - Preview GitHub resources"
	@echo "  up       - Create GitHub resources"
	@echo "  outputs  - Show stack outputs"
	@echo "  destroy  - Remove GitHub resources"
	@echo "  clean    - Clean cache files"

preview:
	pulumi preview

up:
	pulumi up --yes

outputs:
	pulumi stack output

destroy:
	pulumi destroy --yes

clean:
	rm -rf __pycache__
	find . -name "*.pyc" -delete
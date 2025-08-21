.PHONY: help preview up destroy clean

help:
	@echo "GitHub Teams Management with Hy"
	@echo ""
	@echo "Targets:"
	@echo "  preview  - Preview infrastructure changes"
	@echo "  up       - Deploy GitHub teams"
	@echo "  destroy  - Remove GitHub teams"
	@echo "  clean    - Clean local files"

preview:
	pulumi preview

up:
	pulumi up --yes

destroy:
	pulumi destroy --yes

clean:
	rm -rf __pycache__
	rm -f *.pyc
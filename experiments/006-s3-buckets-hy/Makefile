# S3 Buckets with Hy - Experiment 006
.PHONY: help init config-localstack preview up destroy clean test-s3 list-buckets

# Default target
help:
	@echo "S3 Buckets Hy Experiment - Pulumi with LocalStack"
	@echo "=================================================="
	@echo "Available targets:"
	@echo "  make init             - Initialize Pulumi stack"
	@echo "  make config-localstack - Configure for LocalStack"
	@echo "  make preview          - Preview infrastructure changes"
	@echo "  make up               - Deploy infrastructure"
	@echo "  make destroy          - Destroy infrastructure"
	@echo "  make clean            - Remove stack completely"
	@echo "  make test-s3          - Test S3 operations with boto3"
	@echo "  make list-buckets     - List buckets in LocalStack"
	@echo ""
	@echo "Quick start:"
	@echo "  make init config-localstack up"

# Initialize Pulumi stack for LocalStack development
init:
	@echo "Initializing Pulumi stack for LocalStack..."
	pulumi stack init dev-localstack --secrets-provider=passphrase || pulumi stack select dev-localstack
	@echo "Stack initialized/selected: dev-localstack"

# Configure Pulumi to use LocalStack endpoints
config-localstack:
	@echo "Configuring LocalStack endpoints..."
	pulumi config set aws:endpoints '{"s3": "http://localhost:4566", "iam": "http://localhost:4566", "sts": "http://localhost:4566"}'
	pulumi config set aws:skipCredentialsValidation true
	pulumi config set aws:skipMetadataApiCheck true  
	pulumi config set aws:s3UsePathStyle true
	pulumi config set aws:region us-east-1
	@echo "LocalStack configuration complete!"

# Preview infrastructure changes
preview:
	@echo "Previewing infrastructure changes..."
	export AWS_ACCESS_KEY_ID=test && \
	export AWS_SECRET_ACCESS_KEY=test && \
	export AWS_REGION=us-east-1 && \
	pulumi preview

# Deploy infrastructure to LocalStack
up:
	@echo "Deploying S3 buckets to LocalStack..."
	export AWS_ACCESS_KEY_ID=test && \
	export AWS_SECRET_ACCESS_KEY=test && \
	export AWS_REGION=us-east-1 && \
	pulumi up --yes

# Destroy infrastructure
destroy:
	@echo "Destroying S3 buckets..."
	export AWS_ACCESS_KEY_ID=test && \
	export AWS_SECRET_ACCESS_KEY=test && \
	export AWS_REGION=us-east-1 && \
	pulumi destroy --yes

# Remove stack completely
clean: destroy
	@echo "Removing Pulumi stack..."
	pulumi stack rm dev-localstack --yes || true
	rm -rf Pulumi.dev-localstack.yaml
	@echo "Stack removed"

# Test S3 operations with boto3
test-s3:
	@echo "Testing S3 operations with boto3..."
	@python3 -c "import boto3; \
		s3 = boto3.client('s3', endpoint_url='http://localhost:4566', \
			aws_access_key_id='test', aws_secret_access_key='test', region_name='us-east-1'); \
		buckets = s3.list_buckets(); \
		print('Buckets:', [b['Name'] for b in buckets['Buckets']]); \
		media_bucket = next((b for b in buckets['Buckets'] if 'media' in b['Name']), None); \
		if media_bucket: \
			print(f\"Media bucket found: {media_bucket['Name']}\"); \
			s3.put_object(Bucket=media_bucket['Name'], Key='test.txt', Body=b'Hello from Hy!'); \
			print('Test object uploaded'); \
		else: \
			print('No media bucket found - run make up first')"

# List all buckets in LocalStack
list-buckets:
	@echo "Listing S3 buckets in LocalStack..."
	@aws --endpoint-url=http://localhost:4566 s3 ls || echo "No buckets found or LocalStack not running"

# Check LocalStack status
check-localstack:
	@echo "Checking LocalStack status..."
	@curl -s http://localhost:4566/_localstack/health | python3 -m json.tool || echo "LocalStack not running"

# Run the Hy program directly (for testing)
run-hy:
	@echo "Running Hy program directly..."
	@hy __main__.hy

# Install dependencies
install-deps:
	@echo "Installing Python/Hy dependencies..."
	@pip install hy pulumi pulumi-aws boto3

# Full setup and deploy
full-setup: init config-localstack up test-s3
	@echo "Full setup complete! S3 buckets deployed to LocalStack"

# Show current stack configuration
show-config:
	@echo "Current stack configuration:"
	@pulumi config
	@echo ""
	@echo "Stack outputs:"
	@pulumi stack output 2>/dev/null || echo "No outputs yet - run 'make up' first"
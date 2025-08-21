# LocalStack on FreeBSD Setup Guide

## Prerequisites

### 1. Docker Installation and Setup

```bash
# Install Docker and docker-compose
sudo pkg install docker docker-compose

# Current versions as of testing:
# - docker: 18.09.5_26
# - docker-compose: 1.24.0_4

# Enable Docker service
sudo sysrc docker_enable=YES

# Start Docker daemon
sudo service docker start

# Add your user to docker group
sudo pw groupmod docker -m $USER

# IMPORTANT: Logout and login again for group changes to take effect
```

### 2. AWS CLI Installation

```bash
# Install AWS CLI via pip (system package is v1, we want v2-compatible)
pip3 install --user awscli

# Verify installation
~/.local/bin/aws --version
# Output: aws-cli/1.42.14 Python/3.11.11 FreeBSD/14.3-RELEASE botocore/1.40.14

# Add to PATH if needed
export PATH=$HOME/.local/bin:$PATH
```

## Starting LocalStack

### Method 1: Using gmake (Recommended)

```bash
# After Docker daemon is running:
gmake localstack-start

# This will:
# - Check Docker is running
# - Start LocalStack container with all services
# - Wait for it to be ready
# - Display configuration instructions
```

### Method 2: Manual Docker Command

```bash
# Start LocalStack manually
docker run -d \
  --name localstack \
  -p 4566:4566 \
  -p 4571:4571 \
  -e SERVICES=s3,ec2,iam,lambda,dynamodb,sqs,sns \
  -e DEBUG=1 \
  -e DATA_DIR=/tmp/localstack/data \
  -v /tmp/localstack:/tmp/localstack \
  localstack/localstack:latest

# Check it's running
docker ps | grep localstack

# View logs
docker logs -f localstack
```

### Method 3: Using Helper Script

```bash
# Use the provided script
./scripts/start-localstack.sh

# This script will:
# - Check Docker is running
# - Remove old containers
# - Start LocalStack
# - Test the health endpoint
# - Display configuration
```

## Configuration

### Set Environment Variables

```bash
# Option 1: Use gmake helper
eval $(gmake localstack-env)

# Option 2: Set manually
export AWS_ENDPOINT=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION=us-east-1
```

### Configure Pulumi for LocalStack

```bash
# Set Pulumi AWS provider to use LocalStack
pulumi config set aws:endpoints:s3 http://localhost:4566
pulumi config set aws:endpoints:ec2 http://localhost:4566
pulumi config set aws:endpoints:iam http://localhost:4566
pulumi config set aws:endpoints:lambda http://localhost:4566
pulumi config set aws:endpoints:dynamodb http://localhost:4566
pulumi config set aws:skipCredentialsValidation true
pulumi config set aws:skipRequestingAccountId true
pulumi config set aws:s3ForcePathStyle true
```

## Testing LocalStack

### Basic AWS CLI Tests

```bash
# Test S3
aws --endpoint-url=$AWS_ENDPOINT s3 ls
aws --endpoint-url=$AWS_ENDPOINT s3 mb s3://test-bucket
aws --endpoint-url=$AWS_ENDPOINT s3 ls
aws --endpoint-url=$AWS_ENDPOINT s3 rb s3://test-bucket

# Test EC2
aws --endpoint-url=$AWS_ENDPOINT ec2 describe-instances

# Test IAM
aws --endpoint-url=$AWS_ENDPOINT iam list-users

# Test Lambda
aws --endpoint-url=$AWS_ENDPOINT lambda list-functions
```

### Using the Test Script

```bash
# Run comprehensive AWS CLI test
./scripts/test-aws-cli.sh
```

### Health Check

```bash
# Check LocalStack health
curl http://localhost:4566/_localstack/health | python3 -m json.tool
```

## Pulumi with LocalStack

### Example: S3 Bucket Creation

```bash
cd experiments/006-s3-buckets-hy

# Initialize stack for LocalStack
pulumi stack init localstack --secrets-provider passphrase

# Configure for LocalStack
pulumi config set aws:endpoints:s3 http://localhost:4566
pulumi config set aws:skipCredentialsValidation true
pulumi config set aws:skipRequestingAccountId true
pulumi config set aws:s3ForcePathStyle true

# Deploy
pulumi up

# Verify with AWS CLI
aws --endpoint-url=$AWS_ENDPOINT s3 ls
```

## Troubleshooting

### Docker Daemon Not Running

```bash
# Check Docker service status
service docker status

# If not enabled:
sudo sysrc docker_enable=YES

# Start Docker:
sudo service docker start

# Verify:
docker ps
```

### Permission Denied

```bash
# Check if user is in docker group
groups | grep docker

# If not, add user:
sudo pw groupmod docker -m $USER
# Then logout and login again
```

### LocalStack Container Issues

```bash
# Check if container exists
docker ps -a | grep localstack

# Remove old container
docker stop localstack
docker rm localstack

# Check logs
docker logs localstack

# Restart
gmake localstack-stop
gmake localstack-start
```

### Port Already in Use

```bash
# Check what's using port 4566
sockstat -l | grep 4566

# Kill the process or use different port
docker run -d \
  --name localstack \
  -p 4567:4566 \  # Different host port
  ...
```

## Docker-Compose Alternative

Create `docker-compose.yml`:

```yaml
version: '3.8'
services:
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"
      - "4571:4571"
    environment:
      - SERVICES=s3,ec2,iam,lambda,dynamodb,sqs,sns
      - DEBUG=1
      - DATA_DIR=/tmp/localstack/data
    volumes:
      - /tmp/localstack:/tmp/localstack
      - /var/run/docker.sock:/var/run/docker.sock
```

Then run:
```bash
docker-compose up -d
docker-compose logs -f localstack
```

## Summary

1. **Docker Required**: LocalStack runs as a Docker container
2. **User Permissions**: User must be in docker group (requires logout/login)
3. **AWS CLI**: Use pip-installed version for better compatibility
4. **Environment**: Set AWS_ENDPOINT to http://localhost:4566
5. **Pulumi Config**: Configure endpoints and skip validations

## Quick Start Commands

```bash
# One-time setup
sudo pkg install docker docker-compose
sudo sysrc docker_enable=YES
sudo service docker start
sudo pw groupmod docker -m $USER
# Logout and login

# Start LocalStack
gmake localstack-start

# Configure environment
eval $(gmake localstack-env)

# Test
aws --endpoint-url=$AWS_ENDPOINT s3 ls

# Use with Pulumi
cd experiments/006-s3-buckets-hy
pulumi up
```

## Notes for FreeBSD Users

- Docker on FreeBSD uses the linuxulator for Linux container support
- Performance is generally good but may vary compared to native Linux
- Some Docker features may have limitations on FreeBSD
- Consider using jails or bhyve VMs for production workloads
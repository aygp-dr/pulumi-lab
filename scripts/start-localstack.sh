#!/bin/sh
# Start LocalStack for Pulumi Lab testing on FreeBSD

echo "========================================="
echo "LocalStack Setup for FreeBSD"
echo "========================================="
echo ""

# Check if Docker is running
if ! docker ps >/dev/null 2>&1; then
    echo "Docker daemon is not running."
    echo ""
    echo "Please run these commands manually:"
    echo "  sudo service docker start"
    echo "  sudo pw groupmod docker -m $USER"
    echo ""
    echo "Then logout and login again for group changes to take effect."
    echo ""
    echo "After that, run this script again."
    exit 1
fi

echo "✓ Docker is running"
echo ""

# Check for existing LocalStack container
if docker ps -a | grep -q localstack; then
    echo "Found existing LocalStack container. Removing..."
    docker stop localstack 2>/dev/null
    docker rm localstack 2>/dev/null
fi

# Start LocalStack
echo "Starting LocalStack..."
docker run -d \
    --name localstack \
    -p 4566:4566 \
    -p 4571:4571 \
    -e SERVICES=s3,ec2,iam,lambda,dynamodb,sqs,sns \
    -e DEBUG=1 \
    -e DATA_DIR=/tmp/localstack/data \
    -v /tmp/localstack:/tmp/localstack \
    localstack/localstack:latest

echo ""
echo "Waiting for LocalStack to be ready..."
sleep 10

# Check if LocalStack is running
if docker ps | grep -q localstack; then
    echo "✓ LocalStack is running"
    echo ""
    
    # Show logs
    echo "LocalStack logs (last 10 lines):"
    docker logs localstack 2>&1 | tail -10
    echo ""
    
    # Test LocalStack health
    echo "Testing LocalStack health endpoint..."
    curl -s http://localhost:4566/_localstack/health | python3 -m json.tool | head -20
    echo ""
    
    # Set environment variables
    echo "========================================="
    echo "LocalStack is ready!"
    echo ""
    echo "Set these environment variables:"
    echo ""
    echo "export AWS_ENDPOINT=http://localhost:4566"
    echo "export AWS_ACCESS_KEY_ID=test"
    echo "export AWS_SECRET_ACCESS_KEY=test"
    echo "export AWS_REGION=us-east-1"
    echo ""
    echo "Or run: eval \$(gmake localstack-env)"
    echo ""
    echo "Test with AWS CLI:"
    echo "aws --endpoint-url=http://localhost:4566 s3 ls"
    echo "========================================="
else
    echo "✗ Failed to start LocalStack"
    echo "Check Docker logs: docker logs localstack"
    exit 1
fi
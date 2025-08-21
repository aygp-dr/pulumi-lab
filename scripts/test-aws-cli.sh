#!/bin/sh
# Test AWS CLI installation and configuration

echo "========================================="
echo "AWS CLI Test for Pulumi Lab"
echo "========================================="
echo ""

# Check AWS CLI installation
echo "1. AWS CLI Installation:"
if command -v aws >/dev/null 2>&1; then
    echo "   ✓ System AWS CLI: $(which aws)"
    aws --version
else
    echo "   ✗ System AWS CLI not found"
fi

if [ -f "$HOME/.local/bin/aws" ]; then
    echo "   ✓ User AWS CLI: ~/.local/bin/aws"
    $HOME/.local/bin/aws --version
    AWS_CMD="$HOME/.local/bin/aws"
else
    echo "   ✗ User AWS CLI not installed"
    echo "   Install with: pip3 install --user awscli"
    AWS_CMD="aws"
fi
echo ""

# Check AWS configuration
echo "2. AWS Configuration:"
if [ -f "$HOME/.aws/config" ]; then
    echo "   ✓ Config file exists"
else
    echo "   ℹ No config file (~/.aws/config)"
fi

if [ -f "$HOME/.aws/credentials" ]; then
    echo "   ✓ Credentials file exists"
else
    echo "   ℹ No credentials file (~/.aws/credentials)"
fi
echo ""

# Check environment variables
echo "3. Environment Variables:"
if [ -n "$AWS_ENDPOINT" ]; then
    echo "   ✓ AWS_ENDPOINT=$AWS_ENDPOINT"
else
    echo "   ℹ AWS_ENDPOINT not set (will use AWS default)"
fi

if [ -n "$AWS_ACCESS_KEY_ID" ]; then
    echo "   ✓ AWS_ACCESS_KEY_ID is set"
else
    echo "   ℹ AWS_ACCESS_KEY_ID not set"
fi

if [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "   ✓ AWS_SECRET_ACCESS_KEY is set"
else
    echo "   ℹ AWS_SECRET_ACCESS_KEY not set"
fi

if [ -n "$AWS_REGION" ]; then
    echo "   ✓ AWS_REGION=$AWS_REGION"
else
    echo "   ℹ AWS_REGION not set (will use default)"
fi
echo ""

# Test LocalStack if endpoint is set
if [ "$AWS_ENDPOINT" = "http://localhost:4566" ]; then
    echo "4. LocalStack Test:"
    echo "   Testing connection to LocalStack..."
    
    # Test S3
    if $AWS_CMD --endpoint-url=$AWS_ENDPOINT s3 ls 2>/dev/null; then
        echo "   ✓ S3 service is accessible"
    else
        echo "   ✗ Cannot connect to LocalStack S3"
        echo "   Is LocalStack running? Check with: docker ps | grep localstack"
    fi
    
    # Test creating a bucket
    TEST_BUCKET="test-bucket-$(date +%s)"
    if $AWS_CMD --endpoint-url=$AWS_ENDPOINT s3 mb s3://$TEST_BUCKET 2>/dev/null; then
        echo "   ✓ Created test bucket: $TEST_BUCKET"
        $AWS_CMD --endpoint-url=$AWS_ENDPOINT s3 rb s3://$TEST_BUCKET 2>/dev/null
        echo "   ✓ Deleted test bucket"
    else
        echo "   ✗ Cannot create S3 bucket"
    fi
else
    echo "4. LocalStack Test:"
    echo "   ℹ Not configured for LocalStack"
    echo "   To test with LocalStack, set:"
    echo "     export AWS_ENDPOINT=http://localhost:4566"
    echo "     export AWS_ACCESS_KEY_ID=test"
    echo "     export AWS_SECRET_ACCESS_KEY=test"
fi

echo ""
echo "========================================="
echo "Summary:"
if [ -f "$HOME/.local/bin/aws" ] || command -v aws >/dev/null 2>&1; then
    echo "✓ AWS CLI is installed and ready"
    echo ""
    echo "Next steps:"
    echo "1. Start LocalStack: ./scripts/start-localstack.sh"
    echo "2. Configure environment: eval \$(gmake localstack-env)"
    echo "3. Test connection: $AWS_CMD --endpoint-url=http://localhost:4566 s3 ls"
else
    echo "✗ AWS CLI needs to be installed"
    echo "Run: pip3 install --user awscli"
fi
echo "========================================="
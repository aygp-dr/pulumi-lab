# ✅ Working Pulumi + Minio Setup on FreeBSD

## Current Working Configuration

### System
- **OS**: FreeBSD nexushive 14.3-RELEASE (amd64)
- **Pulumi**: 3.145.0 (via Linux compatibility layer)
- **Minio**: 2025.06.13.11.33.47 (native FreeBSD)
- **AWS CLI**: 1.42.14 (via pip)

### What's Working

#### ✅ Pulumi CLI
```bash
$ pulumi version
v3.145.0
```

#### ✅ Minio S3 Storage
```bash
$ ./scripts/start-minio.sh
# Minio running at http://localhost:9000
# Console at http://localhost:9001
```

#### ✅ AWS CLI with Minio
```bash
$ export AWS_ACCESS_KEY_ID=minioadmin
$ export AWS_SECRET_ACCESS_KEY=minioadmin
$ aws --endpoint-url=http://localhost:9000 s3 ls
2025-08-20 21:36:44 test-bucket

$ aws --endpoint-url=http://localhost:9000 s3 cp file.txt s3://test-bucket/
upload: file.txt to s3://test-bucket/file.txt
```

### What Doesn't Work

#### ❌ Docker/LocalStack
- Docker daemon doesn't run natively on FreeBSD
- LocalStack requires Docker
- Would need VirtualBox + docker-machine or remote Docker host

#### ⚠️ Non-S3 AWS Services
- Only S3 operations work with Minio
- For other services (Lambda, DynamoDB, etc.), need actual AWS or remote LocalStack

## Quick Start Commands

### 1. Start Minio
```bash
./scripts/start-minio.sh
```

### 2. Configure Environment
```bash
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
export AWS_ENDPOINT=http://localhost:9000
```

### 3. Test S3 Operations
```bash
# Create bucket
aws --endpoint-url=$AWS_ENDPOINT s3 mb s3://my-bucket

# Upload file
aws --endpoint-url=$AWS_ENDPOINT s3 cp README.org s3://my-bucket/

# List files
aws --endpoint-url=$AWS_ENDPOINT s3 ls s3://my-bucket/
```

### 4. Use with Pulumi
```python
import pulumi_aws as aws

# Configure provider for Minio
provider = aws.Provider("minio",
    endpoints=[aws.ProviderEndpointArgs(s3="http://localhost:9000")],
    s3_use_path_style=True,
    skip_credentials_validation=True,
    skip_requesting_account_id=True,
    access_key="minioadmin",
    secret_key="minioadmin",
    region="us-east-1"
)

# Create resources
bucket = aws.s3.BucketV2("my-bucket",
    opts=pulumi.ResourceOptions(provider=provider))
```

## Experiments That Will Work

### ✅ Can Run with Minio
- `006-s3-buckets-hy` - S3 bucket operations
- Any S3-only experiments
- Static website hosting tests

### ⚠️ Need Modification
- Experiments using multiple AWS services
- Can modify to use only S3 features

### ❌ Won't Work Without Docker
- Lambda experiments
- ECS/Fargate experiments  
- Full AWS service emulation

## Alternative Solutions

1. **For Lambda Testing**: Use actual AWS Lambda with free tier
2. **For DynamoDB**: Install local DynamoDB or use AWS free tier
3. **For Full LocalStack**: Set up Linux VM with Docker
4. **For CI/CD**: Use GitHub Actions with Linux runners

## Summary

**Working Solution**: Pulumi + Minio on FreeBSD provides a functional S3 testing environment without Docker. This covers a significant portion of infrastructure testing needs, especially for storage-focused applications.

**Limitations**: Non-S3 AWS services require either:
- Real AWS accounts (with free tier)
- Remote Docker/LocalStack setup
- Service-specific alternatives

This setup is production-ready for S3 operations and development/testing of Pulumi infrastructure code.
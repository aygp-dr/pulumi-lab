#!/usr/bin/env python3
"""Test Pulumi with Minio S3-compatible storage"""

import pulumi
import pulumi_aws as aws

# Configure AWS provider for Minio
minio_provider = aws.Provider("minio",
    endpoints=[aws.ProviderEndpointArgs(
        s3="http://localhost:9000",
    )],
    s3_use_path_style=True,
    skip_credentials_validation=True,
    skip_requesting_account_id=True,
    skip_metadata_api_check=True,
    access_key="minioadmin",
    secret_key="minioadmin",
    region="us-east-1"
)

# Create a bucket
bucket = aws.s3.BucketV2("pulumi-test-bucket",
    bucket="pulumi-test-bucket",
    opts=pulumi.ResourceOptions(provider=minio_provider)
)

# Export the bucket name
pulumi.export("bucket_name", bucket.bucket)
pulumi.export("minio_endpoint", "http://localhost:9000")

print("✅ Pulumi configuration for Minio is ready!")
print("Run 'pulumi up' to create the bucket in Minio")
"""
Python Blocking vs Async patterns with Pulumi
Based on: https://www.pulumi.com/docs/iac/languages-sdks/python/python-blocking-async/

Demonstrates the difference between blocking and async operations in Pulumi Python
"""

import mimetypes
import os
import asyncio
from typing import List, Dict, Any

import pulumi
import pulumi_aws as aws


# Configuration
config = pulumi.Config()
app_name = config.get("app-name", "python-async-demo")
environment = pulumi.get_stack()

# LocalStack provider for testing
localstack_provider = aws.Provider("localstack",
    region="us-east-1",
    access_key="test",
    secret_key="test",
    skip_credentials_validation=True,
    skip_metadata_api_check=True,
    skip_requesting_account_id=True,
    endpoints=aws.ProviderEndpointsArgs(
        s3="http://localhost:4566",
        cloudfront="http://localhost:4566",
        route53="http://localhost:4566"
    )
)

# 1. BLOCKING APPROACH (Traditional)
print("=== Creating resources with blocking patterns ===")

# Create bucket (blocking)
bucket = aws.s3.BucketV2('s3-bucket',
    bucket=f"{app_name}-static-{environment}",
    opts=pulumi.ResourceOptions(provider=localstack_provider)
)

# Website configuration (blocking)
website_config = aws.s3.BucketWebsiteConfigurationV2('website-config',
    bucket=bucket.id,
    index_document=aws.s3.BucketWebsiteConfigurationV2IndexDocumentArgs(
        suffix="index.html"
    ),
    error_document=aws.s3.BucketWebsiteConfigurationV2ErrorDocumentArgs(
        key="404.html"
    ),
    opts=pulumi.ResourceOptions(provider=localstack_provider)
)

# Public access configuration (blocking)
public_access_block = aws.s3.BucketPublicAccessBlock('public-access',
    bucket=bucket.id,
    block_public_acls=False,
    block_public_policy=False,
    ignore_public_acls=False,
    restrict_public_buckets=False,
    opts=pulumi.ResourceOptions(provider=localstack_provider)
)

# Upload files using blocking approach
content_dir = "www"
if os.path.exists(content_dir):
    print(f"Uploading files from {content_dir}/ (blocking approach)")
    for file in os.listdir(content_dir):
        filepath = os.path.join(content_dir, file)
        if os.path.isfile(filepath):
            mime_type, _ = mimetypes.guess_type(filepath)
            obj = aws.s3.BucketObject(file,
                bucket=bucket.id,
                source=pulumi.FileAsset(filepath),
                content_type=mime_type or "text/plain",
                opts=pulumi.ResourceOptions(provider=localstack_provider)
            )
else:
    print(f"Content directory '{content_dir}' not found, creating sample files...")
    
    # Create sample HTML content
    index_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>{app_name} - Async Demo</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; }}
        .container {{ max-width: 800px; margin: 0 auto; }}
        .async-demo {{ background: #e8f4f8; padding: 20px; border-radius: 8px; }}
        .blocking-demo {{ background: #f8e8e8; padding: 20px; border-radius: 8px; }}
        code {{ background: #f0f0f0; padding: 2px 4px; border-radius: 3px; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Pulumi Python Async Demo</h1>
        <p>Environment: <strong>{environment}</strong></p>
        
        <div class="blocking-demo">
            <h2>🔄 Blocking Operations</h2>
            <p>These resources were created using traditional blocking Pulumi patterns:</p>
            <ul>
                <li>S3 bucket created synchronously</li>
                <li>Files uploaded one by one</li>
                <li>Each operation waits for the previous to complete</li>
            </ul>
            <code>bucket = aws.s3.BucketV2('bucket')</code>
        </div>
        
        <div class="async-demo">
            <h2>⚡ Async Operations</h2>
            <p>Advanced resources use async patterns for better performance:</p>
            <ul>
                <li>Parallel resource creation</li>
                <li>Concurrent file uploads</li>
                <li>Non-blocking I/O operations</li>
            </ul>
            <code>await asyncio.gather(*upload_tasks)</code>
        </div>
        
        <footer>
            <p>Created with Pulumi and LocalStack • <a href="/api.json">API Data</a></p>
        </footer>
    </div>
</body>
</html>"""
    
    # Create index.html
    index_obj = aws.s3.BucketObject('index.html',
        bucket=bucket.id,
        content=index_content,
        content_type="text/html",
        opts=pulumi.ResourceOptions(provider=localstack_provider)
    )
    
    # Create 404.html
    error_content = """<!DOCTYPE html>
<html>
<head>
    <title>Page Not Found</title>
    <style>body { font-family: Arial, sans-serif; text-align: center; margin: 100px; }</style>
</head>
<body>
    <h1>404 - Page Not Found</h1>
    <p>The requested page could not be found.</p>
    <a href="/">Return to Home</a>
</body>
</html>"""
    
    error_obj = aws.s3.BucketObject('404.html',
        bucket=bucket.id,
        content=error_content,
        content_type="text/html",
        opts=pulumi.ResourceOptions(provider=localstack_provider)
    )

# 2. ASYNC APPROACH (Advanced patterns)
print("=== Creating resources with async patterns ===")

# Async bucket policy creation
def create_bucket_policy(bucket_name: pulumi.Output[str]) -> pulumi.Output[str]:
    """Create bucket policy using apply (async-style)"""
    return bucket_name.apply(lambda name: f"""{{
    "Version": "2012-10-17",
    "Statement": [
        {{
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::{name}/*"
        }}
    ]
}}""")

# Apply bucket policy (async)
bucket_policy = aws.s3.BucketPolicy('bucket-policy',
    bucket=bucket.id,
    policy=create_bucket_policy(bucket.bucket),
    opts=pulumi.ResourceOptions(
        provider=localstack_provider,
        depends_on=[public_access_block]
    )
)

# Async data generation
async def generate_api_data() -> Dict[str, Any]:
    """Generate API data asynchronously"""
    await asyncio.sleep(0.1)  # Simulate async work
    return {
        "app_name": app_name,
        "environment": environment,
        "timestamp": "2025-08-20T12:00:00Z",
        "features": {
            "async_uploads": True,
            "blocking_uploads": True,
            "localstack_testing": True
        },
        "endpoints": {
            "home": "/",
            "api": "/api.json",
            "health": "/health.json"
        },
        "stats": {
            "files_uploaded": 5,
            "total_size_bytes": 4096,
            "compression_enabled": False
        }
    }

# Create multiple files with async patterns
def create_multiple_files(bucket_id: pulumi.Output[str]) -> List[aws.s3.BucketObject]:
    """Create multiple S3 objects with async-style operations"""
    
    files_to_create = [
        {
            "key": "styles.css",
            "content": """
body { 
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    line-height: 1.6;
    color: #333;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    margin: 0;
}
.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
    background: white;
    box-shadow: 0 0 20px rgba(0,0,0,0.1);
    border-radius: 10px;
    margin-top: 20px;
}
.async-demo, .blocking-demo {
    margin: 20px 0;
    padding: 20px;
    border-radius: 8px;
    border-left: 4px solid #3498db;
}
.async-demo { background: #e8f6f3; border-left-color: #1abc9c; }
.blocking-demo { background: #fdf2e9; border-left-color: #e67e22; }
            """.strip(),
            "content_type": "text/css"
        },
        {
            "key": "app.js",
            "content": """
// Pulumi Async Demo JavaScript
document.addEventListener('DOMContentLoaded', function() {
    console.log('Pulumi Async Demo loaded');
    
    // Fetch API data asynchronously
    fetch('/api.json')
        .then(response => response.json())
        .then(data => {
            console.log('API Data loaded:', data);
            updatePageWithApiData(data);
        })
        .catch(error => console.error('Error loading API data:', error));
});

function updatePageWithApiData(data) {
    const statsDiv = document.getElementById('api-stats');
    if (statsDiv) {
        statsDiv.innerHTML = `
            <h3>Live API Data</h3>
            <p>Environment: ${data.environment}</p>
            <p>Files: ${data.stats.files_uploaded}</p>
            <p>Updated: ${data.timestamp}</p>
        `;
    }
}

// Simulate async operations
async function demoAsyncOperation() {
    console.log('Starting async operation...');
    await new Promise(resolve => setTimeout(resolve, 1000));
    console.log('Async operation completed!');
}

demoAsyncOperation();
            """.strip(),
            "content_type": "application/javascript"
        },
        {
            "key": "health.json",
            "content": '{"status": "healthy", "service": "pulumi-async-demo", "timestamp": "2025-08-20T12:00:00Z"}',
            "content_type": "application/json"
        }
    ]
    
    objects = []
    for file_info in files_to_create:
        obj = aws.s3.BucketObject(file_info["key"],
            bucket=bucket_id,
            content=file_info["content"],
            content_type=file_info["content_type"],
            opts=pulumi.ResourceOptions(provider=localstack_provider)
        )
        objects.append(obj)
    
    return objects

# Create files using the async pattern
additional_files = create_multiple_files(bucket.id)

# Create API JSON file with async-generated content
def create_api_json(bucket_id: pulumi.Output[str]) -> aws.s3.BucketObject:
    """Create API JSON file with generated content"""
    import json
    
    api_data = {
        "app_name": app_name,
        "environment": environment,
        "version": "1.0.0",
        "build_timestamp": "2025-08-20T12:00:00Z",
        "features": {
            "async_resource_creation": True,
            "blocking_resource_creation": True,
            "localstack_integration": True,
            "python_sdk_demo": True
        },
        "infrastructure": {
            "provider": "AWS (LocalStack)",
            "region": "us-east-1",
            "services": ["S3", "CloudFront"]
        },
        "endpoints": {
            "home": "/",
            "api": "/api.json",
            "health": "/health.json",
            "styles": "/styles.css",
            "script": "/app.js"
        },
        "performance": {
            "async_upload_time_ms": 150,
            "blocking_upload_time_ms": 800,
            "parallel_operations": True
        }
    }
    
    return aws.s3.BucketObject('api.json',
        bucket=bucket_id,
        content=json.dumps(api_data, indent=2),
        content_type="application/json",
        opts=pulumi.ResourceOptions(provider=localstack_provider)
    )

api_json_file = create_api_json(bucket.id)

# 3. ADVANCED ASYNC PATTERNS
print("=== Advanced async patterns ===")

# Async resource creation with conditional logic
def create_cloudfront_distribution(bucket_name: pulumi.Output[str], 
                                 bucket_domain: pulumi.Output[str]) -> aws.cloudfront.Distribution:
    """Create CloudFront distribution with async configuration"""
    
    # Use apply to create async configuration
    def create_origin_config(domain):
        return aws.cloudfront.DistributionOriginArgs(
            domain_name=domain,
            origin_id=f"{app_name}-origin",
            s3_origin_config=aws.cloudfront.DistributionOriginS3OriginConfigArgs(
                origin_access_identity=""
            )
        )
    
    return aws.cloudfront.Distribution('cdn',
        enabled=True,
        default_root_object="index.html",
        origins=[bucket_domain.apply(create_origin_config)],
        default_cache_behavior=aws.cloudfront.DistributionDefaultCacheBehaviorArgs(
            target_origin_id=f"{app_name}-origin",
            viewer_protocol_policy="redirect-to-https",
            allowed_methods=["GET", "HEAD", "OPTIONS"],
            cached_methods=["GET", "HEAD", "OPTIONS"],
            forwarded_values=aws.cloudfront.DistributionDefaultCacheBehaviorForwardedValuesArgs(
                query_string=False,
                cookies=aws.cloudfront.DistributionDefaultCacheBehaviorForwardedValuesCookiesArgs(
                    forward="none"
                )
            ),
            min_ttl=0,
            default_ttl=86400,
            max_ttl=31536000
        ),
        restrictions=aws.cloudfront.DistributionRestrictionsArgs(
            geo_restriction=aws.cloudfront.DistributionRestrictionsGeoRestrictionArgs(
                restriction_type="none"
            )
        ),
        viewer_certificate=aws.cloudfront.DistributionViewerCertificateArgs(
            cloudfront_default_certificate=True
        ),
        opts=pulumi.ResourceOptions(
            provider=localstack_provider,
            depends_on=[bucket_policy]
        )
    )

# Create CloudFront distribution (if not using LocalStack limitations)
# cdn = create_cloudfront_distribution(bucket.bucket, bucket.bucket_domain_name)

# Async output processing
def process_outputs_async(*args) -> pulumi.Output[Dict[str, Any]]:
    """Process multiple outputs asynchronously"""
    bucket_name, website_endpoint = args
    
    def combine_outputs(name, endpoint):
        return {
            "website_urls": {
                "s3_website": f"http://{endpoint}",
                "s3_bucket": f"https://{name}.s3.amazonaws.com",
                "localstack_s3": f"http://localhost:4566/{name}"
            },
            "deployment_info": {
                "app_name": app_name,
                "environment": environment,
                "deployment_method": "async_pulumi",
                "provider": "localstack"
            },
            "files_deployed": [
                "index.html",
                "404.html", 
                "styles.css",
                "app.js",
                "api.json",
                "health.json"
            ]
        }
    
    return pulumi.Output.all(bucket_name, website_endpoint).apply(
        lambda args: combine_outputs(args[0], args[1])
    )

# Export async-processed outputs
deployment_info = process_outputs_async(
    bucket.bucket,
    website_config.website_endpoint
)

# Export individual outputs
pulumi.export("bucket_name", bucket.bucket)
pulumi.export("website_endpoint", website_config.website_endpoint)
pulumi.export("deployment_info", deployment_info)

# Export async vs blocking comparison
pulumi.export("performance_comparison", {
    "blocking_approach": {
        "description": "Resources created sequentially",
        "files": ["index.html", "404.html"],
        "pattern": "Traditional Pulumi resource creation"
    },
    "async_approach": {
        "description": "Resources created with async patterns",
        "files": ["styles.css", "app.js", "api.json", "health.json"],
        "pattern": "Output.apply() and async functions"
    },
    "benefits": {
        "async": ["Parallel operations", "Better resource utilization", "Faster deployments"],
        "blocking": ["Simpler code", "Easier debugging", "Predictable order"]
    }
})

# Export LocalStack testing commands
pulumi.export("localstack_commands", {
    "list_buckets": "aws --endpoint-url=http://localhost:4566 s3 ls",
    "list_objects": f"aws --endpoint-url=http://localhost:4566 s3 ls s3://{app_name}-static-{environment}/",
    "get_website": f"curl http://localhost:4566/{app_name}-static-{environment}/index.html",
    "get_api": f"curl http://localhost:4566/{app_name}-static-{environment}/api.json"
})

print("=== Async patterns demonstration complete ===")
print(f"Website will be available at S3 endpoint: {app_name}-static-{environment}")
print("Use LocalStack commands to test the deployment")
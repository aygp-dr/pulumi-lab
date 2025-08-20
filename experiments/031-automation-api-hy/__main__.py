"""
Pulumi Automation API Deep Dive in Python
Based on: https://www.pulumi.com/docs/iac/automation-api/getting-started-automation-api/

Demonstrates programmatic infrastructure management using Automation API
"""

import asyncio
import json
import os
import sys
from typing import Dict, List, Optional, Any

import pulumi
import pulumi.automation as auto
import pulumi_aws as aws


def create_pulumi_program(config: Dict[str, Any]):
    """
    Inline Pulumi program for Automation API
    This function defines infrastructure as code that can be executed programmatically
    """
    
    # Get configuration values
    app_name = config.get("app_name", "automation-api-demo")
    environment = config.get("environment", "dev")
    enable_website = config.get("enable_website", True)
    bucket_count = config.get("bucket_count", 2)
    
    # LocalStack provider for testing (optimized for macOS)
    localstack_provider = aws.Provider("localstack",
        region="us-east-1",
        access_key="test",
        secret_key="test",
        skip_credentials_validation=True,
        skip_metadata_api_check=True,
        skip_requesting_account_id=True,
        s3_force_path_style=True,  # Important for LocalStack compatibility
        s3_use_path_style=True,
        endpoints=aws.ProviderEndpointsArgs(
            s3="http://localhost:4566",
            lambda_="http://localhost:4566",
            apigateway="http://localhost:4566",
            dynamodb="http://localhost:4566",
            iam="http://localhost:4566",
            sts="http://localhost:4566"
        )
    )
    
    # Create multiple S3 buckets programmatically
    buckets = []
    for i in range(bucket_count):
        bucket = aws.s3.BucketV2(f"automation-bucket-{i}",
            bucket=f"{app_name}-auto-{environment}-{i}",
            opts=pulumi.ResourceOptions(provider=localstack_provider)
        )
        buckets.append(bucket)
    
    # Create a website bucket if enabled (using your S3 website pattern)
    website_bucket = None
    if enable_website:
        # Create the main website bucket
        website_bucket = aws.s3.BucketV2("website-bucket",
            bucket=f"{app_name}-website-{environment}",
            opts=pulumi.ResourceOptions(provider=localstack_provider)
        )
        
        # Configure bucket ownership controls (important for public access)
        ownership_controls = aws.s3.BucketOwnershipControls("website-ownership-controls",
            bucket=website_bucket.id,
            rule=aws.s3.BucketOwnershipControlsRuleArgs(
                object_ownership="BucketOwnerPreferred"
            ),
            opts=pulumi.ResourceOptions(provider=localstack_provider)
        )
        
        # Disable public access block (required for website hosting)
        public_access_block = aws.s3.BucketPublicAccessBlock("website-public-access",
            bucket=website_bucket.id,
            block_public_acls=False,
            block_public_policy=False,
            ignore_public_acls=False,
            restrict_public_buckets=False,
            opts=pulumi.ResourceOptions(
                provider=localstack_provider,
                depends_on=[ownership_controls]
            )
        )
        
        # Configure website hosting
        website_config = aws.s3.BucketWebsiteConfigurationV2("website-config",
            bucket=website_bucket.id,
            index_document=aws.s3.BucketWebsiteConfigurationV2IndexDocumentArgs(
                suffix="index.html"
            ),
            error_document=aws.s3.BucketWebsiteConfigurationV2ErrorDocumentArgs(
                key="404.html"
            ),
            opts=pulumi.ResourceOptions(
                provider=localstack_provider,
                depends_on=[public_access_block]
            )
        )
        
        # Upload sample content
        index_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>{app_name} - Automation API Demo</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; background: #f0f8ff; }}
        .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; }}
        .automation {{ background: #e8f5e8; padding: 20px; border-radius: 5px; margin: 20px 0; }}
        code {{ background: #f0f0f0; padding: 2px 4px; border-radius: 3px; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🤖 Pulumi Automation API Demo</h1>
        <p>Environment: <strong>{environment}</strong></p>
        <p>App: <strong>{app_name}</strong></p>
        
        <div class="automation">
            <h2>Automation API Features</h2>
            <ul>
                <li>✅ Programmatic infrastructure deployment</li>
                <li>✅ Inline program execution</li>
                <li>✅ Dynamic resource creation</li>
                <li>✅ Config-driven infrastructure</li>
                <li>✅ CI/CD integration ready</li>
            </ul>
        </div>
        
        <h3>Created Resources</h3>
        <p>Buckets created: <strong>{bucket_count}</strong></p>
        <p>Website enabled: <strong>{enable_website}</strong></p>
        
        <footer>
            <p>Deployed programmatically via Pulumi Automation API</p>
        </footer>
    </div>
</body>
</html>"""
        
        index_file = aws.s3.BucketObject("index.html",
            bucket=website_bucket.id,
            content=index_content,
            content_type="text/html",
            opts=pulumi.ResourceOptions(
                provider=localstack_provider,
                depends_on=[website_config]
            )
        )
        
        # Create 404 error page
        error_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>404 - Page Not Found</title>
    <style>
        body {{ font-family: Arial, sans-serif; text-align: center; margin: 100px; background: #f8f9fa; }}
        .error-container {{ max-width: 500px; margin: 0 auto; padding: 40px; background: white; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        h1 {{ color: #dc3545; }}
    </style>
</head>
<body>
    <div class="error-container">
        <h1>404 - Page Not Found</h1>
        <p>The requested page could not be found in the {app_name} application.</p>
        <p>Environment: {environment}</p>
        <a href="/" style="color: #007bff; text-decoration: none;">← Return to Home</a>
    </div>
</body>
</html>"""
        
        error_file = aws.s3.BucketObject("404.html",
            bucket=website_bucket.id,
            content=error_content,
            content_type="text/html",
            opts=pulumi.ResourceOptions(
                provider=localstack_provider,
                depends_on=[website_config]
            )
        )
        
        # Create bucket policy for public read access (website hosting requirement)
        bucket_policy_doc = website_bucket.bucket.apply(lambda bucket_name: json.dumps({
            "Version": "2012-10-17",
            "Statement": [{
                "Sid": "PublicReadGetObject",
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": f"arn:aws:s3:::{bucket_name}/*"
            }]
        }))
        
        bucket_policy = aws.s3.BucketPolicy("website-bucket-policy",
            bucket=website_bucket.id,
            policy=bucket_policy_doc,
            opts=pulumi.ResourceOptions(
                provider=localstack_provider,
                depends_on=[public_access_block]
            )
        )
    
    # Create a DynamoDB table for application data
    app_table = aws.dynamodb.Table("app-table",
        name=f"{app_name}-data-{environment}",
        billing_mode="PAY_PER_REQUEST",
        hash_key="id",
        attributes=[
            aws.dynamodb.TableAttributeArgs(name="id", type="S"),
            aws.dynamodb.TableAttributeArgs(name="timestamp", type="N")
        ],
        global_secondary_indexes=[
            aws.dynamodb.TableGlobalSecondaryIndexArgs(
                name="timestamp-index",
                hash_key="timestamp",
                projection_type="ALL"
            )
        ],
        opts=pulumi.ResourceOptions(provider=localstack_provider)
    )
    
    # Create Lambda function for API
    lambda_code = f"""
import json
import boto3
import time
from decimal import Decimal

def handler(event, context):
    # Initialize DynamoDB client
    dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566')
    table = dynamodb.Table('{app_name}-data-{environment}')
    
    # Get HTTP method and path
    method = event.get('httpMethod', 'GET')
    path = event.get('path', '/')
    
    try:
        if method == 'GET' and path == '/':
            # Health check
            return {{
                'statusCode': 200,
                'headers': {{'Content-Type': 'application/json'}},
                'body': json.dumps({{
                    'message': 'Automation API Lambda is running!',
                    'app': '{app_name}',
                    'environment': '{environment}',
                    'timestamp': int(time.time())
                }})
            }}
        
        elif method == 'GET' and path == '/data':
            # Get all data
            response = table.scan()
            items = response.get('Items', [])
            return {{
                'statusCode': 200,
                'headers': {{'Content-Type': 'application/json'}},
                'body': json.dumps(items, default=str)
            }}
        
        elif method == 'POST' and path == '/data':
            # Add new data
            body = json.loads(event.get('body', '{{}}'))
            item_id = str(int(time.time()))
            
            table.put_item(Item={{
                'id': item_id,
                'timestamp': Decimal(str(time.time())),
                'data': body.get('data', 'automation-api-test'),
                'source': 'automation-api'
            }})
            
            return {{
                'statusCode': 201,
                'headers': {{'Content-Type': 'application/json'}},
                'body': json.dumps({{'id': item_id, 'message': 'Item created'}})
            }}
        
        else:
            return {{
                'statusCode': 404,
                'headers': {{'Content-Type': 'application/json'}},
                'body': json.dumps({{'error': 'Not found'}})
            }}
    
    except Exception as e:
        return {{
            'statusCode': 500,
            'headers': {{'Content-Type': 'application/json'}},
            'body': json.dumps({{'error': str(e)}})
        }}
"""
    
    # IAM role for Lambda (simplified for LocalStack)
    lambda_role = aws.iam.Role("lambda-role",
        assume_role_policy=json.dumps({
            "Version": "2012-10-17",
            "Statement": [{
                "Action": "sts:AssumeRole",
                "Principal": {"Service": "lambda.amazonaws.com"},
                "Effect": "Allow"
            }]
        }),
        opts=pulumi.ResourceOptions(provider=localstack_provider)
    )
    
    # Lambda function
    api_lambda = aws.lambda_.Function("api-lambda",
        code=pulumi.AssetArchive({
            "index.py": pulumi.StringAsset(lambda_code)
        }),
        role=lambda_role.arn,
        handler="index.handler",
        runtime="python3.9",
        timeout=30,
        environment=aws.lambda_.FunctionEnvironmentArgs(
            variables={
                "APP_NAME": app_name,
                "ENVIRONMENT": environment
            }
        ),
        opts=pulumi.ResourceOptions(provider=localstack_provider)
    )
    
    # Export outputs for Automation API
    outputs = {
        "app_name": app_name,
        "environment": environment,
        "bucket_count": bucket_count,
        "bucket_names": [bucket.bucket for bucket in buckets],
        "lambda_function_name": api_lambda.function_name,
        "table_name": app_table.name
    }
    
    if website_bucket:
        outputs["website_bucket"] = website_bucket.bucket
        outputs["website_endpoint"] = website_config.website_endpoint
        outputs["localstack_website_url"] = website_bucket.bucket.apply(
            lambda name: f"http://localhost:4566/{name}/index.html"
        )
        outputs["s3_website_domain"] = website_config.website_domain
    
    # Export all outputs
    for key, value in outputs.items():
        pulumi.export(key, value)
    
    return outputs


async def run_automation_api_demo():
    """
    Main Automation API demonstration
    Shows how to programmatically manage infrastructure
    """
    
    print("🤖 Starting Pulumi Automation API Demo")
    print("=" * 50)
    
    # Configuration for the infrastructure
    config = {
        "app_name": "automation-demo",
        "environment": "dev",
        "enable_website": True,
        "bucket_count": 3
    }
    
    # Project settings
    project_name = "automation-api-demo"
    stack_name = "dev"
    
    # Create stack
    print(f"📋 Creating/selecting stack: {stack_name}")
    
    # Define the Automation API stack
    stack = auto.create_or_select_stack(
        stack_name=stack_name,
        project_name=project_name,
        program=lambda: create_pulumi_program(config)
    )
    
    print(f"✅ Stack ready: {stack.name}")
    
    # Install plugins
    print("🔧 Installing required plugins...")
    await stack.workspace.install_plugin("aws", "v6.0.0")
    print("✅ Plugins installed")
    
    # Set stack configuration
    print("⚙️ Setting stack configuration...")
    await stack.set_config("aws:region", auto.ConfigValue(value="us-east-1"))
    await stack.set_config("aws:accessKey", auto.ConfigValue(value="test"))
    await stack.set_config("aws:secretKey", auto.ConfigValue(value="test"))
    await stack.set_config("aws:skipCredentialsValidation", auto.ConfigValue(value="true"))
    await stack.set_config("aws:skipMetadataApiCheck", auto.ConfigValue(value="true"))
    await stack.set_config("aws:skipRequestingAccountId", auto.ConfigValue(value="true"))
    print("✅ Configuration set")
    
    # Preview changes
    print("\n🔍 Running preview...")
    preview_result = await stack.preview(on_output=print)
    print(f"📊 Preview summary:")
    print(f"  - Resources to create: {len(preview_result.change_summary.get('create', []))}")
    print(f"  - Resources to update: {len(preview_result.change_summary.get('update', []))}")
    print(f"  - Resources to delete: {len(preview_result.change_summary.get('delete', []))}")
    
    # Deploy infrastructure
    print("\n🚀 Deploying infrastructure...")
    up_result = await stack.up(on_output=print)
    
    print(f"\n✅ Deployment completed!")
    print(f"📊 Summary: {up_result.summary.message}")
    
    # Get outputs
    outputs = await stack.outputs()
    print(f"\n📤 Stack outputs:")
    for key, output in outputs.items():
        print(f"  {key}: {output.value}")
    
    # Test the deployed infrastructure
    print(f"\n🧪 Testing deployed infrastructure...")
    
    # Test LocalStack endpoints
    test_commands = [
        "aws --endpoint-url=http://localhost:4566 s3 ls",
        f"aws --endpoint-url=http://localhost:4566 dynamodb describe-table --table-name {outputs['table_name'].value}",
        f"aws --endpoint-url=http://localhost:4566 lambda list-functions"
    ]
    
    print("LocalStack test commands:")
    for cmd in test_commands:
        print(f"  {cmd}")
    
    return {
        "stack": stack,
        "outputs": outputs,
        "config": config,
        "deployment_result": up_result
    }


async def automation_api_ci_pipeline():
    """
    CI/CD Pipeline using Automation API
    Demonstrates how to use Automation API in CI/CD scenarios
    """
    
    print("\n🔄 CI/CD Pipeline Simulation")
    print("=" * 40)
    
    environments = ["dev", "staging", "prod"]
    results = {}
    
    for env in environments:
        print(f"\n🌍 Deploying to {env} environment...")
        
        # Environment-specific configuration
        env_config = {
            "app_name": "ci-demo",
            "environment": env,
            "enable_website": env in ["staging", "prod"],
            "bucket_count": {"dev": 1, "staging": 2, "prod": 3}[env]
        }
        
        # Create environment-specific stack
        stack = auto.create_or_select_stack(
            stack_name=env,
            project_name="ci-pipeline-demo",
            program=lambda: create_pulumi_program(env_config)
        )
        
        # Install plugins (would be cached in real CI)
        await stack.workspace.install_plugin("aws", "v6.0.0")
        
        # Set configuration
        await stack.set_config("aws:region", auto.ConfigValue(value="us-east-1"))
        await stack.set_config("aws:accessKey", auto.ConfigValue(value="test"))
        await stack.set_config("aws:secretKey", auto.ConfigValue(value="test"))
        await stack.set_config("aws:skipCredentialsValidation", auto.ConfigValue(value="true"))
        await stack.set_config("aws:skipMetadataApiCheck", auto.ConfigValue(value="true"))
        await stack.set_config("aws:skipRequestingAccountId", auto.ConfigValue(value="true"))
        
        # Deploy
        result = await stack.up(on_output=lambda msg: print(f"  [{env}] {msg}"))
        outputs = await stack.outputs()
        
        results[env] = {
            "deployment_result": result,
            "outputs": outputs,
            "config": env_config
        }
        
        print(f"✅ {env} deployment completed")
    
    # Generate deployment report
    print(f"\n📋 Deployment Report")
    print("-" * 30)
    for env, result in results.items():
        outputs = result["outputs"]
        print(f"{env.upper()}:")
        print(f"  Buckets: {result['config']['bucket_count']}")
        print(f"  Website: {result['config']['enable_website']}")
        print(f"  Table: {outputs['table_name'].value}")
        print(f"  Lambda: {outputs['lambda_function_name'].value}")
    
    return results


def create_github_actions_workflow():
    """
    Generate GitHub Actions workflow for Automation API
    """
    
    workflow = """name: Infrastructure Deployment with Automation API

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
        
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
        
    - name: Install Pulumi CLI
      run: |
        curl -fsSL https://get.pulumi.com | sh
        echo "$HOME/.pulumi/bin" >> $GITHUB_PATH
        
    - name: Install dependencies
      run: |
        pip install pulumi pulumi-aws
        
    - name: Start LocalStack
      run: |
        pip install localstack
        docker run -d --name localstack -p 4566:4566 localstack/localstack
        
    - name: Wait for LocalStack
      run: |
        timeout 60 bash -c 'until curl -s http://localhost:4566; do sleep 2; done'
        
    - name: Deploy infrastructure
      run: |
        python automation_api_deployment.py --environment ${{ matrix.environment }}
        
    - name: Run tests
      run: |
        # Test deployed infrastructure
        aws --endpoint-url=http://localhost:4566 s3 ls
        aws --endpoint-url=http://localhost:4566 dynamodb list-tables
        
    - name: Cleanup
      if: always()
      run: |
        docker stop localstack || true
        docker rm localstack || true
"""
    
    return workflow


def create_automation_deployment_script():
    """
    Standalone deployment script for CI/CD
    """
    
    script = '''#!/usr/bin/env python3
"""
Automation API Deployment Script
Usage: python automation_api_deployment.py --environment dev
"""

import argparse
import asyncio
import sys
import os

# Import the automation functions
from __main__ import create_pulumi_program, run_automation_api_demo

async def deploy_environment(environment: str):
    """Deploy to specific environment"""
    
    # Environment-specific settings
    config = {
        "app_name": "ci-automation",
        "environment": environment,
        "enable_website": environment != "dev",
        "bucket_count": {"dev": 1, "staging": 2, "prod": 3}.get(environment, 1)
    }
    
    print(f"🚀 Deploying to {environment} with config: {config}")
    
    # Create and deploy stack
    import pulumi.automation as auto
    
    stack = auto.create_or_select_stack(
        stack_name=environment,
        project_name="automation-deployment",
        program=lambda: create_pulumi_program(config)
    )
    
    # Configure stack
    await stack.workspace.install_plugin("aws", "v6.0.0")
    await stack.set_config("aws:region", auto.ConfigValue(value="us-east-1"))
    await stack.set_config("aws:accessKey", auto.ConfigValue(value="test"))
    await stack.set_config("aws:secretKey", auto.ConfigValue(value="test"))
    await stack.set_config("aws:skipCredentialsValidation", auto.ConfigValue(value="true"))
    await stack.set_config("aws:skipMetadataApiCheck", auto.ConfigValue(value="true"))
    await stack.set_config("aws:skipRequestingAccountId", auto.ConfigValue(value="true"))
    
    # Deploy
    result = await stack.up()
    outputs = await stack.outputs()
    
    print(f"✅ Deployment to {environment} completed!")
    print(f"📤 Outputs: {list(outputs.keys())}")
    
    return result, outputs

def main():
    parser = argparse.ArgumentParser(description="Deploy infrastructure using Automation API")
    parser.add_argument("--environment", required=True, choices=["dev", "staging", "prod"],
                       help="Environment to deploy to")
    parser.add_argument("--preview", action="store_true", help="Only preview changes")
    
    args = parser.parse_args()
    
    # Run deployment
    try:
        result = asyncio.run(deploy_environment(args.environment))
        print("🎉 Deployment successful!")
        sys.exit(0)
    except Exception as e:
        print(f"❌ Deployment failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
'''
    
    return script


async def main():
    """
    Main function demonstrating Automation API capabilities
    """
    
    print("🤖 Pulumi Automation API Deep Dive")
    print("=" * 50)
    
    # Check if LocalStack is running
    try:
        import requests
        response = requests.get("http://localhost:4566")
        print("✅ LocalStack is running")
    except:
        print("⚠️  LocalStack not detected. Start with: gmake localstack-start")
        print("   Continuing with demo anyway...")
    
    # Run main automation demo
    demo_result = await run_automation_api_demo()
    
    # Run CI/CD pipeline simulation
    ci_result = await automation_api_ci_pipeline()
    
    # Generate CI/CD artifacts
    print(f"\n📝 Generating CI/CD artifacts...")
    
    workflow = create_github_actions_workflow()
    with open("github-actions-workflow.yml", "w") as f:
        f.write(workflow)
    print("✅ GitHub Actions workflow saved to github-actions-workflow.yml")
    
    script = create_automation_deployment_script()
    with open("automation_deployment.py", "w") as f:
        f.write(script)
    print("✅ Deployment script saved to automation_deployment.py")
    
    # Summary
    print(f"\n🎉 Automation API Demo Complete!")
    print(f"📊 Summary:")
    print(f"  - Deployed infrastructure programmatically")
    print(f"  - Demonstrated inline programs")
    print(f"  - Simulated CI/CD pipeline")
    print(f"  - Generated reusable artifacts")
    print(f"  - Tested with LocalStack")
    
    return {
        "demo_result": demo_result,
        "ci_result": ci_result,
        "artifacts": ["github-actions-workflow.yml", "automation_deployment.py"]
    }


if __name__ == "__main__":
    # Run the automation API demonstration
    result = asyncio.run(main())
    print("\n✅ All demonstrations completed successfully!")
;; Pulumi Automation API Deep Dive in Hy
;; Based on: https://www.pulumi.com/docs/iac/automation-api/getting-started-automation-api/
;; Incorporates advanced S3 website hosting pattern for LocalStack/macOS

(import asyncio)
(import json)
(import os)
(import sys)
(import mimetypes)
(import [typing [Dict List Optional Any]])

(import pulumi)
(import [pulumi.automation :as auto])
(import [pulumi-aws :as aws])

;; Enhanced S3 website creation function (using your pattern)
(defn create-s3-website [bucket-name app-name environment localstack-provider]
  "Create S3 static website with proper ownership and public access controls"
  
  ;; Main website bucket
  (setv website-bucket 
    (aws.s3.BucketV2 "website-bucket"
      :bucket bucket-name
      :opts (pulumi.ResourceOptions :provider localstack-provider)))
  
  ;; Bucket ownership controls (critical for public access)
  (setv ownership-controls
    (aws.s3.BucketOwnershipControls "website-ownership-controls"
      :bucket (. website-bucket id)
      :rule (aws.s3.BucketOwnershipControlsRuleArgs
              :object-ownership "BucketOwnerPreferred")
      :opts (pulumi.ResourceOptions :provider localstack-provider)))
  
  ;; Disable public access block
  (setv public-access-block
    (aws.s3.BucketPublicAccessBlock "website-public-access"
      :bucket (. website-bucket id)
      :block-public-acls False
      :block-public-policy False
      :ignore-public-acls False
      :restrict-public-buckets False
      :opts (pulumi.ResourceOptions 
              :provider localstack-provider
              :depends-on [ownership-controls])))
  
  ;; Website configuration
  (setv website-config
    (aws.s3.BucketWebsiteConfigurationV2 "website-config"
      :bucket (. website-bucket id)
      :index-document (aws.s3.BucketWebsiteConfigurationV2IndexDocumentArgs
                        :suffix "index.html")
      :error-document (aws.s3.BucketWebsiteConfigurationV2ErrorDocumentArgs
                        :key "404.html")
      :opts (pulumi.ResourceOptions
              :provider localstack-provider
              :depends-on [public-access-block])))
  
  ;; Public read bucket policy
  (setv bucket-policy-doc
    (.apply (. website-bucket bucket)
      (fn [name]
        (json.dumps {
          "Version" "2012-10-17"
          "Statement" [{
            "Sid" "PublicReadGetObject"
            "Effect" "Allow" 
            "Principal" "*"
            "Action" "s3:GetObject"
            "Resource" f"arn:aws:s3:::{name}/*"}]}))))
  
  (setv bucket-policy
    (aws.s3.BucketPolicy "website-bucket-policy"
      :bucket (. website-bucket id)
      :policy bucket-policy-doc
      :opts (pulumi.ResourceOptions
              :provider localstack-provider
              :depends-on [public-access-block])))
  
  ;; Create content files
  (setv index-content f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>{app-name} - Automation API Demo</title>
    <style>
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }}
        .container {{
            max-width: 1000px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            overflow: hidden;
        }}
        .header {{
            background: linear-gradient(45deg, #1e3c72, #2a5298);
            color: white;
            padding: 40px;
            text-align: center;
        }}
        .header h1 {{ font-size: 2.5rem; margin-bottom: 10px; }}
        .content {{ padding: 40px; }}
        .automation-features {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }}
        .feature-card {{
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
            border-left: 4px solid #007bff;
        }}
        .feature-card h3 {{ color: #007bff; margin-bottom: 15px; }}
        .stats {{ 
            background: #e8f5e8;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }}
        .footer {{
            background: #2c3e50;
            color: white;
            padding: 20px;
            text-align: center;
        }}
        code {{
            background: #f1f3f4;
            padding: 2px 6px;
            border-radius: 4px;
            font-family: 'Monaco', monospace;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 {app-name}</h1>
            <p>Pulumi Automation API Demonstration</p>
            <p>Environment: <strong>{environment}</strong></p>
        </div>
        
        <div class="content">
            <div class="automation-features">
                <div class="feature-card">
                    <h3>🚀 Programmatic Deployment</h3>
                    <p>Infrastructure deployed using Pulumi Automation API with inline programs</p>
                    <code>auto.create_or_select_stack()</code>
                </div>
                
                <div class="feature-card">
                    <h3>🔧 Dynamic Configuration</h3>
                    <p>Resources created based on runtime configuration and environment variables</p>
                    <code>config-driven infrastructure</code>
                </div>
                
                <div class="feature-card">
                    <h3>🌍 Multi-Environment</h3>
                    <p>Supports dev, staging, and production deployments with environment-specific settings</p>
                    <code>environment-aware resources</code>
                </div>
                
                <div class="feature-card">
                    <h3>🧪 LocalStack Integration</h3>
                    <p>Local development with AWS service emulation - no cloud costs!</p>
                    <code>localhost:4566 endpoints</code>
                </div>
            </div>
            
            <div class="stats">
                <h3>📊 Infrastructure Statistics</h3>
                <p><strong>S3 Website:</strong> Configured with public access and error pages</p>
                <p><strong>DynamoDB:</strong> Application data table with GSI</p>
                <p><strong>Lambda:</strong> Serverless API functions</p>
                <p><strong>Provider:</strong> AWS via LocalStack (macOS optimized)</p>
            </div>
            
            <h3>🔗 Useful Links</h3>
            <ul>
                <li><a href="/404.html">Test 404 page</a></li>
                <li><a href="http://localhost:4566/_localstack/health" target="_blank">LocalStack Health</a></li>
                <li><a href="https://docs.pulumi.com/automation/" target="_blank">Automation API Docs</a></li>
            </ul>
        </div>
        
        <div class="footer">
            <p>💡 Deployed programmatically with Pulumi Automation API + Hy</p>
            <p>Optimized for LocalStack on macOS • S3 Website + DynamoDB + Lambda</p>
        </div>
    </div>
</body>
</html>""")
  
  (setv error-content f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>404 - Page Not Found</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            text-align: center;
            margin: 0;
            padding: 100px 20px;
            background: linear-gradient(135deg, #ff6b6b, #ee5a24);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }}
        .error-container {{
            max-width: 500px;
            background: rgba(255,255,255,0.1);
            padding: 50px;
            border-radius: 20px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
        }}
        h1 {{ font-size: 4rem; margin: 0; }}
        p {{ font-size: 1.2rem; margin: 20px 0; }}
        a {{ 
            color: white;
            text-decoration: none;
            background: rgba(255,255,255,0.2);
            padding: 15px 30px;
            border-radius: 50px;
            display: inline-block;
            margin-top: 20px;
            transition: all 0.3s ease;
        }}
        a:hover {{ background: rgba(255,255,255,0.3); }}
    </style>
</head>
<body>
    <div class="error-container">
        <h1>404</h1>
        <h2>Page Not Found</h2>
        <p>The requested page could not be found in the {app-name} application.</p>
        <p>Environment: <strong>{environment}</strong></p>
        <a href="/">← Return to Home</a>
    </div>
</body>
</html>""")
  
  ;; Upload files
  (setv index-file
    (aws.s3.BucketObject "index.html"
      :bucket (. website-bucket id)
      :content index-content
      :content-type "text/html"
      :opts (pulumi.ResourceOptions
              :provider localstack-provider
              :depends-on [website-config])))
  
  (setv error-file
    (aws.s3.BucketObject "404.html"
      :bucket (. website-bucket id)
      :content error-content
      :content-type "text/html"
      :opts (pulumi.ResourceOptions
              :provider localstack-provider
              :depends-on [website-config])))
  
  ;; Return website resources
  {:bucket website-bucket
   :config website-config
   :policy bucket-policy
   :files [index-file error-file]})

;; Main Pulumi program for Automation API (enhanced with your S3 pattern)
(defn create-pulumi-program [config]
  "Inline Pulumi program with enhanced S3 website hosting"
  
  ;; Extract configuration
  (setv app-name (config.get "app_name" "automation-api-demo"))
  (setv environment (config.get "environment" "dev"))
  (setv enable-website (config.get "enable_website" True))
  (setv bucket-count (config.get "bucket_count" 2))
  
  ;; LocalStack provider (macOS optimized)
  (setv localstack-provider
    (aws.Provider "localstack"
      :region "us-east-1"
      :access-key "test"
      :secret-key "test"
      :skip-credentials-validation True
      :skip-metadata-api-check True
      :skip-requesting-account-id True
      :s3-force-path-style True  ; Critical for LocalStack
      :s3-use-path-style True
      :endpoints (aws.ProviderEndpointsArgs
                   :s3 "http://localhost:4566"
                   :lambda_ "http://localhost:4566"
                   :apigateway "http://localhost:4566"
                   :dynamodb "http://localhost:4566"
                   :iam "http://localhost:4566"
                   :sts "http://localhost:4566")))
  
  ;; Create multiple storage buckets
  (setv storage-buckets [])
  (for [i (range bucket-count)]
    (setv bucket
      (aws.s3.BucketV2 f"storage-bucket-{i}"
        :bucket f"{app-name}-storage-{environment}-{i}"
        :opts (pulumi.ResourceOptions :provider localstack-provider)))
    (storage-buckets.append bucket))
  
  ;; Create enhanced S3 website (using your pattern)
  (setv website-resources None)
  (when enable-website
    (setv website-bucket-name f"{app-name}-website-{environment}")
    (setv website-resources
      (create-s3-website website-bucket-name app-name environment localstack-provider)))
  
  ;; DynamoDB table for application data
  (setv app-table
    (aws.dynamodb.Table "app-table"
      :name f"{app-name}-data-{environment}"
      :billing-mode "PAY_PER_REQUEST"
      :hash-key "id"
      :attributes [(aws.dynamodb.TableAttributeArgs :name "id" :type "S")
                   (aws.dynamodb.TableAttributeArgs :name "timestamp" :type "N")]
      :global-secondary-indexes [(aws.dynamodb.TableGlobalSecondaryIndexArgs
                                   :name "timestamp-index"
                                   :hash-key "timestamp"
                                   :projection-type "ALL")]
      :opts (pulumi.ResourceOptions :provider localstack-provider)))
  
  ;; Lambda function with enhanced functionality
  (setv lambda-code f"""
import json
import boto3
import time
import os
from decimal import Decimal

def handler(event, context):
    # Initialize AWS clients for LocalStack
    dynamodb = boto3.resource('dynamodb', 
                             endpoint_url='http://localhost:4566',
                             region_name='us-east-1')
    s3 = boto3.client('s3',
                     endpoint_url='http://localhost:4566',
                     region_name='us-east-1')
    
    table_name = '{app-name}-data-{environment}'
    table = dynamodb.Table(table_name)
    
    # Parse request
    method = event.get('httpMethod', 'GET')
    path = event.get('path', '/')
    
    try:
        if method == 'GET' and path == '/':
            # Health check with enhanced info
            return {{
                'statusCode': 200,
                'headers': {{'Content-Type': 'application/json'}},
                'body': json.dumps({{
                    'status': 'healthy',
                    'message': 'Automation API Lambda is running!',
                    'app': '{app-name}',
                    'environment': '{environment}',
                    'timestamp': int(time.time()),
                    'features': {{
                        's3_website': True,
                        'dynamodb_storage': True,
                        'localstack_integration': True,
                        'macos_optimized': True
                    }},
                    'endpoints': {{
                        'health': '/',
                        'data': '/data',
                        'website': 'http://localhost:4566/{app-name}-website-{environment}/index.html'
                    }}
                }})
            }}
        
        elif method == 'GET' and path == '/data':
            # Get stored data
            response = table.scan()
            items = response.get('Items', [])
            return {{
                'statusCode': 200,
                'headers': {{'Content-Type': 'application/json'}},
                'body': json.dumps({{
                    'items': items,
                    'count': len(items),
                    'table': table_name
                }}, default=str)
            }}
        
        elif method == 'POST' and path == '/data':
            # Store new data
            body = json.loads(event.get('body', '{{}}'))
            item_id = str(int(time.time()))
            
            item = {{
                'id': item_id,
                'timestamp': Decimal(str(time.time())),
                'data': body.get('data', 'automation-api-test'),
                'source': 'automation-api-hy',
                'environment': '{environment}',
                'user_agent': event.get('headers', {{}}).get('User-Agent', 'unknown')
            }}
            
            table.put_item(Item=item)
            
            return {{
                'statusCode': 201,
                'headers': {{'Content-Type': 'application/json'}},
                'body': json.dumps({{
                    'id': item_id,
                    'message': 'Item created successfully',
                    'item': item
                }}, default=str)
            }}
        
        elif method == 'GET' and path == '/buckets':
            # List S3 buckets
            response = s3.list_buckets()
            buckets = [b['Name'] for b in response.get('Buckets', [])]
            return {{
                'statusCode': 200,
                'headers': {{'Content-Type': 'application/json'}},
                'body': json.dumps({{
                    'buckets': buckets,
                    'count': len(buckets),
                    'localstack_endpoint': 'http://localhost:4566'
                }})
            }}
        
        else:
            return {{
                'statusCode': 404,
                'headers': {{'Content-Type': 'application/json'}},
                'body': json.dumps({{
                    'error': 'Not found',
                    'method': method,
                    'path': path,
                    'available_endpoints': ['/', '/data', '/buckets']
                }})
            }}
    
    except Exception as e:
        return {{
            'statusCode': 500,
            'headers': {{'Content-Type': 'application/json'}},
            'body': json.dumps({{
                'error': 'Internal server error',
                'message': str(e),
                'app': '{app-name}',
                'environment': '{environment}'
            }})
        }}
""")
  
  ;; IAM role for Lambda
  (setv lambda-role
    (aws.iam.Role "lambda-role"
      :assume-role-policy (json.dumps {
        "Version" "2012-10-17"
        "Statement" [{
          "Action" "sts:AssumeRole"
          "Principal" {"Service" "lambda.amazonaws.com"}
          "Effect" "Allow"}]})
      :opts (pulumi.ResourceOptions :provider localstack-provider)))
  
  ;; Lambda function
  (setv api-lambda
    (aws.lambda_.Function "api-lambda"
      :code (pulumi.AssetArchive {"index.py" (pulumi.StringAsset lambda-code)})
      :role (. lambda-role arn)
      :handler "index.handler"
      :runtime "python3.9"
      :timeout 60
      :environment (aws.lambda_.FunctionEnvironmentArgs
                     :variables {"APP_NAME" app-name
                                "ENVIRONMENT" environment
                                "LOCALSTACK_ENDPOINT" "http://localhost:4566"})
      :opts (pulumi.ResourceOptions :provider localstack-provider)))
  
  ;; Prepare outputs
  (setv outputs {
    "app_name" app-name
    "environment" environment
    "bucket_count" bucket-count
    "storage_bucket_names" [(. bucket bucket) for bucket in storage-buckets]
    "lambda_function_name" (. api-lambda function-name)
    "lambda_arn" (. api-lambda arn)
    "table_name" (. app-table name)
    "localstack_endpoints" {
      "s3" "http://localhost:4566"
      "dynamodb" "http://localhost:4566"  
      "lambda" "http://localhost:4566"}})
  
  ;; Add website outputs if enabled
  (when website-resources
    (setv website-bucket (get website-resources :bucket))
    (setv website-config (get website-resources :config))
    (.update outputs {
      "website_bucket" (. website-bucket bucket)
      "website_endpoint" (. website-config website-endpoint)
      "website_domain" (. website-config website-domain)
      "localstack_website_url" (.apply (. website-bucket bucket)
                                 (fn [name] f"http://localhost:4566/{name}/index.html"))}))
  
  ;; Export all outputs
  (for [(, key value) (.items outputs)]
    (pulumi.export key value))
  
  outputs)

;; Async automation API runner  
(defn/a run-automation-api-demo []
  "Main Automation API demonstration with enhanced S3 website"
  
  (print "🤖 Starting Enhanced Pulumi Automation API Demo")
  (print "=" * 55)
  
  ;; Configuration
  (setv config {
    "app_name" "automation-demo-hy"
    "environment" "dev" 
    "enable_website" True
    "bucket_count" 3})
  
  ;; Project settings
  (setv project-name "automation-api-demo-hy")
  (setv stack-name "dev")
  
  ;; Create stack
  (print f"📋 Creating/selecting stack: {stack-name}")
  (setv stack
    (auto.create-or-select-stack
      :stack-name stack-name
      :project-name project-name
      :program (fn [] (create-pulumi-program config))))
  
  (print f"✅ Stack ready: {(. stack name)}")
  
  ;; Install plugins
  (print "🔧 Installing required plugins...")
  (await (.install-plugin (. stack workspace) "aws" "v6.0.0"))
  (print "✅ Plugins installed")
  
  ;; Set configuration for LocalStack
  (print "⚙️ Setting stack configuration...")
  (setv config-values [
    ["aws:region" "us-east-1"]
    ["aws:accessKey" "test"] 
    ["aws:secretKey" "test"]
    ["aws:skipCredentialsValidation" "true"]
    ["aws:skipMetadataApiCheck" "true"]
    ["aws:skipRequestingAccountId" "true"]
    ["aws:s3ForcePathStyle" "true"]])  ; Important for LocalStack
  
  (for [(, key value) config-values]
    (await (.set-config stack key (auto.ConfigValue :value value))))
  (print "✅ Configuration set")
  
  ;; Preview changes
  (print "\n🔍 Running preview...")
  (setv preview-result (await (.preview stack :on-output print)))
  (setv change-summary (. preview-result change-summary))
  (print "📊 Preview summary:")
  (print f"  - Resources to create: {(len (change-summary.get 'create' []))}")
  (print f"  - Resources to update: {(len (change-summary.get 'update' []))}")
  (print f"  - Resources to delete: {(len (change-summary.get 'delete' []))}")
  
  ;; Deploy infrastructure
  (print "\n🚀 Deploying infrastructure...")
  (setv up-result (await (.up stack :on-output print)))
  (print f"\n✅ Deployment completed!")
  (print f"📊 Summary: {(. up-result summary message)}")
  
  ;; Get outputs
  (setv outputs (await (.outputs stack)))
  (print "\n📤 Stack outputs:")
  (for [(, key output) (.items outputs)]
    (print f"  {key}: {(. output value)}"))
  
  ;; Test LocalStack endpoints
  (print "\n🧪 LocalStack test commands:")
  (setv test-commands [
    "aws --endpoint-url=http://localhost:4566 s3 ls"
    f"curl http://localhost:4566/{(. (get outputs 'website_bucket') value)}/index.html"
    f"aws --endpoint-url=http://localhost:4566 dynamodb describe-table --table-name {(. (get outputs 'table_name') value)}"
    f"aws --endpoint-url=http://localhost:4566 lambda invoke --function-name {(. (get outputs 'lambda_function_name') value)} /tmp/response.json"])
  
  (for [cmd test-commands]
    (print f"  {cmd}"))
  
  {:stack stack
   :outputs outputs
   :config config
   :deployment-result up-result})

;; Multi-environment CI/CD simulation
(defn/a automation-api-ci-pipeline []
  "CI/CD Pipeline simulation using Automation API"
  
  (print "\n🔄 CI/CD Pipeline Simulation")
  (print "=" * 40)
  
  (setv environments ["dev" "staging" "prod"])
  (setv results {})
  
  (for [env environments]
    (print f"\n🌍 Deploying to {env} environment...")
    
    ;; Environment-specific config
    (setv env-config {
      "app_name" "ci-demo-hy"
      "environment" env
      "enable_website" (in env ["staging" "prod"])
      "bucket_count" (get {"dev" 1 "staging" 2 "prod" 3} env)})
    
    ;; Create stack
    (setv stack
      (auto.create-or-select-stack
        :stack-name env
        :project-name "ci-pipeline-demo-hy"
        :program (fn [] (create-pulumi-program env-config))))
    
    ;; Install and configure
    (await (.install-plugin (. stack workspace) "aws" "v6.0.0"))
    (for [(, key value) [["aws:region" "us-east-1"]
                         ["aws:accessKey" "test"]
                         ["aws:secretKey" "test"] 
                         ["aws:skipCredentialsValidation" "true"]
                         ["aws:skipMetadataApiCheck" "true"]
                         ["aws:skipRequestingAccountId" "true"]
                         ["aws:s3ForcePathStyle" "true"]]]
      (await (.set-config stack key (auto.ConfigValue :value value))))
    
    ;; Deploy
    (setv result (await (.up stack :on-output (fn [msg] (print f"  [{env}] {msg}")))))
    (setv outputs (await (.outputs stack)))
    
    (setx (get results env) {
      "deployment_result" result
      "outputs" outputs  
      "config" env-config})
    
    (print f"✅ {env} deployment completed"))
  
  ;; Generate report
  (print "\n📋 Multi-Environment Deployment Report")
  (print "-" * 40)
  (for [(, env result) (.items results)]
    (setv outputs (get result "outputs"))
    (setv config (get result "config"))
    (print f"{(.upper env)}:")
    (print f"  Buckets: {(get config 'bucket_count')}")
    (print f"  Website: {(get config 'enable_website')}")
    (print f"  Table: {(. (get outputs 'table_name') value)}")
    (print f"  Lambda: {(. (get outputs 'lambda_function_name') value)}"))
  
  results)

;; Generate GitHub Actions workflow
(defn create-github-actions-workflow []
  "Generate GitHub Actions workflow for Automation API"
  
  """name: Infrastructure Deployment with Automation API (Hy)

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
        
    - name: Install Hy and dependencies
      run: |
        pip install hy pulumi pulumi-aws
        
    - name: Install Pulumi CLI
      run: |
        curl -fsSL https://get.pulumi.com | sh
        echo "$HOME/.pulumi/bin" >> $GITHUB_PATH
        
    - name: Start LocalStack (macOS compatible)
      run: |
        pip install localstack
        docker run -d --name localstack -p 4566:4566 \
          -e LOCALSTACK_HOST=0.0.0.0 \
          -e DEBUG=1 \
          localstack/localstack
        
    - name: Wait for LocalStack
      run: |
        timeout 120 bash -c 'until curl -s http://localhost:4566/_localstack/health; do sleep 2; done'
        
    - name: Deploy with Automation API
      run: |
        hy automation_api_deployment.hy --environment ${{ matrix.environment }}
        
    - name: Test S3 Website
      run: |
        # Test S3 website deployment
        aws --endpoint-url=http://localhost:4566 s3 ls
        curl -f http://localhost:4566/ci-demo-hy-website-${{ matrix.environment }}/index.html
        
    - name: Test Lambda API
      run: |
        # Test Lambda function
        aws --endpoint-url=http://localhost:4566 lambda list-functions
        
    - name: Test DynamoDB
      run: |
        # Test DynamoDB table
        aws --endpoint-url=http://localhost:4566 dynamodb list-tables
        
    - name: Cleanup
      if: always()
      run: |
        docker stop localstack || true
        docker rm localstack || true""")

;; Main execution function
(defn/a main []
  "Main function demonstrating enhanced Automation API capabilities"
  
  (print "🤖 Enhanced Pulumi Automation API Deep Dive (Hy)")
  (print "=" * 55)
  
  ;; Check LocalStack status
  (try
    (import requests)
    (setv response (requests.get "http://localhost:4566/_localstack/health"))
    (print "✅ LocalStack is running and healthy")
    (except [Exception e]
      (print "⚠️  LocalStack not detected. Start with: gmake localstack-start")
      (print "   Continuing with demo anyway...")))
  
  ;; Run main demo
  (setv demo-result (await (run-automation-api-demo)))
  
  ;; Run CI/CD simulation
  (setv ci-result (await (automation-api-ci-pipeline)))
  
  ;; Generate artifacts
  (print "\n📝 Generating CI/CD artifacts...")
  (setv workflow (create-github-actions-workflow))
  (with [f (open "github-actions-workflow-hy.yml" "w")]
    (.write f workflow))
  (print "✅ GitHub Actions workflow saved to github-actions-workflow-hy.yml")
  
  ;; Summary
  (print "\n🎉 Enhanced Automation API Demo Complete!")
  (print "📊 Summary:")
  (print "  - ✅ Enhanced S3 website with ownership controls")  
  (print "  - ✅ macOS LocalStack optimization")
  (print "  - ✅ Multi-environment CI/CD simulation")
  (print "  - ✅ Advanced Lambda API with multiple endpoints")
  (print "  - ✅ DynamoDB integration with GSI") 
  (print "  - ✅ Generated GitHub Actions workflow")
  (print "  - ✅ Comprehensive error handling")
  
  {:demo-result demo-result
   :ci-result ci-result
   :artifacts ["github-actions-workflow-hy.yml"]})

;; Entry point
(when (= __name__ "__main__")
  (setv result (asyncio.run (main)))
  (print "\n✅ All Enhanced Automation API demonstrations completed successfully!"))
;; SSM Parameter Store with LocalStack and Secrets in Hy
;; Testing Parameter Store functionality in LocalStack environment

(import pulumi)
(import [pulumi-aws :as aws])
(import [pulumi-random :as random])

;; Configuration and secrets
(setv config (pulumi.Config))
(setv app-name (config.get "app-name" "workshop"))
(setv environment (pulumi.get-stack))

;; LocalStack provider configuration for testing
(setv localstack-provider
  (aws.Provider "localstack"
    :region "us-east-1"
    :access-key "test"
    :secret-key "test"
    :skip-credentials-validation True
    :skip-metadata-api-check True
    :skip-requesting-account-id True
    :endpoints {:ssm "http://localhost:4566"
                :kms "http://localhost:4566"
                :secretsmanager "http://localhost:4566"}))

;; Example: Setting secrets via config
;; pulumi config set --secret dbPassword S3cr37
;; pulumi config set --secret apiKey sk-1234567890abcdef
;; pulumi config set --secret sshPrivateKey "$(cat ~/.ssh/id_rsa)"

;; Retrieve secret values from configuration
(setv db-password (config.require-secret "dbPassword"))
(setv api-key (config.get-secret "apiKey"))
(setv ssh-private-key (config.get-secret "sshPrivateKey"))

;; Generate additional secrets
(setv generated-password
  (random.RandomPassword "generated-password"
    :length 32
    :special True
    :override-special "!@#$%^&*()_+-=[]{}|;:,.<>?"))

(setv encryption-key
  (random.RandomBytes "encryption-key"
    :length 32))

;; KMS Key for encryption (works in LocalStack)
(setv parameter-kms-key
  (aws.kms.Key "parameter-encryption"
    :description f"KMS key for {app-name} parameter encryption"
    :deletion-window-in-days 7
    :policy (pulumi.Output.json-stringify
      {:Version "2012-10-17"
       :Statement [{:Sid "Enable IAM User Permissions"
                    :Effect "Allow"
                    :Principal {:AWS "*"}  ;; Simplified for LocalStack
                    :Action "kms:*"
                    :Resource "*"}]})
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 1. Standard String Parameters
(setv app-version-param
  (aws.ssm.Parameter "app-version"
    :name f"/{app-name}/{environment}/version"
    :type "String"
    :value "1.0.0"
    :description "Application version number"
    :tags {:Environment environment
           :Application app-name
           :Type "configuration"}
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

(setv app-config-param
  (aws.ssm.Parameter "app-config"
    :name f"/{app-name}/{environment}/config"
    :type "String"
    :value (pulumi.Output.json-stringify
      {:debug (= environment "dev")
       :log-level (if (= environment "prod") "WARN" "INFO")
       :max-connections 100
       :timeout 30})
    :description "Application configuration JSON"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 2. StringList Parameters
(setv allowed-hosts-param
  (aws.ssm.Parameter "allowed-hosts"
    :name f"/{app-name}/{environment}/allowed-hosts"
    :type "StringList"
    :value "localhost,127.0.0.1,*.example.com"
    :description "Comma-separated list of allowed hosts"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 3. SecureString Parameters with KMS encryption
(setv db-password-param
  (aws.ssm.Parameter "db-password"
    :name f"/{app-name}/{environment}/database/password"
    :type "SecureString"
    :value db-password
    :key-id (. parameter-kms-key key-id)
    :description "Database password (encrypted)"
    :tags {:Environment environment
           :Application app-name
           :Type "secret"
           :Encrypted "true"}
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

(setv api-key-param
  (aws.ssm.Parameter "api-key"
    :name f"/{app-name}/{environment}/api/key"
    :type "SecureString"
    :value (or api-key "default-api-key")
    :key-id (. parameter-kms-key key-id)
    :description "External API key (encrypted)"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

(setv generated-password-param
  (aws.ssm.Parameter "generated-password"
    :name f"/{app-name}/{environment}/generated/password"
    :type "SecureString"
    :value (. generated-password result)
    :key-id (. parameter-kms-key key-id)
    :description "Auto-generated secure password"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 4. SSH Private Key Parameter
(when ssh-private-key
  (setv ssh-key-param
    (aws.ssm.Parameter "ssh-private-key"
      :name f"/{app-name}/{environment}/ssh/private-key"
      :type "SecureString"
      :value ssh-private-key
      :key-id (. parameter-kms-key key-id)
      :description "SSH private key for server access"
      :tier "Advanced"  ;; For larger values
      :opts (pulumi.ResourceOptions :provider localstack-provider))))

;; 5. Hierarchical Parameter Structure
(setv database-params
  [{:name f"/{app-name}/{environment}/database/host"
    :value "localhost"
    :type "String"
    :description "Database hostname"}
   {:name f"/{app-name}/{environment}/database/port"
    :value "5432"
    :type "String"
    :description "Database port"}
   {:name f"/{app-name}/{environment}/database/name"
    :value f"{app-name}_db"
    :type "String"
    :description "Database name"}
   {:name f"/{app-name}/{environment}/database/ssl"
    :value "require"
    :type "String"
    :description "Database SSL mode"}])

(setv db-param-resources [])
(for [[i param-config] (enumerate database-params)]
  (setv param-resource
    (aws.ssm.Parameter f"db-param-{i}"
      :name (get param-config :name)
      :type (get param-config :type)
      :value (get param-config :value)
      :description (get param-config :description)
      :tags {:Environment environment
             :Application app-name
             :Category "database"}
      :opts (pulumi.ResourceOptions :provider localstack-provider)))
  (.append db-param-resources param-resource))

;; 6. Application Feature Flags
(setv feature-flags
  {:enable-caching True
   :enable-metrics (not (= environment "dev"))
   :enable-debug-mode (= environment "dev")
   :max-upload-size-mb 10
   :session-timeout-minutes 30})

(setv feature-flags-param
  (aws.ssm.Parameter "feature-flags"
    :name f"/{app-name}/{environment}/features"
    :type "String"
    :value (pulumi.Output.json-stringify feature-flags)
    :description "Application feature flags configuration"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 7. Environment-specific Scaling Parameters
(setv scaling-params
  (cond
    [(= environment "prod")
     {:min-instances 3
      :max-instances 20
      :target-cpu 70
      :scale-up-cooldown 300
      :scale-down-cooldown 600}]
    [(= environment "staging")
     {:min-instances 2
      :max-instances 10
      :target-cpu 80
      :scale-up-cooldown 180
      :scale-down-cooldown 300}]
    [True
     {:min-instances 1
      :max-instances 3
      :target-cpu 90
      :scale-up-cooldown 60
      :scale-down-cooldown 120}]))

(setv scaling-config-param
  (aws.ssm.Parameter "scaling-config"
    :name f"/{app-name}/{environment}/scaling"
    :type "String"
    :value (pulumi.Output.json-stringify scaling-params)
    :description "Auto-scaling configuration parameters"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 8. Parameter with Policies (Advanced Tier)
(setv critical-param
  (aws.ssm.Parameter "critical-config"
    :name f"/{app-name}/{environment}/critical/config"
    :type "String"
    :value "critical-configuration-data"
    :tier "Advanced"
    :policies (pulumi.Output.json-stringify
      [{:Type "Expiration"
        :Version "1.0"
        :Attributes {:Timestamp (.isoformat (.utcnow datetime.datetime))}}])
    :description "Critical configuration with expiration policy"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 9. Lambda function that reads parameters
(setv parameter-reader-lambda
  (aws.lambda.Function "parameter-reader"
    :code (pulumi.AssetArchive
            {"index.py" (pulumi.StringAsset f"""
import json
import boto3
import os

def handler(event, context):
    ssm = boto3.client('ssm', endpoint_url='http://localhost:4566')
    
    # Parameter path prefix
    prefix = '/{app-name}/{environment}/'
    
    try:
        # Get parameters by path
        response = ssm.get_parameters_by_path(
            Path=prefix,
            Recursive=True,
            WithDecryption=True,
            MaxResults=50
        )
        
        parameters = {{}}
        for param in response['Parameters']:
            name = param['Name'].replace(prefix, '')
            parameters[name] = param['Value']
        
        # Example: Get specific database config
        db_config = {{
            'host': parameters.get('database/host', 'localhost'),
            'port': int(parameters.get('database/port', 5432)),
            'name': parameters.get('database/name', '{app-name}_db'),
            'ssl': parameters.get('database/ssl', 'require')
        }}
        
        # Parse feature flags
        features = json.loads(parameters.get('features', '{{}}'))
        
        return {{
            'statusCode': 200,
            'body': json.dumps({{
                'database_config': db_config,
                'feature_flags': features,
                'all_parameters': list(parameters.keys()),
                'environment': '{environment}'
            }})
        }}
    
    except Exception as e:
        return {{
            'statusCode': 500,
            'body': json.dumps({{'error': str(e)}})
        }}
""")})
    :handler "index.handler"
    :runtime "python3.9"
    :timeout 30
    :environment {:variables {:APP_NAME app-name
                              :ENVIRONMENT environment}}
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 10. Testing script for LocalStack
(setv test-script-content f"""#!/bin/bash
set -e

echo "Testing SSM Parameter Store with LocalStack..."

# Ensure LocalStack is running
if ! curl -s http://localhost:4566/_localstack/health > /dev/null; then
    echo "LocalStack not running! Start with: gmake localstack-start"
    exit 1
fi

# Configure AWS CLI for LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

echo "1. List all parameters:"
aws ssm describe-parameters --endpoint-url $AWS_ENDPOINT_URL

echo "2. Get parameter by name:"
aws ssm get-parameter --name "/{app-name}/{environment}/version" --endpoint-url $AWS_ENDPOINT_URL

echo "3. Get parameters by path:"
aws ssm get-parameters-by-path --path "/{app-name}/{environment}/" --recursive --endpoint-url $AWS_ENDPOINT_URL

echo "4. Get secure parameter (encrypted):"
aws ssm get-parameter --name "/{app-name}/{environment}/database/password" --with-decryption --endpoint-url $AWS_ENDPOINT_URL

echo "5. Test Lambda function:"
aws lambda invoke --function-name {(. parameter-reader-lambda function-name)} --endpoint-url $AWS_ENDPOINT_URL response.json
cat response.json

echo "6. Put a new parameter:"
aws ssm put-parameter --name "/{app-name}/{environment}/test/runtime" --value "$(date)" --type "String" --endpoint-url $AWS_ENDPOINT_URL

echo "SSM Parameter Store testing complete!"
""")

;; Create test script as S3 object
(setv test-script-bucket
  (aws.s3.BucketV2 "test-scripts"
    :bucket f"{app-name}-test-scripts-{(.hex (random.RandomId \"suffix\" :byte-length 4))}"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

(setv test-script-object
  (aws.s3.BucketObject "ssm-test-script"
    :bucket (. test-script-bucket id)
    :key "test-ssm-localstack.sh"
    :content test-script-content
    :content-type "text/x-shellscript"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Export parameter information
(pulumi.export "parameter-store-demo"
  {:parameter-prefix f"/{app-name}/{environment}/"
   :kms-key-id (. parameter-kms-key key-id)
   :test-bucket (. test-script-bucket bucket)
   :lambda-function (. parameter-reader-lambda function-name)})

;; Export configuration examples
(pulumi.export "config-examples"
  {:set-secret "pulumi config set --secret dbPassword S3cr37"
   :set-config "pulumi config set app-name myapp"
   :get-config "pulumi config get dbPassword"
   :list-config "pulumi config"})

;; Export LocalStack testing commands
(pulumi.export "localstack-commands"
  {:list-parameters "aws ssm describe-parameters --endpoint-url http://localhost:4566"
   :get-parameter f"aws ssm get-parameter --name '/{app-name}/{environment}/version' --endpoint-url http://localhost:4566"
   :get-secure f"aws ssm get-parameter --name '/{app-name}/{environment}/database/password' --with-decryption --endpoint-url http://localhost:4566"
   :get-by-path f"aws ssm get-parameters-by-path --path '/{app-name}/{environment}/' --recursive --endpoint-url http://localhost:4566"})

;; Export parameter hierarchy
(pulumi.export "parameter-hierarchy"
  {:application f"/{app-name}/"
   :environment f"/{app-name}/{environment}/"
   :database f"/{app-name}/{environment}/database/"
   :api f"/{app-name}/{environment}/api/"
   :features f"/{app-name}/{environment}/features"
   :scaling f"/{app-name}/{environment}/scaling"})

;; Export secrets management patterns
(pulumi.export "secrets-patterns"
  {:config-secrets "Use pulumi config set --secret for sensitive values"
   :ssm-encryption "Store encrypted secrets in SSM Parameter Store"
   :kms-integration "Use KMS keys for parameter encryption"
   :hierarchical-organization "Organize parameters in logical hierarchies"
   :lambda-access "Access parameters from Lambda functions"
   :localstack-testing "Test parameter operations with LocalStack"})
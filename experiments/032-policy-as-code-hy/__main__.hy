;; Policy as Code Infrastructure Examples in Hy
;; Resources designed to trigger policy violations for demonstration

(import pulumi)
(import [pulumi-aws :as aws])
(import json)

;; Configuration for policy testing
(setv config (pulumi.Config))
(setv app-name (config.get "app-name" "policy-demo"))
(setv enforce-https (config.get-bool "enforce-https"))
(setv max-bucket-count (config.get-int "max-bucket-count" 5))
(setv environment (pulumi.get-stack))

;; LocalStack provider for testing
(setv localstack-provider
  (aws.Provider "localstack"
    :region "us-east-1"
    :access-key "test"
    :secret-key "test"
    :skip-credentials-validation True
    :skip-metadata-api-check True
    :skip-requesting-account-id True
    :s3-force-path-style True
    :endpoints (aws.ProviderEndpointsArgs
                 :s3 "http://localhost:4566"
                 :iam "http://localhost:4566"
                 :lambda_ "http://localhost:4566"
                 :apigateway "http://localhost:4566")))

;; 1. S3 Resources (will trigger various policy violations)

;; Non-compliant bucket (public read)
(setv public-bucket
  (aws.s3.BucketV2 "public-bucket"
    :bucket f"{app-name}-public-{environment}"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

(setv public-access-block-disabled
  (aws.s3.BucketPublicAccessBlock "public-access-disabled"
    :bucket (. public-bucket id)
    :block-public-acls False  ; Policy violation: should be True
    :block-public-policy False  ; Policy violation: should be True
    :ignore-public-acls False
    :restrict-public-buckets False
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Compliant bucket (private)
(setv private-bucket
  (aws.s3.BucketV2 "private-bucket"
    :bucket f"{app-name}-private-{environment}"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

(setv private-access-block
  (aws.s3.BucketPublicAccessBlock "private-access"
    :bucket (. private-bucket id)
    :block-public-acls True
    :block-public-policy True
    :ignore-public-acls True
    :restrict-public-buckets True
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Bucket with versioning disabled (policy violation)
(setv unversioned-bucket
  (aws.s3.BucketV2 "unversioned-bucket"
    :bucket f"{app-name}-unversioned-{environment}"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Compliant bucket with versioning enabled
(setv versioned-bucket
  (aws.s3.BucketV2 "versioned-bucket"
    :bucket f"{app-name}-versioned-{environment}"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

(setv bucket-versioning
  (aws.s3.BucketVersioningV2 "bucket-versioning"
    :bucket (. versioned-bucket id)
    :versioning-configuration (aws.s3.BucketVersioningV2VersioningConfigurationArgs
                                :status "Enabled")
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 2. IAM Resources (potential security violations)

;; Overly permissive IAM policy (violation)
(setv admin-policy-doc
  (json.dumps {
    "Version" "2012-10-17"
    "Statement" [{
      "Effect" "Allow"
      "Action" "*"  ; Policy violation: too broad
      "Resource" "*"}]}))

(setv admin-policy
  (aws.iam.Policy "admin-policy"
    :name f"{app-name}-admin-policy"
    :policy admin-policy-doc
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Compliant least-privilege policy
(setv restricted-policy-doc
  (json.dumps {
    "Version" "2012-10-17"
    "Statement" [{
      "Effect" "Allow"
      "Action" [
        "s3:GetObject"
        "s3:PutObject"]
      "Resource" f"arn:aws:s3:::{app-name}-restricted/*"}]}))

(setv restricted-policy
  (aws.iam.Policy "restricted-policy"
    :name f"{app-name}-restricted-policy"
    :policy restricted-policy-doc
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; IAM role with inline policy (violation: should use managed policies)
(setv inline-policy-role
  (aws.iam.Role "inline-policy-role"
    :name f"{app-name}-inline-role"
    :assume-role-policy (json.dumps {
      "Version" "2012-10-17"
      "Statement" [{
        "Action" "sts:AssumeRole"
        "Principal" {"Service" "lambda.amazonaws.com"}
        "Effect" "Allow"}]})
    :inline-policies [{
      :name "InlinePolicy"
      :policy admin-policy-doc}]  ; Policy violation: inline policy with broad permissions
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 3. Lambda Resources (security and configuration violations)

;; Lambda with environment secrets (violation)
(setv insecure-lambda
  (aws.lambda_.Function "insecure-lambda"
    :name f"{app-name}-insecure-lambda"
    :code (pulumi.AssetArchive {
      "index.py" (pulumi.StringAsset """
def handler(event, context):
    import os
    return {
        'statusCode': 200,
        'body': f'Hello from {os.environ.get("SECRET_KEY", "undefined")}'
    }
""")})
    :handler "index.handler"
    :runtime "python3.9"
    :role (. inline-policy-role arn)
    :timeout 900  ; Policy violation: too high timeout
    :environment (aws.lambda_.FunctionEnvironmentArgs
                   :variables {
                     "SECRET_KEY" "hardcoded-secret-123"  ; Policy violation: hardcoded secret
                     "API_KEY" "sk-1234567890abcdef"})
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Compliant Lambda function
(setv secure-lambda
  (aws.lambda_.Function "secure-lambda"
    :name f"{app-name}-secure-lambda"
    :code (pulumi.AssetArchive {
      "index.py" (pulumi.StringAsset """
def handler(event, context):
    import json
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Secure Lambda function',
            'environment': 'production-ready'
        })
    }
""")})
    :handler "index.handler"
    :runtime "python3.9"
    :role (. restricted-policy arn)
    :timeout 30  ; Reasonable timeout
    ; No hardcoded secrets in environment
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 4. Load Balancer Resources (HTTPS violations)

;; HTTP-only ALB listener (policy violation)
(setv alb
  (aws.lb.LoadBalancer "demo-alb"
    :name f"{app-name}-alb"
    :load-balancer-type "application"
    :scheme "internet-facing"
    :subnets ["subnet-12345" "subnet-67890"]  ; Mock subnet IDs for demo
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

(setv target-group
  (aws.lb.TargetGroup "demo-target-group"
    :name f"{app-name}-tg"
    :port 80
    :protocol "HTTP"
    :vpc-id "vpc-12345"  ; Mock VPC ID
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

(setv http-listener
  (aws.lb.Listener "http-listener"
    :load-balancer-arn (. alb arn)
    :port 80
    :protocol "HTTP"  ; Policy violation: should be HTTPS
    :default-actions [(aws.lb.ListenerDefaultActionArgs
                        :type "forward"
                        :target-group-arn (. target-group arn))]
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 5. Security Group (overly permissive rules)

(setv permissive-sg
  (aws.ec2.SecurityGroup "permissive-sg"
    :name f"{app-name}-permissive-sg"
    :description "Overly permissive security group"
    :vpc-id "vpc-12345"
    :ingress-rules [(aws.ec2.SecurityGroupIngressRuleArgs
                      :from-port 0
                      :to-port 65535  ; Policy violation: too broad port range
                      :ip-protocol "tcp"
                      :cidr-ipv4 "0.0.0.0/0")]  ; Policy violation: open to internet
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Compliant security group
(setv restricted-sg
  (aws.ec2.SecurityGroup "restricted-sg"
    :name f"{app-name}-restricted-sg"
    :description "Properly configured security group"
    :vpc-id "vpc-12345"
    :ingress-rules [(aws.ec2.SecurityGroupIngressRuleArgs
                      :from-port 443
                      :to-port 443
                      :ip-protocol "tcp"
                      :cidr-ipv4 "10.0.0.0/8")]  ; Restricted to private networks
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; 6. RDS Instance (security violations)

(setv insecure-rds
  (aws.rds.Instance "insecure-rds"
    :identifier f"{app-name}-insecure-db"
    :engine "postgres"
    :engine-version "13.7"
    :instance-class "db.t3.micro"
    :allocated-storage 20
    :db-name "testdb"
    :username "admin"
    :password "password123"  ; Policy violation: hardcoded password
    :publicly-accessible True  ; Policy violation: should be private
    :skip-final-snapshot True
    :backup-retention-period 0  ; Policy violation: no backups
    :storage-encrypted False  ; Policy violation: unencrypted
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Export policy violation summary
(pulumi.export "policy-violations-found"
  {"s3-buckets" {
     "public-access-enabled" (. public-bucket bucket)
     "versioning-disabled" (. unversioned-bucket bucket)}
   "iam-policies" {
     "overly-permissive" (. admin-policy name)
     "inline-policy-usage" (. inline-policy-role name)}
   "lambda-functions" {
     "hardcoded-secrets" (. insecure-lambda function-name)
     "excessive-timeout" "900 seconds"}
   "load-balancers" {
     "http-only-listener" (. http-listener port)}
   "security-groups" {
     "overly-permissive-rules" (. permissive-sg name)}
   "databases" {
     "unencrypted-storage" (. insecure-rds identifier)
     "public-accessibility" True
     "hardcoded-password" True
     "no-backups" True}})

;; Export compliant resources for comparison
(pulumi.export "compliant-resources"
  {"s3-buckets" {
     "private-bucket" (. private-bucket bucket)
     "versioned-bucket" (. versioned-bucket bucket)}
   "iam-policies" {
     "least-privilege" (. restricted-policy name)}
   "lambda-functions" {
     "secure-configuration" (. secure-lambda function-name)}
   "security-groups" {
     "properly-restricted" (. restricted-sg name)}})

;; Export policy testing commands
(pulumi.export "policy-testing-commands"
  {"crossguard" [
     "pulumi preview --policy-pack ./policies"
     "pulumi up --policy-pack ./policies"
     "pulumi policy ls"
     "pulumi policy enable <org>/<policy-pack>"]
   "snyk" [
     "snyk iac test . --policy-path=./snyk-policies" 
     "snyk iac test . --severity-threshold=medium"
     "snyk iac describe . --all-projects"
     "snyk monitor --file=Pulumi.yaml"]
   "local-testing" [
     "python -m policies.policy_tests"
     "pytest policies/test_*.py -v"
     "pulumi policy validate ./policies"]})
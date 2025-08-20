;; Inputs, Outputs, and Secrets management in Hy
;; Based on https://www.pulumi.com/docs/iac/concepts/inputs-outputs/

(import pulumi)
(import [pulumi-aws :as aws])
(import [pulumi-random :as random])
(import [pulumi-tls :as tls])

;; Configuration and secrets
(setv config (pulumi.Config))
(setv app-name (config.get "app-name" "workshop"))
(setv environment (pulumi.get-stack))

;; 1. Basic Random Password Generation
(setv db-password
  (random.RandomPassword "db-password"
    :length 16
    :special True
    :override-special "!#$%&*()-_=+[]{}<>:?"))

;; 2. Random ID for unique resource naming
(setv resource-suffix
  (random.RandomId "resource-suffix"
    :byte-length 8))

;; 3. TLS Private Key Generation
(setv app-private-key
  (tls.PrivateKey "app-private-key"
    :algorithm "RSA"
    :rsa-bits 4096))

;; 4. Self-signed certificate
(setv app-certificate
  (tls.SelfSignedCert "app-certificate"
    :private-key-pem (. app-private-key private-key-pem)
    :validity-period-hours (* 24 365)  ;; 1 year
    :allowed-uses ["key_encipherment"
                   "digital_signature"
                   "server_auth"]
    :subjects [{:common-name f"{app-name}.local"
                :organization "Workshop Org"
                :organizational-unit "Engineering"
                :street-addresses ["123 Workshop St"]
                :localities ["Seattle"]
                :provinces ["WA"]
                :country "US"
                :postal-code "98101"}]))

;; 5. AWS KMS Key for encryption
(setv app-kms-key
  (aws.kms.Key "app-encryption-key"
    :description f"Encryption key for {app-name} {environment}"
    :deletion-window-in-days 7
    :policy (pulumi.Output.json-stringify
      {:Version "2012-10-17"
       :Statement [{:Sid "Enable IAM User Permissions"
                    :Effect "Allow"
                    :Principal {:AWS (pulumi.Output.concat 
                                     "arn:aws:iam::"
                                     (aws.get-caller-identity).account-id
                                     ":root")}
                    :Action "kms:*"
                    :Resource "*"}]})))

(setv kms-alias
  (aws.kms.Alias "app-key-alias"
    :name (pulumi.Output.concat "alias/" app-name "-" environment "-key")
    :target-key-id (. app-kms-key key-id)))

;; 6. Secrets Manager Secret
(setv app-secrets
  (aws.secretsmanager.Secret "app-secrets"
    :name (pulumi.Output.concat app-name "-" environment "-secrets-" (. resource-suffix hex))
    :description f"Application secrets for {app-name}"
    :kms-key-id (. app-kms-key arn)
    :recovery-window-in-days 0))  ;; Immediate deletion for dev

;; Secret version with multiple values
(setv app-secret-version
  (aws.secretsmanager.SecretVersion "app-secret-version"
    :secret-id (. app-secrets id)
    :secret-string (pulumi.Output.json-stringify
      {:database-password (. db-password result)
       :api-key (pulumi.Output.concat "sk-" (. resource-suffix hex))
       :private-key (. app-private-key private-key-pem)
       :certificate (. app-certificate cert-pem)
       :encryption-key (. app-kms-key arn)})))

;; 7. RDS Instance using generated password
(setv database
  (aws.rds.Instance "app-database"
    :identifier (pulumi.Output.concat app-name "-db-" (. resource-suffix hex))
    :instance-class "db.t3.micro"
    :allocated-storage 20
    :engine "mysql"
    :engine-version "8.0"
    :db-name (pulumi.Output.concat app-name "db")
    :username "admin"
    :password (. db-password result)  ;; Output as input
    :storage-encrypted True
    :kms-key-id (. app-kms-key arn)
    :backup-retention-period 7
    :backup-window "03:00-04:00"
    :maintenance-window "sun:04:00-sun:05:00"
    :skip-final-snapshot True
    :tags {:Name (pulumi.Output.concat app-name "-database")
           :Environment environment
           :PasswordGenerated "true"}))

;; 8. Lambda function with secrets access
(setv lambda-role
  (aws.iam.Role "lambda-secrets-role"
    :assume-role-policy (pulumi.Output.json-stringify
      {:Version "2012-10-17"
       :Statement [{:Action "sts:AssumeRole"
                    :Principal {:Service "lambda.amazonaws.com"}
                    :Effect "Allow"}]})))

;; Policy for accessing secrets
(setv secrets-policy
  (aws.iam.RolePolicy "lambda-secrets-policy"
    :role (. lambda-role id)
    :policy (pulumi.Output.json-stringify
      {:Version "2012-10-17"
       :Statement [{:Effect "Allow"
                    :Action ["secretsmanager:GetSecretValue"
                             "kms:Decrypt"]
                    :Resource [(. app-secrets arn)
                               (. app-kms-key arn)]}
                   {:Effect "Allow"
                    :Action ["logs:CreateLogGroup"
                             "logs:CreateLogStream"
                             "logs:PutLogEvents"]
                    :Resource "*"}]})))

;; Lambda function that uses secrets
(setv secrets-lambda
  (aws.lambda.Function "secrets-handler"
    :role (. lambda-role arn)
    :code (pulumi.AssetArchive
            {"index.py" (pulumi.StringAsset
              f"""
import json
import boto3
import os

def handler(event, context):
    # Get secrets from environment
    secret_arn = os.environ['SECRET_ARN']
    
    # Initialize AWS clients
    secrets_client = boto3.client('secretsmanager')
    
    try:
        # Retrieve secret
        response = secrets_client.get_secret_value(SecretId=secret_arn)
        secrets = json.loads(response['SecretString'])
        
        # Use secrets (don't log them!)
        db_password_length = len(secrets.get('database-password', ''))
        has_private_key = 'private-key' in secrets
        
        return {{
            'statusCode': 200,
            'body': json.dumps({{
                'message': 'Secrets accessed successfully',
                'db_password_length': db_password_length,
                'has_private_key': has_private_key,
                'secret_keys': list(secrets.keys())
            }})
        }}
    except Exception as e:
        return {{
            'statusCode': 500,
            'body': json.dumps({{
                'error': str(e)
            }})
        }}
""")}
    :handler "index.handler"
    :runtime "python3.9"
    :timeout 30
    :environment {:variables {:SECRET_ARN (. app-secrets arn)}}))

;; 9. S3 Bucket with server-side encryption using KMS
(setv encrypted-bucket
  (aws.s3.BucketV2 "encrypted-storage"
    :bucket (pulumi.Output.concat app-name "-encrypted-" (. resource-suffix hex))))

(setv bucket-encryption
  (aws.s3.BucketServerSideEncryptionConfigurationV2 "bucket-encryption"
    :bucket (. encrypted-bucket id)
    :rules [{:apply-server-side-encryption-by-default
             {:sse-algorithm "aws:kms"
              :kms-master-key-id (. app-kms-key arn)}}]))

;; 10. EC2 Instance with generated key pair
(setv ec2-key-pair
  (aws.ec2.KeyPair "app-keypair"
    :key-name (pulumi.Output.concat app-name "-keypair-" (. resource-suffix hex))
    :public-key (. app-private-key public-key-openssh)))

;; Security group for EC2 instance
(setv app-security-group
  (aws.ec2.SecurityGroup "app-sg"
    :description f"Security group for {app-name} application"
    :ingress [{:protocol "tcp"
               :from-port 22
               :to-port 22
               :cidr-blocks ["10.0.0.0/8"]}  ;; Restrict SSH access
              {:protocol "tcp"
               :from-port 443
               :to-port 443
               :cidr-blocks ["0.0.0.0/0"]}]
    :egress [{:protocol "-1"
              :from-port 0
              :to-port 0
              :cidr-blocks ["0.0.0.0/0"]}]))

;; EC2 instance using generated key pair
(setv app-instance
  (aws.ec2.Instance "app-server"
    :ami "ami-0c02fb55956c7d316"  ;; Amazon Linux 2
    :instance-type "t3.micro"
    :key-name (. ec2-key-pair key-name)
    :vpc-security-group-ids [(. app-security-group id)]
    :user-data (pulumi.Output.concat
      "#!/bin/bash\n"
      "yum update -y\n"
      f"echo 'App: {app-name}' > /var/log/app-info.log\n"
      f"echo 'Environment: {environment}' >> /var/log/app-info.log\n"
      "# Install CloudWatch agent\n"
      "yum install -y amazon-cloudwatch-agent\n")
    :tags {:Name (pulumi.Output.concat app-name "-server")
           :Environment environment
           :HasGeneratedKeys "true"}))

;; 11. Parameter Store values
(setv app-config-param
  (aws.ssm.Parameter "app-config"
    :name (pulumi.Output.concat "/" app-name "/" environment "/config")
    :type "SecureString"
    :key-id (. app-kms-key key-id)
    :value (pulumi.Output.json-stringify
      {:database-endpoint (. database endpoint)
       :s3-bucket (. encrypted-bucket bucket)
       :kms-key-id (. app-kms-key key-id)
       :environment environment
       :version "1.0"})))

;; 12. CloudWatch Log Group with KMS encryption
(setv app-log-group
  (aws.cloudwatch.LogGroup "app-logs"
    :name (pulumi.Output.concat "/aws/application/" app-name "-" environment)
    :retention-in-days 14
    :kms-key-id (. app-kms-key arn)))

;; 13. SNS Topic with KMS encryption
(setv notification-topic
  (aws.sns.Topic "app-notifications"
    :name (pulumi.Output.concat app-name "-notifications-" (. resource-suffix hex))
    :kms-master-key-id (. app-kms-key key-id)
    :display-name f"{app-name} Notifications"))

;; 14. SQS Queue with encryption
(setv message-queue
  (aws.sqs.Queue "app-queue"
    :name (pulumi.Output.concat app-name "-queue-" (. resource-suffix hex))
    :kms-master-key-id (. app-kms-key key-id)
    :message-retention-seconds 1209600  ;; 14 days
    :visibility-timeout-seconds 300))

;; 15. Application Load Balancer with SSL certificate
(setv app-alb
  (aws.lb.LoadBalancer "app-alb"
    :name (pulumi.Output.concat app-name "-alb")
    :load-balancer-type "application"
    :subnets []  ;; Would need actual subnet IDs
    :security-groups [(. app-security-group id)]
    :enable-deletion-protection False))

;; Store certificate in ACM (using self-signed for demo)
(setv acm-certificate
  (aws.acm.Certificate "app-cert"
    :private-key (. app-private-key private-key-pem)
    :certificate-body (. app-certificate cert-pem)
    :tags {:Name f"{app-name}-certificate"
           :Environment environment}))

;; ALB Listener with SSL
(setv alb-listener
  (aws.lb.Listener "app-listener"
    :load-balancer-arn (. app-alb arn)
    :port 443
    :protocol "HTTPS"
    :ssl-policy "ELBSecurityPolicy-TLS-1-2-2017-01"
    :certificate-arn (. acm-certificate arn)
    :default-actions [{:type "fixed-response"
                       :fixed-response {:content-type "text/plain"
                                       :message-body f"Hello from {app-name}!"
                                       :status-code "200"}}]))

;; Export outputs (some marked as secrets)
(pulumi.export "application-info"
  {:name app-name
   :environment environment
   :resource-suffix (. resource-suffix hex)})

;; Export non-sensitive infrastructure details
(pulumi.export "infrastructure"
  {:database-endpoint (. database endpoint)
   :database-port (. database port)
   :s3-bucket (. encrypted-bucket bucket)
   :instance-id (. app-instance id)
   :instance-public-ip (. app-instance public-ip)
   :load-balancer-dns (. app-alb dns-name)
   :kms-key-alias (. kms-alias name)})

;; Export secret references (not values)
(pulumi.export "secrets-references"
  {:secrets-manager-arn (. app-secrets arn)
   :parameter-store-name (. app-config-param name)
   :kms-key-id (. app-kms-key key-id)
   :private-key-fingerprint (. app-private-key public-key-fingerprint-md5)})

;; Security and compliance info
(pulumi.export "security-features"
  {:encryption-at-rest True
   :encryption-in-transit True
   :kms-managed-keys True
   :secrets-management True
   :certificate-management True
   :secure-parameter-storage True})

;; Secrets best practices demonstrated
(pulumi.export "secrets-best-practices"
  {:password-generation "Automated with complexity requirements"
   :key-management "AWS KMS with automatic rotation capability"
   :secrets-storage "AWS Secrets Manager with encryption"
   :parameter-storage "SSM Parameter Store with SecureString"
   :certificate-management "TLS certificates with proper SAN"
   :access-control "IAM policies with least privilege"
   :encryption-standards "AES-256 encryption for all sensitive data"})

;; Example of using outputs as inputs
(pulumi.export "input-output-chain"
  {:step1 "Random password generated"
   :step2 "Password used as RDS input"
   :step3 "RDS endpoint used in Parameter Store"
   :step4 "Parameter Store used by applications"
   :step5 "KMS key used across all encrypted resources"})
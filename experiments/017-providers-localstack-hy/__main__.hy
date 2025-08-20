;; Provider configuration with LocalStack in Hy
;; Based on https://www.pulumi.com/docs/iac/concepts/resources/providers/

(import pulumi)
(import [pulumi-aws :as aws])
(import [pulumi-random :as random])

;; LocalStack provider configuration
(setv localstack-provider
  (aws.Provider "localstack"
    :region "us-east-1"
    :access-key "test"
    :secret-key "test"
    :s3-use-path-style True
    :skip-credentials-validation True
    :skip-metadata-api-check True
    :skip-requesting-account-id True
    :endpoints {:s3 "http://localhost:4566"
                :dynamodb "http://localhost:4566"
                :cloudformation "http://localhost:4566"
                :cloudwatch "http://localhost:4566"
                :es "http://localhost:4566"
                :iam "http://localhost:4566"
                :lambda "http://localhost:4566"
                :route53 "http://localhost:4566"
                :redshift "http://localhost:4566"
                :s3 "http://localhost:4566"
                :secretsmanager "http://localhost:4566"
                :ses "http://localhost:4566"
                :sns "http://localhost:4566"
                :sqs "http://localhost:4566"
                :ssm "http://localhost:4566"
                :stepfunctions "http://localhost:4566"
                :sts "http://localhost:4566"
                :ec2 "http://localhost:4566"
                :ecs "http://localhost:4566"
                :eks "http://localhost:4566"
                :apigateway "http://localhost:4566"
                :kinesis "http://localhost:4566"
                :kms "http://localhost:4566"
                :logs "http://localhost:4566"}))

;; Regular AWS provider for comparison
(setv aws-provider
  (aws.Provider "aws"
    :region "us-west-2"))

;; Random provider for generating unique names
(setv random-provider
  (random.Provider "random"))

;; Generate random suffix for resource names
(setv random-suffix
  (random.RandomId "suffix"
    :byte-length 4
    :opts (pulumi.ResourceOptions :provider random-provider)))

;; Base name with random suffix
(setv base-name 
  (pulumi.Output.concat "workshop-" (. random-suffix hex)))

;; S3 bucket with LocalStack provider
(setv localstack-bucket
  (aws.s3.BucketV2 "localstack-bucket"
    :bucket (pulumi.Output.concat base-name "-localstack")
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; S3 bucket with AWS provider (commented for safety)
;;(setv aws-bucket
;;  (aws.s3.BucketV2 "aws-bucket"
;;    :bucket (pulumi.Output.concat base-name "-aws")
;;    :opts (pulumi.ResourceOptions :provider aws-provider)))

;; DynamoDB table with LocalStack
(setv localstack-table
  (aws.dynamodb.Table "localstack-table"
    :name (pulumi.Output.concat base-name "-table")
    :billing-mode "PAY_PER_REQUEST"
    :hash-key "id"
    :attributes [{:name "id"
                  :type "S"}]
    :tags {:Environment "localstack"
           :Provider "localstack"}
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Lambda function with LocalStack
(setv lambda-zip
  (pulumi.AssetArchive
    {"index.py" (pulumi.StringAsset
      "def handler(event, context):
    import json
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Hello from LocalStack Lambda!',
            'provider': 'localstack',
            'event': event
        })
    }")}))

(setv localstack-lambda
  (aws.lambda.Function "localstack-function"
    :name (pulumi.Output.concat base-name "-function")
    :code lambda-zip
    :role (pulumi.Output.concat 
            "arn:aws:iam::000000000000:role/"
            base-name "-lambda-role")
    :handler "index.handler"
    :runtime "python3.9"
    :timeout 30
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; IAM role for Lambda (LocalStack doesn't enforce IAM strictly)
(setv lambda-role
  (aws.iam.Role "lambda-role"
    :name (pulumi.Output.concat base-name "-lambda-role")
    :assume-role-policy (pulumi.Output.json-stringify
      {:Version "2012-10-17"
       :Statement [{:Action "sts:AssumeRole"
                    :Principal {:Service "lambda.amazonaws.com"}
                    :Effect "Allow"}]})
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; CloudWatch Log Group
(setv log-group
  (aws.cloudwatch.LogGroup "lambda-logs"
    :name (pulumi.Output.concat "/aws/lambda/" base-name "-function")
    :retention-in-days 1
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; SNS Topic
(setv notification-topic
  (aws.sns.Topic "notifications"
    :name (pulumi.Output.concat base-name "-notifications")
    :display-name "Workshop Notifications"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; SQS Queue
(setv message-queue
  (aws.sqs.Queue "messages"
    :name (pulumi.Output.concat base-name "-queue")
    :message-retention-seconds 1209600  ;; 14 days
    :visibility-timeout-seconds 300
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; SNS subscription to SQS
(setv topic-subscription
  (aws.sns.TopicSubscription "queue-subscription"
    :topic-arn (. notification-topic arn)
    :protocol "sqs"
    :endpoint (. message-queue arn)
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; API Gateway for Lambda
(setv api-gateway
  (aws.apigatewayv2.Api "workshop-api"
    :name (pulumi.Output.concat base-name "-api")
    :protocol-type "HTTP"
    :cors-configuration {:allow-origins ["*"]
                         :allow-methods ["GET" "POST"]
                         :allow-headers ["*"]}
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Lambda integration
(setv lambda-integration
  (aws.apigatewayv2.Integration "lambda-integration"
    :api-id (. api-gateway id)
    :integration-type "AWS_PROXY"
    :integration-uri (. localstack-lambda invoke-arn)
    :payload-format-version "2.0"
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; API route
(setv api-route
  (aws.apigatewayv2.Route "default-route"
    :api-id (. api-gateway id)
    :route-key "GET /"
    :target (pulumi.Output.concat "integrations/" (. lambda-integration id))
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; API stage
(setv api-stage
  (aws.apigatewayv2.Stage "dev-stage"
    :api-id (. api-gateway id)
    :name "dev"
    :auto-deploy True
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Lambda permission for API Gateway
(setv lambda-permission
  (aws.lambda.Permission "api-invoke"
    :action "lambda:InvokeFunction"
    :function (. localstack-lambda name)
    :principal "apigateway.amazonaws.com"
    :source-arn (pulumi.Output.concat (. api-gateway execution-arn) "/*/*")
    :opts (pulumi.ResourceOptions :provider localstack-provider)))

;; Provider-specific outputs
(pulumi.export "localstack-provider-config"
  {:endpoint "http://localhost:4566"
   :region "us-east-1"
   :access-key "test"
   :secret-key "test"})

;; Resource outputs
(pulumi.export "random-suffix" (. random-suffix hex))
(pulumi.export "base-name" base-name)
(pulumi.export "localstack-bucket-name" (. localstack-bucket bucket))
(pulumi.export "localstack-table-name" (. localstack-table name))
(pulumi.export "localstack-lambda-name" (. localstack-lambda function-name))
(pulumi.export "api-endpoint" (. api-gateway api-endpoint))
(pulumi.export "topic-arn" (. notification-topic arn))
(pulumi.export "queue-url" (. message-queue url))

;; Testing commands for LocalStack
(pulumi.export "test-commands"
  {:s3-list f"aws --endpoint-url=http://localhost:4566 s3 ls s3://{(. localstack-bucket bucket)}"
   :dynamodb-scan f"aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name {(. localstack-table name)}"
   :lambda-invoke f"aws --endpoint-url=http://localhost:4566 lambda invoke --function-name {(. localstack-lambda function-name)} response.json"
   :api-test f"curl {(. api-gateway api-endpoint)}"
   :sns-publish f"aws --endpoint-url=http://localhost:4566 sns publish --topic-arn {(. notification-topic arn)} --message 'Test message'"
   :sqs-receive f"aws --endpoint-url=http://localhost:4566 sqs receive-message --queue-url {(. message-queue url)}"})
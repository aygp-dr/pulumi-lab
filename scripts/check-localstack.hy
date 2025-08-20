#!/usr/bin/env hy
;; check-localstack.hy - Verify LocalStack infrastructure
;; Checks S3 buckets and other resources created in LocalStack

(import boto3)
(import json)
(import sys)
(import os)

;; Configure for LocalStack
(setv endpoint-url (os.getenv "AWS_ENDPOINT_URL" "http://localhost:4566"))
(setv region (os.getenv "AWS_DEFAULT_REGION" "us-east-1"))

(defn create-localstack-client [service]
  "Create a boto3 client configured for LocalStack"
  (boto3.client service
                :endpoint-url endpoint-url
                :region-name region
                :aws-access-key-id "test"
                :aws-secret-access-key "test"))

(defn check-s3-buckets []
  "List all S3 buckets in LocalStack"
  (try
    (setv s3 (create-localstack-client "s3"))
    (setv response (s3.list-buckets))
    
    (print "\n🪣 S3 Buckets in LocalStack:")
    (print "-" :* 40)
    
    (if (get response "Buckets")
        (for [bucket (get response "Buckets")]
          (do
            (setv bucket-name (get bucket "Name"))
            (print f"  • {bucket-name}")
            
            ;; Try to get bucket location
            (try
              (setv location (s3.get-bucket-location :Bucket bucket-name))
              (print f"    Region: {(or (get location "LocationConstraint") region)}")
              (except [Exception] None))
            
            ;; List objects in bucket
            (try
              (setv objects (s3.list-objects-v2 :Bucket bucket-name))
              (setv object-count (get objects "KeyCount" 0))
              (print f"    Objects: {object-count}")
              (when (> object-count 0)
                (for [obj (get objects "Contents" [])]
                  (print f"      - {(get obj "Key")} ({(get obj "Size")} bytes)")))
              (except [Exception e]
                (print f"    Error listing objects: {e}")))))
        (print "  No buckets found"))
    
    (except [Exception e]
      (print f"❌ Error connecting to LocalStack S3: {e}")
      (print f"   Endpoint: {endpoint-url}")
      (return False)))
  True)

(defn check-dynamodb-tables []
  "List all DynamoDB tables in LocalStack"
  (try
    (setv dynamodb (create-localstack-client "dynamodb"))
    (setv response (dynamodb.list-tables))
    
    (print "\n📊 DynamoDB Tables in LocalStack:")
    (print "-" :* 40)
    
    (if (get response "TableNames")
        (for [table-name (get response "TableNames")]
          (do
            (print f"  • {table-name}")
            (try
              (setv table-info (dynamodb.describe-table :TableName table-name))
              (setv table (get table-info "Table"))
              (print f"    Status: {(get table "TableStatus")}")
              (print f"    Item Count: {(get table "ItemCount")}")
              (except [Exception e]
                (print f"    Error describing table: {e}")))))
        (print "  No tables found"))
    
    (except [Exception e]
      (print f"❌ Error connecting to LocalStack DynamoDB: {e}")
      (return False)))
  True)

(defn check-lambda-functions []
  "List all Lambda functions in LocalStack"
  (try
    (setv lambda-client (create-localstack-client "lambda"))
    (setv response (lambda-client.list-functions))
    
    (print "\n⚡ Lambda Functions in LocalStack:")
    (print "-" :* 40)
    
    (if (get response "Functions")
        (for [func (get response "Functions")]
          (print f"  • {(get func "FunctionName")}")
          (print f"    Runtime: {(get func "Runtime")}")
          (print f"    Handler: {(get func "Handler")}")
          (print f"    State: {(get func "State")}"))
        (print "  No functions found"))
    
    (except [Exception e]
      (print f"❌ Error connecting to LocalStack Lambda: {e}")
      (return False)))
  True)

(defn check-sns-topics []
  "List all SNS topics in LocalStack"
  (try
    (setv sns (create-localstack-client "sns"))
    (setv response (sns.list-topics))
    
    (print "\n📢 SNS Topics in LocalStack:")
    (print "-" :* 40)
    
    (if (get response "Topics")
        (for [topic (get response "Topics")]
          (setv topic-arn (get topic "TopicArn"))
          (setv topic-name (.split topic-arn ":" -1))
          (print f"  • {topic-name}"))
        (print "  No topics found"))
    
    (except [Exception e]
      (print f"❌ Error connecting to LocalStack SNS: {e}")
      (return False)))
  True)

(defn check-sqs-queues []
  "List all SQS queues in LocalStack"
  (try
    (setv sqs (create-localstack-client "sqs"))
    (setv response (sqs.list-queues))
    
    (print "\n📬 SQS Queues in LocalStack:")
    (print "-" :* 40)
    
    (if (get response "QueueUrls")
        (for [queue-url (get response "QueueUrls")]
          (setv queue-name (.split queue-url "/" -1))
          (print f"  • {queue-name}")
          (try
            (setv attrs (sqs.get-queue-attributes 
                          :QueueUrl queue-url
                          :AttributeNames ["All"]))
            (setv attributes (get attrs "Attributes"))
            (print f"    Messages Available: {(get attributes "ApproximateNumberOfMessages" "0")}")
            (print f"    Messages In Flight: {(get attributes "ApproximateNumberOfMessagesNotVisible" "0")}")
            (except [Exception] None)))
        (print "  No queues found"))
    
    (except [Exception e]
      (print f"❌ Error connecting to LocalStack SQS: {e}")
      (return False)))
  True)

(defn main []
  "Main function to check all LocalStack resources"
  (print "=" :* 50)
  (print "🚀 LocalStack Infrastructure Check")
  (print f"   Endpoint: {endpoint-url}")
  (print f"   Region: {region}")
  (print "=" :* 50)
  
  ;; Check connection to LocalStack
  (try
    (setv s3 (create-localstack-client "s3"))
    (s3.list-buckets)
    (print "✅ Successfully connected to LocalStack")
    (except [Exception e]
      (print f"❌ Cannot connect to LocalStack at {endpoint-url}")
      (print f"   Error: {e}")
      (print "\n💡 Make sure LocalStack is running:")
      (print "   docker run -d -p 4566:4566 localstack/localstack")
      (sys.exit 1)))
  
  ;; Check each service
  (setv results [])
  (.append results (check-s3-buckets))
  (.append results (check-dynamodb-tables))
  (.append results (check-lambda-functions))
  (.append results (check-sns-topics))
  (.append results (check-sqs-queues))
  
  (print "\n" "=" :* 50)
  (if (all results)
      (print "✅ All checks completed successfully")
      (print "⚠️  Some checks failed"))
  (print "=" :* 50))

(when (= __name__ "__main__")
  (main))
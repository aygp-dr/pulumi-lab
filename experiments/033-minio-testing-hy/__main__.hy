;; Minio S3-compatible storage testing for FreeBSD
;; Uses Minio as LocalStack alternative for S3 operations

(import pulumi)
(import pulumi_aws :as aws)

;; Configure AWS provider for Minio
(setv minio-provider 
  (aws.Provider "minio"
    :endpoints [(aws.ProviderEndpointArgs :s3 "http://localhost:9000")]
    :s3-use-path-style True
    :skip-credentials-validation True
    :skip-requesting-account-id True
    :skip-metadata-api-check True
    :access-key "minioadmin"
    :secret-key "minioadmin"
    :region "us-east-1"))

;; Create test bucket
(setv test-bucket 
  (aws.s3.BucketV2 "minio-test-bucket"
    :bucket "pulumi-minio-test"
    :force-destroy True
    :opts (pulumi.ResourceOptions :provider minio-provider)))

;; Create a bucket for static website hosting
(setv website-bucket
  (aws.s3.BucketV2 "minio-website-bucket"
    :bucket "pulumi-minio-website"
    :force-destroy True
    :opts (pulumi.ResourceOptions :provider minio-provider)))

;; Configure bucket versioning
(setv bucket-versioning
  (aws.s3.BucketVersioningV2 "versioning"
    :bucket (. test-bucket id)
    :versioning-configuration 
      (aws.s3.BucketVersioningV2VersioningConfigurationArgs :status "Enabled")
    :opts (pulumi.ResourceOptions :provider minio-provider)))

;; Create a sample object
(setv sample-object
  (aws.s3.BucketObject "sample"
    :bucket (. test-bucket id)
    :key "sample.txt"
    :content "Hello from Pulumi + Minio on FreeBSD!"
    :content-type "text/plain"
    :opts (pulumi.ResourceOptions :provider minio-provider)))

;; Export outputs
(pulumi.export "minio_endpoint" "http://localhost:9000")
(pulumi.export "test_bucket_name" (. test-bucket bucket))
(pulumi.export "website_bucket_name" (. website-bucket bucket))
(pulumi.export "sample_object_key" (. sample-object key))

;; Print setup instructions
(print "✅ Minio S3 testing configuration ready!")
(print "")
(print "Prerequisites:")
(print "1. Start Minio: gmake minio-start")
(print "2. Configure environment: eval $(gmake minio-env)")
(print "3. Run: pulumi up")
(print "")
(print "Test with AWS CLI:")
(print "  aws --endpoint-url=http://localhost:9000 s3 ls")
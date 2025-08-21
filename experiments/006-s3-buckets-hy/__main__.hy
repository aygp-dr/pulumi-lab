;; S3 Buckets example with Hy for LocalStack/Minio
;; Simplified version focusing on core S3 functionality
;; Compatible with Hy 1.0.0+ and FreeBSD/macOS

(import pulumi)
(import pulumi_aws :as aws)

;; Create media and content buckets
(setv media-bucket 
  (aws.s3.Bucket "media-bucket"
    :bucket "pulumi-lab-media-bucket"
    :force-destroy True))

(setv content-bucket 
  (aws.s3.Bucket "content-bucket"
    :bucket "pulumi-lab-content-bucket"
    :force-destroy True))

;; Configure bucket versioning
(setv media-versioning
  (aws.s3.BucketVersioning "media-versioning"
    :bucket media-bucket.id
    :versioning-configuration 
      {"status" "Enabled"}))

;; Configure public access block
(setv media-public-access-block
  (aws.s3.BucketPublicAccessBlock "media-pab"
    :bucket media-bucket.id
    :block-public-acls True
    :block-public-policy True
    :ignore-public-acls True
    :restrict-public-buckets True))

;; Enable server-side encryption
(setv media-encryption
  (aws.s3.BucketServerSideEncryptionConfiguration "media-encryption"
    :bucket media-bucket.id
    :rules [{"apply_server_side_encryption_by_default"
             {"sse_algorithm" "AES256"}}]))

;; Export bucket information
(pulumi.export "media_bucket_name" media-bucket.bucket)
(pulumi.export "media_bucket_arn" media-bucket.arn)
(pulumi.export "content_bucket_name" content-bucket.bucket)
(pulumi.export "content_bucket_arn" content-bucket.arn)
(pulumi.export "versioning_enabled" "true")
(pulumi.export "encryption_enabled" "true")
(pulumi.export "localstack_endpoint" "http://localhost:4566")
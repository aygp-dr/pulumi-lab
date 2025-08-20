;; S3 Buckets example from Pulumi docs - converted to Hy

(import pulumi)
(import [pulumi-aws :as aws])

;; Create media and content buckets
(setv media-bucket 
  (aws.s3.BucketV2 "media-bucket"))

(setv content-bucket 
  (aws.s3.BucketV2 "content-bucket"))

;; Configure bucket versioning
(setv media-versioning
  (aws.s3.BucketVersioningV2 "media-versioning"
    :bucket (. media-bucket id)
    :versioning-configuration 
      {:status "Enabled"}))

;; Configure public access block
(setv media-public-access-block
  (aws.s3.BucketPublicAccessBlock "media-pab"
    :bucket (. media-bucket id)
    :block-public-acls True
    :block-public-policy True
    :ignore-public-acls True
    :restrict-public-buckets True))

;; Add lifecycle rule for content bucket
(setv content-lifecycle
  (aws.s3.BucketLifecycleConfigurationV2 "content-lifecycle"
    :bucket (. content-bucket id)
    :rules [{:id "archive-old-content"
             :status "Enabled"
             :transitions [{:days 30
                           :storage-class "STANDARD_IA"}
                          {:days 90
                           :storage-class "GLACIER"}]
             :expiration {:days 365}}]))

;; Create bucket policy for media bucket
(setv media-bucket-policy-doc
  (aws.iam.get-policy-document
    :statements [{:sid "AllowCloudFrontAccess"
                  :effect "Allow"
                  :principals [{:type "Service"
                               :identifiers ["cloudfront.amazonaws.com"]}]
                  :actions ["s3:GetObject"]
                  :resources [(pulumi.Output.concat 
                              (. media-bucket arn) "/*")]}]))

(setv media-bucket-policy
  (aws.s3.BucketPolicy "media-policy"
    :bucket (. media-bucket id)
    :policy (. media-bucket-policy-doc json)))

;; Enable server-side encryption
(setv media-encryption
  (aws.s3.BucketServerSideEncryptionConfigurationV2 "media-encryption"
    :bucket (. media-bucket id)
    :rules [{:apply-server-side-encryption-by-default
             {:sse-algorithm "AES256"}}]))

;; Export bucket information
(pulumi.export "media_bucket_name" (. media-bucket bucket))
(pulumi.export "media_bucket_arn" (. media-bucket arn))
(pulumi.export "content_bucket_name" (. content-bucket bucket))
(pulumi.export "content_bucket_arn" (. content-bucket arn))
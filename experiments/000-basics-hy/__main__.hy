;; Basic Pulumi program in Hy
(import pulumi)
(import [pulumi-aws :as aws])

;; Configuration
(setv config (pulumi.Config))
(setv stack-name (pulumi.get-stack))

;; Create a resource
(setv bucket (aws.s3.BucketV2 "my-bucket"))

;; Export outputs
(pulumi.export "bucket_name" (. bucket bucket))
(pulumi.export "bucket_arn" (. bucket arn))

;; Policy enforcement in Hy
(import pulumi)
(import [pulumi-aws :as aws])
(import [pulumi.policy :as policy])

;; Define policy pack
(defclass SecurityPolicyPack [policy.PolicyPack]
  (defn __init__ [self]
    (super.__init__ 
      "security-policies"
      :policies [
        ;; Require encryption on S3 buckets
        (policy.ResourceValidationPolicy 
          "s3-encryption-required"
          "S3 buckets must have encryption enabled"
          (fn [args validation-args]
            (when (= (. args resource-type) "aws:s3/bucket:Bucket")
              (let [encryption (get (. args props) "serverSideEncryptionConfiguration")]
                (when (not encryption)
                  (policy.ReportViolation 
                    "S3 bucket must have encryption enabled")))))
          
        ;; Require tags
        (policy.ResourceValidationPolicy
          "required-tags"
          "Resources must have required tags"
          (fn [args validation-args]
            (let [tags (get (. args props) "tags" {})]
              (when (not (get tags "Environment"))
                (policy.ReportViolation
                  "Missing required tag: Environment"))
              (when (not (get tags "Owner"))
                (policy.ReportViolation
                  "Missing required tag: Owner")))))]))

;; Apply policies to resources
(setv compliant-bucket
  (aws.s3.BucketV2 "compliant"
    :server-side-encryption-configuration
      {:rule {:apply-server-side-encryption-by-default
              {:sse-algorithm "AES256"}}}
    :tags {:Environment "workshop"
           :Owner "pulumi-lab"}))

(pulumi.export "bucket_status" "compliant")

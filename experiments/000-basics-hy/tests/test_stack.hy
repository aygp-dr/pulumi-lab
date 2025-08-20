;; Test suite for Pulumi stack
(import unittest)
(import pulumi)
(import [unittest.mock :as mock])

(defclass TestPulumiStack [unittest.TestCase]
  "Tests for the Pulumi infrastructure stack"
  
  (defn test-bucket-creation [self]
    "Test that S3 bucket is created with correct properties"
    (with [(mock.patch "pulumi_aws.s3.BucketV2") bucket-mock]
      (setv bucket-mock.return-value.bucket "test-bucket")
      (setv bucket-mock.return-value.arn "arn:aws:s3:::test-bucket")
      
      ;; Import the main module
      (import __main__)
      
      ;; Verify bucket was created
      (self.assertTrue bucket-mock.called)
      (self.assertEqual bucket-mock.call-count 1)))
  
  (defn test-exports-exist [self]
    "Test that required exports are defined"
    (with [(mock.patch "pulumi.export") export-mock]
      ;; Import the main module
      (import __main__)
      
      ;; Check that exports were called
      (self.assertTrue export-mock.called)
      ;; Should have bucket_name and bucket_arn exports
      (self.assertGreaterEqual export-mock.call-count 2)))
  
  (defn test-config-loaded [self]
    "Test that Pulumi config is loaded"
    (with [(mock.patch "pulumi.Config") config-mock]
      (import __main__)
      
      ;; Verify Config was instantiated
      (self.assertTrue config-mock.called)))
  
  (defn test-stack-name [self]
    "Test that stack name is retrieved"
    (with [(mock.patch "pulumi.get_stack") stack-mock]
      (setv stack-mock.return-value "test-stack")
      
      (import __main__)
      
      ;; Verify get_stack was called
      (self.assertTrue stack-mock.called))))

(when (= __name__ "__main__")
  (unittest.main))
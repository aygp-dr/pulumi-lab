#!/usr/bin/env hy
;; test-s3-localstack.hy - Simple S3 test for LocalStack using boto3

(import boto3)
(import os)
(import uuid)

;; Configure for LocalStack
(setv endpoint-url (os.getenv "AWS_ENDPOINT_URL" "http://localhost:4566"))

(defn create-s3-client []
  "Create an S3 client for LocalStack"
  (boto3.client "s3"
                :endpoint-url endpoint-url
                :region-name "us-east-1"
                :aws-access-key-id "test"
                :aws-secret-access-key "test"))

(defn test-s3-operations []
  "Test basic S3 operations in LocalStack"
  (setv s3 (create-s3-client))
  (setv test-bucket f"test-bucket-{(str (uuid.uuid4))}")
  
  (print f"\n🧪 Testing S3 in LocalStack")
  (print f"   Endpoint: {endpoint-url}")
  (print (* "-" 40))
  
  ;; Create bucket
  (print f"\n1. Creating bucket: {test-bucket}")
  (try
    (s3.create-bucket :Bucket test-bucket)
    (print "   ✅ Bucket created")
    (except [Exception e]
      (print f"   ❌ Failed: {e}")
      (return False)))
  
  ;; List buckets
  (print "\n2. Listing buckets:")
  (setv response (s3.list-buckets))
  (for [bucket (get response "Buckets")]
    (print f"   • {(get bucket "Name")}"))
  
  ;; Put object
  (print f"\n3. Uploading object to {test-bucket}")
  (setv test-key "test-file.txt")
  (setv test-content "Hello from Hy and LocalStack!")
  (try
    (s3.put-object :Bucket test-bucket
                   :Key test-key
                   :Body (.encode test-content))
    (print f"   ✅ Uploaded: {test-key}")
    (except [Exception e]
      (print f"   ❌ Failed: {e}")))
  
  ;; List objects
  (print f"\n4. Listing objects in {test-bucket}:")
  (setv response (s3.list-objects-v2 :Bucket test-bucket))
  (if (get response "Contents")
      (for [obj (get response "Contents")]
        (print f"   • {(get obj "Key")} - {(get obj "Size")} bytes"))
      (print "   No objects found"))
  
  ;; Get object
  (print f"\n5. Reading object: {test-key}")
  (try
    (setv response (s3.get-object :Bucket test-bucket :Key test-key))
    (setv content (.decode (.read (get response "Body"))))
    (print f"   Content: '{content}'")
    (print "   ✅ Read successful")
    (except [Exception e]
      (print f"   ❌ Failed: {e}")))
  
  ;; Cleanup
  (print f"\n6. Cleaning up...")
  (try
    ;; Delete object
    (s3.delete-object :Bucket test-bucket :Key test-key)
    (print f"   Deleted object: {test-key}")
    ;; Delete bucket
    (s3.delete-bucket :Bucket test-bucket)
    (print f"   Deleted bucket: {test-bucket}")
    (print "   ✅ Cleanup complete")
    (except [Exception e]
      (print f"   ⚠️  Cleanup failed: {e}")))
  
  (print (+ "\n" (* "=" 40)))
  (print "✅ S3 test completed successfully!")
  True)

(defn main []
  "Main entry point"
  ;; Check LocalStack connection first
  (try
    (setv s3 (create-s3-client))
    (s3.list-buckets)
    (print "✅ Connected to LocalStack")
    (except [Exception e]
      (print f"❌ Cannot connect to LocalStack at {endpoint-url}")
      (print f"   Error: {e}")
      (print "\n💡 Start LocalStack with:")
      (print "   docker run -d -p 4566:4566 localstack/localstack")
      (return)))
  
  ;; Run the test
  (test-s3-operations))

(when (= __name__ "__main__")
  (main))
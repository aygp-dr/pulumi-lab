#!/usr/bin/env hy
;; Test S3 operations with LocalStack using Hy

(import boto3)

;; Create S3 client for LocalStack
(setv s3 (boto3.client "s3" 
  :endpoint-url "http://localhost:4566"
  :aws-access-key-id "test"
  :aws-secret-access-key "test"
  :region-name "us-east-1"))

;; List buckets
(setv buckets (s3.list-buckets))
(print "Buckets:" (lfor b (get buckets "Buckets") (get b "Name")))

;; Find media bucket
(setv media-bucket 
  (next (gfor b (get buckets "Buckets") 
              :if (in "media" (get b "Name")) 
              b) 
        None))

(when media-bucket
  (setv bucket-name (get media-bucket "Name"))
  (print f"\nMedia bucket found: {bucket-name}")
  
  ;; Upload test object
  (s3.put-object :Bucket bucket-name 
                 :Key "test.txt" 
                 :Body (.encode "Hello from Hy!" "utf-8"))
  (print "✓ Test object uploaded")
  
  ;; List objects
  (setv objects (s3.list-objects-v2 :Bucket bucket-name))
  (when (in "Contents" objects)
    (print "✓ Objects in bucket:" 
           (lfor obj (get objects "Contents") (get obj "Key"))))
  
  ;; Get object
  (setv response (s3.get-object :Bucket bucket-name :Key "test.txt"))
  (setv content (.decode (.read (get response "Body")) "utf-8"))
  (print f"✓ Object content: \"{content}\"")
  
  ;; Check versioning
  (setv versioning (s3.get-bucket-versioning :Bucket bucket-name))
  (setv status (versioning.get "Status" "Disabled"))
  (print f"✓ Versioning status: {status}")
  
  (print "\n✅ All S3 operations successful!"))

(when (not media-bucket)
  (print "No media bucket found - run make up first"))
;; Disaster recovery with multi-region
(import pulumi)
(import [pulumi-aws :as aws])

;; Primary region provider
(setv primary-provider
  (aws.Provider "primary"
    :region "us-west-2"))

;; DR region provider  
(setv dr-provider
  (aws.Provider "dr"
    :region "us-east-1"))

;; Primary S3 bucket
(setv primary-bucket
  (aws.s3.BucketV2 "primary-data"
    :versioning {:enabled True}
    :opts (pulumi.ResourceOptions :provider primary-provider)))

;; DR S3 bucket
(setv dr-bucket
  (aws.s3.BucketV2 "dr-data"
    :versioning {:enabled True}
    :opts (pulumi.ResourceOptions :provider dr-provider)))

;; Cross-region replication role
(setv replication-role
  (aws.iam.Role "replication"
    :assume-role-policy (pulumi.Output.json-stringify
      {:Version "2012-10-17"
       :Statement [{:Effect "Allow"
                    :Principal {:Service "s3.amazonaws.com"}
                    :Action "sts:AssumeRole"}]})))

;; Replication policy
(setv replication-policy
  (aws.iam.RolePolicy "replication"
    :role (. replication-role id)
    :policy (pulumi.Output.json-stringify
      {:Version "2012-10-17"
       :Statement [
         {:Effect "Allow"
          :Action ["s3:GetReplicationConfiguration"
                   "s3:ListBucket"]
          :Resource [(. primary-bucket arn)]}
         {:Effect "Allow"
          :Action ["s3:GetObjectVersionForReplication"
                   "s3:GetObjectVersionAcl"]
          :Resource [(pulumi.Output.concat 
                      (. primary-bucket arn) "/*")]}
         {:Effect "Allow"
          :Action ["s3:ReplicateObject"
                   "s3:ReplicateDelete"]
          :Resource [(pulumi.Output.concat
                      (. dr-bucket arn) "/*")]}]})))

;; Configure replication
(setv replication-config
  (aws.s3.BucketReplicationConfiguration "replication"
    :role (. replication-role arn)
    :bucket (. primary-bucket id)
    :rules [{:id "replicate-all"
             :status "Enabled"
             :priority 1
             :destination {:bucket (. dr-bucket arn)
                          :storage-class "STANDARD_IA"}
             :filter {}}]
    :opts (pulumi.ResourceOptions 
           :depends-on [replication-policy])))

;; RDS with automated backups
(setv primary-db
  (aws.rds.Instance "primary"
    :allocated-storage 100
    :engine "postgres"
    :engine-version "14"
    :instance-class "db.t3.medium"
    :backup-retention-period 30
    :backup-window "03:00-04:00"
    :maintenance-window "sun:04:00-sun:05:00"
    :multi-az True
    :skip-final-snapshot False
    :final-snapshot-identifier "final-snapshot"
    :opts (pulumi.ResourceOptions :provider primary-provider)))

;; Outputs
(pulumi.export "primary_bucket" (. primary-bucket bucket))
(pulumi.export "dr_bucket" (. dr-bucket bucket))
(pulumi.export "db_endpoint" (. primary-db endpoint))

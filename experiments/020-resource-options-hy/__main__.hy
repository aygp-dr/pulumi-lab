;; Comprehensive Resource Options demonstration in Hy
;; Based on https://www.pulumi.com/docs/iac/concepts/options/

(import pulumi)
(import [pulumi-aws :as aws])
(import [pulumi-random :as random])

;; Configuration
(setv config (pulumi.Config))
(setv environment (pulumi.get-stack))
(setv app-name (config.get "app-name" "workshop"))

;; Generate random suffix for unique naming
(setv random-suffix
  (random.RandomId "suffix"
    :byte-length 4))

;; 1. Basic resource without options
(setv basic-bucket
  (aws.s3.BucketV2 "basic-bucket"
    :bucket (pulumi.Output.concat app-name "-basic-" (. random-suffix hex))))

;; 2. PROTECT option - prevents accidental deletion
(setv protected-bucket
  (aws.s3.BucketV2 "protected-bucket"
    :bucket (pulumi.Output.concat app-name "-protected-" (. random-suffix hex))
    :opts (pulumi.ResourceOptions 
           :protect True)))

;; 3. DEPENDS_ON option - explicit dependencies
(setv dependency-bucket
  (aws.s3.BucketV2 "dependency-bucket"
    :bucket (pulumi.Output.concat app-name "-dependency-" (. random-suffix hex))
    :opts (pulumi.ResourceOptions 
           :depends-on [basic-bucket random-suffix])))

;; 4. IGNORE_CHANGES option - ignore specific property changes
(setv versioned-bucket
  (aws.s3.BucketV2 "versioned-bucket"
    :bucket (pulumi.Output.concat app-name "-versioned-" (. random-suffix hex))))

(setv bucket-versioning
  (aws.s3.BucketVersioningV2 "bucket-versioning"
    :bucket (. versioned-bucket id)
    :versioning-configuration {:status "Enabled"}
    :opts (pulumi.ResourceOptions 
           :ignore-changes ["versioning_configuration.mfa_delete"])))

;; 5. REPLACE_ON_CHANGES option - force replacement on property changes
(setv vpc
  (aws.ec2.Vpc "main-vpc"
    :cidr-block "10.0.0.0/16"
    :enable-dns-hostnames True
    :opts (pulumi.ResourceOptions 
           :replace-on-changes ["cidr_block"])))

;; 6. DELETE_BEFORE_REPLACE option - change replacement order
(setv launch-template
  (aws.ec2.LaunchTemplate "app-template"
    :image-id "ami-0c02fb55956c7d316"
    :instance-type "t3.micro"
    :vpc-security-group-ids []
    :opts (pulumi.ResourceOptions 
           :delete-before-replace True
           :replace-on-changes ["image_id" "instance_type"])))

;; 7. PARENT option - establish parent-child relationships
(setv parent-log-group
  (aws.cloudwatch.LogGroup "parent-logs"
    :name f"/aws/application/{app-name}"
    :retention-in-days 30))

(setv child-log-stream
  (aws.cloudwatch.LogStream "child-stream"
    :log-group-name (. parent-log-group name)
    :name f"{environment}-stream"
    :opts (pulumi.ResourceOptions 
           :parent parent-log-group)))

;; 8. PROVIDER option - use specific provider configuration
(setv west-provider
  (aws.Provider "west"
    :region "us-west-2"))

(setv east-provider
  (aws.Provider "east"
    :region "us-east-1"))

(setv west-bucket
  (aws.s3.BucketV2 "west-bucket"
    :bucket (pulumi.Output.concat app-name "-west-" (. random-suffix hex))
    :opts (pulumi.ResourceOptions 
           :provider west-provider)))

(setv east-bucket
  (aws.s3.BucketV2 "east-bucket"
    :bucket (pulumi.Output.concat app-name "-east-" (. random-suffix hex))
    :opts (pulumi.ResourceOptions 
           :provider east-provider)))

;; 9. ALIASES option - prevent replacement during refactoring
(setv aliased-bucket
  (aws.s3.BucketV2 "new-bucket-name"
    :bucket (pulumi.Output.concat app-name "-aliased-" (. random-suffix hex))
    :opts (pulumi.ResourceOptions 
           :aliases [(pulumi.Alias :name "old-bucket-name")
                     (pulumi.Alias :name "legacy-bucket")])))

;; 10. CUSTOM_TIMEOUTS option - override default timeouts
(setv rds-instance
  (aws.rds.Instance "database"
    :allocated-storage 20
    :engine "postgres"
    :engine-version "14"
    :instance-class "db.t3.micro"
    :db-name "workshop"
    :username "admin"
    :password "temporary-password"
    :skip-final-snapshot True
    :opts (pulumi.ResourceOptions 
           :custom-timeouts (pulumi.CustomTimeouts
                             :create "10m"
                             :update "10m"
                             :delete "5m"))))

;; 11. RETAIN_ON_DELETE option - keep resource in cloud after Pulumi delete
(setv retained-bucket
  (aws.s3.BucketV2 "retained-bucket"
    :bucket (pulumi.Output.concat app-name "-retained-" (. random-suffix hex))
    :opts (pulumi.ResourceOptions 
           :retain-on-delete True)))

;; 12. TRANSFORMATIONS option - modify resources dynamically
(defn add-common-tags [args]
  "Transformation function to add common tags"
  (when (in "tags" (. args props))
    (setv existing-tags (get (. args props) "tags" {}))
    (setv common-tags {:Environment environment
                       :Project "pulumi-lab"
                       :ManagedBy "Pulumi"
                       :CreatedWith "Hy"})
    (assoc (. args props) "tags" (| existing-tags common-tags)))
  args)

(setv transformed-bucket
  (aws.s3.BucketV2 "transformed-bucket"
    :bucket (pulumi.Output.concat app-name "-transformed-" (. random-suffix hex))
    :tags {:Application app-name}
    :opts (pulumi.ResourceOptions 
           :transformations [add-common-tags])))

;; 13. Multiple options combined
(setv complex-bucket
  (aws.s3.BucketV2 "complex-bucket"
    :bucket (pulumi.Output.concat app-name "-complex-" (. random-suffix hex))
    :opts (pulumi.ResourceOptions 
           :depends-on [basic-bucket]
           :protect (= environment "prod")
           :ignore-changes ["tags.LastModified"]
           :provider west-provider
           :aliases [(pulumi.Alias :name "old-complex-bucket")]
           :transformations [add-common-tags]
           :retain-on-delete (= environment "prod"))))

;; 14. Import existing resources (commented for safety)
;; (setv imported-bucket
;;   (aws.s3.BucketV2 "imported-bucket"
;;     :bucket "existing-bucket-name"
;;     :opts (pulumi.ResourceOptions 
;;            :import "existing-bucket-name")))

;; 15. Advanced dependency management
(setv network-acl
  (aws.ec2.NetworkAcl "network-acl"
    :vpc-id (. vpc id)
    :egress [{:protocol "-1"
              :rule-no 100
              :action "allow"
              :cidr-block "0.0.0.0/0"
              :from-port 0
              :to-port 0}]
    :ingress [{:protocol "-1"
               :rule-no 100
               :action "allow"
               :cidr-block "0.0.0.0/0"
               :from-port 0
               :to-port 0}]
    :opts (pulumi.ResourceOptions 
           :depends-on [vpc]
           :replace-on-changes ["vpc_id"])))

;; 16. Conditional resource options
(setv conditional-bucket
  (aws.s3.BucketV2 "conditional-bucket"
    :bucket (pulumi.Output.concat app-name "-conditional-" (. random-suffix hex))
    :opts (pulumi.ResourceOptions 
           :protect (= environment "prod")
           :retain-on-delete (= environment "prod")
           :ignore-changes (if (= environment "dev") 
                               ["tags"]
                               [])
           :provider (if (in environment ["staging" "prod"])
                         west-provider
                         east-provider))))

;; 17. Resource with multiple aliases for migration scenarios
(setv migrated-bucket
  (aws.s3.BucketV2 "v2-bucket"
    :bucket (pulumi.Output.concat app-name "-v2-" (. random-suffix hex))
    :opts (pulumi.ResourceOptions 
           :aliases [(pulumi.Alias :name "v1-bucket")
                     (pulumi.Alias :name "legacy-storage-bucket")
                     (pulumi.Alias :name "old-data-bucket"
                                   :type "aws:s3/bucket:Bucket")])))

;; 18. Bucket policy that ignores changes to specific conditions
(setv bucket-policy
  (aws.s3.BucketPolicy "bucket-policy"
    :bucket (. basic-bucket id)
    :policy (pulumi.Output.json-stringify
      {:Version "2012-10-17"
       :Statement [{:Sid "AllowPublicRead"
                    :Effect "Allow"
                    :Principal "*"
                    :Action "s3:GetObject"
                    :Resource (pulumi.Output.concat 
                               (. basic-bucket arn) "/*")
                    :Condition {:StringEquals
                                {"aws:Referer" ["https://example.com"]}}}]})
    :opts (pulumi.ResourceOptions 
           :depends-on [basic-bucket]
           :ignore-changes ["policy.Statement[0].Condition"])))

;; Resource options summary export
(pulumi.export "resource-options-demo"
  {:protect-example (. protected-bucket bucket)
   :depends-on-example (. dependency-bucket bucket)
   :ignore-changes-example (. bucket-versioning id)
   :replace-on-changes-example (. vpc id)
   :delete-before-replace-example (. launch-template id)
   :parent-child-example {:parent (. parent-log-group name)
                          :child (. child-log-stream name)}
   :multi-provider-example {:west (. west-bucket bucket)
                            :east (. east-bucket bucket)}
   :aliases-example (. aliased-bucket bucket)
   :custom-timeouts-example (. rds-instance id)
   :retain-on-delete-example (. retained-bucket bucket)
   :transformations-example (. transformed-bucket bucket)
   :complex-options-example (. complex-bucket bucket)})

;; Environment-specific options patterns
(pulumi.export "environment-patterns"
  (cond
    [(= environment "prod")
     {:protection-enabled True
      :retention-enabled True
      :backup-frequency "daily"
      :monitoring-level "detailed"}]
    [(= environment "staging")
     {:protection-enabled False
      :retention-enabled True
      :backup-frequency "weekly"
      :monitoring-level "basic"}]
    [True
     {:protection-enabled False
      :retention-enabled False
      :backup-frequency "none"
      :monitoring-level "minimal"}]))

;; Options best practices
(pulumi.export "best-practices"
  {:protection ["Enable for production resources"
                "Use conditional protection based on environment"]
   :dependencies ["Prefer implicit dependencies"
                  "Use explicit depends_on sparingly"
                  "Avoid circular dependencies"]
   :ignoreChanges ["Use for drift-prone properties"
                   "Avoid for critical configuration"
                   "Document ignored changes"]
   :replaceOnChanges ["Use for immutable properties"
                      "Combine with deleteBeforeReplace when needed"]
   :aliases ["Essential for resource refactoring"
             "Support multiple aliases for complex migrations"
             "Include type information when needed"]
   :providers ["Use for multi-region deployments"
               "Configure once, reference multiple times"
               "Environment-specific provider selection"]
   :transformations ["Implement common tagging"
                     "Enforce naming conventions"
                     "Add environment-specific modifications"]})
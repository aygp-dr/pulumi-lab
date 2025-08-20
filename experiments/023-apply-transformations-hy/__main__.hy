;; Output.apply() and transformations in Hy
;; Based on https://www.pulumi.com/docs/iac/concepts/inputs-outputs/apply/

(import pulumi)
(import [pulumi-aws :as aws])
(import [pulumi-random :as random])
(import json)
(import base64)

;; Configuration
(setv config (pulumi.Config))
(setv app-name (config.get "app-name" "workshop"))
(setv environment (pulumi.get-stack))

;; 1. Basic apply() usage for string manipulation
(setv random-suffix
  (random.RandomId "suffix"
    :byte-length 4))

;; Apply transformation to create formatted names
(setv formatted-bucket-name
  (-> (. random-suffix hex)
      (.apply (fn [hex-val] 
                f"{app-name}-{environment}-bucket-{hex-val}"))))

(setv main-bucket
  (aws.s3.BucketV2 "main-bucket"
    :bucket formatted-bucket-name))

;; 2. Complex apply() with multiple outputs
(setv vpc
  (aws.ec2.Vpc "main-vpc"
    :cidr-block "10.0.0.0/16"
    :enable-dns-hostnames True
    :enable-dns-support True))

(setv subnet
  (aws.ec2.Subnet "main-subnet"
    :vpc-id (. vpc id)
    :cidr-block "10.0.1.0/24"
    :availability-zone "us-west-2a"))

;; Apply to create complex security group rules
(setv security-group
  (aws.ec2.SecurityGroup "app-sg"
    :vpc-id (. vpc id)
    :description "Application security group"
    :ingress (-> (pulumi.Output.all (. vpc cidr-block) (. subnet cidr-block))
                 (.apply (fn [vals]
                           (setv [vpc-cidr subnet-cidr] vals)
                           [{:protocol "tcp"
                             :from-port 80
                             :to-port 80
                             :cidr-blocks [vpc-cidr]}
                            {:protocol "tcp"
                             :from-port 443
                             :to-port 443
                             :cidr-blocks ["0.0.0.0/0"]}
                            {:protocol "tcp"
                             :from-port 22
                             :to-port 22
                             :cidr-blocks [subnet-cidr]}])))
    :egress [{:protocol "-1"
              :from-port 0
              :to-port 0
              :cidr-blocks ["0.0.0.0/0"]}]))

;; 3. Apply for JSON manipulation
(setv iam-policy-document
  (-> (pulumi.Output.all (. main-bucket arn) (. main-bucket bucket))
      (.apply (fn [vals]
                (setv [bucket-arn bucket-name] vals)
                (json.dumps
                  {:Version "2012-10-17"
                   :Statement [{:Effect "Allow"
                                :Action ["s3:GetObject" "s3:PutObject"]
                                :Resource f"{bucket-arn}/*"}
                               {:Effect "Allow"
                                :Action ["s3:ListBucket"]
                                :Resource bucket-arn
                                :Condition {:StringLike 
                                           {"s3:prefix" [f"{environment}/*"]}}}]})))))

(setv iam-role
  (aws.iam.Role "app-role"
    :assume-role-policy (json.dumps
      {:Version "2012-10-17"
       :Statement [{:Action "sts:AssumeRole"
                    :Principal {:Service "ec2.amazonaws.com"}
                    :Effect "Allow"}]})))

(setv iam-policy
  (aws.iam.RolePolicy "app-policy"
    :role (. iam-role id)
    :policy iam-policy-document))

;; 4. Apply for conditional logic
(setv instance-type
  (-> (pulumi.Output.of environment)
      (.apply (fn [env]
                (cond
                  [(= env "prod") "t3.large"]
                  [(= env "staging") "t3.medium"]
                  [True "t3.micro"])))))

(setv instance-count
  (-> (pulumi.Output.of environment)
      (.apply (fn [env]
                (cond
                  [(= env "prod") 3]
                  [(= env "staging") 2]
                  [True 1])))))

;; 5. Apply for data transformation and encoding
(setv user-data-script
  (-> (pulumi.Output.all 
        (. main-bucket bucket)
        (. vpc id)
        environment)
      (.apply (fn [vals]
                (setv [bucket-name vpc-id env] vals)
                (setv script f"""#!/bin/bash
yum update -y
yum install -y aws-cli

# Configure application
echo 'S3_BUCKET={bucket-name}' >> /etc/environment
echo 'VPC_ID={vpc-id}' >> /etc/environment
echo 'ENVIRONMENT={env}' >> /etc/environment

# Download application from S3
aws s3 cp s3://{bucket-name}/{env}/app.tar.gz /tmp/
cd /tmp && tar -xzf app.tar.gz

# Start application
chmod +x app.sh
./app.sh
""")
                (base64.b64encode (.encode script "utf-8"))))))

;; 6. Apply for creating derived resources
(setv launch-template
  (aws.ec2.LaunchTemplate "app-template"
    :image-id "ami-0c02fb55956c7d316"
    :instance-type instance-type
    :vpc-security-group-ids [(. security-group id)]
    :user-data user-data-script
    :tag-specifications [{:resource-type "instance"
                          :tags {:Name (-> (. random-suffix hex)
                                           (.apply (fn [hex-val]
                                                     f"{app-name}-{environment}-{hex-val}")))
                                 :Environment environment
                                 :Application app-name}}]))

;; 7. Apply for complex string formatting
(setv cloudformation-template
  (-> (pulumi.Output.all 
        (. vpc id)
        (. subnet id)
        (. security-group id)
        (. launch-template id))
      (.apply (fn [vals]
                (setv [vpc-id subnet-id sg-id template-id] vals)
                (json.dumps
                  {:AWSTemplateFormatVersion "2010-09-09"
                   :Description f"Auto Scaling Group for {app-name}"
                   :Resources
                     {:AutoScalingGroup
                        {:Type "AWS::AutoScaling::AutoScalingGroup"
                         :Properties
                           {:VPCZoneIdentifier [subnet-id]
                            :LaunchTemplate {:LaunchTemplateId template-id
                                           :Version "$Latest"}
                            :MinSize 1
                            :MaxSize 5
                            :DesiredCapacity 2
                            :Tags [{:Key "Name"
                                   :Value f"{app-name}-asg"
                                   :PropagateAtLaunch True}]}}
                     :LoadBalancer
                        {:Type "AWS::ElasticLoadBalancingV2::LoadBalancer"
                         :Properties
                           {:Scheme "internet-facing"
                            :Type "application"
                            :Subnets [subnet-id]
                            :SecurityGroups [sg-id]}}}})))))

;; Store CloudFormation template in S3
(setv cf-template-object
  (aws.s3.BucketObject "cf-template"
    :bucket (. main-bucket id)
    :key f"{environment}/cloudformation-template.json"
    :content cloudformation-template
    :content-type "application/json"))

;; 8. Apply for mathematical operations
(setv storage-requirements
  (-> instance-count
      (.apply (fn [count]
                {:ebs-volume-size (* count 20)  ;; 20GB per instance
                 :backup-retention (* count 7)  ;; 7 days per instance
                 :log-retention (min (* count 30) 90)  ;; Max 90 days
                 :total-cost (* count 0.10)}))))  ;; $0.10 per instance per hour

;; 9. Apply for URL construction
(setv api-endpoints
  (-> (pulumi.Output.all 
        (. main-bucket bucket)
        (. main-bucket region))
      (.apply (fn [vals]
                (setv [bucket-name region] vals)
                {:s3-url f"https://{bucket-name}.s3.{region}.amazonaws.com"
                 :cloudformation-url f"https://{bucket-name}.s3.{region}.amazonaws.com/{environment}/cloudformation-template.json"
                 :app-health-check f"https://{bucket-name}.s3-website-{region}.amazonaws.com/health"
                 :metrics-endpoint f"https://cloudwatch.{region}.amazonaws.com/metrics/{app-name}"}))))

;; 10. Apply for conditional resource properties
(setv monitoring-config
  (-> (pulumi.Output.of environment)
      (.apply (fn [env]
                (cond
                  [(= env "prod")
                   {:detailed-monitoring True
                    :log-level "WARN"
                    :metrics-interval 60
                    :retention-days 90}]
                  [(= env "staging")
                   {:detailed-monitoring True
                    :log-level "INFO"
                    :metrics-interval 300
                    :retention-days 30}]
                  [True
                   {:detailed-monitoring False
                    :log-level "DEBUG"
                    :metrics-interval 900
                    :retention-days 7}])))))

;; CloudWatch Log Group with dynamic retention
(setv app-log-group
  (aws.cloudwatch.LogGroup "app-logs"
    :name (-> (. random-suffix hex)
              (.apply (fn [hex-val]
                        f"/aws/application/{app-name}-{environment}-{hex-val}")))
    :retention-in-days (-> monitoring-config
                           (.apply (fn [config]
                                     (get config :retention-days))))))

;; 11. Apply for array transformations
(setv availability-zones
  (aws.get-availability-zones :state "available"))

(setv multi-az-subnets
  (-> (pulumi.Output.all 
        (. vpc id)
        (. availability-zones names))
      (.apply (fn [vals]
                (setv [vpc-id az-names] vals)
                (list-comp
                  {:cidr f"10.0.{(+ i 10)}.0/24"
                   :az (get az-names i)
                   :name f"{app-name}-subnet-{i}"}
                  [i (range (min (len az-names) 3))])))))

;; Create actual subnets from the applied transformation
(setv subnet-resources
  (-> multi-az-subnets
      (.apply (fn [subnet-configs]
                (for [config subnet-configs]
                  (aws.ec2.Subnet (get config :name)
                    :vpc-id (. vpc id)
                    :cidr-block (get config :cidr)
                    :availability-zone (get config :az)
                    :map-public-ip-on-launch True
                    :tags {:Name (get config :name)
                           :Type "public"}))))))

;; 12. Apply for resource tagging
(setv common-tags
  (-> (pulumi.Output.all 
        app-name
        environment
        (. random-suffix hex))
      (.apply (fn [vals]
                (setv [app env suffix] vals)
                {:Application app
                 :Environment env
                 :ManagedBy "Pulumi"
                 :CreatedWith "Hy"
                 :ResourceGroup f"{app}-{env}-{suffix}"
                 :CostCenter (cond
                               [(= env "prod") "production"]
                               [(= env "staging") "development"]
                               [True "experimental"])
                 :Owner "platform-team"
                 :Project "pulumi-lab"})))))

;; Export complex transformations
(pulumi.export "transformations-demo"
  {:formatted-bucket-name formatted-bucket-name
   :instance-configuration {:type instance-type
                           :count instance-count}
   :storage-requirements storage-requirements
   :api-endpoints api-endpoints
   :monitoring-config monitoring-config
   :common-tags common-tags})

;; Export apply() examples
(pulumi.export "apply-examples"
  {:string-manipulation "formatted-bucket-name uses hex transformation"
   :json-creation "iam-policy-document builds JSON from outputs"
   :conditional-logic "instance-type varies by environment"
   :data-encoding "user-data-script encodes bash script"
   :mathematical-ops "storage-requirements calculates based on count"
   :url-construction "api-endpoints builds URLs from resource properties"
   :array-processing "multi-az-subnets creates subnet configurations"})

;; Export best practices
(pulumi.export "apply-best-practices"
  {:when-to-use ["Transform output values"
                 "Combine multiple outputs"
                 "Create derived resources"
                 "Conditional resource properties"]
   :patterns ["Use pulumi.Output.all() for multiple inputs"
              "Keep apply functions pure (no side effects)"
              "Handle errors gracefully"
              "Minimize nesting of apply calls"]
   :performance ["Combine operations in single apply"
                 "Avoid unnecessary transformations"
                 "Cache complex calculations"]
   :debugging ["Use print statements in apply functions"
              "Test transformations with known values"
              "Validate output types and formats"]})
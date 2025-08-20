;; Resource naming patterns in Hy
;; Based on https://www.pulumi.com/docs/iac/concepts/resources/names/

(import pulumi)
(import [pulumi-aws :as aws])

;; Simple resource naming
(setv my-role (aws.iam.Role "my-role"))

;; Naming with configuration
(setv config (pulumi.Config))
(setv app-name (config.get "app-name" "workshop"))
(setv environment (pulumi.get-stack))

;; Function to create consistent names
(defn resource-name [resource-type name]
  "Create consistent resource names"
  f"{app-name}-{environment}-{resource-type}-{name}")

;; Function to create tags
(defn default-tags [resource-name &optional [additional-tags {}]]
  "Create default tags for resources"
  (| {:Name resource-name
      :Environment environment
      :Application app-name
      :ManagedBy "Pulumi"
      :Project "pulumi-lab"}
     additional-tags))

;; IAM Roles with consistent naming
(setv lambda-role
  (aws.iam.Role (resource-name "role" "lambda")
    :assume-role-policy (pulumi.Output.json-stringify
      {:Version "2012-10-17"
       :Statement [{:Action "sts:AssumeRole"
                    :Principal {:Service "lambda.amazonaws.com"}
                    :Effect "Allow"}]})
    :tags (default-tags (resource-name "role" "lambda")
                        {:ResourceType "IAM Role"
                         :Purpose "Lambda Execution"})))

(setv ec2-role
  (aws.iam.Role (resource-name "role" "ec2")
    :assume-role-policy (pulumi.Output.json-stringify
      {:Version "2012-10-17"
       :Statement [{:Action "sts:AssumeRole"
                    :Principal {:Service "ec2.amazonaws.com"}
                    :Effect "Allow"}]})
    :tags (default-tags (resource-name "role" "ec2")
                        {:ResourceType "IAM Role"
                         :Purpose "EC2 Instance Profile"})))

;; Instance profiles
(setv ec2-instance-profile
  (aws.iam.InstanceProfile (resource-name "profile" "ec2")
    :role (. ec2-role name)
    :tags (default-tags (resource-name "profile" "ec2"))))

;; Policy attachments with descriptive names
(setv lambda-basic-execution
  (aws.iam.RolePolicyAttachment (resource-name "attachment" "lambda-basic")
    :role (. lambda-role name)
    :policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"))

(setv ec2-ssm-managed
  (aws.iam.RolePolicyAttachment (resource-name "attachment" "ec2-ssm")
    :role (. ec2-role name)
    :policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"))

;; S3 Buckets with unique names
(setv data-bucket
  (aws.s3.BucketV2 (resource-name "bucket" "data")
    :tags (default-tags (resource-name "bucket" "data")
                        {:ResourceType "S3 Bucket"
                         :Purpose "Application Data Storage"})))

(setv logs-bucket
  (aws.s3.BucketV2 (resource-name "bucket" "logs")
    :tags (default-tags (resource-name "bucket" "logs")
                        {:ResourceType "S3 Bucket"
                         :Purpose "Application Logs"})))

;; CloudWatch Log Groups
(setv app-log-group
  (aws.cloudwatch.LogGroup (resource-name "logs" "application")
    :name f"/aws/application/{(resource-name \"logs\" \"application\")}"
    :retention-in-days 30
    :tags (default-tags (resource-name "logs" "application"))))

(setv lambda-log-group
  (aws.cloudwatch.LogGroup (resource-name "logs" "lambda")
    :name f"/aws/lambda/{(resource-name \"function\" \"processor\")}"
    :retention-in-days 14
    :tags (default-tags (resource-name "logs" "lambda"))))

;; Security Groups with descriptive names
(setv web-sg
  (aws.ec2.SecurityGroup (resource-name "sg" "web")
    :name-prefix f"{(resource-name \"sg\" \"web\")}-"
    :description "Security group for web servers"
    :ingress [{:protocol "tcp"
               :from-port 80
               :to-port 80
               :cidr-blocks ["0.0.0.0/0"]}
              {:protocol "tcp"
               :from-port 443
               :to-port 443
               :cidr-blocks ["0.0.0.0/0"]}]
    :egress [{:protocol "-1"
              :from-port 0
              :to-port 0
              :cidr-blocks ["0.0.0.0/0"]}]
    :tags (default-tags (resource-name "sg" "web")
                        {:ResourceType "Security Group"
                         :Purpose "Web Server Access"})))

(setv database-sg
  (aws.ec2.SecurityGroup (resource-name "sg" "database")
    :name-prefix f"{(resource-name \"sg\" \"database\")}-"
    :description "Security group for database servers"
    :ingress [{:protocol "tcp"
               :from-port 5432
               :to-port 5432
               :security-groups [(. web-sg id)]}]
    :tags (default-tags (resource-name "sg" "database")
                        {:ResourceType "Security Group"
                         :Purpose "Database Access"})))

;; Lambda Functions with versioning
(setv processor-function
  (aws.lambda.Function (resource-name "function" "processor")
    :role (. lambda-role arn)
    :code (pulumi.FileArchive "./lambda.zip")
    :handler "index.handler"
    :runtime "python3.9"
    :timeout 30
    :memory-size 256
    :environment {:variables {:ENVIRONMENT environment
                              :APP_NAME app-name
                              :LOG_LEVEL "INFO"}}
    :tags (default-tags (resource-name "function" "processor")
                        {:ResourceType "Lambda Function"
                         :Purpose "Data Processing"})))

;; CloudWatch Alarms with descriptive names
(setv lambda-error-alarm
  (aws.cloudwatch.MetricAlarm (resource-name "alarm" "lambda-errors")
    :alarm-name (resource-name "alarm" "lambda-errors")
    :alarm-description f"High error rate for {(resource-name \"function\" \"processor\")}"
    :metric-name "Errors"
    :namespace "AWS/Lambda"
    :statistic "Sum"
    :period 300
    :evaluation-periods 2
    :threshold 5
    :comparison-operator "GreaterThanThreshold"
    :dimensions {:FunctionName (. processor-function function-name)}
    :tags (default-tags (resource-name "alarm" "lambda-errors"))))

;; SNS Topics for notifications
(setv alert-topic
  (aws.sns.Topic (resource-name "topic" "alerts")
    :name (resource-name "topic" "alerts")
    :display-name f"Alerts for {app-name} {environment}"
    :tags (default-tags (resource-name "topic" "alerts")
                        {:ResourceType "SNS Topic"
                         :Purpose "Alert Notifications"})))

;; Auto Scaling Groups with detailed naming
(setv web-asg
  (aws.autoscaling.Group (resource-name "asg" "web")
    :name (resource-name "asg" "web")
    :min-size 1
    :max-size 5
    :desired-capacity 2
    :health-check-type "ELB"
    :health-check-grace-period 300
    :tags [{:key "Name"
            :value (resource-name "asg" "web")
            :propagate-at-launch True}
           {:key "Environment"
            :value environment
            :propagate-at-launch True}
           {:key "Application"
            :value app-name
            :propagate-at-launch True}]))

;; Export naming utilities for other modules
(pulumi.export "naming-pattern" (resource-name "type" "name"))
(pulumi.export "app-name" app-name)
(pulumi.export "environment" environment)

;; Export resource ARNs and names
(pulumi.export "lambda-role-arn" (. lambda-role arn))
(pulumi.export "ec2-role-arn" (. ec2-role arn))
(pulumi.export "data-bucket-name" (. data-bucket bucket))
(pulumi.export "logs-bucket-name" (. logs-bucket bucket))
(pulumi.export "processor-function-name" (. processor-function function-name))
(pulumi.export "web-sg-id" (. web-sg id))
(pulumi.export "database-sg-id" (. database-sg id))

;; Export naming convention documentation
(pulumi.export "naming-convention"
  {:pattern "{app-name}-{environment}-{resource-type}-{name}"
   :example (resource-name "bucket" "data")
   :components {:app-name "Application identifier"
                :environment "Stack/environment name"
                :resource-type "AWS resource type"
                :name "Specific resource identifier"}})
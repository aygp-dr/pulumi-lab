;; Configuration Management patterns in Hy
;; Based on https://www.pulumi.com/docs/iac/concepts/config/

(import pulumi)
(import [pulumi-aws :as aws])
(import [pulumi-random :as random])
(import json)

;; 1. Basic Configuration Access
(setv config (pulumi.Config))
(setv app-config (pulumi.Config "app"))
(setv aws-config (pulumi.Config "aws"))

;; Basic configuration values
(setv app-name (config.get "app-name" "workshop"))
(setv environment (pulumi.get-stack))
(setv region (aws-config.get "region" "us-west-2"))

;; 2. Typed Configuration Values
(setv instance-count (config.get-int "instance-count" 1))
(setv enable-monitoring (config.get-bool "enable-monitoring" False))
(setv budget-limit (config.get-float "budget-limit" 100.0))

;; 3. Required Configuration (will fail if not provided)
(setv domain-name (config.require "domain-name"))
(setv notification-email (config.require "notification-email"))

;; 4. Secret Configuration
(setv database-password (config.require-secret "database-password"))
(setv api-key (config.get-secret "api-key"))
(setv ssl-certificate (config.get-secret "ssl-certificate"))

;; 5. Object Configuration
(setv database-config 
  (app-config.get-object "database" 
    {:engine "postgres"
     :version "14"
     :instance-class "db.t3.micro"
     :storage 20}))

(setv monitoring-config
  (app-config.get-object "monitoring"
    {:retention-days 30
     :detailed-monitoring False
     :log-level "INFO"
     :metrics-enabled True}))

;; 6. Array Configuration
(setv allowed-cidrs 
  (config.get-object "allowed-cidrs" 
    ["10.0.0.0/8" "172.16.0.0/12"]))

(setv backup-schedules
  (config.get-object "backup-schedules"
    ["0 2 * * *"   ;; Daily at 2 AM
     "0 2 * * 0"]))  ;; Weekly on Sunday at 2 AM

;; 7. Environment-Specific Defaults
(defn get-env-default [key defaults]
  "Get configuration with environment-specific defaults"
  (config.get key (get defaults environment (get defaults "default"))))

(setv instance-type
  (get-env-default "instance-type"
    {"prod" "t3.large"
     "staging" "t3.medium"
     "default" "t3.micro"}))

(setv max-instances
  (config.get-int "max-instances"
    (cond
      [(= environment "prod") 10]
      [(= environment "staging") 5]
      [True 2])))

;; 8. Conditional Configuration
(setv backup-enabled 
  (config.get-bool "backup-enabled" 
    (in environment ["prod" "staging"])))

(setv encryption-enabled
  (config.get-bool "encryption-enabled"
    (= environment "prod")))

;; 9. Configuration Validation
(defn validate-config []
  "Validate configuration values"
  (setv errors [])
  
  ;; Validate instance count
  (when (or (< instance-count 1) (> instance-count max-instances))
    (.append errors f"instance-count must be between 1 and {max-instances}"))
  
  ;; Validate domain name format
  (when (not (and domain-name (.endswith domain-name ".com")))
    (.append errors "domain-name must end with .com"))
  
  ;; Validate email format
  (when (not (in "@" notification-email))
    (.append errors "notification-email must be a valid email address"))
  
  ;; Validate budget
  (when (< budget-limit 0)
    (.append errors "budget-limit must be positive"))
  
  (when errors
    (raise (Exception f"Configuration validation failed: {(', '.join errors)}")))
  
  True)

;; Run validation
(validate-config)

;; 10. Configuration-Driven Resource Creation
(setv random-suffix
  (random.RandomId "suffix"
    :byte-length 4))

;; VPC with configuration-driven CIDR
(setv vpc-cidr (config.get "vpc-cidr" "10.0.0.0/16"))
(setv vpc
  (aws.ec2.Vpc "main-vpc"
    :cidr-block vpc-cidr
    :enable-dns-hostnames True
    :enable-dns-support True
    :tags {:Name f"{app-name}-vpc"
           :Environment environment}))

;; Subnets based on configuration
(setv subnet-configs
  (config.get-object "subnets"
    [{"cidr" "10.0.1.0/24" "type" "public" "az" "a"}
     {"cidr" "10.0.2.0/24" "type" "private" "az" "b"}]))

(setv subnets [])
(for [[i subnet-config] (enumerate subnet-configs)]
  (setv subnet
    (aws.ec2.Subnet f"subnet-{i}"
      :vpc-id (. vpc id)
      :cidr-block (get subnet-config "cidr")
      :availability-zone f"{region}{(get subnet-config \"az\")}"
      :map-public-ip-on-launch (= (get subnet-config "type") "public")
      :tags {:Name f"{app-name}-{(get subnet-config \"type\")}-{i}"
             :Type (get subnet-config "type")
             :Environment environment}))
  (.append subnets subnet))

;; Database with configuration
(setv database
  (aws.rds.Instance "app-database"
    :identifier f"{app-name}-{environment}-db"
    :engine (get database-config "engine")
    :engine-version (get database-config "version")
    :instance-class (get database-config "instance-class")
    :allocated-storage (get database-config "storage")
    :db-name (.replace app-name "-" "")
    :username "admin"
    :password database-password
    :storage-encrypted encryption-enabled
    :backup-retention-period (if backup-enabled 7 0)
    :skip-final-snapshot (not backup-enabled)
    :tags {:Name f"{app-name}-database"
           :Environment environment}))

;; CloudWatch Log Group with configuration
(setv log-group
  (aws.cloudwatch.LogGroup "app-logs"
    :name f"/aws/application/{app-name}-{environment}"
    :retention-in-days (get monitoring-config "retention-days")))

;; Security Group with configured CIDR blocks
(setv security-group
  (aws.ec2.SecurityGroup "app-sg"
    :vpc-id (. vpc id)
    :description f"Security group for {app-name}"
    :ingress (list-comp
               {:protocol "tcp"
                :from-port 443
                :to-port 443
                :cidr-blocks [cidr]}
               [cidr allowed-cidrs])
    :egress [{:protocol "-1"
              :from-port 0
              :to-port 0
              :cidr-blocks ["0.0.0.0/0"]}]
    :tags {:Name f"{app-name}-sg"
           :Environment environment}))

;; Auto Scaling Group with configuration
(setv launch-template
  (aws.ec2.LaunchTemplate "app-template"
    :image-id "ami-0c02fb55956c7d316"
    :instance-type instance-type
    :vpc-security-group-ids [(. security-group id)]
    :monitoring {:enabled (get monitoring-config "detailed-monitoring")}
    :tag-specifications [{:resource-type "instance"
                          :tags {:Name f"{app-name}-instance"
                                 :Environment environment
                                 :Application app-name}}]))

(setv auto-scaling-group
  (aws.autoscaling.Group "app-asg"
    :min-size 1
    :max-size max-instances
    :desired-capacity instance-count
    :vpc-zone-identifiers (list-comp (. subnet id) [subnet subnets])
    :launch-template {:id (. launch-template id)
                      :version "$Latest"}
    :health-check-type "EC2"
    :health-check-grace-period 300
    :tags [{:key "Name"
            :value f"{app-name}-asg"
            :propagate-at-launch True}]))

;; SNS Topic for notifications
(setv notification-topic
  (aws.sns.Topic "notifications"
    :name f"{app-name}-{environment}-notifications"
    :display-name f"{app-name} Notifications"))

(setv email-subscription
  (aws.sns.TopicSubscription "email-notification"
    :topic-arn (. notification-topic arn)
    :protocol "email"
    :endpoint notification-email))

;; CloudWatch Alarms based on configuration
(when (get monitoring-config "metrics-enabled")
  (setv cpu-alarm
    (aws.cloudwatch.MetricAlarm "high-cpu"
      :alarm-name f"{app-name}-{environment}-high-cpu"
      :alarm-description "High CPU utilization"
      :metric-name "CPUUtilization"
      :namespace "AWS/EC2"
      :statistic "Average"
      :period 300
      :evaluation-periods 2
      :threshold 80
      :comparison-operator "GreaterThanThreshold"
      :alarm-actions [(. notification-topic arn)]
      :dimensions {:AutoScalingGroupName (. auto-scaling-group name)})))

;; Backup Configuration
(when backup-enabled
  (setv backup-vault
    (aws.backup.Vault "app-backup-vault"
      :name f"{app-name}-{environment}-vault"
      :kms-key-id "alias/aws/backup"))
  
  (setv backup-plan
    (aws.backup.Plan "app-backup-plan"
      :name f"{app-name}-{environment}-plan"
      :rules (list-comp
               {:rule-name f"backup-{i}"
                :target-vault-name (. backup-vault name)
                :schedule schedule
                :start-window 60
                :completion-window 300
                :lifecycle {:delete-after 30}}
               [[i schedule] (enumerate backup-schedules)]))))

;; 11. Configuration Summary Export
(pulumi.export "configuration-summary"
  {:app-name app-name
   :environment environment
   :region region
   :instance-count instance-count
   :instance-type instance-type
   :max-instances max-instances
   :monitoring-enabled (get monitoring-config "metrics-enabled")
   :backup-enabled backup-enabled
   :encryption-enabled encryption-enabled
   :domain-name domain-name
   :notification-email notification-email})

;; 12. Database Configuration Export
(pulumi.export "database-configuration"
  {:endpoint (. database endpoint)
   :port (. database port)
   :engine (get database-config "engine")
   :version (get database-config "version")
   :instance-class (get database-config "instance-class")
   :storage-size (get database-config "storage")
   :encrypted encryption-enabled
   :backup-enabled backup-enabled})

;; 13. Network Configuration Export
(pulumi.export "network-configuration"
  {:vpc-id (. vpc id)
   :vpc-cidr vpc-cidr
   :subnet-count (len subnets)
   :subnet-ids (list-comp (. subnet id) [subnet subnets])
   :allowed-cidrs allowed-cidrs
   :security-group-id (. security-group id)})

;; 14. Monitoring Configuration Export
(pulumi.export "monitoring-configuration"
  {:log-group-name (. log-group name)
   :log-retention-days (get monitoring-config "retention-days")
   :detailed-monitoring (get monitoring-config "detailed-monitoring")
   :metrics-enabled (get monitoring-config "metrics-enabled")
   :notification-topic-arn (. notification-topic arn)})

;; 15. Configuration Best Practices Export
(pulumi.export "configuration-best-practices"
  {:organization "Use hierarchical configuration (app:database:engine)"
   :environments "Provide environment-specific defaults"
   :secrets "Always use secret configuration for sensitive data"
   :validation "Validate configuration values early"
   :documentation "Document all configuration options in Pulumi.yaml"
   :defaults "Provide sensible defaults for optional values"
   :typing "Use typed accessors (get-int, get-bool, etc.)"})

;; 16. Sample Configuration Files Export
(pulumi.export "sample-configurations"
  {:development {:instance-count 1
                 :instance-type "t3.micro"
                 :enable-monitoring False
                 :backup-enabled False
                 :budget-limit 50.0}
   :staging {:instance-count 2
             :instance-type "t3.small"
             :enable-monitoring True
             :backup-enabled True
             :budget-limit 200.0}
   :production {:instance-count 3
                :instance-type "t3.large"
                :enable-monitoring True
                :backup-enabled True
                :budget-limit 1000.0
                :encryption-enabled True}})
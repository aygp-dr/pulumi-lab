;; Project configuration and stack settings in Hy

(import pulumi)
(import [pulumi-aws :as aws])
(import json)

;; Get configuration values
(setv config (pulumi.Config))
(setv app-config (pulumi.Config "app"))

;; Basic configuration
(setv app-name (app-config.get "name"))
(setv instance-count (app-config.get-int "instanceCount"))
(setv enable-logging (app-config.get-bool "enableLogging"))

;; Object configuration
(setv db-config (app-config.get-object "database"))
(setv db-engine (get db-config "engine"))
(setv db-version (get db-config "version"))
(setv db-instance-class (get db-config "instanceClass"))

;; Array configuration
(setv allowed-cidrs (app-config.get-object "allowedCidrs"))

;; Secret configuration
(setv db-password (app-config.get-secret "dbPassword"))

;; Stack reference for cross-stack dependencies
(setv stack-name (pulumi.get-stack))
(setv organization (pulumi.get-organization))

;; Conditional logic based on stack
(setv is-production (= stack-name "prod"))
(setv is-development (= stack-name "dev"))

;; Environment-specific settings
(setv settings 
  (cond
    [is-production {:instance-type "t3.medium"
                   :min-size 2
                   :max-size 10
                   :deletion-protection True}]
    [is-development {:instance-type "t3.micro"
                    :min-size 1
                    :max-size 3
                    :deletion-protection False}]
    [True {:instance-type "t3.small"
           :min-size 1
           :max-size 5
           :deletion-protection False}]))

;; Create VPC based on stack
(setv vpc-cidr
  (cond
    [is-production "10.0.0.0/16"]
    [is-development "10.1.0.0/16"]
    [True "10.2.0.0/16"]))

(setv main-vpc
  (aws.ec2.Vpc f"{app-name}-vpc"
    :cidr-block vpc-cidr
    :enable-dns-hostnames True
    :enable-dns-support True
    :tags {:Name f"{app-name}-vpc"
           :Environment stack-name
           :ManagedBy "Pulumi"}))

;; Security group with dynamic rules
(setv app-sg
  (aws.ec2.SecurityGroup f"{app-name}-sg"
    :name-prefix f"{app-name}-"
    :description f"Security group for {app-name}"
    :vpc-id (. main-vpc id)
    :ingress (list-comp 
               {:protocol "tcp"
                :from-port 80
                :to-port 80
                :cidr-blocks [cidr]}
               [cidr allowed-cidrs])
    :egress [{:protocol "-1"
              :from-port 0
              :to-port 0
              :cidr-blocks ["0.0.0.0/0"]}]
    :tags {:Name f"{app-name}-sg"
           :Environment stack-name}))

;; RDS database with configuration
(setv db-subnet-group
  (aws.rds.SubnetGroup f"{app-name}-db-subnet"
    :subnet-ids [] ;; Would use actual subnet IDs
    :tags {:Name f"{app-name}-db-subnet"}))

(setv database
  (aws.rds.Instance f"{app-name}-db"
    :engine db-engine
    :engine-version db-version
    :instance-class db-instance-class
    :allocated-storage 20
    :db-name app-name
    :username "admin"
    :password db-password
    :vpc-security-group-ids [(. app-sg id)]
    :db-subnet-group-name (. db-subnet-group name)
    :skip-final-snapshot (not is-production)
    :deletion-protection (get settings :deletion-protection)
    :backup-retention-period (if is-production 30 7)
    :backup-window "03:00-04:00"
    :maintenance-window "sun:04:00-sun:05:00"
    :tags {:Name f"{app-name}-database"
           :Environment stack-name}))

;; CloudWatch Log Group (conditional)
(when enable-logging
  (setv log-group
    (aws.cloudwatch.LogGroup f"{app-name}-logs"
      :name f"/aws/application/{app-name}"
      :retention-in-days (if is-production 90 30)
      :tags {:Environment stack-name
             :Application app-name})))

;; Auto Scaling Group based on configuration
(setv launch-template
  (aws.ec2.LaunchTemplate f"{app-name}-template"
    :image-id "ami-0c02fb55956c7d316"  ;; Amazon Linux 2
    :instance-type (get settings :instance-type)
    :security-group-names [(. app-sg name)]
    :user-data (pulumi.Output.concat
      "#!/bin/bash\n"
      "yum update -y\n"
      f"echo 'Application: {app-name}' > /var/log/app-info.log\n"
      f"echo 'Environment: {stack-name}' >> /var/log/app-info.log\n"
      f"echo 'Instance Count: {instance-count}' >> /var/log/app-info.log\n")
    :tags {:Name f"{app-name}-template"
           :Environment stack-name}))

;; Configuration-driven outputs
(setv output-map
  {:app-name app-name
   :environment stack-name
   :instance-count instance-count
   :vpc-id (. main-vpc id)
   :vpc-cidr (. main-vpc cidr-block)
   :database-endpoint (. database endpoint)
   :security-group-id (. app-sg id)
   :settings settings})

;; Conditional outputs
(when enable-logging
  (assoc output-map :log-group-name (. log-group name)))

;; Export all configuration
(for [[key value] (.items output-map)]
  (pulumi.export (name key) value))

;; Export configuration summary
(pulumi.export "configuration-summary"
  {:database {:engine db-engine
              :version db-version
              :class db-instance-class}
   :network {:allowed-cidrs allowed-cidrs
             :vpc-cidr vpc-cidr}
   :compute {:instance-type (get settings :instance-type)
             :min-size (get settings :min-size)
             :max-size (get settings :max-size)}
   :features {:logging-enabled enable-logging
              :deletion-protection (get settings :deletion-protection)}})

;; Stack tags (applied to all resources)
(pulumi.export "stack-tags"
  {:Project "pulumi-lab"
   :Environment stack-name
   :ManagedBy "Pulumi"
   :Owner "workshop"
   :CostCenter (if is-production "prod-ops" "dev-ops")})
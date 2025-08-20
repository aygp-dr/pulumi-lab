;; Provider Functions for Infrastructure Auditing in Hy
;; Based on https://www.pulumi.com/docs/iac/concepts/functions/provider-functions/

(import pulumi)
(import [pulumi-aws :as aws])
(import json)

;; Configuration
(setv config (pulumi.Config))
(setv environment (pulumi.get-stack))
(setv app-name (config.get "app-name" "workshop"))

;; 1. AWS Account and Caller Identity Audit
(setv caller-identity 
  (aws.get-caller-identity))

(setv account-id (. caller-identity account-id))
(setv user-arn (. caller-identity arn))

;; 2. Regional Availability Zone Audit
(setv availability-zones
  (aws.get-availability-zones 
    :state "available"))

;; 3. VPC and Network Infrastructure Audit
(setv default-vpc
  (aws.ec2.get-vpc
    :default True))

(setv vpc-subnets
  (aws.ec2.get-subnets
    :filters [{:name "vpc-id"
               :values [(. default-vpc id)]}]))

;; 4. Security Group Audit
(setv security-groups
  (aws.ec2.get-security-groups
    :filters [{:name "vpc-id"
               :values [(. default-vpc id)]}]))

;; Filter for potentially risky security groups
(setv open-security-groups
  (aws.ec2.get-security-groups
    :filters [{:name "ip-permission.from-port"
               :values ["22" "80" "443" "3389"]}
              {:name "ip-permission.cidr"
               :values ["0.0.0.0/0"]}]))

;; 5. AMI and Instance Type Audit
(setv amazon-linux-amis
  (aws.ec2.get-ami-ids
    :owners ["amazon"]
    :filters [{:name "name"
               :values ["amzn2-ami-hvm-*"]}
              {:name "architecture"
               :values ["x86_64"]}
              {:name "state"
               :values ["available"]}]
    :sort-ascending False))

;; Get latest Amazon Linux AMI
(setv latest-ami
  (aws.ec2.get-ami
    :most-recent True
    :owners ["amazon"]
    :filters [{:name "name"
               :values ["amzn2-ami-hvm-*"]}
              {:name "architecture"
               :values ["x86_64"]}]))

;; 6. Instance Type Availability Audit
(setv instance-type-offerings
  (aws.ec2.get-instance-type-offerings
    :location-type "availability-zone"))

;; 7. S3 Bucket Policy and Configuration Audit
(setv existing-buckets
  (aws.s3.get-buckets))

;; 8. IAM Policy and Role Audit
(setv current-user-policies
  (aws.iam.get-user-policies
    :user-name (.split (. caller-identity arn) "/")[-1]))

;; Get managed policies attached to current user
(setv user-attached-policies
  (aws.iam.get-attached-user-policies
    :user-name (.split (. caller-identity arn) "/")[-1]))

;; 9. SSL/TLS Certificate Audit
(setv acm-certificates
  (aws.acm.get-certificates
    :statuses ["ISSUED" "PENDING_VALIDATION"]))

;; 10. Route53 Zones and Records Audit
(setv route53-zones
  (aws.route53.get-zones
    :private-zone False))

;; 11. CloudWatch Log Groups Audit
(setv log-groups
  (aws.cloudwatch.get-log-groups))

;; 12. Lambda Functions Audit
(setv lambda-functions
  (aws.lambda.get-functions))

;; 13. RDS Instances and Security Audit
(setv rds-instances
  (aws.rds.get-instances))

(setv rds-snapshots
  (aws.rds.get-snapshots
    :snapshot-type "automated"
    :include-shared False
    :include-public False))

;; 14. EBS Volume and Snapshot Audit
(setv ebs-volumes
  (aws.ebs.get-volumes))

(setv ebs-snapshots
  (aws.ebs.get-snapshots
    :owner-ids [account-id]))

;; 15. KMS Key Audit
(setv kms-keys
  (aws.kms.get-keys))

;; 16. CloudTrail Configuration Audit
(setv cloudtrails
  (aws.cloudtrail.get-trails))

;; 17. Cost and Billing Audit Functions
(setv cost-categories
  (aws.costexplorer.get-cost-categories))

;; 18. Organizations Audit (if applicable)
(setv org-accounts
  (aws.organizations.get-accounts))

;; 19. Compliance and Config Rules Audit
(setv config-rules
  (aws.config.get-rules))

;; 20. Network ACL Audit
(setv network-acls
  (aws.ec2.get-network-acls
    :filters [{:name "vpc-id"
               :values [(. default-vpc id)]}]))

;; 21. Internet Gateway Audit
(setv internet-gateways
  (aws.ec2.get-internet-gateways
    :filters [{:name "attachment.vpc-id"
               :values [(. default-vpc id)]}]))

;; 22. NAT Gateway Audit
(setv nat-gateways
  (aws.ec2.get-nat-gateways
    :vpc-id (. default-vpc id)))

;; 23. ELB/ALB Audit
(setv classic-load-balancers
  (aws.elb.get-load-balancers))

(setv application-load-balancers
  (aws.lb.get-load-balancers
    :load-balancer-type "application"))

;; 24. Auto Scaling Groups Audit
(setv auto-scaling-groups
  (aws.autoscaling.get-groups))

;; 25. ElastiCache Audit
(setv elasticache-clusters
  (aws.elasticache.get-clusters))

;; Create audit summary resource
(setv audit-summary
  (aws.s3.BucketObject "audit-summary"
    :bucket "audit-results-bucket"  ;; Would need to create this bucket first
    :key f"audit-{environment}-{(.strftime (datetime.datetime.now) \"%Y%m%d-%H%M%S\")}.json"
    :content (pulumi.Output.json-stringify
      {:timestamp (.isoformat (.utcnow datetime.datetime))
       :environment environment
       :account-id account-id
       :region (config.get "aws:region")
       :summary {:vpcs 1  ;; Default VPC
                 :subnets (len (. vpc-subnets ids))
                 :security-groups (len (. security-groups ids))
                 :open-security-groups (len (. open-security-groups ids))
                 :s3-buckets (len (. existing-buckets buckets))
                 :log-groups (len (. log-groups log-group-names))
                 :lambda-functions (len (. lambda-functions function-names))
                 :rds-instances (len (. rds-instances instance-identifiers))
                 :ebs-volumes (len (. ebs-volumes ids))
                 :kms-keys (len (. kms-keys keys))
                 :cloudtrails (len (. cloudtrails names))
                 :config-rules (len (. config-rules names))}})
    :content-type "application/json"))

;; Security findings and recommendations
(setv security-findings
  {:open-security-groups (. open-security-groups ids)
   :unencrypted-volumes (list-comp 
                          (. vol id)
                          [vol (. ebs-volumes volumes)]
                          (not (. vol encrypted)))
   :public-buckets []  ;; Would need additional logic to check bucket policies
   :unused-keys []     ;; Would need additional logic to check key usage
   :recommendations ["Enable CloudTrail in all regions"
                     "Encrypt all EBS volumes"
                     "Review security group rules"
                     "Enable Config rules for compliance"
                     "Implement least privilege IAM policies"
                     "Enable MFA for root account"
                     "Regular access key rotation"]})

;; Cost optimization opportunities
(setv cost-optimization
  {:unused-resources {:ebs-snapshots-older-than-30-days []
                      :unattached-ebs-volumes []
                      :unused-elastic-ips []
                      :idle-load-balancers []}
   :rightsizing-opportunities {:oversized-instances []
                               :underutilized-rds []
                               :unused-reserved-instances []}
   :storage-optimization {:infrequent-access-candidates []
                          :glacier-candidates []
                          :lifecycle-policy-missing []}})

;; Compliance audit results
(setv compliance-audit
  {:encryption {:ebs-encryption-enabled False
                :s3-bucket-encryption []
                :rds-encryption []
                :cloudtrail-encryption False}
   :monitoring {:cloudwatch-logs-retention []
                :cloudtrail-enabled (> (len (. cloudtrails names)) 0)
                :config-enabled (> (len (. config-rules names)) 0)
                :vpc-flow-logs-enabled False}
   :access-control {:mfa-enabled False
                    :password-policy-compliant False
                    :unused-iam-users []
                    :overprivileged-roles []}
   :network-security {:security-groups-reviewed False
                      :nacl-rules-reviewed False
                      :public-subnets-justified False}})

;; Export comprehensive audit results
(pulumi.export "infrastructure-audit"
  {:account-info {:account-id account-id
                  :user-arn user-arn
                  :region (config.get "aws:region")}
   :network {:default-vpc-id (. default-vpc id)
             :subnet-count (len (. vpc-subnets ids))
             :availability-zones (. availability-zones names)
             :security-groups-count (len (. security-groups ids))
             :open-security-groups-count (len (. open-security-groups ids))}
   :compute {:latest-ami-id (. latest-ami id)
             :instance-types-available (len (. instance-type-offerings instance-types))
             :auto-scaling-groups (len (. auto-scaling-groups names))}
   :storage {:s3-buckets-count (len (. existing-buckets buckets))
             :ebs-volumes-count (len (. ebs-volumes ids))
             :ebs-snapshots-count (len (. ebs-snapshots ids))}
   :database {:rds-instances-count (len (. rds-instances instance-identifiers))
              :rds-snapshots-count (len (. rds-snapshots db-snapshot-identifiers))
              :elasticache-clusters-count (len (. elasticache-clusters cluster-ids))}
   :security {:kms-keys-count (len (. kms-keys keys))
              :acm-certificates-count (len (. acm-certificates certificates))
              :cloudtrails-count (len (. cloudtrails names))}
   :monitoring {:log-groups-count (len (. log-groups log-group-names))
                :config-rules-count (len (. config-rules names))}
   :serverless {:lambda-functions-count (len (. lambda-functions function-names))}})

(pulumi.export "security-findings" security-findings)
(pulumi.export "cost-optimization" cost-optimization)
(pulumi.export "compliance-audit" compliance-audit)

;; Audit recommendations
(pulumi.export "audit-recommendations"
  {:immediate-actions ["Review and restrict overly permissive security groups"
                       "Enable encryption for unencrypted EBS volumes"
                       "Set up CloudTrail if not already configured"
                       "Review IAM policies for least privilege"]
   :short-term-goals ["Implement comprehensive tagging strategy"
                      "Set up cost monitoring and budgets"
                      "Enable AWS Config for compliance monitoring"
                      "Implement regular access reviews"]
   :long-term-strategy ["Develop disaster recovery plan"
                        "Implement infrastructure as code for all resources"
                        "Set up automated security scanning"
                        "Establish cost optimization review cycle"]})

;; Provider function examples for reference
(pulumi.export "provider-function-examples"
  {:data-sources ["aws.get_caller_identity()"
                  "aws.ec2.get_vpcs()"
                  "aws.s3.get_buckets()" 
                  "aws.iam.get_user_policies()"]
   :use-cases ["Infrastructure discovery"
               "Compliance auditing"
               "Cost optimization"
               "Security assessment"
               "Resource inventory"]
   :best-practices ["Use filters to limit data retrieval"
                    "Cache results when possible"
                    "Handle pagination for large datasets"
                    "Combine multiple data sources for comprehensive audits"]})
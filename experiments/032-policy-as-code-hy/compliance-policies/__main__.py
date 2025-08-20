"""
Pulumi AWS Compliance-Ready Policies Integration
Demonstrates using @pulumi/aws-compliance-policies package
"""

from pulumi_policy import PolicyPack, EnforcementLevel
import json

# Import common compliance policies
# Note: In practice, you would install @pulumi/aws-compliance-policies
# npm install @pulumi/aws-compliance-policies

# Simulated compliance-ready policies based on the 93 available policies

# ISO 27001 Compliance Policies
def iso27001_s3_encryption_at_rest(args, report_violation, config):
    """ISO 27001: S3 buckets must have encryption at rest enabled"""
    if args.resource_type == "aws:s3/bucketV2:BucketV2":
        # Check if there's a corresponding encryption configuration
        # This would typically be validated through the policy framework
        report_violation(
            "ISO 27001 Compliance: S3 bucket must have server-side encryption configured",
            EnforcementLevel.MANDATORY
        )

def iso27001_rds_encryption(args, report_violation, config):
    """ISO 27001: RDS instances must have encryption enabled"""
    if args.resource_type == "aws:rds/instance:Instance":
        props = args.get("props", {})
        if not props.get("storageEncrypted", False):
            report_violation(
                "ISO 27001 Compliance: RDS instance storage must be encrypted",
                EnforcementLevel.MANDATORY
            )

# PCI DSS Compliance Policies  
def pcidss_alb_https_only(args, report_violation, config):
    """PCI DSS: Application Load Balancers must use HTTPS"""
    if args.resource_type == "aws:lb/listener:Listener":
        props = args.get("props", {})
        protocol = props.get("protocol", "").upper()
        
        if protocol == "HTTP":
            report_violation(
                "PCI DSS Compliance: Load balancer listeners must use HTTPS to protect cardholder data",
                EnforcementLevel.MANDATORY
            )

def pcidss_no_default_security_groups(args, report_violation, config):
    """PCI DSS: Default security groups should not be used"""
    if args.resource_type == "aws:ec2/securityGroup:SecurityGroup":
        props = args.get("props", {})
        name = props.get("name", "")
        
        if name.lower() == "default":
            report_violation(
                "PCI DSS Compliance: Default security groups should not be used",
                EnforcementLevel.MANDATORY
            )

# HITRUST Compliance Policies
def hitrust_cloudtrail_enabled(args, report_violation, config):
    """HITRUST: CloudTrail must be enabled for audit logging"""
    if args.resource_type == "aws:cloudtrail/trail:Trail":
        props = args.get("props", {})
        
        if not props.get("enableLogging", False):
            report_violation(
                "HITRUST Compliance: CloudTrail logging must be enabled for audit requirements",
                EnforcementLevel.MANDATORY
            )

def hitrust_s3_logging_enabled(args, report_violation, config):
    """HITRUST: S3 bucket access logging must be enabled"""
    if args.resource_type == "aws:s3/bucketLoggingV2:BucketLoggingV2":
        # This policy would check for logging configuration
        # Implementation details depend on the resource structure
        pass

# SOC 2 Compliance Policies
def soc2_lambda_environment_encryption(args, report_violation, config):
    """SOC 2: Lambda environment variables must be encrypted"""
    if args.resource_type == "aws:lambda/function:Function":
        props = args.get("props", {})
        kms_key_arn = props.get("kmsKeyArn")
        
        # Check if environment variables exist but no KMS key is specified
        environment = props.get("environment", {})
        variables = environment.get("variables", {})
        
        if variables and not kms_key_arn:
            report_violation(
                "SOC 2 Compliance: Lambda environment variables must be encrypted with KMS",
                EnforcementLevel.MANDATORY
            )

def soc2_rds_backup_retention(args, report_violation, config):
    """SOC 2: RDS instances must have backup retention for data availability"""
    if args.resource_type == "aws:rds/instance:Instance":
        props = args.get("props", {})
        retention = props.get("backupRetentionPeriod", 0)
        
        if retention < 7:  # Minimum 7 days for SOC 2
            report_violation(
                "SOC 2 Compliance: RDS instances must have backup retention period of at least 7 days",
                EnforcementLevel.MANDATORY
            )

# GDPR Compliance Policies
def gdpr_s3_versioning_for_data_protection(args, report_violation, config):
    """GDPR: S3 buckets must have versioning for data protection"""
    if args.resource_type == "aws:s3/bucketVersioningV2:BucketVersioningV2":
        props = args.get("props", {})
        versioning_config = props.get("versioningConfiguration", {})
        
        if versioning_config.get("status") != "Enabled":
            report_violation(
                "GDPR Compliance: S3 bucket versioning must be enabled for data protection and recovery",
                EnforcementLevel.MANDATORY
            )

def gdpr_data_encryption_in_transit(args, report_violation, config):
    """GDPR: Data must be encrypted in transit"""
    if args.resource_type == "aws:lb/listener:Listener":
        props = args.get("props", {})
        protocol = props.get("protocol", "").upper()
        port = props.get("port", 80)
        
        if protocol == "HTTP" and port != 80:  # Allow HTTP on port 80 for redirects
            report_violation(
                "GDPR Compliance: Data transmission must be encrypted (use HTTPS)",
                EnforcementLevel.MANDATORY
            )

# NIST Cybersecurity Framework
def nist_multi_factor_authentication(args, report_violation, config):
    """NIST: IAM users should have MFA enabled"""
    if args.resource_type == "aws:iam/user:User":
        # This would typically check for MFA device attachment
        # Simplified for demonstration
        report_violation(
            "NIST Cybersecurity Framework: IAM users should have multi-factor authentication enabled",
            EnforcementLevel.ADVISORY
        )

def nist_network_segmentation(args, report_violation, config):
    """NIST: Network access should be segmented"""
    if args.resource_type == "aws:ec2/securityGroup:SecurityGroup":
        props = args.get("props", {})
        ingress_rules = props.get("ingressRules", [])
        
        for rule in ingress_rules:
            cidr = rule.get("cidrIpv4", "")
            if cidr == "0.0.0.0/0":
                from_port = rule.get("fromPort", 0)
                to_port = rule.get("toPort", 65535)
                
                if from_port == 0 and to_port == 65535:
                    report_violation(
                        "NIST Cybersecurity Framework: Network access should be segmented, avoid unrestricted access",
                        EnforcementLevel.MANDATORY
                    )

# Create compliance policy pack
compliance_policies = PolicyPack(
    name="aws-compliance-policies",
    policies=[
        # ISO 27001 Policies
        {
            "name": "iso27001-s3-encryption-at-rest",
            "description": "ISO 27001: S3 buckets must have encryption at rest",
            "validate": iso27001_s3_encryption_at_rest,
            "compliance_frameworks": ["ISO 27001"],
            "severity": "critical",
            "topics": ["encryption", "data-protection"]
        },
        {
            "name": "iso27001-rds-encryption", 
            "description": "ISO 27001: RDS instances must have encryption enabled",
            "validate": iso27001_rds_encryption,
            "compliance_frameworks": ["ISO 27001"],
            "severity": "critical", 
            "topics": ["encryption", "database-security"]
        },
        
        # PCI DSS Policies
        {
            "name": "pcidss-alb-https-only",
            "description": "PCI DSS: Application Load Balancers must use HTTPS",
            "validate": pcidss_alb_https_only,
            "compliance_frameworks": ["PCI DSS"],
            "severity": "high",
            "topics": ["network-security", "encryption-in-transit"]
        },
        {
            "name": "pcidss-no-default-security-groups",
            "description": "PCI DSS: Default security groups should not be used", 
            "validate": pcidss_no_default_security_groups,
            "compliance_frameworks": ["PCI DSS"],
            "severity": "medium",
            "topics": ["network-security", "access-control"]
        },
        
        # HITRUST Policies
        {
            "name": "hitrust-cloudtrail-enabled",
            "description": "HITRUST: CloudTrail must be enabled for audit logging",
            "validate": hitrust_cloudtrail_enabled,
            "compliance_frameworks": ["HITRUST"],
            "severity": "high",
            "topics": ["logging", "audit", "monitoring"]
        },
        
        # SOC 2 Policies
        {
            "name": "soc2-lambda-environment-encryption",
            "description": "SOC 2: Lambda environment variables must be encrypted",
            "validate": soc2_lambda_environment_encryption,
            "compliance_frameworks": ["SOC 2"],
            "severity": "medium",
            "topics": ["encryption", "serverless-security"]
        },
        {
            "name": "soc2-rds-backup-retention",
            "description": "SOC 2: RDS instances must have backup retention",
            "validate": soc2_rds_backup_retention,
            "compliance_frameworks": ["SOC 2"], 
            "severity": "medium",
            "topics": ["backup", "data-availability"]
        },
        
        # GDPR Policies
        {
            "name": "gdpr-s3-versioning-data-protection",
            "description": "GDPR: S3 buckets must have versioning for data protection",
            "validate": gdpr_s3_versioning_for_data_protection,
            "compliance_frameworks": ["GDPR"],
            "severity": "high",
            "topics": ["data-protection", "versioning"]
        },
        {
            "name": "gdpr-data-encryption-in-transit",
            "description": "GDPR: Data must be encrypted in transit",
            "validate": gdpr_data_encryption_in_transit,
            "compliance_frameworks": ["GDPR"],
            "severity": "high",
            "topics": ["encryption-in-transit", "data-protection"]
        },
        
        # NIST Cybersecurity Framework
        {
            "name": "nist-multi-factor-authentication",
            "description": "NIST: IAM users should have MFA enabled",
            "validate": nist_multi_factor_authentication,
            "compliance_frameworks": ["NIST Cybersecurity Framework"],
            "severity": "medium",
            "topics": ["access-control", "multi-factor-authentication"]
        },
        {
            "name": "nist-network-segmentation",
            "description": "NIST: Network access should be segmented",
            "validate": nist_network_segmentation,
            "compliance_frameworks": ["NIST Cybersecurity Framework"],
            "severity": "high",
            "topics": ["network-security", "segmentation"]
        }
    ]
)
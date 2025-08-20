"""
Pulumi CrossGuard Policy Pack
Comprehensive security and compliance policies for AWS resources
"""

from pulumi_policy import (
    PolicyPack,
    ReportViolation, 
    EnforcementLevel,
    ResourceValidationPolicy,
    StackValidationPolicy,
    PolicyConfigSchema
)
from typing import Dict, Any, Optional
import re


# Configuration schema
config_schema = PolicyConfigSchema(
    properties={
        "enforcement-level": {
            "type": "string",
            "enum": ["advisory", "mandatory"],
            "default": "mandatory"
        },
        "max-s3-buckets": {
            "type": "number",
            "default": 5
        },
        "require-https": {
            "type": "boolean", 
            "default": True
        },
        "require-encryption": {
            "type": "boolean",
            "default": True
        }
    }
)


def get_enforcement_level(config: Dict[str, Any]) -> EnforcementLevel:
    """Get enforcement level from config"""
    level = config.get("enforcement-level", "mandatory")
    return EnforcementLevel.MANDATORY if level == "mandatory" else EnforcementLevel.ADVISORY


# S3 Security Policies
def s3_bucket_public_access_block(args, report_violation, config):
    """S3 buckets should have public access blocked"""
    if args.resource_type == "aws:s3/bucketPublicAccessBlock:BucketPublicAccessBlock":
        props = args.get("props", {})
        
        violations = []
        if not props.get("blockPublicAcls", True):
            violations.append("blockPublicAcls should be true")
        if not props.get("blockPublicPolicy", True):
            violations.append("blockPublicPolicy should be true")
        if not props.get("ignorePublicAcls", True):
            violations.append("ignorePublicAcls should be true")
        if not props.get("restrictPublicBuckets", True):
            violations.append("restrictPublicBuckets should be true")
            
        if violations:
            report_violation(
                f"S3 bucket public access block violations: {', '.join(violations)}",
                get_enforcement_level(config)
            )


def s3_bucket_versioning_enabled(args, report_violation, config):
    """S3 buckets should have versioning enabled"""
    if args.resource_type == "aws:s3/bucketVersioningV2:BucketVersioningV2":
        props = args.get("props", {})
        versioning_config = props.get("versioningConfiguration", {})
        
        if versioning_config.get("status") != "Enabled":
            report_violation(
                "S3 bucket should have versioning enabled for data protection",
                get_enforcement_level(config)
            )


def s3_bucket_encryption_required(args, report_violation, config):
    """S3 buckets should have server-side encryption"""
    if not config.get("require-encryption", True):
        return
        
    if args.resource_type == "aws:s3/bucketServerSideEncryptionConfigurationV2:BucketServerSideEncryptionConfigurationV2":
        props = args.get("props", {})
        rules = props.get("rules", [])
        
        if not rules:
            report_violation(
                "S3 bucket must have server-side encryption configured",
                get_enforcement_level(config)
            )
        else:
            for rule in rules:
                apply_config = rule.get("applyServerSideEncryptionByDefault", {})
                if not apply_config.get("sseAlgorithm"):
                    report_violation(
                        "S3 bucket encryption rule must specify SSE algorithm",
                        get_enforcement_level(config)
                    )


# IAM Security Policies
def iam_policy_no_wildcard_actions(args, report_violation, config):
    """IAM policies should not use wildcard actions"""
    if args.resource_type == "aws:iam/policy:Policy":
        props = args.get("props", {})
        policy_doc = props.get("policy")
        
        if policy_doc and isinstance(policy_doc, str):
            import json
            try:
                policy = json.loads(policy_doc)
                statements = policy.get("Statement", [])
                
                if not isinstance(statements, list):
                    statements = [statements]
                    
                for statement in statements:
                    actions = statement.get("Action", [])
                    if not isinstance(actions, list):
                        actions = [actions]
                        
                    for action in actions:
                        if action == "*" or (isinstance(action, str) and "*:*" in action):
                            report_violation(
                                f"IAM policy contains overly permissive action: {action}",
                                EnforcementLevel.MANDATORY
                            )
            except json.JSONDecodeError:
                report_violation(
                    "IAM policy document is not valid JSON",
                    EnforcementLevel.MANDATORY
                )


def iam_role_no_inline_policies(args, report_violation, config):
    """IAM roles should use managed policies instead of inline policies"""
    if args.resource_type == "aws:iam/role:Role":
        props = args.get("props", {})
        inline_policies = props.get("inlinePolicies", [])
        
        if inline_policies:
            report_violation(
                "IAM role should use managed policies instead of inline policies for better governance",
                get_enforcement_level(config)
            )


# Lambda Security Policies  
def lambda_no_hardcoded_secrets(args, report_violation, config):
    """Lambda functions should not have hardcoded secrets in environment variables"""
    if args.resource_type == "aws:lambda/function:Function":
        props = args.get("props", {})
        environment = props.get("environment", {})
        variables = environment.get("variables", {})
        
        # Patterns that suggest secrets
        secret_patterns = [
            r'(?i)(password|pwd|pass)',
            r'(?i)(secret|key|token)', 
            r'(?i)(api[_-]?key)',
            r'sk-[a-zA-Z0-9]{20,}',  # Common API key pattern
            r'(?i)(access[_-]?key)',
            r'(?i)(private[_-]?key)'
        ]
        
        for var_name, var_value in variables.items():
            if isinstance(var_value, str):
                # Check variable name
                for pattern in secret_patterns:
                    if re.search(pattern, var_name):
                        report_violation(
                            f"Lambda function environment variable '{var_name}' appears to contain a secret. Use AWS Secrets Manager or Parameter Store instead.",
                            EnforcementLevel.MANDATORY
                        )
                        break
                        
                # Check for obvious hardcoded values
                if len(var_value) > 10 and any(char.isdigit() for char in var_value) and any(char.isalpha() for char in var_value):
                    for pattern in secret_patterns[:3]:  # Check basic secret patterns in values
                        if re.search(pattern, var_name.lower()):
                            report_violation(
                                f"Lambda function environment variable '{var_name}' appears to contain a hardcoded secret",
                                EnforcementLevel.MANDATORY
                            )


def lambda_reasonable_timeout(args, report_violation, config):
    """Lambda functions should have reasonable timeout values"""
    if args.resource_type == "aws:lambda/function:Function":
        props = args.get("props", {})
        timeout = props.get("timeout", 3)
        
        if timeout > 300:  # 5 minutes
            report_violation(
                f"Lambda function timeout ({timeout}s) is excessive. Consider if this is necessary.",
                get_enforcement_level(config)
            )


# Load Balancer Security Policies
def alb_listener_https_only(args, report_violation, config):
    """ALB listeners should use HTTPS"""
    if not config.get("require-https", True):
        return
        
    if args.resource_type == "aws:lb/listener:Listener":
        props = args.get("props", {})
        protocol = props.get("protocol", "")
        port = props.get("port", 80)
        
        if protocol.upper() == "HTTP" and port != 80:
            # Allow HTTP on port 80 for redirects, but warn about other HTTP ports
            report_violation(
                f"Load balancer listener should use HTTPS instead of HTTP on port {port}",
                get_enforcement_level(config)
            )
        elif protocol.upper() == "HTTP" and port == 80:
            # Advisory warning for HTTP on port 80
            report_violation(
                "Load balancer listener uses HTTP on port 80. Consider implementing HTTPS redirect.",
                EnforcementLevel.ADVISORY
            )


# Security Group Policies
def security_group_no_unrestricted_ingress(args, report_violation, config):
    """Security groups should not allow unrestricted inbound access"""
    if args.resource_type == "aws:ec2/securityGroup:SecurityGroup":
        props = args.get("props", {})
        ingress_rules = props.get("ingressRules", [])
        
        for rule in ingress_rules:
            cidr_ipv4 = rule.get("cidrIpv4", "")
            from_port = rule.get("fromPort", 0)
            to_port = rule.get("toPort", 0)
            
            # Check for unrestricted access
            if cidr_ipv4 == "0.0.0.0/0":
                if from_port == 0 and to_port == 65535:
                    report_violation(
                        "Security group allows unrestricted access on all ports from anywhere",
                        EnforcementLevel.MANDATORY
                    )
                elif from_port != 80 and from_port != 443:
                    report_violation(
                        f"Security group allows unrestricted access on port {from_port} from anywhere",
                        get_enforcement_level(config)
                    )


# RDS Security Policies
def rds_instance_encrypted_storage(args, report_violation, config):
    """RDS instances should have encrypted storage"""
    if not config.get("require-encryption", True):
        return
        
    if args.resource_type == "aws:rds/instance:Instance":
        props = args.get("props", {})
        
        if not props.get("storageEncrypted", False):
            report_violation(
                "RDS instance should have encrypted storage enabled",
                get_enforcement_level(config)
            )


def rds_instance_not_publicly_accessible(args, report_violation, config):
    """RDS instances should not be publicly accessible"""
    if args.resource_type == "aws:rds/instance:Instance":
        props = args.get("props", {})
        
        if props.get("publiclyAccessible", False):
            report_violation(
                "RDS instance should not be publicly accessible",
                EnforcementLevel.MANDATORY
            )


def rds_instance_backup_retention(args, report_violation, config):
    """RDS instances should have backup retention configured"""
    if args.resource_type == "aws:rds/instance:Instance":
        props = args.get("props", {})
        backup_retention = props.get("backupRetentionPeriod", 0)
        
        if backup_retention == 0:
            report_violation(
                "RDS instance should have backup retention period configured (non-zero)",
                get_enforcement_level(config)
            )


# Stack-wide policies
def s3_bucket_count_limit(args, report_violation, config):
    """Limit the number of S3 buckets in a stack"""
    max_buckets = config.get("max-s3-buckets", 5)
    
    s3_buckets = [r for r in args.resources if r.resource_type == "aws:s3/bucketV2:BucketV2"]
    
    if len(s3_buckets) > max_buckets:
        report_violation(
            f"Stack contains {len(s3_buckets)} S3 buckets, which exceeds the limit of {max_buckets}",
            get_enforcement_level(config)
        )


# Define all policies
policies = PolicyPack(
    name="pulumi-lab-policies",
    config_schema=config_schema,
    policies=[
        # S3 Policies
        ResourceValidationPolicy(
            name="s3-bucket-public-access-block",
            description="S3 buckets should have public access blocked",
            validate=s3_bucket_public_access_block,
        ),
        ResourceValidationPolicy(
            name="s3-bucket-versioning-enabled", 
            description="S3 buckets should have versioning enabled",
            validate=s3_bucket_versioning_enabled,
        ),
        ResourceValidationPolicy(
            name="s3-bucket-encryption-required",
            description="S3 buckets should have server-side encryption",
            validate=s3_bucket_encryption_required,
        ),
        
        # IAM Policies
        ResourceValidationPolicy(
            name="iam-policy-no-wildcard-actions",
            description="IAM policies should not use wildcard actions",
            validate=iam_policy_no_wildcard_actions,
        ),
        ResourceValidationPolicy(
            name="iam-role-no-inline-policies", 
            description="IAM roles should use managed policies",
            validate=iam_role_no_inline_policies,
        ),
        
        # Lambda Policies
        ResourceValidationPolicy(
            name="lambda-no-hardcoded-secrets",
            description="Lambda functions should not have hardcoded secrets",
            validate=lambda_no_hardcoded_secrets,
        ),
        ResourceValidationPolicy(
            name="lambda-reasonable-timeout",
            description="Lambda functions should have reasonable timeouts", 
            validate=lambda_reasonable_timeout,
        ),
        
        # Load Balancer Policies
        ResourceValidationPolicy(
            name="alb-listener-https-only",
            description="ALB listeners should use HTTPS",
            validate=alb_listener_https_only,
        ),
        
        # Security Group Policies
        ResourceValidationPolicy(
            name="security-group-no-unrestricted-ingress",
            description="Security groups should not allow unrestricted access",
            validate=security_group_no_unrestricted_ingress,
        ),
        
        # RDS Policies
        ResourceValidationPolicy(
            name="rds-instance-encrypted-storage",
            description="RDS instances should have encrypted storage",
            validate=rds_instance_encrypted_storage,
        ),
        ResourceValidationPolicy(
            name="rds-instance-not-publicly-accessible",
            description="RDS instances should not be publicly accessible",
            validate=rds_instance_not_publicly_accessible,
        ),
        ResourceValidationPolicy(
            name="rds-instance-backup-retention",
            description="RDS instances should have backup retention",
            validate=rds_instance_backup_retention,
        ),
        
        # Stack Policies
        StackValidationPolicy(
            name="s3-bucket-count-limit",
            description="Limit number of S3 buckets per stack",
            validate=s3_bucket_count_limit,
        ),
    ],
)
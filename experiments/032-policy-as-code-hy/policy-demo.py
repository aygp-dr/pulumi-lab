#!/usr/bin/env python3
"""
Policy as Code Demonstration Script
Demonstrates Pulumi CrossGuard and Snyk integration
"""

import asyncio
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

# Color codes for output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def print_section(title: str):
    """Print a formatted section header"""
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*60}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{title.center(60)}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'='*60}{Colors.ENDC}\n")

def print_step(step: str):
    """Print a formatted step"""
    print(f"{Colors.BLUE}🔸 {step}{Colors.ENDC}")

def print_success(message: str):
    """Print a success message"""
    print(f"{Colors.GREEN}✅ {message}{Colors.ENDC}")

def print_warning(message: str):
    """Print a warning message"""
    print(f"{Colors.YELLOW}⚠️  {message}{Colors.ENDC}")

def print_error(message: str):
    """Print an error message"""
    print(f"{Colors.RED}❌ {message}{Colors.ENDC}")

def run_command(command: str, capture_output: bool = False, check: bool = True) -> Optional[str]:
    """Run a shell command and return output if requested"""
    print(f"{Colors.CYAN}$ {command}{Colors.ENDC}")
    
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=capture_output,
            text=True,
            check=check
        )
        
        if capture_output:
            return result.stdout.strip()
        return None
        
    except subprocess.CalledProcessError as e:
        print_error(f"Command failed: {e}")
        if capture_output and e.stdout:
            print(e.stdout)
        if e.stderr:
            print(e.stderr)
        return None

class PolicyDemo:
    def __init__(self):
        self.base_dir = Path(__file__).parent
        self.policy_dir = self.base_dir / "policies"
        self.snyk_dir = self.base_dir / "snyk-policies"
        self.compliance_dir = self.base_dir / "compliance-policies"
        
    def check_prerequisites(self) -> bool:
        """Check if required tools are installed"""
        print_section("Prerequisites Check")
        
        required_tools = {
            "pulumi": "Pulumi CLI",
            "python": "Python interpreter", 
            "pip": "Python package manager"
        }
        
        optional_tools = {
            "snyk": "Snyk CLI (for security scanning)",
            "hy": "Hy language (for .hy file execution)"
        }
        
        all_good = True
        
        # Check required tools
        for tool, description in required_tools.items():
            result = run_command(f"which {tool}", capture_output=True, check=False)
            if result:
                print_success(f"{description}: {result}")
            else:
                print_error(f"{description}: Not found")
                all_good = False
        
        # Check optional tools
        for tool, description in optional_tools.items():
            result = run_command(f"which {tool}", capture_output=True, check=False)
            if result:
                print_success(f"{description}: {result}")
            else:
                print_warning(f"{description}: Not found (optional)")
        
        return all_good
    
    def setup_environment(self):
        """Set up the demo environment"""
        print_section("Environment Setup")
        
        print_step("Installing Pulumi policy dependencies")
        run_command("pip install pulumi-policy")
        
        print_step("Checking Pulumi stack")
        stack_info = run_command("pulumi stack --show-name", capture_output=True, check=False)
        if not stack_info:
            print_step("Initializing Pulumi stack")
            run_command("pulumi stack init policy-demo --no-select")
            run_command("pulumi stack select policy-demo")
        else:
            print_success(f"Current stack: {stack_info}")
    
    def demonstrate_policy_violations(self):
        """Run Pulumi preview to show policy violations"""
        print_section("Policy Violations Demonstration")
        
        print_step("Running Pulumi preview without policies")
        run_command("pulumi preview", check=False)
        
        print_step("Running Pulumi preview with CrossGuard policies")
        if self.policy_dir.exists():
            run_command(f"pulumi preview --policy-pack {self.policy_dir}", check=False)
        else:
            print_warning("CrossGuard policies directory not found")
        
        print_step("Running Pulumi preview with compliance policies")
        if self.compliance_dir.exists():
            run_command(f"pulumi preview --policy-pack {self.compliance_dir}", check=False)
        else:
            print_warning("Compliance policies directory not found")
    
    def run_snyk_scanning(self):
        """Run Snyk IaC scanning"""
        print_section("Snyk Security Scanning")
        
        # Check if Snyk is available
        snyk_path = run_command("which snyk", capture_output=True, check=False)
        if not snyk_path:
            print_warning("Snyk CLI not found. Install with: npm install -g snyk")
            print_step("Showing example Snyk commands instead")
            self.show_snyk_examples()
            return
        
        print_step("Running Snyk IaC test")
        run_command("snyk iac test .", check=False)
        
        print_step("Running Snyk IaC test with custom policies")
        if self.snyk_dir.exists():
            run_command(f"snyk iac test . --policy-path={self.snyk_dir}", check=False)
        
        print_step("Generating Snyk report")
        run_command("snyk iac test . --json > snyk-results.json", check=False)
        
        print_step("Running Snyk describe (if available)")
        run_command("snyk iac describe . --all-projects", check=False)
    
    def show_snyk_examples(self):
        """Show example Snyk commands"""
        print_step("Example Snyk commands for this project:")
        
        commands = [
            "# Install Snyk CLI",
            "npm install -g snyk",
            "",
            "# Authenticate with Snyk",
            "snyk auth",
            "",
            "# Basic IaC scanning",
            "snyk iac test .",
            "",
            "# Scan with specific severity threshold",
            "snyk iac test . --severity-threshold=medium",
            "",
            "# Scan with custom policies",
            f"snyk iac test . --policy-path={self.snyk_dir}",
            "",
            "# Generate reports",
            "snyk iac test . --json > snyk-results.json",
            "snyk iac test . --sarif > snyk-results.sarif",
            "",
            "# Monitor the project",
            "snyk monitor --file=Pulumi.yaml",
            "",
            "# Describe current infrastructure",
            "snyk iac describe . --all-projects"
        ]
        
        for cmd in commands:
            if cmd.startswith("#"):
                print(f"{Colors.YELLOW}{cmd}{Colors.ENDC}")
            elif cmd == "":
                print()
            else:
                print(f"{Colors.CYAN}{cmd}{Colors.ENDC}")
    
    def analyze_policy_results(self):
        """Analyze and explain policy violations"""
        print_section("Policy Analysis & Remediation")
        
        violations = {
            "Critical": [
                "IAM policies with wildcard permissions (*:*)",
                "RDS instances without encryption",
                "Security groups with unrestricted access (0.0.0.0/0)",
                "Hardcoded secrets in Lambda environment variables"
            ],
            "High": [
                "S3 buckets with public access enabled", 
                "Load balancers using HTTP instead of HTTPS",
                "RDS instances that are publicly accessible"
            ],
            "Medium": [
                "S3 buckets without versioning enabled",
                "Lambda functions with excessive timeouts",
                "IAM roles using inline policies instead of managed policies"
            ],
            "Low": [
                "Missing backup retention for RDS instances",
                "Security groups without descriptive names"
            ]
        }
        
        for severity, issues in violations.items():
            color = Colors.RED if severity == "Critical" else \
                   Colors.YELLOW if severity == "High" else \
                   Colors.BLUE if severity == "Medium" else Colors.GREEN
            
            print(f"\n{color}{Colors.BOLD}{severity} Severity Issues:{Colors.ENDC}")
            for issue in issues:
                print(f"  {color}• {issue}{Colors.ENDC}")
        
        print(f"\n{Colors.HEADER}{Colors.BOLD}Remediation Recommendations:{Colors.ENDC}")
        
        remediations = [
            "Replace wildcard IAM permissions with least-privilege access",
            "Enable encryption for all storage resources (S3, RDS, EBS)",
            "Implement HTTPS-only listeners for load balancers", 
            "Use AWS Secrets Manager or Parameter Store for sensitive values",
            "Enable S3 bucket versioning for data protection",
            "Configure appropriate security group rules with specific CIDR blocks",
            "Set reasonable Lambda timeout values (< 5 minutes for most use cases)",
            "Use managed IAM policies instead of inline policies"
        ]
        
        for i, rec in enumerate(remediations, 1):
            print(f"{Colors.GREEN}{i}. {rec}{Colors.ENDC}")
    
    def show_compliance_mapping(self):
        """Show compliance framework mappings"""
        print_section("Compliance Framework Mappings")
        
        frameworks = {
            "ISO 27001": [
                "S3 encryption at rest (A.10.1.1)",
                "RDS encryption (A.10.1.1)",
                "Access logging (A.12.4.1)",
                "Network access controls (A.13.1.1)"
            ],
            "PCI DSS": [
                "HTTPS enforcement (Req 4.1)",
                "Network segmentation (Req 1.3)",
                "Access controls (Req 7.1)",
                "Encryption of cardholder data (Req 3.4)"
            ],
            "SOC 2": [
                "Data availability (CC6.1)",
                "Logical access (CC6.2)", 
                "System operations (CC8.1)",
                "Change management (CC8.1)"
            ],
            "GDPR": [
                "Data protection by design (Art 25)",
                "Data encryption (Art 32)",
                "Data breach notification (Art 33)",
                "Data portability (Art 20)"
            ]
        }
        
        for framework, requirements in frameworks.items():
            print(f"\n{Colors.BLUE}{Colors.BOLD}{framework}:{Colors.ENDC}")
            for req in requirements:
                print(f"  {Colors.CYAN}• {req}{Colors.ENDC}")
    
    def demonstrate_policy_testing(self):
        """Demonstrate policy testing approaches"""
        print_section("Policy Testing Strategies")
        
        print_step("Unit testing policies")
        print("Create test cases for individual policy rules:")
        
        test_example = '''
# Example policy test
def test_s3_public_access_policy():
    # Test case 1: Should pass - private bucket
    private_bucket = {
        "resource_type": "aws:s3/bucketPublicAccessBlock:BucketPublicAccessBlock",
        "props": {
            "blockPublicAcls": True,
            "blockPublicPolicy": True,
            "ignorePublicAcls": True,
            "restrictPublicBuckets": True
        }
    }
    assert policy_passes(s3_bucket_public_access_block, private_bucket)
    
    # Test case 2: Should fail - public bucket
    public_bucket = {
        "resource_type": "aws:s3/bucketPublicAccessBlock:BucketPublicAccessBlock", 
        "props": {
            "blockPublicAcls": False,  # Violation
            "blockPublicPolicy": False  # Violation
        }
    }
    assert policy_fails(s3_bucket_public_access_block, public_bucket)
'''
        print(f"{Colors.GREEN}{test_example}{Colors.ENDC}")
        
        print_step("Integration testing with Pulumi Automation API")
        integration_example = '''
# Example integration test
async def test_policy_enforcement_in_stack():
    stack = auto.create_stack(
        stack_name="policy-test",
        program=lambda: create_test_infrastructure()
    )
    
    # Should fail with policy violations
    with pytest.raises(PolicyViolationError):
        await stack.up(policy_packs=["./policies"])
'''
        print(f"{Colors.GREEN}{integration_example}{Colors.ENDC}")
    
    def show_ci_cd_integration(self):
        """Show CI/CD integration examples"""
        print_section("CI/CD Integration Patterns")
        
        print_step("GitHub Actions integration")
        github_workflow = '''
name: Infrastructure Policy Validation

on: [push, pull_request]

jobs:
  policy-validation:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Pulumi
      uses: pulumi/action@v3
      
    - name: Install Snyk
      run: npm install -g snyk
      
    - name: Pulumi Preview with Policies
      run: pulumi preview --policy-pack ./policies
      env:
        PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}
        
    - name: Snyk IaC Scan  
      run: snyk iac test . --severity-threshold=medium
      env:
        SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
'''
        print(f"{Colors.GREEN}{github_workflow}{Colors.ENDC}")
        
        print_step("Pre-commit hooks integration")
        precommit_example = '''
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: pulumi-policy-check
        name: Pulumi Policy Check
        entry: pulumi preview --policy-pack ./policies
        language: system
        
      - id: snyk-iac-scan
        name: Snyk IaC Security Scan  
        entry: snyk iac test .
        language: system
'''
        print(f"{Colors.GREEN}{precommit_example}{Colors.ENDC}")
    
    def run_full_demo(self):
        """Run the complete policy demonstration"""
        print_section("🚀 Pulumi Policy as Code Demonstration")
        print(f"{Colors.CYAN}This demo shows CrossGuard policies and Snyk integration{Colors.ENDC}")
        
        if not self.check_prerequisites():
            print_error("Prerequisites not met. Please install missing tools.")
            return False
        
        try:
            self.setup_environment()
            self.demonstrate_policy_violations()
            self.run_snyk_scanning()
            self.analyze_policy_results()
            self.show_compliance_mapping()
            self.demonstrate_policy_testing()
            self.show_ci_cd_integration()
            
            print_section("✅ Demo Complete")
            print_success("Policy as Code demonstration completed successfully!")
            print(f"{Colors.CYAN}Key takeaways:{Colors.ENDC}")
            print(f"{Colors.BLUE}• CrossGuard enables custom security policies{Colors.ENDC}")
            print(f"{Colors.BLUE}• Snyk provides industry-standard security scanning{Colors.ENDC}")
            print(f"{Colors.BLUE}• Compliance frameworks can be mapped to policies{Colors.ENDC}")  
            print(f"{Colors.BLUE}• Policy testing ensures reliability{Colors.ENDC}")
            print(f"{Colors.BLUE}• CI/CD integration enables shift-left security{Colors.ENDC}")
            
            return True
            
        except Exception as e:
            print_error(f"Demo failed: {e}")
            return False

def main():
    """Main entry point"""
    demo = PolicyDemo()
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "check":
            demo.check_prerequisites()
        elif command == "setup":
            demo.setup_environment()  
        elif command == "policies":
            demo.demonstrate_policy_violations()
        elif command == "snyk":
            demo.run_snyk_scanning()
        elif command == "analyze":
            demo.analyze_policy_results()
        elif command == "compliance":
            demo.show_compliance_mapping()
        elif command == "testing":
            demo.demonstrate_policy_testing()
        elif command == "cicd":
            demo.show_ci_cd_integration()
        else:
            print(f"Unknown command: {command}")
            print("Available commands: check, setup, policies, snyk, analyze, compliance, testing, cicd")
    else:
        # Run full demo
        success = demo.run_full_demo()
        sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
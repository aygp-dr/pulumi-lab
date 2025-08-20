"""
Pulumi Architecture Patterns: Traditional CLI vs Automation API
Demonstrates the architectural differences shown in the provided diagram
"""

import asyncio
import json
import os
import time
from typing import Dict, Any, List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pulumi.automation as auto
import pulumi_aws as aws
import pulumi


# =============================================================================
# TRADITIONAL CLI PATTERN (Left side of diagram)
# =============================================================================

def traditional_cli_pattern():
    """
    Traditional Pulumi CLI Pattern:
    User/CI/CD -> Pulumi CLI -> Pulumi Engine -> Cloud
    
    This is the standard approach where infrastructure is managed
    through direct CLI commands.
    """
    
    print("🔧 Traditional CLI Pattern")
    print("=" * 40)
    print("User/CI/CD -> Pulumi CLI -> Pulumi Engine -> Cloud")
    print("")
    print("Commands used:")
    print("  pulumi up")
    print("  pulumi preview") 
    print("  pulumi destroy")
    print("  pulumi stack select")
    print("")
    print("Characteristics:")
    print("- Direct CLI interaction")
    print("- Static infrastructure definitions")
    print("- Manual or scripted deployment")
    print("- Limited programmatic control")


# =============================================================================
# AUTOMATION API PATTERN (Right side of diagram)
# =============================================================================

# Pydantic models for API requests
class DeploymentRequest(BaseModel):
    app_name: str
    environment: str
    bucket_count: int = 2
    enable_website: bool = True

class StackInfo(BaseModel):
    name: str
    status: str
    outputs: Dict[str, Any]
    last_update: str

# FastAPI web service (HTTP -> WebService -> Automation API -> Cloud)
app = FastAPI(title="Pulumi Automation API Service", version="1.0.0")

class InfrastructureService:
    """
    Web Service that uses Automation API
    HTTP -> WebService -> Automation API -> Cloud
    """
    
    def __init__(self):
        self.active_stacks = {}
    
    async def create_infrastructure_program(self, config: Dict[str, Any]):
        """Inline Pulumi program for web service deployments"""
        
        app_name = config.get("app_name", "web-service")
        environment = config.get("environment", "dev")
        bucket_count = config.get("bucket_count", 2)
        
        # LocalStack provider
        provider = aws.Provider("localstack",
            region="us-east-1",
            access_key="test",
            secret_key="test",
            skip_credentials_validation=True,
            skip_metadata_api_check=True,
            skip_requesting_account_id=True,
            s3_force_path_style=True,
            endpoints=aws.ProviderEndpointsArgs(
                s3="http://localhost:4566"
            )
        )
        
        # Create buckets based on request
        buckets = []
        for i in range(bucket_count):
            bucket = aws.s3.BucketV2(f"api-bucket-{i}",
                bucket=f"{app_name}-api-{environment}-{i}",
                opts=pulumi.ResourceOptions(provider=provider)
            )
            buckets.append(bucket)
        
        # Export results
        outputs = {
            "service_name": app_name,
            "environment": environment,
            "bucket_count": bucket_count,
            "buckets": [bucket.bucket for bucket in buckets],
            "deployment_time": time.strftime("%Y-%m-%d %H:%M:%S"),
            "deployment_method": "automation-api-web-service"
        }
        
        for key, value in outputs.items():
            pulumi.export(key, value)
        
        return outputs
    
    async def deploy_stack(self, request: DeploymentRequest) -> StackInfo:
        """Deploy infrastructure via Automation API"""
        
        stack_name = f"{request.app_name}-{request.environment}"
        project_name = "automation-web-service"
        
        # Create configuration
        config = {
            "app_name": request.app_name,
            "environment": request.environment,
            "bucket_count": request.bucket_count,
            "enable_website": request.enable_website
        }
        
        # Create stack using Automation API
        stack = auto.create_or_select_stack(
            stack_name=stack_name,
            project_name=project_name,
            program=lambda: await self.create_infrastructure_program(config)
        )
        
        # Configure stack
        await stack.workspace.install_plugin("aws", "v6.0.0")
        await stack.set_config("aws:region", auto.ConfigValue(value="us-east-1"))
        await stack.set_config("aws:accessKey", auto.ConfigValue(value="test"))
        await stack.set_config("aws:secretKey", auto.ConfigValue(value="test"))
        
        # Deploy
        result = await stack.up()
        outputs = await stack.outputs()
        
        # Store stack info
        stack_info = StackInfo(
            name=stack_name,
            status="deployed",
            outputs={k: v.value for k, v in outputs.items()},
            last_update=time.strftime("%Y-%m-%d %H:%M:%S")
        )
        
        self.active_stacks[stack_name] = stack_info
        return stack_info

# Global service instance
infra_service = InfrastructureService()

@app.post("/deploy", response_model=StackInfo)
async def deploy_infrastructure(request: DeploymentRequest):
    """
    HTTP endpoint for infrastructure deployment
    Demonstrates: HTTP -> WebService -> Automation API -> Cloud
    """
    try:
        return await infra_service.deploy_stack(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/stacks")
async def list_stacks():
    """List all active stacks"""
    return {"stacks": list(infra_service.active_stacks.keys())}

@app.get("/stacks/{stack_name}")
async def get_stack_info(stack_name: str):
    """Get information about a specific stack"""
    if stack_name not in infra_service.active_stacks:
        raise HTTPException(status_code=404, detail="Stack not found")
    return infra_service.active_stacks[stack_name]


# =============================================================================
# YOUR CLI PATTERN (User -> Your CLI -> Automation API -> Cloud)
# =============================================================================

class CustomCLI:
    """
    Custom CLI that uses Automation API
    User -> Your CLI -> Automation API -> Cloud
    """
    
    def __init__(self):
        self.service = InfrastructureService()
    
    async def create_environment(self, env_name: str, app_name: str):
        """Create a new environment using Automation API"""
        
        print(f"🚀 Creating environment: {env_name}")
        print(f"📱 Application: {app_name}")
        
        request = DeploymentRequest(
            app_name=app_name,
            environment=env_name,
            bucket_count=3 if env_name == "prod" else 1,
            enable_website=True
        )
        
        stack_info = await self.service.deploy_stack(request)
        
        print(f"✅ Environment created: {stack_info.name}")
        print(f"📊 Outputs: {json.dumps(stack_info.outputs, indent=2)}")
        
        return stack_info
    
    async def list_environments(self):
        """List all environments"""
        print("📋 Active environments:")
        for stack_name, info in self.service.active_stacks.items():
            print(f"  - {stack_name}: {info.status} (updated: {info.last_update})")
    
    def help(self):
        """Show CLI help"""
        print("""
Custom Infrastructure CLI

Commands:
  create <env> <app>  - Create new environment
  list               - List all environments  
  info <env>         - Show environment details
  help               - Show this help

Examples:
  create dev myapp
  create prod myapp
  list
  info dev-myapp
        """)


# =============================================================================
# OPS WORKFLOW PATTERN (CI/CD -> Your Ops Workflow -> Automation API -> Cloud)
# =============================================================================

class OpsWorkflow:
    """
    Operations Workflow using Automation API
    CI/CD -> Your Ops Workflow -> Automation API -> Cloud
    """
    
    def __init__(self):
        self.service = InfrastructureService()
        self.environments = ["dev", "staging", "prod"]
    
    async def full_deployment_pipeline(self, app_name: str):
        """
        Complete deployment pipeline across all environments
        Simulates CI/CD triggering ops workflow
        """
        
        print(f"🔄 Starting deployment pipeline for: {app_name}")
        print("=" * 50)
        
        results = {}
        
        for env in self.environments:
            print(f"\n🌍 Deploying to {env} environment...")
            
            # Environment-specific configuration
            config = {
                "bucket_count": {"dev": 1, "staging": 2, "prod": 5}[env],
                "enable_website": env in ["staging", "prod"]
            }
            
            request = DeploymentRequest(
                app_name=app_name,
                environment=env,
                **config
            )
            
            try:
                stack_info = await self.service.deploy_stack(request)
                results[env] = {
                    "status": "success",
                    "stack": stack_info.name,
                    "outputs": stack_info.outputs
                }
                print(f"✅ {env} deployment successful")
                
            except Exception as e:
                results[env] = {
                    "status": "failed", 
                    "error": str(e)
                }
                print(f"❌ {env} deployment failed: {e}")
        
        # Generate deployment report
        print(f"\n📋 Deployment Pipeline Report")
        print("=" * 40)
        for env, result in results.items():
            status_icon = "✅" if result["status"] == "success" else "❌"
            print(f"{status_icon} {env.upper()}: {result['status']}")
            
            if result["status"] == "success":
                buckets = result["outputs"].get("bucket_count", 0)
                print(f"   Buckets deployed: {buckets}")
        
        return results
    
    async def rollback_environment(self, env_name: str, app_name: str):
        """Rollback a specific environment"""
        stack_name = f"{app_name}-{env_name}"
        
        print(f"🔄 Rolling back environment: {stack_name}")
        
        # In a real implementation, this would use the Automation API
        # to destroy or rollback the stack
        try:
            # Simulate rollback
            await asyncio.sleep(2)
            print(f"✅ Rollback completed for: {stack_name}")
        except Exception as e:
            print(f"❌ Rollback failed: {e}")


# =============================================================================
# DEMONSTRATION FUNCTIONS
# =============================================================================

async def demonstrate_architecture_patterns():
    """Demonstrate all architecture patterns from the diagram"""
    
    print("🏗️ Pulumi Architecture Patterns Demonstration")
    print("=" * 60)
    
    # Pattern 1: Traditional CLI (left side of diagram)
    print("\n" + "="*60)
    print("1️⃣ TRADITIONAL CLI PATTERN")
    print("="*60)
    traditional_cli_pattern()
    
    # Pattern 2: Web Service via Automation API  
    print("\n" + "="*60)
    print("2️⃣ WEB SERVICE PATTERN")
    print("="*60)
    print("HTTP -> WebService -> Automation API -> Cloud")
    print("")
    print("Starting FastAPI web service...")
    print("Available endpoints:")
    print("  POST /deploy       - Deploy infrastructure")
    print("  GET  /stacks       - List all stacks")  
    print("  GET  /stacks/{id}  - Get stack details")
    print("")
    print("Example request:")
    example_request = {
        "app_name": "web-demo",
        "environment": "dev", 
        "bucket_count": 2,
        "enable_website": True
    }
    print(f"  curl -X POST http://localhost:8000/deploy \\")
    print(f"    -H 'Content-Type: application/json' \\")
    print(f"    -d '{json.dumps(example_request)}'")
    
    # Pattern 3: Custom CLI via Automation API
    print("\n" + "="*60)
    print("3️⃣ CUSTOM CLI PATTERN") 
    print("="*60)
    print("User -> Your CLI -> Automation API -> Cloud")
    print("")
    
    cli = CustomCLI()
    print("Creating development environment...")
    await cli.create_environment("dev", "cli-demo")
    
    print("\nCreating production environment...")
    await cli.create_environment("prod", "cli-demo")
    
    print("\nListing all environments:")
    await cli.list_environments()
    
    # Pattern 4: Ops Workflow via Automation API
    print("\n" + "="*60)
    print("4️⃣ OPS WORKFLOW PATTERN")
    print("="*60) 
    print("CI/CD -> Your Ops Workflow -> Automation API -> Cloud")
    print("")
    
    workflow = OpsWorkflow()
    await workflow.full_deployment_pipeline("ops-demo")
    
    # Summary
    print("\n" + "="*60)
    print("📊 ARCHITECTURE PATTERNS SUMMARY")
    print("="*60)
    
    patterns = [
        ("Traditional CLI", "Direct CLI commands", "Manual/scripted"),
        ("Web Service", "HTTP API endpoints", "Programmatic web interface"),
        ("Custom CLI", "Custom command interface", "Tailored user experience"), 
        ("Ops Workflow", "CI/CD integration", "Automated pipeline orchestration")
    ]
    
    for pattern, interface, use_case in patterns:
        print(f"📋 {pattern:15} | {interface:25} | {use_case}")
    
    print("\n🎯 Key Benefits of Automation API:")
    print("✅ Programmatic infrastructure management")
    print("✅ Custom user interfaces and workflows")
    print("✅ Integration with existing tools and processes") 
    print("✅ Dynamic infrastructure based on runtime conditions")
    print("✅ Advanced deployment orchestration")


async def run_web_service_demo():
    """Run the web service demonstration"""
    import uvicorn
    
    print("🌐 Starting Pulumi Automation API Web Service")
    print("Access at: http://localhost:8000")
    print("API docs at: http://localhost:8000/docs")
    
    # This would start the FastAPI server
    # uvicorn.run(app, host="0.0.0.0", port=8000)
    print("(Web service ready for requests)")


if __name__ == "__main__":
    print("🏗️ Pulumi Architecture Patterns")
    print("Choose demonstration mode:")
    print("1. Complete architecture demonstration")
    print("2. Web service only") 
    print("3. CLI pattern only")
    print("4. Ops workflow only")
    
    import sys
    
    if len(sys.argv) > 1:
        mode = sys.argv[1]
        
        if mode == "web":
            asyncio.run(run_web_service_demo())
        elif mode == "cli":
            cli = CustomCLI()
            cli.help()
            print("\nExample usage:")
            print("python architecture-patterns.py cli create dev myapp")
        elif mode == "ops":
            workflow = OpsWorkflow()
            asyncio.run(workflow.full_deployment_pipeline("ops-example"))
        else:
            asyncio.run(demonstrate_architecture_patterns())
    else:
        asyncio.run(demonstrate_architecture_patterns())
# Installation Guide

## Prerequisites

### Required Software

1. **Python 3.11+**
   ```bash
   python --version  # Should show 3.11 or higher
   ```

2. **uv (Python package manager)**
   ```bash
   # Install uv
   curl -LsSf https://astral.sh/uv/install.sh | sh
   
   # Or with pip
   pip install uv
   ```

3. **Pulumi CLI**
   ```bash
   # Install Pulumi
   curl -fsSL https://get.pulumi.com | sh
   
   # Add to PATH
   export PATH="$HOME/.pulumi/bin:$PATH"
   
   # Verify installation
   pulumi version
   ```

4. **Docker** (for LocalStack)
   ```bash
   docker --version  # Required for LocalStack
   ```

5. **Emacs 30+** (optional, for org-mode integration)
   ```bash
   emacs --version  # Should show 30.1 or higher
   ```

## Project Setup

### 1. Clone the Repository
```bash
git clone https://github.com/aygp-dr/pulumi-lab.git
cd pulumi-lab
```

### 2. Create Virtual Environment and Install Dependencies
```bash
# Using make (recommended)
make install setup-hy

# Or manually with uv
uv venv
source .venv/bin/activate  # On Unix/macOS
uv pip install -e .
```

### 3. Configure Environment

#### Using direnv (recommended)
```bash
# Install direnv
brew install direnv  # macOS
apt-get install direnv  # Ubuntu/Debian

# Allow the .envrc file
direnv allow .

# Environment will auto-load when entering directory
```

#### Manual Configuration
```bash
# Add to your shell profile
export PATH="$HOME/.pulumi/bin:$PATH"
export PULUMI_BACKEND_URL="file://~/.pulumi"
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
```

## Python Dependencies

### Core Dependencies
- **pulumi**: Infrastructure as Code SDK
- **pulumi-aws**: AWS provider for Pulumi
- **pulumi-github**: GitHub provider for Pulumi
- **hy**: Lisp dialect for Python
- **boto3**: AWS SDK for Python

### Installation with uv
```bash
# Core Pulumi packages
uv add pulumi pulumi-aws pulumi-github

# Hy language
uv add hy hyrule

# AWS SDK for LocalStack testing
uv add boto3

# Development tools
uv add --dev pytest ruff black mypy
```

## LocalStack Setup

### 1. Start LocalStack
```bash
# Using docker
docker run -d \
  --name localstack \
  -p 4566:4566 \
  -e SERVICES=s3,dynamodb,lambda,sns,sqs \
  localstack/localstack

# Or using make
make localstack-start
```

### 2. Verify LocalStack
```bash
# Check if running
docker ps | grep localstack

# Test with AWS CLI
aws --endpoint-url=http://localhost:4566 s3 ls

# Or use our Hy script
hy scripts/check-localstack.hy
```

## Hy Language Setup

### 1. Verify Hy Installation
```bash
# Check Hy REPL
hy --version

# Test Hy script
hy -c "(print \"Hy is working!\")"
```

### 2. Run Test Scripts
```bash
# Test S3 operations in LocalStack
hy scripts/test-s3-localstack.hy

# Check all LocalStack resources
hy scripts/check-localstack.hy
```

## Emacs Integration (Optional)

### 1. Install pulumi-lab.el
```elisp
;; Add to your init.el
(add-to-list 'load-path "/path/to/pulumi-lab")
(require 'pulumi-lab)

;; Or with use-package
(use-package pulumi-lab
  :load-path "/path/to/pulumi-lab"
  :hook ((python-mode org-mode hy-mode) . pulumi-lab-enable-for-project))
```

### 2. Install Emacs Dependencies
```elisp
;; Install from MELPA
M-x package-install RET hy-mode RET
M-x package-install RET lsp-mode RET
M-x package-install RET company RET
M-x package-install RET flycheck RET
M-x package-install RET projectile RET
```

### 3. Auto-install Missing Packages
```elisp
;; Run in Emacs
M-x pulumi-lab-ensure-packages
```

## Verification

### 1. Check All Dependencies
```bash
# Run verification script
cat > check_deps.py << 'EOF'
import sys
import importlib

deps = [
    "pulumi",
    "pulumi_aws",
    "pulumi_github", 
    "hy",
    "boto3",
]

for dep in deps:
    try:
        mod = importlib.import_module(dep.replace("-", "_"))
        print(f"✅ {dep}: installed")
    except ImportError:
        print(f"❌ {dep}: missing")
        sys.exit(1)

print("\n✅ All dependencies installed!")
EOF

python check_deps.py
```

### 2. Test Pulumi Setup
```bash
# Login to local backend
pulumi login --local

# Check config
pulumi whoami
```

### 3. Test LocalStack Integration
```bash
# Simple S3 test
hy scripts/test-s3-localstack.hy

# Full infrastructure check
hy scripts/check-localstack.hy
```

## Troubleshooting

### Common Issues

1. **Pulumi not found**
   ```bash
   # Add to PATH
   export PATH="$HOME/.pulumi/bin:$PATH"
   ```

2. **Hy import errors**
   ```bash
   # Reinstall Hy
   uv pip uninstall hy
   uv add hy
   ```

3. **LocalStack connection refused**
   ```bash
   # Restart LocalStack
   docker restart localstack
   
   # Check logs
   docker logs localstack
   ```

4. **boto3 endpoint issues**
   ```bash
   # Ensure environment variables are set
   export AWS_ENDPOINT_URL="http://localhost:4566"
   ```

5. **Emacs org-babel errors**
   ```bash
   # Load pulumi-lab package
   M-x load-library RET pulumi-lab RET
   ```

## Next Steps

1. Run your first experiment:
   ```bash
   cd experiments/001-github-provider
   pulumi up
   ```

2. Create a new experiment:
   ```bash
   # In Emacs
   M-x pulumi-lab-create-experiment
   
   # Or manually
   mkdir experiments/XXX-my-experiment
   ```

3. Test with Hy:
   ```bash
   # Run any Hy experiment
   cd experiments/002-github-teams-hy
   hy __main__.hy
   ```
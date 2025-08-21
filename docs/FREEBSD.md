# FreeBSD Setup Guide for Pulumi Lab

## Overview

This guide covers running Pulumi on FreeBSD 14.3-RELEASE, including workarounds for platform limitations.

## Current Status

### ✅ Working
- **Pulumi CLI**: v3.145.0 via Linux compatibility layer
- **Hy**: 1.0.0 (Lisp for Python)
- **Minio**: 2025.06.13 for S3-compatible storage
- **Python**: 3.11.11
- **Node.js**: v22.14.0

### ⚠️ Limitations
- Pulumi not in FreeBSD ports/pkg
- Docker daemon doesn't run natively
- LocalStack requires Docker (use Minio instead)

## Installation

### 1. Prerequisites

```bash
# Verify Linux compatibility layer
kldstat | grep linux
# Should show: linux.ko, linux_common.ko, linux64.ko

# If not loaded:
sudo kldload linux64
```

### 2. Install Pulumi

```bash
# Quick setup
gmake freebsd-setup

# Or manually:
cd /tmp
curl -LO https://get.pulumi.com/releases/sdk/pulumi-v3.145.0-linux-x64.tar.gz
tar -xzf pulumi-v3.145.0-linux-x64.tar.gz
mkdir -p ~/.local/bin
cp pulumi/* ~/.local/bin/
export PATH=$HOME/.local/bin:$PATH
```

### 3. Install Dependencies

```bash
# Python packages
pip3 install --user pulumi pulumi-aws pulumi-github hy

# AWS CLI
pip3 install --user awscli
```

## S3 Testing with Minio

Since Docker/LocalStack doesn't work natively, use Minio:

### Install Minio

```bash
sudo pkg install minio minio-client
```

### Start Minio

```bash
# Using helper script
./scripts/start-minio.sh

# Or with gmake
gmake minio-start
```

### Configure Environment

```bash
eval $(gmake minio-env)
# Sets: AWS_ENDPOINT, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
```

### Test Connection

```bash
gmake minio-test
# Or
aws --endpoint-url=http://localhost:9000 s3 ls
```

## Running Experiments

### S3-Compatible Experiments

```bash
cd experiments/033-minio-testing-hy
pulumi stack init test --secrets-provider passphrase
pulumi up
```

### GitHub Provider Experiments

```bash
cd experiments/001-github-provider
npm install
pulumi up
```

## Makefile Targets

```bash
gmake help              # Show all targets
gmake freebsd-setup     # Install Pulumi
gmake freebsd-test      # Verify installation
gmake minio-start       # Start Minio S3
gmake minio-stop        # Stop Minio
gmake minio-test        # Test S3 connection
gmake minio-env         # Show environment vars
```

## Troubleshooting

### Pulumi Not Found
```bash
export PATH=$HOME/.local/bin:$PATH
echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
```

### Minio Connection Failed
```bash
# Check if running
pgrep minio

# Check logs
tail -f /tmp/minio.log

# Restart
pkill minio
gmake minio-start
```

### Import Errors in Hy
Use Hy 1.0.0 syntax:
```hy
;; Correct
(import pulumi_aws :as aws)

;; Wrong (old syntax)
(import [pulumi-aws :as aws])
```

## Alternative Solutions

For services beyond S3:
1. Use actual AWS with free tier
2. Set up Linux VM with Docker
3. Use docker-machine with remote host
4. Deploy from CI/CD pipelines

## Quick Reference

```bash
# Start working environment
gmake minio-start
eval $(gmake minio-env)
cd experiments/033-minio-testing-hy
pulumi up

# Test S3 operations
aws --endpoint-url=$AWS_ENDPOINT s3 mb s3://test-bucket
aws --endpoint-url=$AWS_ENDPOINT s3 ls

# Clean up
pulumi destroy
gmake minio-stop
```
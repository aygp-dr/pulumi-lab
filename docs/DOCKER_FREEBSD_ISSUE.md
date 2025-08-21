# Docker on FreeBSD - Important Notes

## The Problem

**Docker doesn't run natively on FreeBSD.** The `docker` package in FreeBSD ports is only the Docker **client**, not the Docker daemon (dockerd).

### What We Found

```bash
# Docker client is installed
$ which docker
/usr/local/bin/docker

# But no Docker daemon or service script exists
$ ls /usr/local/etc/rc.d/ | grep docker
(no output)

# The docker group doesn't exist
$ sudo pw groupmod docker -m $USER
pw: unknown group 'docker'

# Service can't start because there's no daemon
$ sudo service docker start
docker does not exist in /etc/rc.d or the local startup
directories (/usr/local/etc/rc.d), or is not executable
```

## Why This Happens

FreeBSD uses a different container technology (jails) and doesn't support Linux containers natively. Docker requires Linux kernel features that FreeBSD doesn't have.

## Solutions for Running Docker on FreeBSD

### Option 1: Docker Machine with VirtualBox (Recommended)

```bash
# Install docker-machine and VirtualBox
sudo pkg install docker-machine virtualbox-ose

# Create a Docker VM
docker-machine create --driver virtualbox default

# Set up environment to use the VM
eval $(docker-machine env default)

# Now Docker commands will work through the VM
docker run hello-world
```

### Option 2: Use a Linux VM with bhyve

```bash
# Install bhyve and vm-bhyve
sudo pkg install vm-bhyve bhyve-firmware

# Create a Linux VM and install Docker inside it
# Then connect Docker client to the VM's Docker daemon
```

### Option 3: Use FreeBSD Jails Instead

```bash
# Install ezjail or iocage
sudo pkg install ezjail

# Create jails for service isolation
# This is the FreeBSD-native way, but won't run Docker images
```

### Option 4: Use a Remote Docker Host

```bash
# Connect to a remote Docker daemon
export DOCKER_HOST=tcp://remote-docker-host:2375
docker ps  # Will connect to remote host
```

### Option 5: Use Podman in a Linux VM

```bash
# Podman also doesn't run natively on FreeBSD
# But can be run in a Linux VM or jail with Linux compatibility
```

## Alternative for LocalStack Testing

Since LocalStack requires Docker, here are alternatives:

### 1. Use LocalStack on a Remote Host

```bash
# SSH to a Linux machine with Docker
ssh linux-host

# Run LocalStack there
docker run -d -p 4566:4566 localstack/localstack

# On FreeBSD, connect to remote LocalStack
export AWS_ENDPOINT=http://linux-host:4566
aws --endpoint-url=$AWS_ENDPOINT s3 ls
```

### 2. Use AWS Free Tier

Instead of LocalStack, use actual AWS services with free tier limits:
- S3: 5GB storage free
- Lambda: 1M requests free
- DynamoDB: 25GB storage free

### 3. Use Minio for S3 Testing

```bash
# Minio runs natively on FreeBSD
sudo pkg install minio

# Start Minio (S3-compatible storage)
minio server /tmp/minio-data

# Use Minio endpoint instead of LocalStack
export AWS_ENDPOINT=http://localhost:9000
```

## Recommended Approach for Pulumi Lab

Given the constraints, here's what we recommend:

1. **For Development**: Write and test Pulumi code without deployment
2. **For S3 Testing**: Use Minio (native FreeBSD support)
3. **For Full Testing**: Use docker-machine with VirtualBox
4. **For Production**: Deploy from CI/CD on Linux

## Docker Machine Setup (Quick Start)

```bash
# One-time setup
sudo pkg install docker-machine virtualbox-ose

# Load VirtualBox kernel module
sudo kldload vboxdrv

# Create Docker VM
docker-machine create --driver virtualbox \
  --virtualbox-memory "2048" \
  --virtualbox-cpu-count "2" \
  default

# Start the VM
docker-machine start default

# Configure shell
eval $(docker-machine env default)

# Verify
docker version  # Should show both client and server

# Run LocalStack in the VM
docker run -d -p 4566:4566 localstack/localstack

# Get VM IP
docker-machine ip default

# Connect from FreeBSD
export AWS_ENDPOINT=http://$(docker-machine ip default):4566
aws --endpoint-url=$AWS_ENDPOINT s3 ls
```

## Summary

- **Docker client**: ✅ Installed and working
- **Docker daemon**: ❌ Not available natively on FreeBSD
- **Solution**: Use docker-machine with VirtualBox or remote Docker host
- **Alternative**: Use FreeBSD-native tools (jails, Minio) where possible

This is a fundamental limitation of FreeBSD, not a configuration issue.
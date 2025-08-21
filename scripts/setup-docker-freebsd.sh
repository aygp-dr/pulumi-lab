#!/bin/sh
# Setup Docker on FreeBSD using docker-machine
# Based on https://wiki.freebsd.org/Docker

echo "========================================="
echo "Docker Setup for FreeBSD"
echo "========================================="
echo ""
echo "Docker doesn't run natively on FreeBSD."
echo "This script will help you set up docker-machine."
echo ""

# Check current installation
echo "Current Docker-related packages:"
pkg info | grep -E "docker|containerd" | sed 's/^/  /'
echo ""

# Option 1: Clean reinstall
echo "Option 1: Clean Reinstall (Recommended if having issues)"
echo "---------------------------------------------------------"
echo "To completely reinstall Docker tools:"
echo ""
echo "# Remove existing packages"
echo "sudo pkg remove -y docker docker-compose docker-machine"
echo "sudo pkg autoremove -y"
echo ""
echo "# Reinstall"
echo "sudo pkg install -y docker docker-machine"
echo ""

# Option 2: Use docker-machine with ssh
echo "Option 2: Docker Machine with SSH to Linux Host"
echo "-------------------------------------------------"
echo "If you have a Linux server with Docker:"
echo ""
echo "docker-machine create \\"
echo "  --driver generic \\"
echo "  --generic-ip-address=<LINUX_HOST_IP> \\"
echo "  --generic-ssh-user=<USERNAME> \\"
echo "  --generic-ssh-key=~/.ssh/id_rsa \\"
echo "  remote-docker"
echo ""
echo "eval \$(docker-machine env remote-docker)"
echo ""

# Option 3: Use VirtualBox (requires more setup)
echo "Option 3: Docker Machine with VirtualBox"
echo "-----------------------------------------"
echo "# Install VirtualBox (large download)"
echo "sudo pkg install virtualbox-ose virtualbox-ose-kmod"
echo ""
echo "# Load VirtualBox kernel module"
echo "sudo kldload vboxdrv"
echo "echo 'vboxdrv_load=\"YES\"' | sudo tee -a /boot/loader.conf"
echo ""
echo "# Add user to vboxusers group"
echo "sudo pw groupmod vboxusers -m \$USER"
echo ""
echo "# Create Docker VM"
echo "docker-machine create --driver virtualbox default"
echo "eval \$(docker-machine env default)"
echo ""

# Option 4: Use Podman in a jail
echo "Option 4: Linux Jail with Podman (Advanced)"
echo "--------------------------------------------"
echo "# Create a Linux jail with compatibility layer"
echo "# Install podman inside the jail"
echo "# This is complex and requires Linux compatibility setup"
echo ""

# Option 5: Remote development
echo "Option 5: Use Remote Docker (Simplest)"
echo "---------------------------------------"
echo "If you have Docker on another machine:"
echo ""
echo "# On the remote Linux/Mac machine:"
echo "docker run -d -p 4566:4566 localstack/localstack"
echo ""
echo "# On FreeBSD:"
echo "export DOCKER_HOST=tcp://<remote-ip>:2376"
echo "export AWS_ENDPOINT=http://<remote-ip>:4566"
echo ""

# Alternative: Use native FreeBSD tools
echo "Alternative: FreeBSD-Native Solutions"
echo "--------------------------------------"
echo "Instead of Docker, consider:"
echo ""
echo "1. FreeBSD Jails for isolation:"
echo "   sudo pkg install ezjail"
echo ""
echo "2. Minio for S3-compatible storage:"
echo "   sudo pkg install minio"
echo "   minio server /tmp/minio-data"
echo ""
echo "3. bhyve for full VMs:"
echo "   sudo pkg install vm-bhyve"
echo ""

echo "========================================="
echo "Checking Your Current Setup"
echo "========================================="
echo ""

# Check docker
if command -v docker >/dev/null 2>&1; then
    echo "✓ Docker client installed: $(docker version --format '{{.Client.Version}}' 2>/dev/null || echo 'unknown')"
else
    echo "✗ Docker client not found"
fi

# Check docker-machine
if command -v docker-machine >/dev/null 2>&1; then
    echo "✓ Docker-machine installed: $(docker-machine version 2>/dev/null | head -1)"
    echo ""
    echo "Docker machines:"
    docker-machine ls 2>/dev/null || echo "  No machines created yet"
else
    echo "✗ Docker-machine not found"
fi

echo ""
echo "========================================="
echo "Recommended Next Steps"
echo "========================================="
echo ""
echo "For Pulumi Lab with LocalStack, we recommend:"
echo ""
echo "1. Use a Linux VM or cloud instance for Docker"
echo "2. Install Minio locally for S3 testing"
echo "3. Use Pulumi's local backend for state"
echo "4. Deploy to real AWS for production testing"
echo ""
echo "Quick Minio setup for S3 testing:"
echo "  sudo pkg install minio"
echo "  minio server /tmp/minio-data &"
echo "  export AWS_ENDPOINT=http://localhost:9000"
echo "  export AWS_ACCESS_KEY_ID=minioadmin"
echo "  export AWS_SECRET_ACCESS_KEY=minioadmin"
echo ""
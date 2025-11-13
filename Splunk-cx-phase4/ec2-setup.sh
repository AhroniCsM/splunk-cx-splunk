#!/bin/bash
# Setup script for fresh EC2 instance (x86_64)
# Run this FIRST on a new EC2 instance before deploying

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       EC2 Instance Setup for Phase 4                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Cannot detect OS"
    exit 1
fi

echo "Detected OS: $OS"
echo ""

# Install Docker based on OS
if [ "$OS" = "amzn" ] || [ "$OS" = "rhel" ] || [ "$OS" = "centos" ]; then
    echo "Installing Docker on Amazon Linux/RHEL/CentOS..."
    sudo yum update -y
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $(whoami)
    
elif [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    echo "Installing Docker on Ubuntu/Debian..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $(whoami)
    
else
    echo "❌ Unsupported OS: $OS"
    exit 1
fi

echo "✅ Docker installed"
echo ""

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create symlink for 'docker compose' command
sudo ln -sf /usr/local/bin/docker-compose /usr/libexec/docker/cli-plugins/docker-compose 2>/dev/null || true

echo "✅ Docker Compose installed"
echo ""

# Install AWS CLI if not present
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
    echo "✅ AWS CLI installed"
else
    echo "✅ AWS CLI already installed"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                Setup Complete!                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  IMPORTANT: Docker group changes require logout/login"
echo ""
echo "Next steps:"
echo "  1. Logout and login again (or run: newgrp docker)"
echo "  2. Transfer deployment files to this instance"
echo "  3. Run: ./deploy-on-ec2.sh"
echo ""
echo "To verify setup:"
echo "  docker --version"
echo "  docker compose version"
echo "  aws --version"
echo ""


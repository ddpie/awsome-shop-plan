#!/bin/bash
# AWSome Shop - EC2 One-Click Deploy Script
# Usage: ssh into EC2, then: curl -fsSL <this-script-url> | bash
# Or: scp this script to EC2 and run: bash deploy-ec2.sh

set -e

REPO_BASE="https://github.com/ddpie"
DEPLOY_DIR="$HOME/awsome-shop"

echo "========== AWSome Shop Deploy =========="

# 1. Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "[1/4] Installing Docker..."
    sudo yum update -y 2>/dev/null || sudo apt-get update -y
    sudo yum install -y docker 2>/dev/null || sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo "Docker installed. You may need to re-login for group changes."
fi

# Install Docker Compose plugin if not present
if ! docker compose version &> /dev/null; then
    echo "[1/4] Installing Docker Compose plugin..."
    sudo mkdir -p /usr/local/lib/docker/cli-plugins
    sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

echo "[1/4] Docker ready: $(docker --version)"

# 2. Clone/update repos
echo "[2/4] Cloning repositories..."
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

REPOS="awsome-shop-plan awsome-shop-auth-service awsome-shop-gateway-service awsome-shop-product-service awsome-shop-points-service awsome-shop-order-service"

for repo in $REPOS; do
    if [ -d "$repo" ]; then
        echo "  Updating $repo..."
        cd "$repo" && git pull --ff-only && cd ..
    else
        echo "  Cloning $repo..."
        git clone "$REPO_BASE/$repo.git"
    fi
done

# 3. Build and start
echo "[3/4] Building and starting services..."
cd "$DEPLOY_DIR/awsome-shop-plan"
docker compose up --build -d

# 4. Wait for health
echo "[4/4] Waiting for services to start..."
echo "This may take 3-5 minutes for first build..."

for i in $(seq 1 60); do
    if curl -sf http://localhost:8080/actuator/health > /dev/null 2>&1; then
        echo ""
        echo "========== Deploy Complete =========="
        echo "Gateway:  http://$(curl -s ifconfig.me):8080"
        echo "Auth:     http://localhost:8001"
        echo "Product:  http://localhost:8002"
        echo "Points:   http://localhost:8003"
        echo "Order:    http://localhost:8004"
        echo ""
        echo "Test: curl http://localhost:8080/api/v1/public/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin123\"}'"
        exit 0
    fi
    echo -n "."
    sleep 5
done

echo ""
echo "Services may still be starting. Check with: docker compose -f $DEPLOY_DIR/awsome-shop-plan/docker-compose.yml logs -f"

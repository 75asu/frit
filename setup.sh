#!/bin/bash
# frit setup script
# Run this once when you start a fresh Lightning Studio
# Usage: curl -sL https://raw.githubusercontent.com/binarysquadd/frit/main/setup.sh | bash

set -e

echo "=== frit setup ==="

# 1. System packages (these vanish when Studio stops)
echo "[1/5] Installing system packages..."
sudo apt update -qq
sudo apt install -y -qq nvidia-container-toolkit docker.io curl git make 2>/dev/null

# 2. Start Docker
echo "[2/5] Starting Docker..."
sudo service docker start 2>/dev/null || true
sudo usermod -aG docker $USER 2>/dev/null || true

# 3. Verify GPU
echo "[3/5] Checking GPU..."
nvidia-smi --query-gpu=name,memory.total,driver_version,temperature.gpu --format=csv,noheader

# 4. Test GPU passthrough
echo "[4/5] Testing GPU container passthrough..."
sudo docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi --query-gpu=name --format=csv,noheader

# 5. Install Go (if missing)
echo "[5/5] Checking Go..."
if ! command -v go &>/dev/null; then
    wget -q https://go.dev/dl/go1.22.2.linux-amd64.tar.gz -O /tmp/go.tar.gz
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
    export PATH=$PATH:/usr/local/go/bin
fi
go version

echo ""
echo "=== Ready. GPU is live, Docker is running, Go is installed. ==="
echo "Next: make run    (start the metrics exporter)"
echo "      make chaos  (run a chaos experiment)"

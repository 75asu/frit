.PHONY: setup run metrics chaos clean og-image

# Requires: setup.sh has been run first (apt packages, Docker, Go)
# All targets assume a T4 GPU from Lightning.ai free tier

setup:
	@bash setup.sh

# Start the GPU metrics exporter (Go binary)
run:
	cd cmd/exporter && go run main.go

# Stream metrics to terminal (quick check)
metrics:
	@echo "=== GPU State ==="
	@nvidia-smi --query-gpu=name,temperature.gpu,power.draw,utilization.gpu,memory.used,memory.total --format=csv
	@echo ""
	@echo "=== Live stream (Ctrl+C to stop) ==="
	@nvidia-smi dmon -s pucm -d 2

# Test GPU passthrough
test-gpu:
	@echo "=== Testing Docker GPU passthrough ==="
	@sudo docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi --query-gpu=name --format=csv,noheader
	@echo "GPU passthrough: OK"

# Chaos experiments
chaos:
	@echo "Available experiments:"
	@echo "  make chaos-memory   Fill GPU memory to 90% and observe"
	@echo "  make chaos-kill     Simulate GPU driver crash"
	@echo "  make chaos-load     Run competing workload on GPU"

chaos-memory:
	@echo "=== Chaos: GPU Memory Exhaustion ==="
	@echo "Launching memory hog container..."
	@sudo docker run --rm --gpus all -d --name gpu-hog nvidia/cuda:12.0-base \
		python3 -c "import torch; x=torch.zeros(14*1024**3, device='cuda', dtype=torch.float32); import time; time.sleep(120)"
	@sleep 5
	@echo "GPU state after memory allocation:"
	@nvidia-smi --query-gpu=memory.used,memory.total --format=csv
	@echo ""
	@echo "Now try running: make metrics  (observe memory pressure)"
	@echo "Clean up: docker rm -f gpu-hog"

chaos-kill:
	@echo "=== Chaos: Simulated Driver Crash ==="
	@echo "(Cannot actually rmmod nvidia on shared cloud GPU)"
	@echo "Instead: observe what happens when a GPU process dies mid-inference"
	@echo "Run: sudo docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi"
	@echo "Then: kill the container mid-execution and check nvidia-smi output"

chaos-load:
	@echo "=== Chaos: Competing GPU Workloads ==="
	@echo "Launching two containers sharing the same T4..."
	@sudo docker run --rm --gpus all -d --name gpu-a nvidia/cuda:12.0-base \
		bash -c "while true; do python3 -c 'import torch; a=torch.randn(5000,5000,device=\"cuda\"); b=torch.randn(5000,5000,device=\"cuda\"); c=a@b; del c'; done"
	@sudo docker run --rm --gpus all -d --name gpu-b nvidia/cuda:12.0-base \
		bash -c "while true; do python3 -c 'import torch; a=torch.randn(5000,5000,device=\"cuda\"); b=torch.randn(5000,5000,device=\"cuda\"); c=a@b; del c'; done"
	@sleep 3
	@echo "GPU state with competing workloads:"
	@nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv
	@echo "Clean up: docker rm -f gpu-a gpu-b"

# Full checklist (run this after setup to verify everything)
checklist:
	@echo "=== GPU Lab Checklist ==="
	@echo ""
	@echo "[x] nvidia-smi                  - GPU is alive?"
	@nvidia-smi --query-gpu=name --format=csv,noheader || echo "[ ] FAIL"
	@echo "[x] nvidia-smi dmon             - Live metrics stream?"
	@timeout 3 nvidia-smi dmon -s pucm -c 1 >/dev/null 2>&1 && echo "OK" || echo "[ ] FAIL"
	@echo "[x] Docker GPU passthrough      - GPU inside container?"
	@sudo docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "[ ] FAIL"
	@echo "[x] NVML query                  - Programmatic metrics?"
	@nvidia-smi --query-gpu=temperature.gpu,power.draw,utilization.gpu,memory.used --format=csv,noheader || echo "[ ] FAIL"
	@echo "[ ] DCGM installed              - Advanced datacenter metrics? (run: make dcgm-install)"
	@echo ""
	@echo "=== Checklist complete ==="

# Install DCGM for advanced metrics
dcgm-install:
	@echo "=== Installing DCGM ==="
	@wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/datacenter-gpu-manager_4.1.7_amd64.deb -O /tmp/dcgm.deb
	@sudo dpkg -i /tmp/dcgm.deb 2>/dev/null || true
	@sudo apt install -f -y -qq 2>/dev/null
	@echo "DCGM installed. Try: dcgmi discovery -l"

clean:
	@docker rm -f gpu-hog gpu-a gpu-b 2>/dev/null || true
	@echo "Cleaned up chaos containers."

## og-image: regenerate docs/og.png from docs/og-card.html
og-image:
	"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
		--headless \
		--disable-gpu \
		--screenshot="$(shell pwd)/docs/og.png" \
		--window-size=1200,627 \
		--hide-scrollbars \
		"file://$(shell pwd)/docs/og-card.html"
	@echo "Generated: docs/og.png"

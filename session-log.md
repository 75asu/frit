# GPU Lab Session Log

## 2026-05-20 — Session 1: First T4

**Machine:** Lightning.ai T4 Studio, 16GB VRAM, CUDA 13.0, Driver 580

### What I did
- Started first GPU Studio on Lightning.ai free tier
- Ran nvidia-smi: confirmed Tesla T4, 15GB usable, 40C idle, 34W
- Ran nvidia-smi dmon -s pucm: streaming metrics works
- Installed nvidia-container-toolkit and Docker
- GPU passthrough confirmed: `docker run --gpus all nvidia/cuda nvidia-smi` shows T4

### What I learned
- `nvidia-smi -q -d TEMPERATURE` is wrong syntax. Correct: `nvidia-smi --query-gpu=temperature.gpu`
- Lightning Studio files persist at /teamspace/studios/this_studio, but apt packages don't
- T4 has NO ECC (Volatile Uncorr. ECC column shows 0). Need A100+ for ECC testing
- GPU at idle pulls 34W, max is 70W. Plenty of headroom

### Next session
- Install DCGM
- Write Go binary that queries NVML and exposes Prometheus metrics
- Run chaos-memory experiment

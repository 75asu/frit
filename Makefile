SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help
-include .env
export
export ANSIBLE_CONFIG := ansible/ansible.cfg

KUBECONFIG := $(shell pwd)/kubeconfig.yaml
KUBECTL    := kubectl --kubeconfig=$(KUBECONFIG)

# Run a command on the VM over SSH (live IP from gcloud). Usage: $(call onvm,<cmd>)
ONVM = set -a; [ -f .env ] && . ./.env; set +a; \
       ssh -i "$${SSH_KEY_PATH/\#\~/$$HOME}" -o StrictHostKeyChecking=accept-new \
           "$${TARGET_USER}@$$(bin/vm.sh ip)"

.PHONY: help up down ssh status inventory vm-start connect gpu k3s bootstrap cluster teardown \
        kubeconfig tunnel tunnel-gitea kubectl run metrics chaos chaos-memory chaos-load clean og-image

help: ## show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n",$$1,$$2}'

# -- The GPU VM: lifecycle (0 <-> 100) ----------------------------------------
up: connect cluster ## 0->100: start VM, connect, then GPU + k3s + bootstrap
	@echo "frit is up. Run 'make tunnel' then 'make kubectl CMD=\"get pods -A\"'."
down: ## stop the VM -- billing stops; disk + cluster persist
	@bin/vm.sh stop
teardown: inventory ## 100->0: wipe cluster + GPU stack back to bare Ubuntu (no residue)
	@ansible-playbook ansible/playbooks/teardown.yaml
	@# Vault tokens are bound to the destroyed cluster -- clear them so the next up re-inits cleanly.
	@[ -f .env ] && sed -i '' -E 's/^(VAULT_UNSEAL_KEY|VAULT_ROOT_TOKEN)=.*/\1=/' .env && echo "cleared stale Vault tokens from .env" || true
ssh: ## open a shell on the VM
	@bin/vm.sh ssh
status: ## VM status + current external IP
	@bin/vm.sh status

# -- Connection ----------------------------------------------------------------
inventory: ## render inventory/hosts.yaml from .env (live IP from gcloud)
	@bin/render-inventory.sh
vm-start: ## start the GPU VM (Spot)
	@bin/vm.sh start
connect: vm-start inventory ## start the VM, render live IP, preflight (SSH + sudo + GPU present)
	@ansible-playbook ansible/playbooks/preflight.yaml

# -- Provisioning (each idempotent) -------------------------------------------
gpu: inventory ## GPU foundation: NVIDIA driver + nvidia-container-toolkit + DCGM + Docker
	@ansible-playbook ansible/playbooks/gpu.yaml
k3s: inventory ## k3s single-node + Helm + Go
	@ansible-playbook ansible/playbooks/k3s.yaml
bootstrap: inventory ## Gitea + Flux + Vault + ESO, then Flux applies gitops/
	@ansible-playbook ansible/playbooks/bootstrap.yaml
cluster: inventory ## full provision in order: gpu -> k3s -> bootstrap
	@ansible-playbook ansible/playbooks/site.yaml

# -- Local cluster access ------------------------------------------------------
kubeconfig: inventory ## fetch kubeconfig from the VM (then use make tunnel + make kubectl)
	@ansible all -m fetch -a "src=/etc/rancher/k3s/k3s.yaml dest=$(shell pwd)/kubeconfig.yaml flat=yes mode=0600" --become
	@echo "kubeconfig.yaml written. Run: make tunnel"
tunnel: ## SSH-forward the k3s API (127.0.0.1:6443) -- keep this terminal open
	@$(ONVM) -N -L 6443:127.0.0.1:6443
tunnel-gitea: ## SSH-forward Gitea (127.0.0.1:30080)
	@$(ONVM) -N -L 30080:127.0.0.1:30080
kubectl: ## kubectl via the fetched kubeconfig (needs make tunnel). Usage: make kubectl CMD="get pods -A"
	@$(KUBECTL) $(CMD)

# -- GPU checks + chaos (over SSH) --------------------------------------------
run: ## run any command on the VM. Usage: make run CMD="nvidia-smi"
	@$(ONVM) "$(CMD)"
metrics: ## live GPU stats from the VM
	@$(ONVM) "nvidia-smi --query-gpu=name,temperature.gpu,power.draw,utilization.gpu,memory.used,memory.total --format=csv"
chaos: ## list chaos experiments
	@echo "Available: make chaos-memory | make chaos-load"
chaos-memory: ## fill GPU VRAM and observe degradation
	@$(ONVM) "docker run --rm --gpus all -d --name gpu-hog nvidia/cuda:12.0-base sleep 120"
	@$(MAKE) metrics
chaos-load: ## run a competing GPU workload
	@$(ONVM) "docker run --rm --gpus all -d --name gpu-a nvidia/cuda:12.0-base sleep 120"
	@$(MAKE) metrics
clean: ## kill chaos containers on the VM
	@$(ONVM) "docker rm -f gpu-hog gpu-a gpu-b 2>/dev/null || true"

# -- Misc ----------------------------------------------------------------------
og-image: ## regenerate docs/og.png from docs/og-card.html
	@"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
		--headless --disable-gpu --screenshot="$(shell pwd)/docs/og.png" \
		--window-size=1200,627 --hide-scrollbars "file://$(shell pwd)/docs/og-card.html"
	@echo "Generated: docs/og.png"

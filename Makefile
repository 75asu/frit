-include .env
export

STUDIO     := LIGHTNING_API_KEY=$(LIGHTNING_API_KEY) LIGHTNING_USER_ID=$(LIGHTNING_USER_ID) python3 scripts/studio.py
KUBECONFIG := $(shell pwd)/kubeconfig.yaml
KUBECTL    := kubectl --kubeconfig=$(KUBECONFIG)

# SSH user changes per studio instance — fetch it once from the SDK.
# Cached in a make variable so we only call studio.py once per make invocation.
SSH_USER   := $(shell $(STUDIO) ssh-user 2>/dev/null)
ANSIBLE    := ansible-playbook \
              -i "frit," \
              -e "ansible_user=$(SSH_USER)" \
              -e "ansible_ssh_private_key_file=$(HOME)/.lightning/lightning_rsa" \
              -e "ansible_host=ssh.lightning.ai" \
              --ssh-extra-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

.PHONY: env status start stop sync run keys k3s bootstrap up wait-ssh setup kubeconfig tunnel tunnel-gitea kubectl metrics chaos chaos-memory chaos-load clean og-image

# -- First-time setup ---------------------------------------------------------

# Copy .env.example -> .env so you can fill in real credentials
env:
	@if [ -f .env ]; then \
		echo ".env already exists -- edit it directly or delete it first."; \
	else \
		cp .env.example .env; \
		echo ".env created. Open it and fill in your credentials before running anything else."; \
	fi

# -- Studio lifecycle ---------------------------------------------------------

status:
	$(STUDIO) status

start:
	$(STUDIO) start

stop:
	$(STUDIO) stop

# -- Code sync ----------------------------------------------------------------

# Push local repo to studio (only changed files via SDK upload)
sync:
	$(STUDIO) sync

# -- Remote execution: make run CMD="nvidia-smi" ------------------------------

run:
	$(STUDIO) run "$(CMD)"

# -- SSH key setup (once per machine) ----------------------------------------
# Downloads ~/.lightning/lightning_rsa, writes "Host frit" into ~/.ssh/config,
# and smoke-tests the SSH connection.
# Run this once on any new machine before anything else.
keys:
	set -a && source .env && set +a && ansible-playbook -c local scripts/ansible/local.yml

# -- Cluster provisioning -----------------------------------------------------
# k3s: install k3s + Helm + Go on the T4. Idempotent.
# bootstrap: install Gitea + Flux + Vault + ESO, push code to Gitea, seed secrets.
# up: full bring-up from a blank T4 (start + k3s + bootstrap).
#
# Normal first-run flow:
#   make env      # create .env from .env.example, fill in credentials
#   make keys     # one-time SSH setup
#   make up       # brings up the full cluster

k3s:
	$(ANSIBLE) scripts/ansible/k3s.yaml

bootstrap:
	$(ANSIBLE) scripts/ansible/bootstrap.yaml

up: start wait-ssh k3s bootstrap
	@echo "Cluster is up. Access via: make tunnel (then make kubectl CMD='get pods -A')"

# Wait for SSH and apt to both be ready.
# Studio takes ~60s to accept SSH, then another ~2min for its own apt-get update to finish.
wait-ssh:
	@echo "Waiting for studio SSH to be ready..."
	@until ssh -o ConnectTimeout=5 -o BatchMode=yes frit true 2>/dev/null; do \
		echo "  ...SSH not ready yet, retrying in 10s"; \
		sleep 10; \
	done
	@echo "SSH ready. Waiting for studio apt-get to finish..."
	@until ssh -o BatchMode=yes frit "! pgrep -x apt-get > /dev/null && ! pgrep -x dpkg > /dev/null" 2>/dev/null; do \
		echo "  ...apt still running, retrying in 15s"; \
		sleep 15; \
	done
	@echo "Studio is fully ready."

# -- Legacy: bare prerequisites (kept for backward compat) --------------------
setup:
	$(ANSIBLE) scripts/ansible/setup.yml

# -- Local cluster access -----------------------------------------------------
# kubeconfig.yaml is fetched from the T4 automatically at the end of `make bootstrap`.
# Run these targets on the Mac to get local kubectl access.

# Fetch kubeconfig from T4 without running full bootstrap.
# kubeconfig server is 127.0.0.1:6443 — needs make tunnel to reach it.
kubeconfig:
	ansible -i "frit," all \
		-e "ansible_user=$(SSH_USER)" \
		-e "ansible_ssh_private_key_file=$(HOME)/.lightning/lightning_rsa" \
		-e "ansible_host=ssh.lightning.ai" \
		--ssh-extra-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
		-m fetch \
		-a "src=/etc/rancher/k3s/k3s.yaml dest=$(shell pwd)/kubeconfig.yaml flat=yes mode=0600" \
		--become
	@echo "kubeconfig.yaml written. Run: make tunnel"

# SSH port-forward — exposes k3s API locally.
# Keep this running in a separate terminal while using kubectl.
# ctrl-c to stop.
tunnel:
	@echo "Forwarding 127.0.0.1:6443 → T4 k3s API. Keep this terminal open."
	@echo "In another terminal: make kubectl CMD='get pods -A'"
	ssh -N -L 6443:127.0.0.1:6443 frit

# SSH port-forward for Gitea (NodePort 30080).
tunnel-gitea:
	@echo "Forwarding 127.0.0.1:30080 → T4 Gitea. Keep this terminal open."
	ssh -N -L 30080:127.0.0.1:30080 frit

# kubectl from Mac using the fetched kubeconfig (requires make tunnel in another terminal).
# Usage: make kubectl CMD="get pods -A"
#        make kubectl CMD="get helmreleases -A"
#        make kubectl CMD="logs -n vault vault-0"
kubectl:
	$(KUBECTL) $(CMD)

# -- GPU checks ---------------------------------------------------------------

metrics:
	$(STUDIO) run "nvidia-smi --query-gpu=name,temperature.gpu,power.draw,utilization.gpu,memory.used,memory.total --format=csv"

# -- Chaos experiments --------------------------------------------------------

chaos:
	@echo "Available: make chaos-memory | make chaos-load"

chaos-memory:
	$(STUDIO) run "docker run --rm --gpus all -d --name gpu-hog nvidia/cuda:12.0-base \
		python3 -c \"import torch; x=torch.zeros(14*1024**3, device='cuda'); import time; time.sleep(120)\""
	$(MAKE) metrics

chaos-load:
	$(STUDIO) run "docker run --rm --gpus all -d --name gpu-a nvidia/cuda:12.0-base \
		bash -c 'while true; do python3 -c \"import torch; a=torch.randn(5000,5000,device=\\\"cuda\\\"); a@a\"; done'"
	$(MAKE) metrics

clean:
	$(STUDIO) run "docker rm -f gpu-hog gpu-a gpu-b 2>/dev/null || true"

# -- Misc ---------------------------------------------------------------------

og-image:
	"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
		--headless --disable-gpu \
		--screenshot="$(shell pwd)/docs/og.png" \
		--window-size=1200,627 --hide-scrollbars \
		"file://$(shell pwd)/docs/og-card.html"
	@echo "Generated: docs/og.png"

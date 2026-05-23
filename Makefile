-include .env
export

STUDIO := LIGHTNING_API_KEY=$(LIGHTNING_API_KEY) LIGHTNING_USER_ID=$(LIGHTNING_USER_ID) python3 scripts/studio.py

.PHONY: env status start stop sync run keys setup metrics chaos chaos-memory chaos-load clean og-image

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
# Run this once on any new machine before make setup.
keys:
	set -a && source .env && set +a && ansible-playbook -c local scripts/ansible/local.yml

# -- Studio provisioning ------------------------------------------------------
# Installs Go, DCGM, nvidia-container-toolkit on the studio.
# Idempotent -- safe to re-run after every studio restart.
# Requires: make keys (run once per machine first)
setup:
	ansible-playbook -i frit, scripts/ansible/setup.yml

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

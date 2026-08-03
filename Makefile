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
        kubeconfig tunnel tunnel-gitea grafana grafana-pass prometheus webui unseal kubectl kube-install kube-uninstall sync run metrics chaos chaos-memory chaos-load clean diagram og-image \
        use-t4 use-l4 active save stop-all status-all labs cluster-firewall cluster-join

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
	@echo ">>> connecting + binding 127.0.0.1:6443 (a bind error prints below if the port is busy) ..."
	@$(ONVM) -t -o ExitOnForwardFailure=yes -L 6443:127.0.0.1:6443 "echo '>>> TUNNEL READY: k3s API on 127.0.0.1:6443 -- open a NEW terminal and run: make kubectl CMD=\"get pods -A\"'; echo '>>> keep THIS terminal open; press Ctrl-C here to close the tunnel.'; sleep infinity"
tunnel-gitea: ## SSH-forward Gitea (127.0.0.1:30080)
	@echo ">>> connecting + binding 127.0.0.1:30080 ..."
	@$(ONVM) -t -o ExitOnForwardFailure=yes -L 30080:127.0.0.1:30080 "echo '>>> TUNNEL READY: Gitea on http://127.0.0.1:30080 -- keep THIS terminal open; press Ctrl-C here to close it.'; sleep infinity"
grafana: ## open Grafana at http://localhost:3000 -- pure SSH, no local kubeconfig touched
	@echo ">>> Grafana: http://localhost:3000   login: admin   (password: run 'make grafana-pass')"
	@echo ">>> wait ~3s for the port-forward to bind, then open the URL. Ctrl-C closes it."
	@$(ONVM) -t -L 3000:localhost:3000 "sudo k3s kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80"
grafana-pass: ## print the Grafana admin user + password (from the in-cluster secret)
	@$(ONVM) "ns=monitoring; s=grafana-admin-secret; echo -n 'user: '; sudo k3s kubectl -n \$$ns get secret \$$s -o jsonpath='{.data.admin-user}' | base64 -d; echo; echo -n 'pass: '; sudo k3s kubectl -n \$$ns get secret \$$s -o jsonpath='{.data.admin-password}' | base64 -d; echo"
prometheus: ## open Prometheus at http://localhost:9090 -- pure SSH, no local kubeconfig touched
	@echo ">>> Prometheus: http://localhost:9090   (wait ~3s, then open. Ctrl-C closes it.)"
	@$(ONVM) -t -L 9090:localhost:9090 "sudo k3s kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090"
webui: ## open Open WebUI -- the Claude.ai-equivalent chat -- at http://localhost:8080
	@echo ">>> Open WebUI: http://localhost:8080   (first visit asks you to create a LOCAL admin account)"
	@echo ">>> then pick the Qwen3 model in the top-left dropdown. Ctrl-C closes the tunnel."
	@$(ONVM) -t -L 8080:localhost:8080 "sudo k3s kubectl -n open-webui port-forward svc/open-webui 8080:80"
unseal: ## unseal Vault (Shamir re-seals on every VM restart) + kick ESO to re-sync secrets
	@echo ">>> unsealing Vault + restarting ESO ..."
	@$(ONVM) "sudo k3s kubectl -n vault exec vault-0 -- vault operator unseal '$$VAULT_UNSEAL_KEY' | grep -i '^Sealed' && sudo k3s kubectl -n external-secrets rollout restart deploy/external-secrets >/dev/null && echo 'ESO restarted -- secrets will re-sync'"
kubectl: ## kubectl via the fetched kubeconfig (needs make tunnel). Usage: make kubectl CMD="get pods -A"
	@$(KUBECTL) $(CMD)

# ── Multi-machine (labs) ── .env is the ACTIVE machine's config; per-machine sources are
# .env.t4 (asu-sandbox / T4) and .env.l4 (asu-l4 / L4). Each source carries its own coords
# + its own Vault creds (Vault is per-cluster). Switch active with use-t4/use-l4; after an `up`
# mints fresh Vault creds, run `save` to persist .env back to its source. stop-all/status-all
# act on BOTH regardless of active. Kube context is per-machine: frit-t4 / frit-l4.
use-t4: ## switch active machine -> T4 (asu-sandbox). Then: make up | down | tunnel
	@test -f .env.t4 || { echo "no .env.t4 -- create it first (cp .env .env.t4; add LAB=t4)"; exit 1; }
	@cp .env.t4 .env && echo ">>> active = T4 (asu-sandbox)"
use-l4: ## switch active machine -> L4 (asu-l4). Then: make up | down | tunnel
	@test -f .env.l4 || { echo "no .env.l4 -- create it first (cp .env .env.l4; set GCP_VM_NAME=asu-l4, GCP_ZONE=asia-south1-b, LAB=l4; clear VAULT_* + TARGET_HOST)"; exit 1; }
	@cp .env.l4 .env && echo ">>> active = L4 (asu-l4)"
use-a100: ## switch active machine -> A100 (asu-a100, Singapore, 2x A100 SXM4 NVLink). Then: make up | down
	@test -f .env.a100 || { echo "no .env.a100 -- create it first (cp .env .env.a100; set GCP_VM_NAME=asu-a100, GCP_ZONE=asia-southeast1-b, LAB=a100; clear VAULT_* + TARGET_HOST)"; exit 1; }
	@cp .env.a100 .env && echo ">>> active = A100 (asu-a100) -- MOST EXPENSIVE BOX (~\$$2-3/hr Spot). 'make down' when idle."
active: ## show which machine .env currently targets
	@echo "active LAB=$(LAB)  VM=$(GCP_VM_NAME)  zone=$(GCP_ZONE)"
save: ## persist the active .env back to its per-machine source (.env.$(LAB)) -- run after `up` mints Vault creds
	@test -n "$(LAB)" || { echo "no LAB= in .env; add LAB=t4 or LAB=l4 so save knows the target file"; exit 1; }
	@cp .env .env.$(LAB) && echo ">>> saved active .env -> .env.$(LAB) (Vault creds + coords persisted for next start)"
labs: ## list the per-machine env files present
	@for f in .env.t4 .env.l4; do [ -f $$f ] && echo "  $$f: $$(sed -nE 's/^GCP_VM_NAME=//p' $$f) @ $$(sed -nE 's/^GCP_ZONE=//p' $$f)"; done
stop-all: ## END OF SESSION: stop EVERY lab VM (billing stops; disks + clusters persist)
	@# Iterates every .env.* that names a VM -- so a newly added machine can NEVER be missed by the bill guard.
	@for f in .env.*; do \
	  [ -f "$$f" ] && grep -qE '^GCP_PROJECT=[^[:space:]#]' "$$f" && grep -qE '^GCP_VM_NAME=[^[:space:]#]' "$$f" || continue; \
	  echo ">>> stopping ($$f):"; ENV_FILE=$$f bin/vm.sh stop || true; \
	done
	@echo ">>> all lab VMs stopped. Disks persist; Flux + Vault recover on next 'make up'."
status-all: ## status + IP of EVERY lab VM
	@for f in .env.*; do \
	  [ -f "$$f" ] && grep -qE '^GCP_PROJECT=[^[:space:]#]' "$$f" && grep -qE '^GCP_VM_NAME=[^[:space:]#]' "$$f" || continue; \
	  echo "-- $$f --"; ENV_FILE=$$f bin/vm.sh status || true; \
	done
bill-check: ## HARD CHECK: fail loudly if ANY lab VM is still RUNNING (use before walking away)
	@bad=0; for f in .env.*; do \
	  [ -f "$$f" ] && grep -qE '^GCP_PROJECT=[^[:space:]#]' "$$f" && grep -qE '^GCP_VM_NAME=[^[:space:]#]' "$$f" || continue; \
	  s=$$(ENV_FILE=$$f bin/vm.sh status 2>/dev/null); \
	  case "$$s" in *RUNNING*) echo "!!! STILL BILLING: $$s"; bad=1 ;; *) echo "ok: $$s" ;; esac; \
	done; \
	[ $$bad -eq 0 ] && echo ">>> clean: nothing is billing." || { echo ">>> run 'make stop-all' NOW"; exit 1; }

# ── Multi-node cluster (T4 server + L4 agent, ONE k3s) ──
cluster-firewall: ## create the GCP firewall rule for k3s node-to-node traffic (6443/10250/8472; idempotent)
	@bin/cluster.sh firewall
cluster-join: ## join the ACTIVE machine (an agent, e.g. after `make use-l4`) to the T4 server as a GPU worker node
	@bin/cluster.sh join

KCTX ?= frit$(if $(LAB),-$(LAB),)
kube-install: ## merge the ACTIVE machine's kubeconfig into ~/.kube/config as context 'frit-<lab>' (for kubectl + kubie). Needs 'make tunnel'.
	@test -f $(KUBECONFIG) || { echo "no kubeconfig.yaml -- run 'make up' (or 'make kubeconfig') first"; exit 1; }
	@mkdir -p $$HOME/.kube
	@if [ -f $$HOME/.kube/config ]; then cp $$HOME/.kube/config $$HOME/.kube/config.pre-frit.bak; echo ">>> backed up ~/.kube/config -> ~/.kube/config.pre-frit.bak"; fi
	@sed -E 's/(^ *(- )?name): default *$$/\1: $(KCTX)/; s/(^ *current-context): default *$$/\1: $(KCTX)/; s/(^ *cluster): default *$$/\1: $(KCTX)/; s/(^ *user): default *$$/\1: $(KCTX)/' $(KUBECONFIG) > /tmp/frit-kctx.yaml
	@KUBECONFIG=$$HOME/.kube/config:/tmp/frit-kctx.yaml kubectl config view --flatten > /tmp/kube-merged && mv /tmp/kube-merged $$HOME/.kube/config && chmod 600 $$HOME/.kube/config && rm -f /tmp/frit-kctx.yaml
	@echo ">>> context '$(KCTX)' added. Start the tunnel (keep it open):  make tunnel"
	@echo ">>> then use it directly:  kubectl --context $(KCTX) get pods -A   |   kubie ctx $(KCTX)"
kube-uninstall: ## remove the 'frit' context/cluster/user from ~/.kube/config (backup stays at ~/.kube/config.pre-frit.bak)
	@kubectl --kubeconfig="$$HOME/.kube/config" config delete-context $(KCTX) || true
	@kubectl --kubeconfig="$$HOME/.kube/config" config delete-cluster $(KCTX) || true
	@kubectl --kubeconfig="$$HOME/.kube/config" config delete-user $(KCTX) || true
	@echo ">>> removed '$(KCTX)' from ~/.kube/config"
sync: ## deliver gitops changes: commit first, then this pushes laptop->GitHub->Gitea + forces Flux to reconcile
	@echo ">>> 1/3  laptop -> GitHub (origin)"
	@git push origin main
	@echo ">>> 2/3  GitHub -> VM clone -> in-cluster Gitea (the repo Flux watches)"
	@$(ONVM) "sudo git -C /opt/frit pull --ff-only origin main && sudo git -C /opt/frit push gitea main"
	@echo ">>> 3/3  reconcile Flux (source + infra first, then apps -- apps dependsOn infra)"
	@$(ONVM) "sudo flux --kubeconfig /etc/rancher/k3s/k3s.yaml reconcile kustomization infra --with-source && sudo flux --kubeconfig /etc/rancher/k3s/k3s.yaml reconcile kustomization apps"
	@echo ">>> synced."

# -- GPU checks + chaos (over SSH) --------------------------------------------
run: ## run any command on the VM. Usage: make run CMD="nvidia-smi"
	@$(ONVM) "$(CMD)"
verify: ## GATE: confirm the ACTIVE model is actually serving + generating (run before a benchmark)
	@$(ONVM) "sudo bash /opt/frit/bin/verify-serve.sh"
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
diagram: ## re-render the architecture diagram (dark + light PNGs) from docs/architecture.drawio
	@docs/render-diagram.sh
og-image: ## regenerate docs/og.png from docs/og-card.html
	@"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
		--headless --disable-gpu --screenshot="$(shell pwd)/docs/og.png" \
		--window-size=1200,627 --hide-scrollbars "file://$(shell pwd)/docs/og-card.html"
	@echo "Generated: docs/og.png"

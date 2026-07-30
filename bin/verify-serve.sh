#!/usr/bin/env bash
# frit serve-verification GATE , run on the VM via `make verify`. Exit non-zero on any failure.
# Confirms the ACTIVE model (per gitops = the source of truth for what SHOULD serve) is the one
# actually serving on Ray Serve AND that it generates. Runs BEFORE a benchmark so we never bench a
# stale model (a flip that silently didn't take) and so guidellm doesn't start against a not-yet-ready
# engine. The JSON body lives HERE (not shell-quoted through `make run`), which is the whole reason
# this is a script and not an ad-hoc one-liner.
#   1. read the active model_id + route from the live gitops
#   2. poll /v1/models until THAT model_id appears (covers both "still loading" and "stale/old model")
#   3. one test chat completion -> assert non-empty -> print the text + round-trip time
set -euo pipefail

K="k3s kubectl -n ray"
REPO="${FRIT_REPO:-/opt/frit}"
KUST="$REPO/gitops/apps/ray/kustomization.yaml"

# 1. what SHOULD be serving (from gitops)
active="$(grep -oE 'serveConfigV2=model-configs/[^[:space:]]+\.yaml' "$KUST" | head -1 | sed 's|serveConfigV2=||')"
cfg="$REPO/gitops/apps/ray/$active"
model_id="$(awk '/model_id:/{print $2; exit}' "$cfg")"
route="$(awk '/route_prefix:/{print $2; exit}' "$cfg")"
echo "active config : $active"
echo "expect        : model_id=$model_id  route=$route"

head="$($K get pod -l ray.io/node-type=head -o jsonpath='{.items[0].metadata.name}')"
[ -n "$head" ] || { echo "FAIL: no Ray head pod found"; exit 1; }

# 2. poll until the EXPECTED model is the one serving at its route (up to ~6 min)
printf 'waiting for %s at %s ' "$model_id" "$route"
served=""
for _ in $(seq 1 72); do
  models="$($K exec "$head" -- curl -s --max-time 5 "http://localhost:8000${route}/v1/models" 2>/dev/null || true)"
  if printf '%s' "$models" | grep -q "\"id\":\"$model_id\""; then served=1; echo " OK"; break; fi
  printf '.'; sleep 5
done
[ -n "$served" ] || { echo " TIMEOUT (~6m); last response: ${models:-<none>}"; exit 1; }

# 3. real generation , body inline so no quoting travels through make run/ssh
body="$(printf '{"model":"%s","messages":[{"role":"user","content":"Reply with exactly one word: ready"}],"max_tokens":16,"temperature":0}' "$model_id")"
t0="$(date +%s.%N)"
resp="$($K exec "$head" -- curl -s --max-time 60 "http://localhost:8000${route}/v1/chat/completions" -H 'content-type: application/json' -d "$body")"
t1="$(date +%s.%N)"
content="$(printf '%s' "$resp" | sed -n 's/.*"content":"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$content" ] || { echo "FAIL: empty completion. response: $resp"; exit 1; }
rt="$(awk "BEGIN{printf \"%.2f\", $t1-$t0}")"
echo "generated     : \"$content\"   (round-trip ${rt}s)"
echo "VERIFY PASS , $model_id is serving + generating"

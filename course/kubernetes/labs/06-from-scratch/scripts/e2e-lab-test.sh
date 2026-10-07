#!/usr/bin/env bash
# End-to-end validation of the from-scratch lab (run on the lab EC2 instance as ubuntu).
set -euo pipefail

LAB_DIR="${LAB_DIR:-$HOME/kubernetes-talks/course/kubernetes/labs/06-from-scratch}"
LOG_DIR="${HOME}/lab-logs"
mkdir -p "$LOG_DIR"

export ETCDCTL_API=3
export PATH="${HOME}/etcd-v3.5.0-linux-amd64:${PATH}"

log() { echo "[$(date -Is)] $*" | tee -a "${LOG_DIR}/e2e.log"; }
fail() { log "FAIL: $*"; exit 1; }
ok() { log "OK: $*"; }

wait_http() {
  local url="$1" tries="${2:-60}"
  for i in $(seq 1 "$tries"); do
    if curl -sf "$url" >/dev/null 2>&1; then return 0; fi
    sleep 2
  done
  return 1
}

wait_pods_ready() {
  local tries="${1:-120}"
  for i in $(seq 1 "$tries"); do
    local ready
    ready=$(kubectl get deploy hello-dep -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "")
    if [[ "$ready" == "3" ]]; then return 0; fi
    sleep 5
  done
  kubectl get pods -o wide || true
  return 1
}

cd "$HOME"

if [[ "${LAB_CLEAN:-1}" == "1" ]]; then
  log "=== cleanup previous run ==="
  sudo pkill -f 'kubernetes/server/bin/' 2>/dev/null || true
  pkill -f 'etcd-v3.5.0-linux-amd64/etcd' 2>/dev/null || true
  sleep 2
  rm -rf "${HOME}/default.etcd"
fi

log "=== etcd ==="
if [[ ! -x "${HOME}/etcd-v3.5.0-linux-amd64/etcd" ]]; then
  curl -sqL go.rael.dev/etcd-v35 | tar -zxf -
fi
sudo install "${HOME}/etcd-v3.5.0-linux-amd64/etcdctl" /usr/local/bin/

pkill -f 'etcd-v3.5.0-linux-amd64/etcd' 2>/dev/null || true
sleep 1
nohup "${HOME}/etcd-v3.5.0-linux-amd64/etcd" -log-level error >"${LOG_DIR}/etcd.log" 2>&1 &
sleep 2
curl -sf http://localhost:2379/health | grep -q '"health":"true"' || fail "etcd health"

log "=== kubernetes binaries ==="
if [[ ! -x "${HOME}/kubernetes/server/bin/kube-apiserver" ]]; then
  curl -sqL go.rael.dev/k8s1-16-0rc2 | tar -zxf -
fi

log "=== kube-apiserver ==="
pkill -f 'kubernetes/server/bin/kube-apiserver' 2>/dev/null || true
sleep 1
nohup sudo "${HOME}/kubernetes/server/bin/kube-apiserver" \
  --etcd-servers=http://localhost:2379 \
  --v=2 >"${LOG_DIR}/apiserver.log" 2>&1 &
wait_http "http://localhost:8080/healthz" 90 || fail "apiserver healthz"
ok "apiserver up"

log "=== configmap ==="
cm_count=$(curl -sq http://localhost:8080/api/v1/namespaces/default/configmaps | jq '.items | length')
[[ "$cm_count" == "0" ]] || log "warn: expected 0 configmaps, got $cm_count"

curl -s -X POST -H "Content-Type: application/json" \
  -d '{"apiVersion":"v1","kind":"ConfigMap","metadata":{"name":"hello-cm"},"data":{"GREETING":"Hello folks"}}' \
  http://localhost:8080/api/v1/namespaces/default/configmaps | jq -e '.metadata.name == "hello-cm" or .reason == "AlreadyExists"' >/dev/null \
  || fail "configmap create"

log "=== kubectl config ==="
sudo install "${HOME}/kubernetes/server/bin/kubectl" /usr/local/bin/
mkdir -p ~/.kube
kubectl config set-cluster localhost --server=http://localhost:8080 >/dev/null
kubectl config set-context localhost --cluster=localhost >/dev/null
kubectl config use-context localhost >/dev/null

kubectl get cm hello-cm -o jsonpath='{.data.GREETING}' | grep -q 'Hello folks' || fail "configmap via kubectl"

log "=== deployment ==="
cd "$LAB_DIR"
code=$(curl -sq -o /dev/null -w '%{http_code}' -X POST -H "Content-Type: application/json" \
  -d @hello-manifests/hello-dep.json \
  http://localhost:8080/api/v1/namespaces/default/deployments)
[[ "$code" == "404" ]] || fail "expected 404 on v1 deployments, got $code"

dep_code=$(curl -sq -o /tmp/hello-dep-resp.json -w '%{http_code}' -X POST -H "Content-Type: application/json" \
  -d @hello-manifests/hello-dep.json \
  http://localhost:8080/apis/apps/v1/namespaces/default/deployments)
[[ "$dep_code" == "201" || "$dep_code" == "409" ]] || fail "deployment create HTTP $dep_code"

rs_count=$(kubectl get rs --no-headers 2>/dev/null | wc -l)
[[ "$rs_count" == "0" ]] || fail "expected 0 replicasets before controller-manager"

log "=== controller-manager ==="
sudo "${HOME}/kubernetes/server/bin/kubeadm" init phase certs all >>"${LOG_DIR}/kubeadm-certs.log" 2>&1

pkill -f 'kubernetes/server/bin/kube-controller-manager' 2>/dev/null || true
sleep 1
nohup sudo "${HOME}/kubernetes/server/bin/kube-controller-manager" \
  --master=localhost:8080 \
  --service-account-private-key-file=/etc/kubernetes/pki/sa.key \
  --v=2 >"${LOG_DIR}/controller.log" 2>&1 &
sleep 8
rs_count=$(kubectl get rs --no-headers 2>/dev/null | wc -l)
[[ "$rs_count" -ge 1 ]] || fail "replicaset not created by controller-manager"

log "=== scheduler ==="
pkill -f 'kubernetes/server/bin/kube-scheduler' 2>/dev/null || true
sleep 1
nohup sudo "${HOME}/kubernetes/server/bin/kube-scheduler" \
  --master=localhost:8080 \
  --v=2 >"${LOG_DIR}/scheduler.log" 2>&1 &
sleep 3

log "=== kubelet ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/ensure-docker-for-kubelet.sh" | tee -a "${LOG_DIR}/e2e.log"
sudo systemctl start docker || sudo service docker start
sleep 2

pkill -f 'kubernetes/server/bin/kubelet' 2>/dev/null || true
sleep 1
nohup sudo "${HOME}/kubernetes/server/bin/kubelet" \
  --register-node \
  --kubeconfig="${HOME}/.kube/config" \
  --runtime-cgroups=/systemd/system.slice \
  --kubelet-cgroups=/systemd/system.slice \
  --cgroup-driver=cgroupfs \
  --pod-infra-container-image=k8s.gcr.io/pause:3.1 \
  --v=2 >"${LOG_DIR}/kubelet.log" 2>&1 &
sleep 5

kubectl get nodes --no-headers | grep -q Ready || {
  sleep 15
  kubectl get nodes -o wide || true
}

wait_pods_ready 150 || fail "pods not ready in time"
ok "all 3 pods ready"

log "=== service (before kube-proxy) ==="
kubectl apply -f hello-manifests/hello-svc.yml
cluster_ip=$(kubectl get svc hello -o jsonpath='{.spec.clusterIP}')
if curl -sf --connect-timeout 3 "http://${cluster_ip}" >/dev/null 2>&1; then
  log "warn: cluster IP responded before kube-proxy (unexpected but ok)"
else
  ok "cluster IP unreachable before kube-proxy (expected)"
fi

log "=== kube-proxy ==="
pkill -f 'kubernetes/server/bin/kube-proxy' 2>/dev/null || true
sleep 1
nohup sudo "${HOME}/kubernetes/server/bin/kube-proxy" \
  --master=localhost:8080 \
  --v=2 >"${LOG_DIR}/kube-proxy.log" 2>&1 &
sleep 8

for i in $(seq 1 30); do
  if curl -sf --connect-timeout 5 "http://${cluster_ip}" | head -c 20 >/dev/null 2>&1; then
    ok "hello service reachable via cluster IP"
    curl -sf --connect-timeout 5 "http://${cluster_ip}" | head -5 | tee -a "${LOG_DIR}/e2e.log"
    log "=== E2E LAB PASSED ==="
    exit 0
  fi
  sleep 3
done

fail "hello service not reachable after kube-proxy"
tail -50 "${LOG_DIR}/kube-proxy.log" || true
tail -50 "${LOG_DIR}/kubelet.log" || true
exit 1

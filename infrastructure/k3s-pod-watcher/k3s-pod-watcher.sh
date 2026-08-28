#!/bin/bash
# K3s Pod Watcher - Ensures critical pods are running after system boot

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Wait for k3s API to be ready
log "Waiting for k3s API to be ready..."
for i in {1..60}; do
    if /usr/local/bin/kubectl get nodes &>/dev/null; then
        log "k3s API is ready"
        break
    fi
    sleep 5
done

# Critical namespaces to check
NAMESPACES="argocd ejbca openbao pki spire"

for ns in $NAMESPACES; do
    log "Checking namespace: $ns"
    
    # Wait for pods to be ready
    for i in {1..30}; do
        NOT_READY=$(/usr/local/bin/kubectl get pods -n "$ns" --field-selector=status.phase!=Running,status.phase!=Succeeded -o name 2>/dev/null | wc -l)
        if [ "$NOT_READY" -eq 0 ]; then
            log "All pods in $ns are ready"
            break
        fi
        log "Waiting for $NOT_READY pods in $ns to be ready..."
        sleep 10
    done
    
    # Force delete any pods stuck in Error/Completed states
    /usr/local/bin/kubectl delete pods -n "$ns" --field-selector=status.phase=Failed --all 2>/dev/null || true
    /usr/local/bin/kubectl delete pods -n "$ns" --field-selector=status.phase=Succeeded --all 2>/dev/null || true
done

log "Pod watcher check complete"

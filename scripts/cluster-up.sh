#!/usr/bin/env bash
# scripts/cluster-up.sh - run from the jaka_infrastructure root
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -f .env ]]; then
    set -a; source .env; set +a
fi

services=(order payment inventory notification)
app_root=..
tag=${TAG:-dev-$(date +%s)}

for svc in "${services[@]}"; do
    for suffix in DB_PASS DB_ADMIN_PASS; do
        name="${svc^^}_${suffix}"
        [[ -n "${!name:-}" ]] || { echo "missing env $name" >&2; exit 1; }
    done
done

# 1. cluster
kind get clusters | grep -qx jaka || kind create cluster --config kind-config.yaml

# 1b. preload third-party images
cache_dir=${TMPDIR:-/tmp}/kind-images
mkdir -p "$cache_dir"
for img in postgres:16 redis:7-alpine axllent/mailpit:latest \
           quay.io/strimzi/kafka:1.3.1-kafka-4.3.1 \
           quay.io/strimzi/operator:1.3.1 \
           registry.k8s.io/metrics-server/metrics-server:v0.9.1 \
           docker.io/envoyproxy/gateway:v1.9.2; do
    docker image inspect "$img" >/dev/null 2>&1 || docker pull "$img"
    f="$cache_dir/$(echo "$img" | tr '/:' '__').tar"
    docker save --platform linux/amd64 "$img" -o "$f"
    kind load image-archive "$f" --name jaka
done


# 2. image
for svc in "${services[@]}"; do
    docker build -t "$svc-service:$tag" "$app_root/$svc-service/$svc-service"
    kind load docker-image "$svc-service:$tag" --name jaka
done

# 3. namespace + secret (dry-run | apply = idempotent)

for ns in dev kafka; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
for svc in "${services[@]}"; do
    up=${svc^^}
    app_var="${up}_DB_PASS"; admin_var="${up}_DB_ADMIN_PASS"
    kubectl create secret generic "$svc-service-secret" -n dev \
        --from-literal=SPRING_DATASOURCE_PASSWORD="${!app_var}" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create secret generic "$svc-db-admin"       -n dev \
        --from-literal=password="${!admin_var}"                 --dry-run=client -o yaml | kubectl apply -f -
done

# 4. Add-on
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.1/components.yaml
if ! kubectl get deploy metrics-server -n kube-system \
        -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q kubelet-insecure-tls; then
    kubectl patch deploy metrics-server -n kube-system --type=json --patch-file k8s/metrics-server-patch.json
fi
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm --version v1.9.2 \
    -n envoy-gateway-system --create-namespace --wait
if [[ -z "$(kubectl get deploy strimzi-cluster-operator -n kafka --ignore-not-found -o name)" ]]; then
    curl -sL https://github.com/strimzi/strimzi-kafka-operator/releases/download/1.3.1/strimzi-cluster-operator-1.3.1.yaml \
        | sed 's/namespace: myproject/namespace: kafka/' \
        | kubectl create -f - -n kafka
fi
kubectl wait deploy/strimzi-cluster-operator -n kafka --for=condition=Available --timeout=5m

# 5. kafka
kubectl apply -f k8s/kafka/kafka-single-node.yml -n kafka
kubectl wait kafka/jaka -n kafka --for=condition=Ready --timeout=10m
kubectl apply -f k8s/kafka/topics.yml

# 6. DB, Redis, Job taoj role, Mailpit
for svc in "${services[@]}"; do kubectl apply -f "k8s/$svc-service/"; done
for svc in "${services[@]}"; do
    kubectl rollout status "statefulset/$svc-db" -n dev --timeout=5m
done

# 7. App
for svc in "${services[@]}"; do
    helm upgrade --install "$svc-service" charts/spring-service -n dev \
        -f "charts/spring-service/values/$svc-dev.yml" --set image.tag="$tag"
done

# 8. gateway
kubectl apply -f k8s/gateway.yml
kubectl wait --for=condition=Accepted gateway/web        -n dev --timeout=2m
kubectl wait --for=condition=Available deploy    --all   -n dev --timeout=10m

echo "Done. Open gateway in other terminal:"
echo ' svc=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=web -o name)'
echo ' kubectl port-forward -n envoy-gateway-system $svc 8090:80'

# 9. dọn image cũ trên node (giữ tag vừa deploy)
for n in jaka-control-plane jaka-worker jaka-worker2; do
    docker exec "$n" crictl images -o json \
      | jq -r '.images[].repoTags[]' \
      | grep -E '/(order|payment|inventory|notification)-service:dev-' \
      | grep -v ":$tag$" \
      | xargs -r docker exec "$n" crictl rmi || true
done

#!/usr/bin/env bash
set -euo pipefail

svc="${1:?Missing service name (order|payment|inventory|notification)}"
tag="${2:-}"
region="${AWS_REGION:-ap-southeast-1}"

: "${REGISTRY:?REGISTRY must be set (e.g <acct>.dkr.ecr.${region}.amazonaws.com)}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
repo_name="jaka-mod-${svc}-service"

#No tag given -> ask ECR for the newest one
newest_tag() {
    aws ecr describe-images --region "$region" \
        --repository-name "$repo_name" \
        --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' \
        --output text
}

if [ -z "$tag" ] || [ "$tag" = "latest" ]; then
    tag="$(newest_tag)"
    echo ">> Using newest tag in ECR: $tag"
fi

release="${svc}-service"

echo ">> Deploying $release image=${REGISTRY}/${repo_name}:${tag}"
if ! helm upgrade --install "$release" "$repo_root/charts/spring-service" \
        -n dev \
        -f "$repo_root/charts/spring-service/values/${svc}-eks.yml" \
        --set "image.repository=${REGISTRY}/${repo_name}" \
        --set "image.tag=${tag}" \
       --wait --rollback-on-failure --timeout "${TIMEOUT:-10m}"; then
    echo "!! Deploy faileed - helm rolled back to the previous revision. History:"
    helm history "$release" -n dev | tail -5
    exit 1
fi

# --- Smoke test: call readiness from inside the cluster ----
port="$(helm get values "$release" -n dev --all -o json | jq -r '.port')"
ctx="$(helm get values "$release" -n dev --all -o json | jq -r '.contextPath')"

echo ">> Smoke test: http://${release}:${port}${ctx}/actuator/health/readiness"
if kubectl run "smoke-${svc}-$$" --rm -i --restart=Never --quiet -n dev \
        --image=curlimages/curl:8.23.0 -- \
        curl -sf "http://${release}:${port}${ctx}/actuator/health/readiness"; then
    echo ">> OK: $release is ready."
else
    echo "!! Smoke test failed - roll back manaually:"
    echo "  helm rollback $release -n dev"
    exit 1
fi
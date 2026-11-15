#!/usr/bin/env bash
# scripts/eks-up.sh - run from anywhere, after `terraform apply` in envs/dev-eks
# Same shape as cluster-up.sh, minus everything AWS now provides (DB, Redis, secrets, LB).
set -euo pipefail
cd "$(dirname "$0")/.."

services=(order payment inventory notification)
app_root=..
# tag=${TAG:-eks-$(date +%s)}

# Every value that only exists after `terraform apply` is read from here - never typed by hand
tf_out() { terraform -chdir=envs/dev-eks output -json "$1"; }
tf_raw() { terraform -chdir=envs/dev-eks output -raw "$1"; }
region=$(tf_raw region)
cluster=$(tf_raw cluster_name)
vpc_id=$(tf_raw vpc_id)
# ecr_urls=$(terraform -chdir=envs/shared output -json ecr_repository_urls)
db_hosts=$(tf_out db_endpoints)
admin_arns=$(tf_out db_admin_secret_arns)
redis_host=$(tf_raw redis_primary_endpoint)
pick() { jq -r --arg s "$2" '.[$s]' <<<"$1"; }    # pick "$ecr_urls" order -> value for key "order"

# 1. kubeconfig -> kubectl/helm now talk to EKS, not kind
aws eks update-kubeconfig --region "$region" --name "$cluster"

# # 2. image: build + push to ECR (replaces `kind load`)
# registry=$(pick "$ecr_urls" order); registry=${registry%%/*}    # 123456789012.dkr.ecr.<region>.amazonaws.com
# aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$registry"
# for svc in "${services[@]}"; do
#     repo=$(pick "$ecr_urls" "$svc")
#     docker build --platform linux/amd64 -t "$repo:$tag" "$app_root/$svc-service/$svc-service"
#     docker push "$repo:$tag"
# done

# 3. namespace (no `kubectl create secret` here - ESO does that in step 6)
for ns in dev kafka; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
# 3b. infra ConfigMap per service: config that changes only when the infrastructure is rebuilt
for svc in "${services[@]}"; do
    args=(--from-literal "SPRING_DATASOURCE_URL=jdbc:postgresql://$(pick "$db_hosts" "$svc"):5432/${svc}db?sslmode=require")
    [[ $svc == order || $svc == payment ]] && args+=(--from-literal "SPRING_DATA_REDIS_HOST=$redis_host")
    kubectl create configmap "$svc-service-infra" -n dev "${args[@]}" \
        --dry-run=client -o yaml | kubectl apply -f -
done

# 4. add-on
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.1/components.yaml
helm repo add eks https://aws.github.io/eks-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo update eks external-secrets
# LB Controller first: its webhook must be up before any Service type LoadBalancer is created
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller --version 3.6.2 \
    -n kube-system --set clusterName="$cluster" --set vpcId="$vpc_id" --set region="$region" --wait
helm upgrade --install external-secrets external-secrets/external-secrets --version 2.14.0 \
    -n external-secrets --create-namespace --wait --timeout 10m
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm --version v1.9.2 \
    -n envoy-gateway-system --create-namespace --wait
if [[ -z "$(kubectl get deploy strimzi-cluster-operator -n kafka --ignore-not-found -o name)" ]]; then
    curl -sL https://github.com/strimzi/strimzi-kafka-operator/releases/download/1.3.1/strimzi-cluster-operator-1.3.1.yaml \
        | sed 's/namespace: myproject/namespace: kafka/' \
        | kubectl create -f - -n kafka
fi
kubectl wait deploy/strimzi-cluster-operator -n kafka --for=condition=Available --timeout=5m

# 5. cluster-wide objects for EKS: default StorageClass (Kafka PVC) + how ESO talks to AWS
kubectl apply -f k8s/eks/storageclass-gp3.yml
kubectl apply -f k8s/eks/cluster-secret-store.yml

# 6. secret: ExternalSecret x8 -> ESO reads Secrets Manager -> creates the same k8s Secrets kind had
for SVC in "${services[@]}"; do
    ADMIN_SECRET_ARN=$(pick "$admin_arns" "$SVC") SVC=$SVC \
        envsubst '${SVC} ${ADMIN_SECRET_ARN}' < k8s/eks/external-secrets.yml.tpl
done | kubectl apply -f -
kubectl wait externalsecret --all -n dev --for=condition=Ready --timeout=5m

# 7. Job that creates <svc>_user in RDS
#    delete first: a Job's pod template is immutable, and the SQL is idempotent (ALTER if exists)
for SVC in "${services[@]}"; do
    kubectl delete job "$SVC-db-create-app-role" -n dev --ignore-not-found
done
for SVC in "${services[@]}"; do
    DB_HOST=$(pick "$db_hosts" "$SVC") SVC=$SVC \
        envsubst '${SVC} ${DB_HOST}' < k8s/eks/create-app-role.yml.tpl
done | kubectl apply -f -
for SVC in "${services[@]}"; do
    kubectl wait "job/$SVC-db-create-app-role" -n dev --for=condition=Complete --timeout=5m
done

# 8. kafka (PVC -> gp3 EBS via EBS CSI) + Mailpit (only this file from k8s/notification-service/ -
#    the other files there are kind's in-cluster DB/Redis, replaced by RDS/ElastiCache)
kubectl apply -f k8s/kafka/kafka-single-node.yml -n kafka
kubectl wait kafka/jaka -n kafka --for=condition=Ready --timeout=10m
kubectl apply -f k8s/kafka/topics.yml
kubectl apply -f k8s/notification-service/mailpit.yml

# # 9. App: values/<svc>-eks.yml + values only known after apply via --set
# for svc in "${services[@]}"; do
#     extra=()
#     [[ $svc == order || $svc == payment ]] && extra=(--set env.SPRING_DATA_REDIS_HOST="$redis_host")
#     helm upgrade --install "$svc-service" charts/spring-service -n dev \
#         -f "charts/spring-service/values/$svc-eks.yml" \
#         --set image.repository="$(pick "$ecr_urls" "$svc")" \
#         --set image.tag="$tag" \
#         --set env.SPRING_DATASOURCE_URL="jdbc:postgresql://$(pick "$db_hosts" "$svc"):5432/${svc}db?sslmode=require" \
#         "${extra[@]}"
# done

# 10. gateway -> NLB
#     gateway.yml is shared with kind: add parametersRef on the fly (sed) instead of editing the file.
#     Done in the same apply as the Gateway, so Envoy's Service is born with the NLB annotations
#     (patching afterwards would first create an internal LB, then try to change it).
kubectl apply -f k8s/eks/envoyproxy-nlb.yml
sed '/controllerName: gateway.envoyproxy.io\/gatewayclass-controller/a\
  parametersRef: { group: gateway.envoyproxy.io, kind: EnvoyProxy, name: nlb, namespace: envoy-gateway-system }' \
    k8s/gateway.yml | kubectl apply -f -
kubectl wait --for=condition=Accepted  gateway/web -n dev --timeout=2m
kubectl wait --for=condition=Available deploy --all -n dev --timeout=10m
kubectl wait --for=condition=Programmed gateway/web -n dev --timeout=10m    # = NLB has a DNS name

nlb=$(kubectl get gateway web -n dev -o jsonpath='{.status.addresses[0].value}')
echo "Done. NLB: http://$nlb  (DNS can take 1-3 min to resolve)"
echo " BASE_URL=http://$nlb ./scripts/saga-demo.sh --timeout"

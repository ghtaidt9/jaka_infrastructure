# Create the Secret with a command — don't commit a YAML file containing the password
kubectl create secret generic order-service-secret -n dev --from-literal=SPRING_DATASOURCE_PASSWORD=order_pass

## Read it back (PowerShell has no base64 -d)
$b64 = kubectl get secret order-service-secret -n dev -o jsonpath='{.data.SPRING_DATASOURCE_PASSWORD}'
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))

# Deployment
## Change one log line in the code, then from order-service/order-service/ build + load v2 FIRST
docker build -t order-service:v2 .
kind load docker-image order-service:v2 --name jaka

## jaka_infrastructure/ (namespace, Secret, ConfigMap, DB already created in Step 2.0)
kubectl apply -f k8s/order-service/
kubectl get deploy,rs,pods -n dev -l app=order-service
kubectl delete pod -n dev <any-one-pod>        # the ReplicaSet creates a new Pod immediately
kubectl set image deploy/order-service order-service=order-service:v2 -n dev
kubectl rollout status deploy/order-service -n dev
kubectl rollout history deploy/order-service -n dev
kubectl rollout undo deploy/order-service -n dev

kubectl get svc,endpointslices -n dev
kubectl run curl -n dev --rm -it --restart=Never --image=curlimages/curl -- curl -s http://order-service:8081/api/orders/actuator/health
kubectl port-forward -n dev svc/order-service 8081:8081
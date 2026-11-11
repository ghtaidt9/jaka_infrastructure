---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: ${SVC}-service-secret
  namespace: dev
spec:
  refreshInterval: 1h
  secretStoreRef: { kind: ClusterSecretStore, name: aws-secrets-manager }
  target:
    name: ${SVC}-service-secret         # trùng secretName trong values/<svc>-*.yml
  data:
    - secretKey: SPRING_DATASOURCE_PASSWORD
      remoteRef:
        key: jaka-mod-dev-eks/${SVC}-db/app-credentials
        property: password
    - secretKey: SPRING_DATA_REDIS_PASSWORD
      remoteRef:
        key: jaka-mod-dev-eks/redis/auth-token  # chuỗi thuần → không có property
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: ${SVC}-db-admin
  namespace: dev
spec:
  refreshInterval: 1h
  secretStoreRef: { kind: ClusterSecretStore, name: aws-secrets-manager }
  target:
    name: ${SVC}-db-admin
  data:
    - secretKey: password
      remoteRef:
        key: ${ADMIN_SECRET_ARN}               # tên do RDS đặt → dùng ARN
        property: password

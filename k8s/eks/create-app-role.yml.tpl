---
apiVersion: batch/v1
kind: Job
metadata:
  name: ${SVC}-db-create-app-role
  namespace: dev
spec:
  backoffLimit: 5
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: psql
          image: postgres:16
          env:
            - name: PGHOST
              value: ${DB_HOST}
            - name: PGSSLMODE
              value: require
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${SVC}-db-admin
                  key: password
            - name: APP_PASS
              valueFrom:
                secretKeyRef:
                  name: ${SVC}-service-secret
                  key: SPRING_DATASOURCE_PASSWORD
          command: ["sh", "-c"]
          args:
            - |
              psql -U ${SVC}_admin -d ${SVC}db -v ON_ERROR_STOP=1 -v app_pass="$APP_PASS" <<'SQL'
              SELECT EXISTS (SELECT FROM pg_roles WHERE rolname = '${SVC}_user') AS role_exists \gset
              \if :role_exists
              ALTER ROLE ${SVC}_user WITH PASSWORD :'app_pass';
              \else
              CREATE ROLE ${SVC}_user LOGIN PASSWORD :'app_pass';
              \endif
              GRANT CREATE, USAGE ON SCHEMA public TO ${SVC}_user;
              SQL

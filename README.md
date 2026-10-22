# jaka_infrastructure

## Rolling update (Kubernetes) vs instance refresh (ASG, Month 1)

Both replace the running version of a service gradually, without taking it fully offline. The difference is **what gets replaced**: an ASG replaces whole EC2 instances, while a Deployment replaces only containers (Pods) on nodes that are already running.

### How each one works

**ASG instance refresh (Month 1, `modules/service/compute.tf`)**

1. Write the new image tag to the SSM parameter `/<prefix>/<service>-image-tag`
2. Start a refresh: `aws autoscaling start-instance-refresh`. The launch template does not change (user-data reads the tag at boot), so Terraform will not start a refresh on its own
3. The ASG launches new EC2 instances: boot Ubuntu → user-data installs Docker + CloudWatch Agent → pulls the image from ECR → `docker run`
4. The ALB target group health check (`interval = 10`, `healthy_threshold = 2`) has to pass, then the ASG waits out `instance_warmup = 300` seconds
5. Old instances are deregistered and terminated

**Kubernetes rolling update (Week 6, `k8s/order-service/deployment.yml`)**

1. `kubectl set image deploy/order-service order-service=order-service:v2 -n dev`
2. The Deployment creates a new ReplicaSet for v2 and scales it up 1 Pod at a time (`maxSurge: 1`)
3. Once a new Pod is Ready, one old Pod is removed (`maxUnavailable: 0` keeps capacity at 2 the whole time)
4. The old ReplicaSet is kept at 0 replicas, ready for rollback

### Side-by-side

| | ASG instance refresh | K8s rolling update |
|---|---|---|
| Unit replaced | EC2 instance (VM) | Pod (container) |
| Trigger | Update SSM tag + `start-instance-refresh` | `kubectl set image` / `kubectl apply` |
| Startup cost | VM boot + user-data + image pull: **minutes** | Container start (image already on node): **seconds** + Spring Boot startup |
| Health gate | ALB target group health check + 300s warmup | readinessProbe (added in week 7; week 6 has none, so traffic can hit a Pod before Spring Boot is up) |
| Capacity during update | `min_healthy_percentage = 100`, `max_healthy_percentage = 200` → never below desired, may double | `maxUnavailable: 0`, `maxSurge: 1` → never below 2, at most 3 Pods |
| Extra cost during update | Extra EC2 instances (billed) | One extra Pod on existing nodes (no new machine) |
| Rollback | Write the previous tag back (`<service>-image-tag-previous`) and run **another** full refresh | `kubectl rollout undo`: old ReplicaSet scales back up, seconds |
| History | None built in (only SSM parameter versions) | `kubectl rollout history` (revisions) |
| If the new version never gets healthy | Refresh fails/cancels; old instances stay (auto-rollback only if enabled) | Rollout hangs; after 600s reports `ProgressDeadlineExceeded`, **no** automatic rollback |

### Takeaway

- **Speed:** K8s is faster because it never boots a machine. The node is already up, so only the container changes.
- **Rollback:** K8s rollback is cheap because the previous ReplicaSet is still there. On the ASG, rollback is just another deployment.
- **Health checks:** Both need a real health gate to be zero-downtime. On AWS that is the target group health check; on K8s it is the readinessProbe, which this repo adds in week 7.
- **Shared pitfall:** neither one rolls back automatically by default. A bad version leaves the update stuck, and someone has to undo it.

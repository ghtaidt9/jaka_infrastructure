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

## EKS (Week 10): `modules/eks` + `envs/dev-eks`

The same Spring Boot services that run on kind locally can run on Amazon EKS. EKS is a separate stack next to the Month 1 EC2 stack: it does not replace or modify `envs/dev`.

### Layout

```
modules/
├── network/            shared; gained public_subnet_tags / private_subnet_tags (default {}, so envs/dev is unchanged)
└── eks/                wraps terraform-aws-modules/eks/aws ~> 21.0
    └── tests/          mock-provider tests (no AWS account needed)
envs/
├── dev/                Month 1: VPC + ALB + ASG + RDS + ElastiCache (aws ~> 5.50)
└── dev-eks/            VPC + EKS cluster + Pod Identity roles (aws ~> 6.0)
```

`envs/dev-eks` calls `modules/network` and `modules/eks` directly. It does not go through `stack/`, which is the EC2/ASG/RDS bundle.

### Why a separate stack and state file

- **Lifecycle:** the EKS control plane costs ~0.10 USD/hour even with no Pods. `terraform destroy` in `envs/dev-eks` removes only EKS; `envs/dev` and its RDS data stay.
- **Provider version:** EKS module v21 needs `aws >= 6.0`, `envs/dev` pins `~> 5.50`. Shared modules declare a minimum (`modules/network`: `>= 5.50`) and each root pins its own major version.
- **Blast radius:** a failed apply or broken state in one stack cannot touch the other.
- **Same bucket, different key:** `dev/terraform.tfstate` and `dev-eks/terraform.tfstate`, both with S3-native locking (`use_lockfile`).

### kind vs EKS

| | kind (local) | EKS (`envs/dev-eks`) |
|---|---|---|
| Control plane | Container on the laptop | Managed by AWS, outside the VPC, HA across 3 AZs |
| Nodes | Containers (`jaka-worker`, `jaka-worker2`) | EC2 managed node group, 2–4 × `t3.medium` in private subnets |
| Pod IP | Docker network (kindnet) | Real VPC IP per Pod (VPC CNI), so private subnets are `/20`, not `/24` |
| Load balancer | None (`AddressNotAssigned`), port-forward 8090 | NLB/ALB via AWS Load Balancer Controller, using the `kubernetes.io/role/*elb` subnet tags |
| Storage | `standard` (local-path) | EBS `gp3` (`aws-ebs-csi-driver` addon) |
| Pod → AWS permissions | None | EKS Pod Identity, one IAM role per ServiceAccount |
| Cost | 0 | Control plane + EC2 nodes + NAT gateway, billed hourly |

### Pod Identity vs the Month 1 instance profile

On the EC2 stack, `modules/service/iam.tf` attaches an IAM role to the **instance profile**: every process on the machine gets the same permissions (SSM parameters, Secrets Manager, KMS, S3 prefix).

On EKS one node runs Pods from **several** services, so a node-wide role would let `payment-service` read `order-service` secrets. `envs/dev-eks/pod-identity.tf` instead creates, per service:

1. an IAM role whose trust policy allows only `pods.eks.amazonaws.com` (`sts:AssumeRole`, `sts:TagSession`)
2. an inline policy limited to `ssm:GetParameter*` on `/jaka-mod/dev-eks/<service>/*`
3. an `aws_eks_pod_identity_association` binding that role to ServiceAccount `<service>` in namespace `dev`

The Helm chart creates the ServiceAccount (`templates/serviceaccount.yml`, name = release name) and the Deployment sets `serviceAccountName`. IRSA/OIDC is disabled (`enable_irsa = false`) because Pod Identity replaces it.

### Endpoint access

`dev-eks` uses a public API endpoint (still IAM-authenticated) so `kubectl` works from a laptop. For production the plan is a private endpoint, reached through an SSM port-forward via an instance inside the VPC (the same pattern used to reach RDS), with deployments done by GitOps instead of CI pushing to the cluster.

### Verify without an AWS account

```bash
# from the repo root
(cd modules/eks && terraform init && terraform test)    # 3 runs: node_min < 2 rejected, 1 subnet rejected, valid plan
(cd envs/dev-eks && terraform init -backend=false && terraform validate)
```

CI runs the same checks (`test` matrix includes `modules/eks`, `validate-envs` includes `dev-eks`), plus `fmt`, `tflint` and `checkov`.

### Apply for real

```bash
cd envs/dev-eks
terraform init -backend-config backend.hcl      # replace <ACCOUNT_ID> first
terraform apply -var-file terraform.tfvars
aws eks update-kubeconfig --region ap-southeast-1 --name jaka-mod-dev-eks
kubectl get nodes
terraform destroy -var-file terraform.tfvars    # right after practice: EKS + NAT bill by the hour
```

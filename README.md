# Voting App

A distributed voting application containerized with Docker and orchestrated using Docker Compose with two-tier networking, health checks, and a multi-service backend.

---

## Author

**Zeyad Elgohari** — Cloud & DevOps Engineer

- GitHub: [github.com/ziadtd](https://github.com/ziadtd)
- LinkedIn: [linkedin.com/in/ziadtd](https://linkedin.com/in/ziadtd)
- Email: ziadtareqd22@gmail.com

---

## Stage 1: Local Containerization

```
                    ┌─────────────────────────────┐
                    │       Frontend Network      │
                    │                             │
                    │  ┌──────────┐  ┌──────────┐ │
                    │  │  Vote    │  │  Result  │ │
                    │  │          │  │          │ │
                    │  └────┬─────┘  └────┬─────┘ │
                    └───────┼─────────────┼───────┘
                            │             │
                    ┌───────┼─────────────┼─────────┐
                    │       │  Backend Network      │
                    │       ▼             ▼         │
                    │  ┌─────────┐  ┌──────────┐    │
                    │  │  Redis  │  │ Postgres │    │
                    │  └────┬────┘  └────┬─────┘    │
                    │       │            │          │
                    │       └────┬───────┘          │
                    │            ▼                  │
                    │       ┌─────────┐             │
                    │       │ Worker  │             │
                    │       └─────────┘             │
                    └───────────────────────────────┘
```

### Services

| Service | Language              | Port | Role                                           |
| ------- | --------------------- | ---- | ---------------------------------------------- |
| vote    | Python / Flask        | 8080 | Voting UI — sends votes to Redis               |
| result  | Node.js               | 8081 | Results UI — reads from Postgres via WebSocket |
| worker  | .NET                  | —    | Processes votes from Redis → Postgres          |
| redis   | Redis 7               | 6379 | Message queue (internal only)                  |
| db      | PostgreSQL 15         | 5432 | Vote storage (internal only)                   |
| seed    | Python + Apache Bench | —    | Populates test data (optional)                 |

### Data Flow

1. User visits **vote** service and casts a vote
2. Vote is pushed to **Redis** queue
3. **Worker** reads from Redis and writes to **PostgreSQL**
4. **Result** service queries Postgres and displays live results via WebSocket

---

### Steps:

### 1. Write the Dockerfiles:

[Vote](/vote/Dockerfile)
[Result](/result/Dockerfile)
[Worker](/worker/Dockerfile)
Optional: [Seed](/seed-data/Dockerfile)

### 2. Write the Compose Yaml manifest:

[docker-compose.yml](./docker-compose.yml)

### 3. Start the application

```bash
docker compose up --build
```

### 4. Access the services

| Service | URL                   |
| ------- | --------------------- |
| Vote    | http://localhost:8080 |
| Results | http://localhost:8081 |

### 5. (Optional) Seed test data

```bash
docker compose --profile seed up seed
```

This sends 3000 test votes — 2000 for option A and 1000 for option B using Apache Bench.

---

## Stage 2: Push Images to AWS ECR

### Steps:

### Step 1: Configure AWS CLI

```bash
aws configure
```

Enter credentials when prompted:

| Field                 | Value                                  |
| --------------------- | -------------------------------------- |
| AWS Access Key ID     | From IAM → User → Security credentials |
| AWS Secret Access Key | From IAM → User → Security credentials |
| Default region        | `us-east-1`                            |
| Default output format | `json`                                 |

Verify authentication:

```bash
aws sts get-caller-identity
```

### Step 2: Create ECR Repositories

Create a repository for each service:

```bash
aws ecr create-repository --repository-name voting-app/vote --region us-east-1
aws ecr create-repository --repository-name voting-app/result --region us-east-1
aws ecr create-repository --repository-name voting-app/worker --region us-east-1
aws ecr create-repository --repository-name voting-app/seed --region us-east-1
```

### Step 3: Authenticate Docker with ECR

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  544885083314.dkr.ecr.us-east-1.amazonaws.com
```

### Step 4: Tag Images

Tag each local image with the full ECR URI:

```bash
docker tag voting-app-vote:latest 544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/vote:latest
docker tag voting-app-result:latest 544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/result:latest
docker tag voting-app-worker:latest 544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/worker:latest
docker tag voting-app-seed:latest 544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/seed:latest
```

### Step 5: Push Images to ECR

```bash
docker push 544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/vote:latest
docker push 544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/result:latest
docker push 544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/worker:latest
docker push 544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/seed:latest
```

ECR Image URIs

| Service | ECR URI                                                                 |
| ------- | ----------------------------------------------------------------------- |
| result  | `544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/result:latest` |
| worker  | `544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/worker:latest` |
| vote    | `544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/vote:latest`   |
| seed    | `544885083314.dkr.ecr.us-east-1.amazonaws.com/voting-app/seed:latest`   |

---

## Stage 3: Provision EKS Cluster with Terraform

### Terraform Files

[main.tf](/terraform/main.tf)
[variables.tf](/terraform/variables.tf)
[vpc.tf](/terraform/vpc.tf)
[eks.tf](/terraform/eks.tf)
[outputs.tf](/terraform/outputs.tf)

### Steps

### Step 1: Initialize Terraform

```bash
cd terraform
terraform init
```

### Step 2: Import existing ECR repositories

```bash
terraform import aws_ecr_repository.vote voting-app/vote
terraform import aws_ecr_repository.result voting-app/result
terraform import aws_ecr_repository.worker voting-app/worker
terraform import aws_ecr_repository.seed voting-app/seed
```

### Step 4: Apply

```bash
terraform apply
```

### Step 5: Connect kubectl

Once `terraform apply` completes, configure kubectl:

```bash
aws eks update-kubeconfig --region us-east-1 --name voting-app-cluster
```

Confirm Access

```bash
kubectl get nodes
```

## Stage 4: Deploy to EKS with Kubernetes

### Step 1: Install EBS CSI Driver

EKS needs the EBS CSI driver to provision persistent volumes for PostgreSQL.

Create IAM role for EBS CSI driver

```bash
aws iam create-role \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::544885083314:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/47529B3A57E7E923C46E83CB098D3473"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "oidc.eks.us-east-1.amazonaws.com/id/47529B3A57E7E923C46E83CB098D3473:aud": "sts.amazonaws.com",
            "oidc.eks.us-east-1.amazonaws.com/id/47529B3A57E7E923C46E83CB098D3473:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  }'

aws iam attach-role-policy \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
```

Install the addon

```bash
aws eks create-addon \
  --cluster-name voting-app-cluster \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::<account-id>:role/AmazonEKS_EBS_CSI_DriverRole \
  --region us-east-1
```

### Step 2: Install AWS Load Balancer Controller

Add Helm repo

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

Create IAM policy

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

Create IAM role

```bash
aws iam create-role \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::<account-id>:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/47529B3A57E7E923C46E83CB098D3473"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "oidc.eks.us-east-1.amazonaws.com/id/47529B3A57E7E923C46E83CB098D3473:aud": "sts.amazonaws.com",
            "oidc.eks.us-east-1.amazonaws.com/id/47529B3A57E7E923C46E83CB098D3473:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  }'

aws iam attach-role-policy \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::544885083314:policy/AWSLoadBalancerControllerIAMPolicy
```

Create Kubernetes service account

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::544885083314:role/AmazonEKSLoadBalancerControllerRole
EOF
```

Install via Helm

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=voting-app-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Step 3: Kubernetes Manifests

[configmap.yaml](/k8s/configmap.yaml)
[secret.yaml](/k8s/secret.yaml)
[postgres-statefulset.yaml](/k8s/postgres-statefulset.yaml)
[postgres-service.yaml](/k8s/postgres-service.yaml)
[redis-deployment.yaml](/k8s/redis-deployment.yaml)
[worker-deployment.yaml](/k8s/worker-deployment.yaml)
[vote-deployment.yaml](/k8s/vote-deployment.yaml)
[result-deployment.yaml](/k8s/result-deployment.yaml)

### Step 4: Deploy

```bash
kubectl apply -f k8s/
```

### Step 5: Get Public URLs

```bash
kubectl get svc vote result
```

| Service | URL                       |
| ------- | ------------------------- |
| Vote    | `http://k8s-default-vote-30b2f27878-f442a93df1fa4f87.elb.us-east-1.amazonaws.com/`   |
| Result  | `http://k8s-default-result-fad4916963-ff6f7c604c87913b.elb.us-east-1.amazonaws.com/` |


### Step 6: (Optional) Seed Test Data

The seed service sends 3000 test votes — 2000 for option A and 1000 for option B — using Apache Bench.

[seed-job.yaml](/k8s/seed-job.yaml)

 Run the seed job

```bash
kubectl apply -f k8s/seed-job.yaml
```

Clean up after seeding

```bash
kubectl delete job seed
```


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

[main.tf](./terraform/main.tf)
[variables.tf](./terraform/variables.tf)
[vpc.tf](./terraform/vpc.tf)
[eks.tf](./terraform/eks.tf)
[outputs.tf](./terraform/outputs.tf)

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


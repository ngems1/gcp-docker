# Profile app on a GCE VM (GitHub Actions + OIDC)

Node.js app on a single Compute Engine VM (Docker Compose), with
**Firestore with MongoDB compatibility** as the database.

Keyless end to end:
- GitHub Actions authenticates to Google Cloud with **Workload Identity Federation (OIDC)**.
  No service-account JSON key or SSH key is stored in GitHub.
- The app authenticates to Firestore with **MONGODB-OIDC** as the VM's service account.
  There is no database username or password anywhere.

```mermaid
flowchart LR
  subgraph GH[GitHub]
    repo[Repository<br/>push to main] --> runner[Actions runner<br/>id-token: write]
  end
  subgraph GCP[Google Cloud project]
    wif[Workload Identity Federation<br/>repo == yours && ref == main]
    sa[gh-deployer SA]
    ar[(Artifact Registry)]
    iap[Identity-Aware Proxy<br/>:22 only]
    fs[(Firestore<br/>MongoDB compat<br/>db: user-account)]
    subgraph VM[Compute Engine VM - SA profile-app-vm]
      app[my-app :80] -- ID token aud=FIRESTORE --> md[metadata server]
    end
  end
  users((Users)) -- HTTP :80 --> app
  runner -- "1 OIDC JWT" --> wif
  wif -- "2 impersonate" --> sa
  sa -- "3 short-lived token" --> runner
  runner -- "4 docker push" --> ar
  runner -- "5 ssh/scp via IAP" --> iap
  iap -- "6 sudo deploy.sh" --> VM
  VM -- "7 pull image" --> ar
  app -- "8 MONGODB-OIDC, TLS 443" --> fs
```

## Layout

| Path | What it is |
|---|---|
| `.github/workflows/deploy-gce.yml` | Build → push to Artifact Registry → deploy over IAP SSH → smoke test |
| `infra/terraform/` | All GCP infrastructure: APIs, VPC/subnet/firewall, static IP, Firestore, Artifact Registry, WIF pool/provider, service accounts + IAM, VM |
| `infra/vm-startup.sh` | VM startup script that installs Docker + compose plugin |
| `deploy/docker-compose.yml` | What runs on the VM (`/opt/profile-app`) |
| `deploy/deploy.sh` | Runs on the VM: writes `.env` (image + Firestore URL from instance metadata), pulls, `compose up`, health + DB check |
| `docker-compose.yaml` | Local development only: a MongoDB container + mongo-express |

## Setup (once)

1. Push this folder to a GitHub repo.
2. Create the infrastructure with Terraform (>= 1.6, or OpenTofu), logged in as a project Owner
   (`gcloud auth application-default login`, or just use Cloud Shell, which has Terraform installed):
   ```bash
   cd infra/terraform
   cp terraform.tfvars.example terraform.tfvars   # set project_id and github_repo
   terraform init
   terraform plan
   terraform apply
   ```
3. Set the GitHub repository variables from the outputs:
   ```bash
   terraform output -raw gh_variable_commands | bash    # needs the GitHub CLI, logged in
   ```
   or copy `terraform output github_variables` into
   **Settings → Secrets and variables → Actions → Variables**. None of them are secrets.
4. Push to `main` (or run the workflow manually). The job summary shows the app URL
   (`terraform output app_url`).

Tear everything down with `terraform destroy`. The Firestore database is deleted too unless
`protect_database = true`. A destroyed Workload Identity Pool keeps its ID reserved for 30 days,
so set a new `wif_pool_id` if you re-create within that window.

For a team setup, move the state to a GCS bucket (see the commented `backend "gcs"` block in
`versions.tf`).

## Networking

| Resource | Name | Settings |
|---|---|---|
| VPC | `profile-app-vpc` | custom subnet mode (no default-network open rules) |
| Subnet | `profile-app-subnet` | `10.10.0.0/24`, `us-east1`, Private Google Access on |
| Firewall | `profile-app-allow-http` | ingress `tcp:80` from `0.0.0.0/0` → VM service account |
| Firewall | `profile-app-allow-iap-ssh` | ingress `tcp:22` from `35.235.240.0/20` (IAP) → VM service account |
| Firewall | implied | deny all other ingress, allow all egress |
| Address | `profile-app-vm-ip` | regional static external IP on nic0; VM internal IP `10.10.0.10` |

Docker only publishes host `:80 → my-app:3000`. The database is a managed service reached
outbound on TLS 443, so it needs no inbound firewall rule.

## Database: Firestore with MongoDB compatibility

- Enterprise-edition Firestore database `user-account` in `us-east1`, created by Terraform (`infra/terraform/firestore.tf`).
- The app still uses the official `mongodb` Node.js driver (6.x). Only the connection string changed:
  ```
  mongodb://<uid>.<location>.firestore.goog:443/user-account?loadBalanced=true&tls=true&retryWrites=false
    &authMechanism=MONGODB-OIDC&authMechanismProperties=ENVIRONMENT:gcp,TOKEN_RESOURCE:FIRESTORE
  ```
- The connection string holds no secret. It is stored as the VM metadata key `mongo-url`, and
  `deploy.sh` copies it into `.env`.
- The VM service account has `roles/datastore.user`, limited by an IAM condition to this one database.
- Local development is unchanged: `docker compose up` (root `docker-compose.yaml`), then `node app/server.js`.
  Without `MONGO_URL` set, the app falls back to `mongodb://admin:password@localhost:27017`.

## Operating

- Browse the data in the console under **Firestore → user-account → Firestore Studio**, or with
  `mongosh` using the same connection string from a machine with `roles/datastore.user`.
- Roll back: re-run an older workflow run, or on the VM set `APP_IMAGE` in `/opt/profile-app/.env` to an older tag and `docker compose up -d`.

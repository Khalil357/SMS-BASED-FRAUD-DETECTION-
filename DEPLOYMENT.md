# Deploying ARGUS to AWS EC2

This guide takes you from a fresh EC2 instance to a running production stack
(backend + Postgres + web client) that GitHub Actions can deploy to. The ML
model is **not** deployed here — it already runs on a separate AWS account and
the backend reaches it over HTTP via `ML_SERVICE_URL`.

The stack on the box:

```
EC2 instance (docker compose)
├── backend     ← argus-backend image (Spring Boot)
├── db          ← postgres:15
└── web-client  ← argus-web-client image (nginx)
```

---

## 1. Launch the EC2 instance (AWS console)

1. Launch an instance (Amazon Linux 2023 or Ubuntu 22.04/24.04 LTS).
2. Pick a key pair — **download the `.pem` and keep it safe** (this is your
   personal admin key, *not* the deploy key from step 4).
3. Security group inbound rules:
   - **22 (SSH)** — your IP only (for admin + the CI deploy).
   - **80 (HTTP)** — from anywhere (web client).
   - **443 (HTTPS)** — from anywhere (only once TLS is set up).
   - **8080** and **5432** — do **NOT** open publicly. The backend and Postgres
     stay on the internal Docker network.

---

## 2. Install Docker on the box

SSH in as your admin user, then:

```bash
# Amazon Linux 2023
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# log out and back in so the group takes effect
```

```bash
# Ubuntu
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# log out and back in
```

Verify: `docker run --rm hello-world`

---

## 3. Create the app directory + files on the box

```bash
mkdir -p ~/argus && cd ~/argus
```

Copy two files into `~/argus`:

1. **`docker-compose.prod.yml`** — from the repo root (deploy with the rest of
   the app; here it lives alongside the `.env`).
2. **`.env`** — the runtime secrets. Create it and fill in real values:

```bash
cat > ~/argus/.env <<'EOF'
DOCKER_USERNAME=your_docker_hub_username
TAG=latest

POSTGRES_DB=sms_fraud
POSTGRES_USER=sms_app
POSTGRES_PASSWORD=REPLACE_WITH_A_STRONG_PASSWORD

# The ML model is on another AWS account — put its stable URL here.
ML_SERVICE_URL=http://REPLACE_WITH_ML_HOST:3232

JWT_SECRET=REPLACE_WITH_AT_LEAST_32_RANDOM_BYTES
MESEJI_API_KEY=REPLACE_WITH_YOUR_MESEJI_KEY
MESEJI_SENDER_ID=MESEJI

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=you@gmail.com
SMTP_PASSWORD=REPLACE_WITH_GMAIL_APP_PASSWORD
EMAIL_FROM=you@gmail.com
EOF

chmod 600 ~/argus/.env
```

> `.env` holds production secrets. It is **never** committed to git — it lives
> only on this box (it is already in `.gitignore`).

---

## 4. Generate a dedicated deploy key (for CI)

GitHub Actions needs its own SSH key — do **not** reuse your personal key.

**On your local machine:**

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/argus_deploy -N ""
```

This creates:
- `~/.ssh/argus_deploy` (private — goes into GitHub, **keep secret**)
- `~/.ssh/argus_deploy.pub` (public — goes onto the EC2 box)

**On the EC2 box** — append the public key to the deploy user's authorized keys:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat >> ~/.ssh/authorized_keys <<'EOF'
<contents of argus_deploy.pub here>
EOF
chmod 600 ~/.ssh/authorized_keys
```

---

## 5. Add the GitHub secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Name | Value |
|------|-------|
| `DOCKER_USERNAME` | Docker Hub username (can be a *Variable*, not secret) |
| `DOCKER_TOKEN` | Docker Hub access token (**Secret**) |
| `EC2_HOST` | EC2 public IP / DNS |
| `EC2_USER` | SSH user (e.g. `ubuntu` or `ec2-user`) |
| `EC2_SSH_KEY` | **the whole private key** `~/.ssh/argus_deploy`, including `-----BEGIN` / `-----END` lines |

---

## 6. First deploy

1. Commit + push `dev` (the workflows and `docker-compose.prod.yml` must exist
   on GitHub first):
   ```bash
   git add . && git commit -m "Add CI/CD pipeline and prod compose" && git push origin dev
   ```
2. In GitHub → **Actions → Deploy → Run workflow** (leave `tag` = `latest`).
3. Watch the `Deploy` job. On success, visit `http://<EC2_HOST>` — you should
   see the web client.

---

## 7. Post-deploy checks

```bash
# on the box
cd ~/argus
docker compose -f docker-compose.prod.yml ps      # all three services Up
docker compose -f docker-compose.prod.yml logs backend   # check boot + Flyway
curl -sf http://localhost:8080/v3/api-docs | head   # backend API is live
```

---

## ⚠️ Before you trust this in production

1. **Rotate the leaked Meseji API key.** A real key was committed to git history
   earlier; gitleaks in CI will flag it. Rotate the key in the Meseji dashboard
   and put the new value in `~/argus/.env`.
2. **Add HTTPS.** The web client is plain HTTP on port 80. Add TLS (e.g.
   Let's Encrypt via Caddy/Traefik, or an ALB with a certificate) before real
   users send SMS content through it.
3. **Restrict the ML call.** `ML_SERVICE_URL` is plain HTTP to another account.
   At minimum confirm the ML owner has restricted access to your EC2's IP.
4. **Pin `JWT_SECRET`** to a real random value (not the default) — it controls
   session/verification tokens.

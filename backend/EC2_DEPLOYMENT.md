# Deploy the backend to Amazon EC2 with Docker Compose

The Compose stack runs four containers:

- `nginx`: the public reverse proxy, published on host port `80`
- `app`: this Spring Boot API, reachable only by Nginx inside Docker
- `db`: PostgreSQL, reachable only inside the Docker network
- `redis`: persistent OTP storage, reachable only inside the Docker network

PostgreSQL and Redis use named volumes, so normal container replacement does not
delete their data.

## 1. Create the EC2 instance

Use Ubuntu 24.04 LTS or Amazon Linux 2023. A `t3.small` is a practical minimum
for building the Java image on the instance; `t3.micro` can run out of memory
during the Maven build. Allocate enough EBS storage for Docker images and the
database (20 GB or more is a reasonable starting point).

Attach an Elastic IP if the frontend must use a stable address. In the instance
security group allow:

| Port | Source | Purpose |
| --- | --- | --- |
| `22/tcp` | Your own IP only | SSH administration |
| `80/tcp` | `0.0.0.0/0` and `::/0` | Public HTTP API through Nginx |

Do not open PostgreSQL port `5432` or Redis port `6379`.

Do not open application port `8080`; Nginx reaches it over the private Compose
network. For a real public web frontend, HTTPS is strongly recommended. Add a
domain and TLS certificate to Nginx, or put an Application Load Balancer in front
of Nginx. An HTTPS frontend cannot call an HTTP API because browsers block mixed
content.

## 2. Install Docker

Ubuntu:

Install Docker Engine, Buildx, and the Compose plugin from Docker's official
[Ubuntu repository](https://docs.docker.com/engine/install/ubuntu/). The final
package-install command in that guide installs `docker-ce`, `docker-ce-cli`,
`containerd.io`, `docker-buildx-plugin`, and `docker-compose-plugin`. Then run:

```bash
sudo apt-get install -y git
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Log out and reconnect after adding the user to the Docker group.

Amazon Linux 2023:

```bash
sudo dnf install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Log out and reconnect, then verify `docker compose version`. If the Compose
plugin is absent, install it using Docker's official
[Linux Compose plugin instructions](https://docs.docker.com/compose/install/linux/).
AWS's current [AL2023 Docker instructions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-container-image.html)
also cover the Docker service and `ec2-user` group setup.

## 3. Copy the project and configure secrets

Clone the repository on EC2 (or upload this backend directory), then enter the
backend directory:

```bash
git clone YOUR_REPOSITORY_URL sms-fraud
cd sms-fraud/backend
cp .env.example .env
chmod 600 .env
```

Edit `.env` and replace every example credential. At minimum set:

```dotenv
POSTGRES_DB=sms_fraud
POSTGRES_USER=sms_app
POSTGRES_PASSWORD=A_LONG_RANDOM_DATABASE_PASSWORD
REDIS_PASSWORD=A_DIFFERENT_LONG_RANDOM_PASSWORD
JWT_SECRET=A_RANDOM_SECRET_WITH_AT_LEAST_32_BYTES

HTTP_PORT=80
APP_URL=http://YOUR_ELASTIC_IP
APP_WEB_URL=https://YOUR_FRONTEND_HOST
CORS_ALLOWED_ORIGINS=https://YOUR_FRONTEND_HOST

ADMIN_SEED_ENABLED=true
ADMIN_EMAIL=YOUR_ADMIN_EMAIL
ADMIN_PHONE=YOUR_ADMIN_PHONE
ADMIN_PASSWORD=A_STRONG_INITIAL_ADMIN_PASSWORD
```

Generate secrets on Linux with `openssl rand -base64 48`. Configure SMTP or
Resend, the ML service, and Meseji values in the same file when those features
are required. `.env` is ignored by Git and excluded from the Docker image.

For multiple allowed frontend origins, separate them with commas:

```dotenv
CORS_ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com
```

## 4. Build and start

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f app
```

On the first clean startup, Flyway creates the PostgreSQL schema. When the log
shows the application started, test the public health endpoint:

```bash
curl http://localhost/actuator/health
```

It should return a JSON response with `"status":"UP"`. The frontend API base
URL is then `http://YOUR_ELASTIC_IP` (or the HTTPS domain configured on the load
balancer/reverse proxy). Do not use `localhost` in a deployed frontend.

After the initial administrator has been created, set
`ADMIN_SEED_ENABLED=false` in `.env` and apply the setting:

```bash
docker compose up -d
```

## 5. Deploy updates and inspect failures

```bash
git pull
docker compose up -d --build
docker compose ps
docker compose logs --tail=200 app
```

Compose waits for PostgreSQL and Redis health checks before starting the API.
All containers use `restart: unless-stopped`, so they return after an instance
reboot once the Docker service starts.

Useful diagnostics:

```bash
docker compose logs --tail=200 db
docker compose logs --tail=200 redis
docker compose exec nginx nginx -t
docker compose exec db pg_isready -U sms_app -d sms_fraud
```

## 6. Back up PostgreSQL

Create a database dump before schema-affecting deployments:

```bash
mkdir -p backups
docker compose exec -T db pg_dump -U sms_app -d sms_fraud -Fc > "backups/sms_fraud_$(date +%F_%H%M).dump"
```

Copy backups off the instance (for example to S3). The named Docker volume is
durable across container recreation, but it is not a substitute for an external
backup.

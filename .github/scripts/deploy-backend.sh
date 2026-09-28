  #!/bin/sh
# Executed on EC2 by .github/workflows/backend-ec2.yml.
set -eu

case "${DEPLOY_SHA:-}" in
    ''|*[!0-9a-f]*) echo "Invalid deployment SHA" >&2; exit 1 ;;
esac
[ "${#DEPLOY_SHA}" -eq 40 ] || { echo "Deployment SHA must be 40 characters" >&2; exit 1; }
[ -n "${EC2_HOST:-}" ] || { echo "EC2_HOST is required" >&2; exit 1; }

cd /home/ec2-user/sms-fraud-backend
[ -f compose.yaml ] && [ -f .env ] || {
    echo "Production Compose configuration is missing" >&2
    exit 1
}

image="alexanderjames101/sms-fraud-backend:$DEPLOY_SHA"
runtime_image="alexanderjames101/sms-fraud-backend:latest"
previous_image="$(sudo -n docker inspect --format '{{.Image}}' sms-fraud-backend-app-1 2>/dev/null || true)"

# Pull the immutable release, not the mutable latest tag.
sudo -n docker pull "$image"

# Flyway may change the schema when the new app starts. Keep a private pre-deploy dump.
umask 077
backup_dir=/home/ec2-user/.sms-fraud-backups
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"
backup="$backup_dir/sms_fraud_$DEPLOY_SHA.dump"
if [ -e "$backup" ]; then
    [ -s "$backup" ] || { echo "Existing database backup is empty: $backup" >&2; exit 1; }
    echo "Reusing existing pre-deploy backup: $backup"
else
    sudo -n docker compose --env-file .env exec -T db sh -c 'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$backup"
    [ -s "$backup" ] || { echo "Database backup is empty" >&2; exit 1; }
    echo "Database backup saved to $backup"
fi

rollback() {
    # This restores only the app image; Flyway schema changes are not reversed.
    if [ -z "$previous_image" ]; then
        echo "No previous app image is available for rollback" >&2
        return 1
    fi
    echo "Attempting to restore the previous app image" >&2
    sudo -n docker image tag "$previous_image" "$runtime_image"
    sudo -n docker compose --env-file .env up -d --no-deps --pull never --force-recreate --wait --wait-timeout 180 app
}

# The existing Compose file names :latest. Retag only on this host so Compose
# starts exactly the SHA image just pulled; --pull never prevents a race.
sudo -n docker image tag "$image" "$runtime_image"
if ! sudo -n docker compose --env-file .env up -d --no-deps --pull never --force-recreate --wait --wait-timeout 180 app; then
    rollback || echo "Automatic app rollback failed; inspect EC2" >&2
    exit 1
fi

# Verify the real HTTPS route as well as the container health check.
if ! curl -fsS --retry 5 --retry-delay 3 --max-time 15 \
    --resolve "$EC2_HOST:443:127.0.0.1" \
    "https://$EC2_HOST/actuator/health" | grep -q '"status":"UP"'; then
    echo "Public API health check failed" >&2
    rollback || echo "Automatic app rollback failed; inspect EC2" >&2
    exit 1
fi

echo "Backend deployment healthy: $DEPLOY_SHA"

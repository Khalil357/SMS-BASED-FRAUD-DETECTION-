#!/bin/sh
set -eu

cd /home/ec2-user/sms-fraud-backend

/usr/bin/docker compose --profile tools run --rm certbot renew --quiet
/usr/bin/docker compose exec -T nginx nginx -s reload

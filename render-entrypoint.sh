#!/usr/bin/env bash
# Container start command for the Render deployment.
# Kept separate from entrypoint.sh so local docker-compose keeps working.
set -Eeuo pipefail

echo "==> Applying database migrations"
# No makemigrations here: migrations are committed to the repo, and generating
# them at boot against a live database is how production schemas drift.
python3 manage.py migrate --noinput

if [[ -n "${HORILLA_ADMIN_USERNAME:-}" && -n "${HORILLA_ADMIN_PASSWORD:-}" ]]; then
    echo "==> Ensuring admin user '${HORILLA_ADMIN_USERNAME}' exists"
    python3 manage.py createhorillauser \
        --first_name "${HORILLA_ADMIN_FIRST_NAME:-Admin}" \
        --last_name "${HORILLA_ADMIN_LAST_NAME:-User}" \
        --username "${HORILLA_ADMIN_USERNAME}" \
        --password "${HORILLA_ADMIN_PASSWORD}" \
        --email "${HORILLA_ADMIN_EMAIL:-admin@example.com}" \
        --phone "${HORILLA_ADMIN_PHONE:-0000000000}" \
        || echo "==> Admin user already exists; leaving it untouched"
else
    echo "==> HORILLA_ADMIN_USERNAME/PASSWORD unset; skipping admin creation"
fi

# Single worker by default: the free instance has 512MB of RAM, and Horilla also
# runs django-apscheduler in-process, which would fire duplicate jobs once per
# worker. Threads give concurrency without a second copy of the app in memory.
exec gunicorn horilla.wsgi:application \
    --bind "0.0.0.0:${PORT:-8000}" \
    --workers "${WEB_CONCURRENCY:-1}" \
    --threads "${GUNICORN_THREADS:-4}" \
    --timeout "${GUNICORN_TIMEOUT:-120}" \
    --access-logfile - \
    --error-logfile -

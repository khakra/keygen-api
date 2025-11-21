#!/usr/bin/env bash
set -e

if [ -f tmp/pids/server.pid ]
then
  rm -f tmp/pids/server.pid
fi

case "$@"
in
setup)
  echo "Running command: bundle exec rails keygen:setup"
  exec bundle exec rails keygen:setup
  ;;
release)
  echo "Running command: bundle exec rails db:migrate"
  exec bundle exec rails db:migrate
  ;;
web)
  # Auto-setup before starting web server (only on first run)
  if [ ! -f /tmp/keygen-setup-complete ]; then
    echo "First run detected. Running keygen:setup with environment variables..."
    DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rails keygen:setup
    touch /tmp/keygen-setup-complete
    echo "Setup complete. Starting web server..."
  else
    echo "Setup already completed. Running migrations..."
    bundle exec rails db:migrate
    echo "Starting web server..."
  fi
  exec bundle exec rails server -b "$BIND" -p "$PORT"
  ;;
console)
  echo "Running command: bundle exec rails console"
  exec bundle exec rails console
  ;;
worker)
  echo "Running command: bundle exec sidekiq"
  exec bundle exec sidekiq
  ;;
*)
  echo "Running command: $@"
  exec "$@"
  ;;
esac

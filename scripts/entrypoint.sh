#!/usr/bin/env bash
set -e

if [ -f tmp/pids/server.pid ]
then
  rm -f tmp/pids/server.pid
fi

# Auto-setup function for first-time deployments
auto_setup() {
  echo "Checking database status..."

  # Wait for database to be ready
  max_attempts=30
  attempt=0
  while ! bundle exec rails runner "ActiveRecord::Base.connection" 2>/dev/null; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
      echo "Database connection failed after $max_attempts attempts"
      exit 1
    fi
    echo "Database not accessible, waiting... (attempt $attempt/$max_attempts)"
    sleep 2
  done

  # Check if this is a fresh database (no migrations run yet)
  if ! bundle exec rails runner "ActiveRecord::Base.connection.table_exists?('schema_migrations')" 2>/dev/null || \
     [ "$(bundle exec rails runner "ActiveRecord::Base.connection.tables.size")" -lt "5" ]; then
    echo "Fresh database detected, running initial setup..."

    # Validate required environment variables for non-interactive setup
    if [ -z "$KEYGEN_HOST" ]; then
      echo "ERROR: KEYGEN_HOST environment variable is required for automated setup"
      exit 1
    fi

    if [ -z "$KEYGEN_ADMIN_EMAIL" ]; then
      echo "ERROR: KEYGEN_ADMIN_EMAIL environment variable is required for automated setup"
      exit 1
    fi

    if [ -z "$KEYGEN_ADMIN_PASSWORD" ]; then
      echo "ERROR: KEYGEN_ADMIN_PASSWORD environment variable is required for automated setup"
      exit 1
    fi

    if [ -z "$SECRET_KEY_BASE" ]; then
      echo "ERROR: SECRET_KEY_BASE environment variable is required"
      exit 1
    fi

    # Run non-interactive setup
    echo "Running keygen:setup with environment variables..."
    bundle exec rails keygen:setup
  else
    echo "Database exists, running migrations..."
    bundle exec rails db:migrate
  fi
}

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
  # Auto-setup before starting web server
  auto_setup
  echo "Running command: bundle exec rails server -b $BIND -p $PORT"
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

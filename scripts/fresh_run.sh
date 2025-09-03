#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/ubuntu/orig_clone/challenge"
BACKEND_DIR="$ROOT/backend"
FRONTEND_DIR="$ROOT/frontend"
DB_NAME="school_mgmt"

log() { echo "[FRESH_RUN] $*"; }

kill_port() {
  local port="$1"
  ss -ltnp | awk -v p=":${port} " '$0 ~ p {print $6}' | sed 's/.*pid=\([0-9]*\).*/\1/' | xargs -r kill -9 || true
}

wait_port() {
  local port="$1"; local tries=${2:-40}
  for _ in $(seq 1 "$tries"); do
    if ss -ltnH | awk '{print $4}' | grep -qE ":${port}$"; then return 0; fi
    sleep 0.5
  done
  return 1
}

reset_db() {
  log "Dropping DB if exists..."
  dropdb "$DB_NAME" || true
  log "Creating DB..."
  createdb "$DB_NAME"
  log "Running schema..."
  psql -d "$DB_NAME" -f "$ROOT/seed_db/tables.sql"
  log "Seeding data..."
  psql -d "$DB_NAME" -f "$ROOT/seed_db/seed-db.sql"
  log "Ensuring role and grants..."
  psql -d postgres -v ON_ERROR_STOP=1 <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'school') THEN
    CREATE ROLE school LOGIN PASSWORD 'school';
  END IF;
END$$;
GRANT ALL PRIVILEGES ON DATABASE school_mgmt TO school;
SQL
  psql -d "$DB_NAME" -v ON_ERROR_STOP=1 <<'SQL'
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO school;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO school;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO school;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO school;
SQL
}

start_backend() {
  log "Starting backend..."
  (cd "$BACKEND_DIR" && nohup npm start > /home/ubuntu/orig_clone/backend_server.log 2>&1 &)
  wait_port 5007 60 || { echo "Backend failed to start on 5007" >&2; exit 1; }
}

start_frontend() {
  log "Starting frontend..."
  (cd "$FRONTEND_DIR" && HUSKY=0 nohup npm run dev > /home/ubuntu/orig_clone/frontend_server.log 2>&1 &)
  wait_port 5173 60 || { echo "Frontend failed to start on 5173" >&2; exit 1; }
}

main() {
  log "Killing existing servers..."
  kill_port 5007
  kill_port 5173

  reset_db

  start_backend
  start_frontend

  log "All set."
  log "Backend: http://localhost:5007"
  log "Frontend: http://localhost:5173"
}

main "$@"



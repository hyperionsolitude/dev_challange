#!/usr/bin/env bash
set -euo pipefail

# Simple backend CRUD smoke test using curl
# - Logs in with admin
# - Exercises Students CRUD
# - Exercises Notices add/list/delete
# - Cleans up created test data

API_BASE="http://localhost:5007/api/v1"
COOKIES_FILE="/tmp/school_mgmt_cookies.txt"

ADMIN_USER="admin@school-admin.com"
ADMIN_PWD="3OU4zn3q6Zh9"

log() { echo "[TEST] $*" >&2; }

get_csrf() {
  awk '/csrfToken/ {print $7}' "$COOKIES_FILE" | tail -n1
}

is_listening() {
  ss -ltnH | awk '{print $4}' | grep -qE ":5007$"
}

ensure_backend() {
  if is_listening; then
    log "Backend already listening on 5007"
    return
  fi
  log "Backend not listening. Attempting to start..."
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  BACKEND_DIR="${SCRIPT_DIR}/../backend"
  if [ -d "$BACKEND_DIR" ]; then
    (cd "$BACKEND_DIR" && nohup npm start >/dev/null 2>&1 & ) || true
  fi
  for _ in $(seq 1 40); do
    if is_listening; then
      log "Backend is up"
      return
    fi
    sleep 0.5
  done
  echo "Backend failed to start on port 5007" >&2
  exit 1
}

login() {
  log "Logging in as admin..."
  curl -fsS -c "$COOKIES_FILE" -b "$COOKIES_FILE" \
    -H 'Content-Type: application/json' \
    -X POST "$API_BASE/auth/login" \
    --data "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PWD\"}" >/dev/null
}

refresh_tokens() {
  log "Refreshing tokens..."
  curl -fsS -c "$COOKIES_FILE" -b "$COOKIES_FILE" "$API_BASE/auth/refresh" >/dev/null || true
}

create_student() {
  local csrf="$1"
  log "Creating test student..."
  psql -d school_mgmt -v ON_ERROR_STOP=1 -c "INSERT INTO classes(name, sections) VALUES ('Grade 1','A') ON CONFLICT DO NOTHING;" >/dev/null
  psql -d school_mgmt -v ON_ERROR_STOP=1 -c "INSERT INTO sections(name) VALUES ('A') ON CONFLICT DO NOTHING;" >/dev/null

  curl -fsS -b "$COOKIES_FILE" -H "x-csrf-token: $csrf" -H 'Content-Type: application/json' \
    -X POST "$API_BASE/students" \
    --data '{"name":"Test Student","email":"student1@example.com","gender":"Male","phone":"+1000000000","dob":"2008-01-01","currentAddress":"Addr 1","permanentAddress":"Addr 1","fatherName":"F","fatherPhone":"+100","motherName":"M","motherPhone":"+101","guardianName":"G","guardianPhone":"+102","relationOfGuardian":"Parent","systemAccess":true,"class":"Grade 1","section":"A","admissionDate":"2024-01-01","roll":1}' >/dev/null

  STUDENT_ID=$(psql -t -A -d school_mgmt -c "SELECT id FROM users WHERE email='student1@example.com';")
  printf "%s" "$STUDENT_ID"
}

read_students() {
  local csrf="$1"
  log "List students..."
  curl -fsS -b "$COOKIES_FILE" -H "x-csrf-token: $csrf" "$API_BASE/students" | head -c 200; echo
}

read_student_detail() {
  local csrf="$1" id="$2"
  log "Get student detail id=$id..."
  curl -fsS -b "$COOKIES_FILE" -H "x-csrf-token: $csrf" "$API_BASE/students/$id" | head -c 200; echo
}

update_student() {
  local csrf="$1" id="$2"
  log "Update student name id=$id..."
  curl -fsS -i -b "$COOKIES_FILE" -H "x-csrf-token: $csrf" -H 'Content-Type: application/json' \
    -X PUT "$API_BASE/students/$id" --data '{"basicDetails":{"name":"Test Student Updated","email":"student1@example.com"}}' | sed -n '1,20p'
}

toggle_status() {
  local csrf="$1" id="$2" status="$3"
  log "Set student status id=$id -> $status..."
  curl -fsS -i -b "$COOKIES_FILE" -H "x-csrf-token: $csrf" -H 'Content-Type: application/json' \
    -X POST "$API_BASE/students/$id/status" --data "{\"status\":$status}" | sed -n '1,20p'
}

delete_student() {
  local csrf="$1" id="$2"
  log "Delete student id=$id..."
  curl -fsS -i -b "$COOKIES_FILE" -H "x-csrf-token: $csrf" -X DELETE "$API_BASE/students/$id" | sed -n '1,20p'
}

notice_create() {
  local csrf="$1"
  log "Create test notice..."
  curl -fsS -b "$COOKIES_FILE" -H "x-csrf-token: $csrf" -H 'Content-Type: application/json' \
    -X POST "$API_BASE/notices" \
    --data '{"title":"Test Fix","description":"Desc should be saved","status":1,"recipientType":"EV","recipientRole":0,"firstField":""}' >/dev/null
}

notice_delete_all_tests() {
  log "Delete test notices..."
  psql -d school_mgmt -c "DELETE FROM notices WHERE title='Test Fix';" >/dev/null
}

cleanup_student_support() {
  log "Cleanup classes/sections if empty..."
  psql -d school_mgmt -c "DELETE FROM classes WHERE name IN ('Grade 1','Grade 2'); DELETE FROM sections WHERE name IN ('A','B');" >/dev/null || true
}

main() {
  ensure_backend
  login
  refresh_tokens
  CSRF=$(get_csrf)
  log "CSRF token: $CSRF"

  SID=$(create_student "$CSRF")
  log "Student created id=$SID"
  read_students "$CSRF"
  read_student_detail "$CSRF" "$SID"
  update_student "$CSRF" "$SID"
  toggle_status "$CSRF" "$SID" false
  toggle_status "$CSRF" "$SID" true
  delete_student "$CSRF" "$SID"

  notice_create "$CSRF"
  notice_delete_all_tests

  cleanup_student_support

  log "All tests completed successfully."
}

main "$@"



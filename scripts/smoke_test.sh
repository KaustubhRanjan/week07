#!/usr/bin/env bash
# =====================================================================
# SIT722 Task 10.3HD - smoke tests for a course-service slot
#
# Usage: bash scripts/smoke_test.sh <base-url> <expected-version>
#   e.g. bash scripts/smoke_test.sh https://koalatech-course-xx-staging.azurewebsites.net 3f2a1b...
#
# Exits non-zero if any check fails. The pipeline only swaps staging
# into production when this script passes against the staging slot.
# =====================================================================
set -uo pipefail

BASE_URL="${1:?base URL required}"
EXPECTED_VERSION="${2:?expected version required}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-40}"   # 40 x 15s = 10 minutes for the container to start
SLEEP_SECONDS="${SLEEP_SECONDS:-15}"

BASE_URL="${BASE_URL%/}"
failures=0

pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; failures=$((failures + 1)); }

echo "== Waiting for ${BASE_URL} to run version ${EXPECTED_VERSION}"
ready=false
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  body=$(curl -s --max-time 15 "${BASE_URL}/health" || true)
  if echo "$body" | grep -q "\"version\":\"${EXPECTED_VERSION}\"" \
     && echo "$body" | grep -q '"status":"healthy"'; then
    echo "  attempt ${attempt}: new version is live -> ${body}"
    ready=true
    break
  fi
  echo "  attempt ${attempt}/${MAX_ATTEMPTS}: not ready yet (${body:-no response})"
  sleep "$SLEEP_SECONDS"
done

if [ "$ready" != true ]; then
  echo "FAIL: ${BASE_URL} never reported a healthy version ${EXPECTED_VERSION}"
  exit 1
fi

echo "== Running smoke tests against ${BASE_URL}"

# 1. Health endpoint: 200, healthy, database reachable
code=$(curl -s -o /tmp/smoke_body -w '%{http_code}' --max-time 15 "${BASE_URL}/health")
body=$(cat /tmp/smoke_body)
[ "$code" = "200" ] && echo "$body" | grep -q '"database":"ok"' \
  && pass "/health -> 200, database ok" \
  || fail "/health -> ${code} ${body}"

# 2. Root endpoint responds
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "${BASE_URL}/")
[ "$code" = "200" ] && pass "/ -> 200" || fail "/ -> ${code} (expected 200)"

# 3. API schema is served (all routes registered)
code=$(curl -s -o /tmp/smoke_body -w '%{http_code}' --max-time 15 "${BASE_URL}/openapi.json")
[ "$code" = "200" ] && grep -q '"/courses"' /tmp/smoke_body \
  && pass "/openapi.json -> 200, /courses route registered" \
  || fail "/openapi.json -> ${code} or /courses route missing"

# 4. Protected route rejects anonymous requests (auth is wired up)
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "${BASE_URL}/courses")
[ "$code" = "401" ] && pass "/courses without token -> 401" || fail "/courses without token -> ${code} (expected 401)"

# 5. Response time is reasonable
time_total=$(curl -s -o /dev/null -w '%{time_total}' --max-time 15 "${BASE_URL}/health")
awk "BEGIN { exit !(${time_total} < 3.0) }" \
  && pass "/health responded in ${time_total}s (< 3s)" \
  || fail "/health took ${time_total}s (>= 3s)"

echo
if [ "$failures" -gt 0 ]; then
  echo "SMOKE TESTS FAILED (${failures} check(s)) - release must NOT go to production"
  exit 1
fi
echo "ALL SMOKE TESTS PASSED for version ${EXPECTED_VERSION}"

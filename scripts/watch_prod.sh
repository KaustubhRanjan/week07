#!/usr/bin/env bash
# =====================================================================
# SIT722 Task 10.3HD - watch production during a release (for the demo)
#
# Usage: bash scripts/watch_prod.sh https://koalatech-course-xx.azurewebsites.net
# Sends a request every 0.5s and counts non-200 responses.
# Press Ctrl+C to stop and print the summary.
# =====================================================================
URL="${1:?production URL required}"
URL="${URL%/}/health"
ok=0; fail=0; last_version=""

summary() {
  echo
  echo "== Summary: ${ok} OK, ${fail} failed out of $((ok + fail)) requests"
  exit 0
}
trap summary INT

while true; do
  body=$(curl -s -o - -w '\n%{http_code}' --max-time 5 "$URL")
  code=$(echo "$body" | tail -n1)
  json=$(echo "$body" | head -n1)
  version=$(echo "$json" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' | cut -c1-7)
  if [ "$code" = "200" ]; then ok=$((ok + 1)); else fail=$((fail + 1)); fi
  marker=""
  if [ -n "$last_version" ] && [ -n "$version" ] && [ "$version" != "$last_version" ]; then
    marker="   <== VERSION CHANGED ${last_version} -> ${version}"
  fi
  [ -n "$version" ] && last_version="$version"
  echo "$(date +%T)  HTTP ${code}  version=${version:-?}  ok=${ok} fail=${fail}${marker}"
  sleep 0.5
done

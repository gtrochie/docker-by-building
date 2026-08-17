#!/usr/bin/env bash
# Validate every Dockerfile (hadolint) and compose file (docker compose config),
# and confirm the sample app imports. Requires hadolint + docker compose on PATH.
# Usage: bash validate.sh
set -u
fail=0
echo "== Dockerfiles (hadolint) =="
while IFS= read -r df; do
  if hadolint "$df" >/tmp/h.out 2>&1; then echo "PASS  $df"
  else echo "FAIL  $df"; sed 's/^/      /' /tmp/h.out; fail=1; fi
done < <(find . -name 'Dockerfile*' -not -path './.git/*' | sort)

echo "== Compose files (docker compose config) =="
for cf in $(find . -name 'compose*.y*ml' -not -path './.git/*' | sort); do
  if docker compose -f "$cf" config >/dev/null 2>/tmp/c.out; then echo "PASS  $cf"
  else echo "FAIL  $cf"; sed 's/^/      /' /tmp/c.out; fail=1; fi
done

echo "== Sample app imports =="
if (cd app && python3 -c "import main" 2>/tmp/a.out); then echo "PASS  app/main.py"
else echo "FAIL  app/main.py"; sed 's/^/      /' /tmp/a.out; fail=1; fi

echo "-----"; [ $fail -eq 0 ] && echo "ALL VALID ✓" || echo "some checks FAILED"
exit $fail

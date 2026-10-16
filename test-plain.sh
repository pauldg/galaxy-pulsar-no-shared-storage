#!/bin/bash
# Runs cat1 on Pulsar and shows where its output ended up: Galaxy's object store or the Pulsar container.
set -euo pipefail
G=${GALAXY_URL:-http://localhost:8080}
ADMIN=dev-admin-key
REPRO=$(cd "$(dirname "$0")" && pwd)

admin() { curl -sSf -X "$1" -H "x-api-key: $ADMIN" -H content-type:application/json ${3:+-d "$3"} "$G$2"; }
api() { curl -sSf -X "$1" -H "x-api-key: $KEY" -H content-type:application/json ${3:+-d "$3"} "$G$2"; }
wait_job() {
    for _ in $(seq 1 60); do
        s=$(api GET "/api/jobs/$1" | jq -r .state)
        case $s in ok|error|failed|deleted) echo "$s"; return;; esac
        sleep 3
    done
    echo timeout
}

uid=$(admin GET "/api/users?f_email=dev@example.org" | jq -r ".[0].id // empty")
[ -n "$uid" ] || uid=$(admin POST /api/users "{\"username\":\"dev\",\"email\":\"dev@example.org\",\"password\":\"devpassword\"}" | jq -r .id)
KEY=$(admin POST "/api/users/$uid/api_key" | jq -r .)

h=$(api POST /api/histories "{\"name\":\"pulsar output test $(date +%H:%M:%S)\"}" | jq -r .id)
up=$(api POST /api/tools/fetch "{\"history_id\":\"$h\",\"targets\":[{\"destination\":{\"type\":\"hdas\"},\"elements\":[{\"src\":\"pasted\",\"paste_content\":\"hello from pulsar\\nline two\\n\",\"ext\":\"txt\",\"name\":\"input.txt\"}]}]}")
in_id=$(jq -r ".outputs[0].id" <<<"$up")
echo "upload (local runner): $(wait_job "$(jq -r ".jobs[0].id" <<<"$up")")"

run=$(api POST /api/tools "{\"tool_id\":\"cat1\",\"history_id\":\"$h\",\"inputs\":{\"input1\":{\"src\":\"hda\",\"id\":\"$in_id\"}}}")
out_id=$(jq -r ".outputs[0].id" <<<"$run")
echo "cat1 (pulsar): $(wait_job "$(jq -r ".jobs[0].id" <<<"$run")")"

ds=$(api GET "/api/datasets/$out_id")
uuid=$(jq -r .uuid <<<"$ds")
echo "Galaxy says: state=$(jq -r .state <<<"$ds") file_size=$(jq -r .file_size <<<"$ds") uuid=$uuid"
f=$(find "$REPRO/galaxy-data/objects" -name "*$uuid*" 2>/dev/null | head -1)
echo "Galaxy object store: ${f:-missing} ($( [ -n "$f" ] && stat -c %s "$f" || echo 0) bytes)"
echo "Pulsar container:"
docker exec pulsar-dev sh -c "find / -xdev -name \"*$uuid*\" -exec ls -l {} \; 2>/dev/null" || true

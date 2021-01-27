#!/usr/bin/env bash
export PATH=bin:$PATH

. "$(dirname "$0")/config.sh"

fetch_fields() {
  curl -sSL -f -k -H "Authorization: Bearer ${1}" "${HOST}/api/${2}" | jq -r "if type==\"array\" then .[] else . end| .${3}"
}

for row in "${ORGS[@]}"; do
  ORG=${row%%:*}
  KEY=${row#*:}
  DIR="$FILE_DIR/$ORG"
  echo "Organization: $ORG"
  echo $(fetch_fields $KEY "search?query=&type=dash-folder" '| {id, title}')
done
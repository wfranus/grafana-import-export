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

  mkdir -p "$DIR/dashboards"
  mkdir -p "$DIR/datasources"
  mkdir -p "$DIR/alert-notifications"

  for folder in $(fetch_fields $KEY "search?query=$ONLY_FOLDER&type=dash-folder" '| {id, title} | @text'); do
    FOLDER_NAME=$(echo $folder | jq -r ".title")
    if [[ -n $ONLY_FOLDER && $ONLY_FOLDER != "" && $FOLDER_NAME != "$ONLY_FOLDER" ]]; then continue; fi
    FOLDER_ID=$(echo $folder | jq -r ".id")
    echo '##################################################'
    echo "Downloading dashboards from folder: ${FOLDER_NAME}"
    echo '##################################################'
    mkdir -p "$DIR/dashboards/$FOLDER_NAME"
    for dash in $(fetch_fields $KEY "search?query=&folderIds=${FOLDER_ID}" ' | {uid, uri} | @text'); do
      DB_UID=$(echo $dash | jq -r ".uid")
      DB_URI=$(echo $dash | jq -r ".uri")
      DB=$(echo ${DB_URI} | sed 's,db/,,g').json
      echo $DB
      jq_cmd='.dashboard.id = null | del(.overwrite,.dashboard.version,.meta.created,.meta.createdBy,.meta.updated,.meta.updatedBy,.meta.expires,.meta.version)'
      if [[ -n $NEW_FOLDERID && $NEW_FOLDERID != "" ]]; then
        jq_cmd="$jq_cmd | walk(if type == \"object\" and has(\"folderId\") then .folderId = \"$NEW_FOLDERID\" else . end)"
      fi
      curl -f -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/dashboards/uid/${DB_UID}" | jq "$jq_cmd" >"$DIR/dashboards/$FOLDER_NAME/$DB"
    done
  done

  for id in $(fetch_fields $KEY 'datasources' 'id'); do
    DS=$(echo $(fetch_fields $KEY "datasources/${id}" 'name') | sed 's/ /-/g').json
    echo $DS
    curl -f -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/datasources/${id}" | jq '' >"$DIR/datasources/${id}.json"
  done

  for id in $(fetch_fields $KEY 'alert-notifications' 'id'); do
    FILENAME=${id}.json
    echo $FILENAME
    curl -f -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/alert-notifications/${id}" | jq 'del(.created,.updated)' >"$DIR/alert-notifications/$FILENAME"
  done
done

#!/usr/bin/env bash

MC_BIN="/usr/bin/mc"

# Dates to keep
[[ ! $DATE_FORMAT ]] && DATE_FORMAT="+%F"
TODAY="$(date "$DATE_FORMAT")"

FILE_EXTENSION="${FILE_NAME##*.}"

DATES_TO_KEEP="${TODAY}"
for i in $(seq 1 "$MAX_RETENTION"); do
  DATES_TO_KEEP="$DATES_TO_KEEP\|$(date --date="$i day ago" "$DATE_FORMAT")"
done

bucket_backup() {
  endpoint="${1}"
  access_key="${2}"
  secret_key="${3}"
  dest="${4}"
  bucket_name="${5}"

  "${MC_BIN}" config host add "${dest}" "${endpoint}" "${access_key}" "${secret_key}"

  bucket_subpath=""
  [[ $bucket_name ]] && bucket_subpath="${bucket_name}/"

  echo "[bucket_backup] Copying backup file. ${BACKUP_LOCATION} -> ${dest}/${bucket_subpath}${BACKUP_FOLDER}/${TODAY}.${FILE_EXTENSION}"
  "${MC_BIN}" cp "${BACKUP_LOCATION}" "${dest}/${bucket_subpath}${BACKUP_FOLDER}/${TODAY}.${FILE_EXTENSION}"

  echo "[bucket_backup] Deleting old backup data"
  echo "[bucket_backup] Deleting data older than $(date --date="${MAX_RETENTION} days ago" "${DATE_FORMAT}")"

  # If you use a scaleway endpoint, there's some specificities to handle
  if [[ $endpoint =~ https://.+s3.fr-par.scw.cloud ]]; then
    bucket_name="$(echo $endpoint|sed "s/https:\/\/\(.*\)\.s3\.fr\-par\.scw\.cloud/\1/g")"
    endpoint="https://s3.fr-par.scw.cloud"
    bucket_subpath=""
    [[ $bucket_name ]] && bucket_subpath="${bucket_name}/"
  fi

  "${MC_BIN}" config host add "r${dest}" "${endpoint}" "${access_key}" "${secret_key}"
  echo "${MC_BIN}" ls -r "r${dest}/${bucket_subpath}${BACKUP_FOLDER}/"
  "${MC_BIN}" ls -r "r${dest}/${bucket_subpath}${BACKUP_FOLDER}/" |
    awk '{print $6}' |
    grep -v -w "$DATES_TO_KEEP" |
    while read backup_file; do
      echo "[bucket_backup] Removing r${dest}/${bucket_subpath}${BACKUP_FOLDER}/$backup_file"
      "${MC_BIN}" rm "r${dest}/${bucket_subpath}${BACKUP_FOLDER}/$backup_file"
    done
}

apply_bucket_backup() {
  suffix="${1}"
  var_endpoint="BUCKET_ENDPOINT${suffix}"
  endpoint="${!var_endpoint}"
  var_access_key="BUCKET_ACCESS_KEY${suffix}"
  access_key="${!var_access_key}"
  var_secret_key="BUCKET_SECRET_KEY${suffix}"
  secret_key="${!var_secret_key}"
  var_bucket_name="BUCKET_NAME${suffix}"
  bucket_name="${!var_bucket_name}"
  dest="cmw${suffix//_}"

  if [[ $endpoint && $access_key && $secret_key ]]; then 
    echo "[apply_bucket_backup] endpoint=${endpoint} bucket_name=${bucket_name} dest=${dest}"
    bucket_backup "${endpoint}" "${access_key}" "${secret_key}" "${dest}" "${bucket_name}"
    return 0
  fi

  return 1
}

apply_bucket_backup ""
i=0

while true; do
  if ! apply_bucket_backup "_${i}"; then
    echo "[main] No more backup buckets..."
    break
  fi

  (( i++ ))
done

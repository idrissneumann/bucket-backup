#!/usr/bin/env bash

MC_BIN="/usr/bin/mc"

# Features flags
[[ ! $DISABLE_BACKUP ]] && DISABLE_BACKUP=""
[[ ! $DISABLE_CLEAN ]] && DISABLE_CLEAN=""

# Dates to keep
[[ ! $DATE_FORMAT ]] && DATE_FORMAT="+%F"
TODAY="$(date "$DATE_FORMAT")"

FILE_EXTENSION="${FILE_NAME##*.}"

DATES_TO_KEEP="${TODAY}"
for i in $(seq 1 "$MAX_RETENTION"); do
  DATES_TO_KEEP="$DATES_TO_KEEP\|$(date --date="$i day ago" "$DATE_FORMAT")"
done

compute_bucket_name_and_path() {
  endpoint="${1}"
  bucket_name="${2}"

  bucket_subpath=""
  [[ $bucket_name ]] && bucket_subpath="${bucket_name}/"

  # If you use a scaleway endpoint, there's some specificities to handle
  if [[ $endpoint =~ https://.+s3.*.scw.cloud ]]; then
    bucket_name="$(echo $endpoint|sed "s/https:\/\/\(.*\)\.s3\..*\.scw\.cloud/\1/g")"
    region="$(echo $endpoint|sed "s/https:\/\/.*\.s3\.\(.*\)\.scw\.cloud/\1/g")"
    endpoint="https://s3.${region}.scw.cloud"
    bucket_subpath=""
    [[ $bucket_name ]] && bucket_subpath="${bucket_name}/"
  fi

  # If you use ovh endpoint, pretty same things
  if [[ $endpoint =~ https://.*.s3..*.perf.cloud.ovh.net ]]; then
    bucket_name="$(echo $endpoint|sed "s/https:\/\/\(.*\)\.s3\..*\.perf\.cloud\.ovh\.net/\1/g")"
    region="$(echo $endpoint|sed "s/https:\/\/.*\.s3\.\(.*\)\.perf\.cloud\.ovh\.net/\1/g")"
    endpoint="https://s3.${region}.perf.cloud.ovh.net"
    bucket_subpath=""
    [[ $bucket_name ]] && bucket_subpath="${bucket_name}/"
  fi

  echo "${region}::${bucket_name}::${endpoint}::${bucket_subpath}"
}

bucket_backup() {
  endpoint="${1}"
  access_key="${2}"
  secret_key="${3}"
  dest="${4}"
  bucket_name="${5}"

  infos="$(compute_bucket_name_and_path "${endpoint}" "${bucket_name}")"
  region="$(echo "${infos}"|awk -F "::" '{print $1}')"
  bucket_name="$(echo "${infos}"|awk -F "::" '{print $2}')"
  endpoint="$(echo "${infos}"|awk -F "::" '{print $3}')"
  bucket_subpath="$(echo "${infos}"|awk -F "::" '{print $4}')"
  echo "[bucket_backup] region=${region}, bucket_name=${bucket_name}, endpoint=${endpoint}, bucket_subpath=${bucket_subpath}"  

  "${MC_BIN}" config host add "${dest}" "${endpoint}" "${access_key}" "${secret_key}"
  echo "[bucket_backup] Copying backup file. ${BACKUP_LOCATION} -> ${dest}/${bucket_subpath}${BACKUP_FOLDER}/${TODAY}.${FILE_EXTENSION}"
  "${MC_BIN}" cp "${BACKUP_LOCATION}" "${dest}/${bucket_subpath}${BACKUP_FOLDER}/${TODAY}.${FILE_EXTENSION}"
}

clean_folder() {
  folder="$1"
  dest="$2"

  echo "[clean_folder] Running ${MC_BIN} ls -r r${dest}/${folder}${BACKUP_FOLDER}/"
  "${MC_BIN}" ls -r "r${dest}/${folder}${BACKUP_FOLDER}/"

  result=$("${MC_BIN}" ls -r "r${dest}/${folder}${BACKUP_FOLDER}/" 2>&1|wc -l)

  if [[ $result -lt 2 ]]; then
    echo "[clean_folder] No results found with folder=${folder}"
    return
  fi

  "${MC_BIN}" ls -r "r${dest}/${folder}${BACKUP_FOLDER}/" |
    awk '{print $6}' |
    grep -v -w "$DATES_TO_KEEP" |
    while read backup_file; do
      echo "[clean_folder] Removing r${dest}/${folder}${BACKUP_FOLDER}/$backup_file"
      "${MC_BIN}" rm "r${dest}/${folder}${BACKUP_FOLDER}/$backup_file"
    done
}

clean_backups() {
  endpoint="${1}"
  access_key="${2}"
  secret_key="${3}"
  dest="${4}"
  bucket_name="${5}"

  echo "[clean_backups] Deleting old backup data"
  echo "[clean_backups] Deleting data older than $(date --date="${MAX_RETENTION} days ago" "${DATE_FORMAT}")"

  infos="$(compute_bucket_name_and_path "${endpoint}" "${bucket_name}")"
  region="$(echo "${infos}"|awk -F "::" '{print $1}')"
  bucket_name="$(echo "${infos}"|awk -F "::" '{print $2}')"
  endpoint="$(echo "${infos}"|awk -F "::" '{print $3}')"
  bucket_subpath="$(echo "${infos}"|awk -F "::" '{print $4}')"
  echo "[clean_backups] region=${region}, bucket_name=${bucket_name}, endpoint=${endpoint}, bucket_subpath=${bucket_subpath}"  

  "${MC_BIN}" config host add "r${dest}" "${endpoint}" "${access_key}" "${secret_key}"
  clean_folder "${bucket_subpath}" "${dest}"
  clean_folder "${bucket_subpath}${bucket_name}/" "${dest}"
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

  echo "[apply_bucket_backup] suffix=${suffix} endpoint=${endpoint} bucket_name=${bucket_name} dest=${dest}"
  if [[ $endpoint && $access_key && $secret_key ]]; then 
    [[ $DISABLE_BACKUP ]] || bucket_backup "${endpoint}" "${access_key}" "${secret_key}" "${dest}" "${bucket_name}"
    [[ $DISABLE_CLEAN ]] || clean_backups "${endpoint}" "${access_key}" "${secret_key}" "${dest}" "${bucket_name}"
    return 0
  fi

  return 1
}

apply_bucket_backup ""
i=1

while true; do
  if ! apply_bucket_backup "_${i}"; then
    echo "[main] No more backup buckets..."
    break
  fi

  (( i++ ))
done

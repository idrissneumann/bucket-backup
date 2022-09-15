#!/usr/bin/env bash

MC_BIN="/usr/bin/mc"

"${MC_BIN}" config host add cmw "${BUCKET_ENDPOINT}" "${BUCKET_ACCESS_KEY}" "${BUCKET_SECRET_KEY}"

# Dates to keep
[[ ! $DATE_FORMAT ]] && DATE_FORMAT="+%F"
TODAY="$(date "$DATE_FORMAT")"

FILE_EXTENSION="${FILE_NAME##*.}"

dates_to_keep_in_grep="${TODAY}"

for i in $(seq 1 "$MAX_RETENTION"); do
  dates_to_keep_in_grep="$dates_to_keep_in_grep\|$(date --date="$i day ago" "$DATE_FORMAT")"
done

bucket_subpath=""
[[ $BUCKET_NAME ]] && bucket_subpath="${BUCKET_NAME}/"

echo "Copying backup file. ${BACKUP_LOCATION} -> cmw/${bucket_subpath}${BACKUP_FOLDER}/${TODAY}.${FILE_EXTENSION}"
"${MC_BIN}" cp "${BACKUP_LOCATION}" "cmw/${bucket_subpath}${BACKUP_FOLDER}/${TODAY}.${FILE_EXTENSION}"

echo "Deleting old backup data"
echo "Deleting data older than $(date --date="${MAX_RETENTION} days ago" "${DATE_FORMAT}")"

# If you use a scaleway endpoint, there's some specificities to handle
if [[ $BUCKET_ENDPOINT =~ https://.+s3.fr-par.scw.cloud ]]; then
  BUCKET_NAME="$(echo $BUCKET_ENDPOINT|sed "s/https:\/\/\(.*\)\.s3\.fr\-par\.scw\.cloud/\1/g")"
  BUCKET_ENDPOINT="https://s3.fr-par.scw.cloud"
  bucket_subpath=""
  [[ $BUCKET_NAME ]] && bucket_subpath="${BUCKET_NAME}/"
fi

"${MC_BIN}" config host add rcmw "${BUCKET_ENDPOINT}" "${BUCKET_ACCESS_KEY}" "${BUCKET_SECRET_KEY}"
echo "${MC_BIN}" ls -r "rcmw/${bucket_subpath}${BACKUP_FOLDER}/"
"${MC_BIN}" ls -r "rcmw/${bucket_subpath}${BACKUP_FOLDER}/" |
  awk '{print $6}' |
  grep -v -w "$dates_to_keep_in_grep" |
  while read backup_file; do
    echo "Removing rcmw/${bucket_subpath}${BACKUP_FOLDER}/$backup_file"
    "${MC_BIN}" rm "rcmw/${bucket_subpath}${BACKUP_FOLDER}/$backup_file"
  done

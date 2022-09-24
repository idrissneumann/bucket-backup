#!/bin/bash

REPO_PATH="${PROJECT_HOME}/bucket-backup/"

cd "${REPO_PATH}" && git pull origin main || :
git reset --hard origin/main
git push -f github main
git push -f pgitlab main
git push -f froggit main
exit 0

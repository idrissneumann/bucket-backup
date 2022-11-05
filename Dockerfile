ARG MC_VERSION

FROM minio/mc:${MC_VERSION}

ENV BACKUP_FOLDER "backup-data"

#Number of backups to retain in days
ENV MAX_RETENTION 5

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

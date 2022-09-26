# Bucket backup

A simple container wich send a mount volume content to an object storage bucket (i.e: S3 on AWS, GCS on GCP, object storage on Scaleway, mini-o on prem, etc).

It's interoperable when your infrastructure provide object storages with S3 compatibility standard  (it's using the mini-o client).

You'll find a tutorial on how to use it with ansible on the [comwork cloud documentation](https://doc.cloud.comwork.io/docs/tutorials/dbaas#backup-on-buckets).

## Table of content

[[_TOC_]]

## Git repositories

* Main repo: https://gitlab.comwork.io/oss/bucket-backup
* Github mirror: https://github.com/idrissneumann/bucket-backup.git
* Gitlab mirror: https://gitlab.com/ineumann/bucket-backup.git
* Bitbucket mirror: https://bitbucket.org/idrissneumann/bucket-backup.git
* Froggit mirror: https://lab.frogg.it/ineumann/bucket-backup.git

## Environment variables

* `BACKUP_LOCATION`: path to the file to backup (if it's a folder, compress-it and archive-it before with `gzip` or `tar`)
* `FILE_NAME`: file to backup basename
* `BUCKET_ENDPOINT`: bucket endpoint url
* `BUCKET_ACCESS_KEY`: bucket access key
* `BUCKET_SECRET_KEY`: bucket secret key
* `BUCKET_NAME` (optional): bucket name (if you're using a global endpoint that serve multiple buckets)
* `DATE_FORMAT` (optional): backup date format (folder name). Default `+%F` which corresponds to `YYYY-MM-JJ`)
* `MAX_RETENTION` (optional): number of days to keep backup. Default: `5` days.s

Not: you can upload to multiple backup using an increment suffix (the suffix must be consecutives and start from `1`):
* `BUCKET_ENDPOINT_1`, `BUCKET_ACCESS_KEY_1`, `BUCKET_SECRET_KEY_1`, `BUCKET_NAME_1`
* `BUCKET_ENDPOINT_2`, `BUCKET_ACCESS_KEY_2`, `BUCKET_SECRET_KEY_2`, `BUCKET_NAME_2`
* etc

## Run it

### With docker-compose

You can check our [`docker-compose.yml`](./docker-compose.yml)

```shell
cp .env.dist .env
# replace the values
docker-compose up --build
```

### Deployment with ansible

You can check our ansible role [here](./ansible-bucket-backup)

You'll find a tutorial on how to use it with ansible on the [comwork cloud documentation](https://doc.cloud.comwork.io/docs/tutorials/dbaas#backup-on-buckets).

#!/usr/bin/env bash

# Helper for packaging the app for elasticbeanstalk deployment.
#
# Expects $BRANCH_NAME and $SEMAPHORE_BUILD_NUMBER to be provided by the environment.
#
# Usage: .elasticbeanstalk/package.sh APP REGION BUCKET
# Ex: .elasticbeanstalk/package.sh ingest us-west-2 elasticbeanstalk-us-west-2-985752656544

set -euo pipefail

APP="${1}"
REGION="${2}"
BUCKET="${3}"

PACKAGE="${APP}-${BRANCH_NAME}-${SEMAPHORE_BUILD_NUMBER}.zip"

.elasticbeanstalk/package.py "${PACKAGE}"

cp ".elasticbeanstalk/app_versions/${PACKAGE}" .semaphore-cache

aws s3 cp --no-progress ".elasticbeanstalk/app_versions/${PACKAGE}" "s3://${BUCKET}/${APP}/"
aws elasticbeanstalk create-application-version \
  --region "${REGION}" \
  --application-name "${APP}" \
  --version-label "${APP}-${BRANCH_NAME}-${SEMAPHORE_BUILD_NUMBER}" \
  --source-bundle "S3Bucket=${BUCKET},S3Key=${APP}/${PACKAGE}"

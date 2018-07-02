#!/usr/bin/env bash

set -euo pipefail

APP="${1}"
REGION="${2}"
BUCKET="${3}"

PACKAGE="${APP}-${BRANCH_NAME}-${SEMAPHORE_BUILD_NUMBER}.zip"

/opt/aws-eb-cli/bin/python .elasticbeanstalk/package.py "${PACKAGE}"
aws s3 cp --no-progress ".elasticbeanstalk/app_versions/${PACKAGE}" "s3://${BUCKET}/${APP}/"
aws elasticbeanstalk create-application-version \
  --region "${REGION}" \
  --application-name "${APP}" \
  --version-label "${APP}-${BRANCH_NAME}-${SEMAPHORE_BUILD_NUMBER}" \
  --source-bundle "S3Bucket=${BUCKET},S3Key=${APP}/${PACKAGE}"

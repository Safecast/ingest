#!/usr/bin/env bash

# Helper for deploying a packaged app to elasticbeanstalk.
#
# Expected environment variables (should be set set by semaphore)
#   - BRANCH_NAME
#   - SEMAPHORE_BUILD_NUMBER
#   - EB_APP_NAME
#   - EB_ENV_NAME
#   - AWS_DEFAULT_REGION
#   - S3_BUCKET_NAME
#
# Optional environment variables
#   - CREATE_APPLICATION_VERSION - set to "true" to also create the application version in s3/elasticbeanstalk
#   - ARTIFACT_EXPIRATION        - when to expire old artifacts during post-deploy cleanup (default: 90 days)

set -euo pipefail

CREATE_APPLICATION_VERSION="${CREATE_APPLICATION_VERSION:-false}"
ARTIFACT_EXPIRATION="${ARTIFACT_EXPIRATION:-129600}"

BRANCH_NAME="${BRANCH_NAME:-${SEMAPHORE_GIT_BRANCH}}"
SEMAPHORE_BUILD_NUMBER="${SEMAPHORE_BUILD_NUMBER:-${SEMAPHORE_WORKFLOW_ID}}"

VERSION="${EB_APP_NAME}-${BRANCH_NAME}-${SEMAPHORE_BUILD_NUMBER}"
PACKAGE="${VERSION}.zip"

if [[ "${CREATE_APPLICATION_VERSION}" == "true" ]]; then
    echo "Creating application version ${VERSION}..."
    cache restore "app_version_${SEMAPHORE_BUILD_NUMBER}"
    aws s3 cp --no-progress ".elasticbeanstalk/app_versions/${PACKAGE}" "s3://${S3_BUCKET_NAME}/${EB_APP_NAME}/"
    aws elasticbeanstalk create-application-version \
      --region "${AWS_DEFAULT_REGION}" \
      --application-name "${EB_APP_NAME}" \
      --version-label "${VERSION}" \
      --source-bundle "S3Bucket=${S3_BUCKET_NAME},S3Key=${EB_APP_NAME}/${PACKAGE}" \
      --process
fi

# Work around https://github.com/aws/aws-cli/issues/3550 in current install of ebcli in semaphore
# and https://github.com/pypa/virtualenv/issues/1029 in virtualenv
virtualenv venv
set +u
source venv/bin/activate
set -u
pip install awsebcli

echo "Deploying ${VERSION} to ${EB_ENV_NAME}..."
eb deploy --quiet "${EB_ENV_NAME}" --version "${VERSION}" --timeout 20

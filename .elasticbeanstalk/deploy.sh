#!/usr/bin/env bash

# Helper for deploying a packaged app to elasticbeanstalk.
#
# Expects $BRANCH_NAME and $SEMAPHORE_BUILD_NUMBER to be provided by the environment.
#
# Usage: .elasticbeanstalk/deploy.sh APP ENVIRONMENT
# Ex: .elasticbeanstalk/deploy.sh "${EB_APP_NAME}" "${EB_ENV_NAME}"

set -euo pipefail

EB_APP_NAME="${1}"
EB_ENV_NAME="${2}"

VERSION="${EB_APP_NAME}-${BRANCH_NAME}-${SEMAPHORE_BUILD_NUMBER}"

echo "Deploying ${VERSION} to ${EB_ENV_NAME}..."
eb deploy "${EB_ENV_NAME}" --version "${VERSION}" --timeout 20

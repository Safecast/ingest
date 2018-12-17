#!/usr/bin/env bash

# Helper for packaging the app for elasticbeanstalk deployment.
#
# Expected environment variables (should be set set by semaphore)
#   - BRANCH_NAME
#   - SEMAPHORE_BUILD_NUMBER
#
# Usage: .elasticbeanstalk/package.sh APP
# Ex: .elasticbeanstalk/package.sh ${SEMAPHORE_PROJECT_NAME}

set -euo pipefail

BRANCH_NAME="${BRANCH_NAME:-${SEMAPHORE_GIT_BRANCH}}"
SEMAPHORE_BUILD_NUMBER="${SEMAPHORE_BUILD_NUMBER:-${SEMAPHORE_WORKFLOW_ID}}"

EB_APP_NAME="${1}"

PACKAGE="${EB_APP_NAME}-${BRANCH_NAME}-${SEMAPHORE_BUILD_NUMBER}.zip"

.elasticbeanstalk/package.py "${PACKAGE}"

cache store "app_version_${SEMAPHORE_BUILD_NUMBER}" .elasticbeanstalk/app_versions

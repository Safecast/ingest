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

EB_APP_NAME="${1}"

PACKAGE="${EB_APP_NAME}-${BRANCH_NAME}-${SEMAPHORE_BUILD_NUMBER}.zip"

.elasticbeanstalk/package.py "${PACKAGE}"

mkdir -p .semaphore-cache/artifacts
cp ".elasticbeanstalk/app_versions/${PACKAGE}" .semaphore-cache/artifacts

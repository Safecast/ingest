#!/usr/bin/env bash

set -euo pipefail

EB_APP_NAME="${1}"
EB_ENV_NAME="${2}"

VERSION="${EB_APP_NAME}-${BRANCH_NAME}-${SEMAPHORE_BUILD_NUMBER}"

echo "Deploying ${VERSION} to ${EB_ENV_NAME}..."
eb deploy "${EB_ENV_NAME}" --version "${VERSION}" --timeout 20

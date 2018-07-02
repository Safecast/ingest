#!/usr/bin/env bash

set -euo pipefail

REVISION=${REVISION:-$(git rev-parse HEAD)}
BRANCH_NAME=${BRANCH_NAME:-$(git rev-parse --abbrev-ref HEAD)}
BUILD_NUMBER=${SEMAPHORE_BUILD_NUMBER:-1}
VERSION="ingest-${BRANCH_NAME}-${BUILD_NUMBER}"

EB_ENV_NAME="${1:-}"

NEWRELIC_APP_ID="${2:-}"
NEWRELIC_API_KEY="${NEWRELIC_API_KEY:-}"

if [[ -z "${EB_ENV_NAME}" ]]; then
  echo "Usage: $0 <environment> [newrelic app id]"
  echo "e.g.: $0 myapp-dev-wrk"
  exit 1
fi

post_deployment() {
    if [[ -z "${NEWRELIC_API_KEY}" ]]; then
        echo "Unable to send deployment notification to NewRelic. Please ensure NEWRELIC_API_KEY is set."
    else
        curl -s -X POST "https://api.newrelic.com/v2/applications/${1}/deployments.json" \
             -H "X-Api-Key:${NEWRELIC_API_KEY}" \
             -H 'Content-Type: application/json' \
             -d \
                "{
                  \"deployment\": {
                    \"revision\": \"${REVISION}\",
                    \"changelog\": \"https://semaphoreci.com/theathletic/the-athletic/branches/${BRANCH_NAME}/builds/${BUILD_NUMBER}\",
                    \"description\": \"${VERSION}\",
                    \"user\": \"semaphore\"
                  }
                }" \
        || echo "Failure pushing deployment marker to NewRelic, continuing with deployment."
    fi
}

echo "Deploying ${VERSION} to ${EB_ENV_NAME}..."
eb deploy "${EB_ENV_NAME}" --version "${VERSION}" --timeout 20

if [[ -n "${NEWRELIC_APP_ID}" ]]; then
    post_deployment "${NEWRELIC_APP_ID}"
fi

#!/bin/bash
#
# Setup a new Git repository on Salsa
#
# This script uses the GitLab REST API and requires an access token.
# The token is obtained from the GitLab profile page -> Access Tokens
# (https://salsa.debian.org/profile/personal_access_tokens).
# The token is in the environment variable SALSA_TOKEN
# or has to be sourced from the ~/.salsarc file and assigned
# to the SALSA_TOKEN variable:
#
#   SALSA_TOKEN="BjDg5RQoRKej738MexCF"
#

set -eu

if ! which jq >/dev/null
then
        echo "You need to apt install jq" >&2
        exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: ./setup-salsa-repository <packagename>"
    exit 1;
fi

check_return_code() {
    if [ $? -ne 0 ]; then
        echo
        echo "Something went wrong!"
        exit 1
    fi
}

test -n "$SALSA_TOKEN" || . ~/.salsarc

PACKAGE=$1

SALSA_URL="https://salsa.debian.org/api/v4"
SALSA_GROUP=java-team
SALSA_GROUP_ID=2588

# -----------------------------------------------------------------------------

echo "Creating the ${PACKAGE} repository..."

RESPONSE=$(curl -s "$SALSA_URL/projects?private_token=$SALSA_TOKEN" \
  --data "path=$PACKAGE&namespace_id=$SALSA_GROUP_ID&visibility=public&issues_enabled=false&snippets_enabled=false&wiki_enabled=false&jobs_enabled=false&printing_merge_request_link_enabled=false")

echo $RESPONSE | jq --exit-status .id > /dev/null
check_return_code

PROJECT_ID=$(echo $RESPONSE | jq '.id')

# -----------------------------------------------------------------------------

echo "Configuring the BTS tag pending hook..."

TAGPENDING_URL="https://webhook.salsa.debian.org/tagpending/$PACKAGE"
curl --silent --output /dev/null -XPOST --header "PRIVATE-TOKEN: $SALSA_TOKEN" $SALSA_URL/projects/$PROJECT_ID/hooks \
     --data "url=$TAGPENDING_URL&push_events=1&enable_ssl_verification=1"
check_return_code

# -----------------------------------------------------------------------------

echo "Configuring the KGB hook..."

KGB_URL="http://kgb.debian.net:9418/webhook/?channel=debian-java%26network=oftc%26private=1%26use_color=1%26use_irc_notices=1%26squash_threshold=20"
curl --silent --output /dev/null -XPOST --header "PRIVATE-TOKEN: $SALSA_TOKEN" $SALSA_URL/projects/$PROJECT_ID/hooks \
     --data "url=$KGB_URL&push_events=yes&issues_events=yes&merge_requests_events=yes&tag_push_events=yes&note_events=yes&job_events=yes&pipeline_events=yes&wiki_events=yes&enable_ssl_verification=yes"
check_return_code

# -----------------------------------------------------------------------------

echo "Configuring email notification on push..."

curl --silent --output /dev/null -XPUT --header "PRIVATE-TOKEN: $SALSA_TOKEN" $SALSA_URL/projects/$PROJECT_ID/services/emails-on-push \
     --data "recipients=pkg-java-commits@lists.alioth.debian.org dispatch@tracker.debian.org"
check_return_code

# -----------------------------------------------------------------------------

echo
echo "Done! The repository is located at ${SALSA_URL%/api*}/$SALSA_GROUP/$PACKAGE"

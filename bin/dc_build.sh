#!/bin/bash
set -euo pipefail

CHANNEL="${1:-stable}"
# Drop the channel arg (if given) so the remainder can be forwarded
[ $# -gt 0 ] && shift
ENV_FILE=".env"

# Build with the requested channel
DOKUWIKI_VERSION="$CHANNEL" docker compose build "$@"

# Resolve the actual version baked into the image
ACTUAL_VERSION=$(docker compose run --rm --entrypoint cat dokuwiki /var/www/html/VERSION | awk '{print $1}')
echo "Resolved DokuWiki version: $ACTUAL_VERSION"

# Tag the image with the concrete version
docker tag "$(docker compose config --images | head -n1)" "dokuwiki/build:${ACTUAL_VERSION}"

# Update (or create) .env with the resolved tag
touch "$ENV_FILE"
if grep -q "^DOKUWIKI_TAG=" "$ENV_FILE"; then
    sed -i "s/^DOKUWIKI_TAG=.*/DOKUWIKI_TAG=${ACTUAL_VERSION}/" "$ENV_FILE"
else
    echo "DOKUWIKI_TAG=${ACTUAL_VERSION}" >> "$ENV_FILE"
fi

echo "Updated $ENV_FILE: DOKUWIKI_TAG=${ACTUAL_VERSION}"

# Bring it up with the newly pinned version
docker compose up -d

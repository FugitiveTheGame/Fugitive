#!/usr/bin/env bash
# Builds the Discord announcement `content` for a release and prints it to
# stdout. Shared by the notify job in publish.yml and the manual announcer in
# announce-release.yml so the format and length handling live in one place.
#
# Required env:
#   RELEASE_NAME  - release title
#   RELEASE_URL   - release html_url
#   RELEASE_BODY  - release body / changelog
set -euo pipefail

content="$(printf '**New Fugitive release:** %s\n**Download Here:** %s\n\n**Changelog:**\n%s' \
	"${RELEASE_NAME:-}" "${RELEASE_URL:-}" "${RELEASE_BODY:-}")"

# Discord caps webhook content at 2000 characters. Trim by Unicode codepoint
# with jq rather than eating a 400 from the API.
printf '%s' "$content" | jq -Rrs 'if length > 2000 then .[0:1997] + "..." else . end'

#!/bin/bash
# usage: q.sh '<graphql json body>'  -> response on stdout; key never echoed
set -a; . ~/.config/boki/secrets.env; set +a
curl -s -u "$UTHANA_API_KEY:" -H 'Content-Type: application/json' https://uthana.com/graphql -d "$1"

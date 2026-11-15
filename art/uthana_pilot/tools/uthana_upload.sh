#!/bin/bash
# usage: upload.sh <file> <name> <auto_rig true|false>
set -a; . ~/.config/boki/secrets.env; set +a
curl -s -u "$UTHANA_API_KEY:" https://uthana.com/graphql \
 -F "operations={\"query\":\"mutation (\$file: Upload!, \$name: String!, \$ar: Boolean) { create_character(file: \$file, name: \$name, auto_rig: \$ar, auto_rig_front_facing: true, include_fingers: false) { character { id name } auto_rig_confidence } }\",\"variables\":{\"file\":null,\"name\":\"$2\",\"ar\":$3}}" \
 -F 'map={"0":["variables.file"]}' -F "0=@$1"

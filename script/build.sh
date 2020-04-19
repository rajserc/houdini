#!/bin/bash


(
echo $HOUDINI_WATCH
set -e
set -o pipefail
export DATABASE_URL=${BUILD_DATABASE_URL:-postgres://postgres:yMC1OeDvyfAILysWMUa6@devdbindiabenefits.cpdsnbqotxlo.us-east-1.rds.amazonaws.com/devdbindiabenefits}
echo $DATABASE_URL
npm run export-button-config && npm run export-i18n && npm run generate-api-js

if [ -n "$HOUDINI_WATCH" ];
then
    echo "we're gonna watch!!!"
    $(npm bin)/webpack  --watch
else
    echo "we're gonna build!!!"
    NODE_ENV=production $(npm bin)/webpack -p
fi
)

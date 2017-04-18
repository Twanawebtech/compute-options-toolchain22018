#!/bin/bash

################################################################
# Install dependencies
################################################################
echo 'Installing dependencies...'
sudo apt-get -qq update 1>/dev/null
sudo apt-get -qq install jq 1>/dev/null
sudo apt-get -qq install figlet 1>/dev/null

figlet 'Node.js'

echo 'Installing nvm (Node.js Version Manager)...'
npm config delete prefix
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.2/install.sh | bash > /dev/null 2>&1
. ~/.nvm/nvm.sh

echo 'Installing Node.js 6.9.1...'
nvm install 6.9.1 1>/dev/null
npm install --progress false --loglevel error 1>/dev/null


################################################################
# And the web app
################################################################
figlet 'Web app'

# Push app
cd service

if [ -z "$CF_APP_HOSTNAME" ]; then
  echo 'CF_APP_HOSTNAME was not set in the pipeline. Using CF_APP as hostname.'
  export CF_APP_HOSTNAME=$CF_APP
fi

if [ -z "$CF_APP_INSTANCES" ]; then
  echo 'CF_APP_INSTANCES was not set in the pipeline. Using 1 as default value.'
  export CF_APP_INSTANCES=1
fi

if ! cf app $CF_APP; then
  cf push $CF_APP -i $CF_APP_INSTANCES --hostname $CF_APP_HOSTNAME --no-start
  cf set-env $CF_APP CLOUDANT_db "${CLOUDANT_db}"
  if [ ! -z "$USE_API_CACHE" ]; then
    cf set-env $CF_APP USE_API_CACHE true
  fi
  if [ -z "$ADMIN_USERNAME" ]; then
    echo 'No admin username configured'
  else
    cf set-env $CF_APP ADMIN_USERNAME "${ADMIN_USERNAME}"
    cf set-env $CF_APP ADMIN_PASSWORD "${ADMIN_PASSWORD}"
  fi
  cf start $CF_APP
else
  OLD_CF_APP=${CF_APP}-OLD-$(date +"%s")
  rollback() {
    set +e
    if cf app $OLD_CF_APP; then
      cf logs $CF_APP --recent
      cf delete $CF_APP -f
      cf rename $OLD_CF_APP $CF_APP
    fi
    exit 1
  }
  set -e
  trap rollback ERR
  figlet -f small 'Deploy new version'
  cf rename $CF_APP $OLD_CF_APP
  cf push $CF_APP -i $CF_APP_INSTANCES --hostname $CF_APP_HOSTNAME --no-start
  cf set-env $CF_APP CLOUDANT_db "${CLOUDANT_db}"
  if [ ! -z "$USE_API_CACHE" ]; then
    cf set-env $CF_APP USE_API_CACHE true
  fi
  if [ -z "$ADMIN_USERNAME" ]; then
    echo 'No admin username configured'
  else
    cf set-env $CF_APP ADMIN_USERNAME "${ADMIN_USERNAME}"
    cf set-env $CF_APP ADMIN_PASSWORD "${ADMIN_PASSWORD}"
  fi
  cf start $CF_APP
  figlet -f small 'Remove old version'
  cf delete $OLD_CF_APP -f
fi

figlet -f slant 'Job done!'

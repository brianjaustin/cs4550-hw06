#!/bin/bash

export SECRET_KEY_BASE=insecure
export MIX_ENV=prod
export PORT=4790
export NODEBIN=`pwd`/assets/node_modules/.bin
export PATH="$PATH:$NODEBIN"

echo "Building..."

mix local.hex --force
mix local.rebar --force
mix deps.get
mix compile

# Setup secret config file.
# From lecture notes
# https://github.com/NatTuck/scratch-2021-01/blob/master/4550/0212/hangman/deploy.sh
CFGD=$(readlink -f ~/.config/bulls)

if [ ! -d "$CFGD" ]; then
    mkdir -p "$CFGD"
fi

if [ ! -e "$CFGD/base" ]; then
    mix phx.gen.secret > "$CFGD/base"
fi

SECRET_KEY_BASE=$(cat "$CFGD/base")
export SECRET_KEY_BASE

(cd assets && npm install)
(cd assets && webpack --mode production)
mix phx.digest

echo "Generating release..."
mix release --force --overwrite

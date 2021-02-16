#!/bin/bash

export SECRET_KEY_BASE=W68eso5YQOlbtvSNUR50N/HDWj6IaEhAwMR3LtzuBEQAefwYVbX84bvoTA7XtiGi
export MIX_ENV=prod
export PORT=4792

echo "Stopping old copy of app, if any..."

_build/prod/rel/hw05/bin/hw05 stop || true

CFGD=$(readlink -f ~/.config/hangman)

if [ ! -e "$CFGD/base" ]; then
    echo "run build first"
    exit 1
fi

echo "Starting app..."

_build/prod/rel/hw05/bin/hw05 start

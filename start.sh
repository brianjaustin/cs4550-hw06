#!/bin/bash

export SECRET_KEY_BASE=W68eso5YQOlbtvSNUR50N/HDWj6IaEhAwMR3LtzuBEQAefwYVbX84bvoTA7XtiGi
export MIX_ENV=prod
export PORT=4794

echo "Stopping old copy of app, if any..."

_build/prod/rel/hw06/bin/hw06 stop || true

CFGD=$(readlink -f ~/.config/bulls)

if [ ! -e "$CFGD/base" ]; then
    echo "run build first"
    exit 1
fi

echo "Starting app..."

_build/prod/rel/hw06/bin/hw06 start

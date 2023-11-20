#!/usr/bin/env bash

if [ ! -v SETUP_ENV_SOURCED ]; then
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

    export SETUP_ENV_SOURCED=true
    export OLD_XDG_CONFIG_HOME=$XDG_CONFIG_HOME
    export XDG_CONFIG_HOME=$SCRIPT_DIR/shell/.config/

    flutter config --enable-custom-devices
else
    echo "setup_env.sh already sourced"
fi

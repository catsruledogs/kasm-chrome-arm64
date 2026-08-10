#!/usr/bin/env bash

set -ex

START_COMMAND="chromium-kasm"
PGREP="chromium"
MAXIMIZE="true"
DEFAULT_ARGS=""

if [[ "${MAXIMIZE}" == "true" ]]; then
    DEFAULT_ARGS+=" --start-maximized"
fi

ARGS="${APP_ARGS:-$DEFAULT_ARGS}"

options=$(getopt -o gau: -l go,assign,url: -n "$0" -- "$@") || exit
eval set -- "$options"

while [[ $1 != -- ]]; do

    case $1 in

        -g|--go)
            GO='true'
            shift
            ;;

        -a|--assign)
            ASSIGN='true'
            shift
            ;;

        -u|--url)
            OPT_URL="$2"
            shift 2
            ;;

        *)
            echo "bad option: $1" >&2
            exit 1
            ;;

    esac

done

shift

kasm_exec() {

    if [ -n "${OPT_URL:-}" ]; then
        URL="${OPT_URL}"
    elif [ -n "${1:-}" ]; then
        URL="$1"
    fi

    if [ -n "${URL:-}" ]; then
        /usr/bin/filter_ready
        /usr/bin/desktop_ready

        "${START_COMMAND}" ${ARGS} "${URL}"
    else
        echo "No URL specified for exec command. Doing nothing."
    fi
}

kasm_startup() {

    if [ -n "${KASM_URL:-}" ]; then
        URL="${KASM_URL}"
    elif [ -z "${URL:-}" ]; then
        URL="${LAUNCH_URL:-}"
    fi

    if [ -z "${DISABLE_CUSTOM_STARTUP:-}" ] || [ -n "${FORCE:-}" ]; then

        echo "Entering process startup loop"

        set +x

        while true; do

            if ! pgrep -x "${PGREP}" > /dev/null; then

                /usr/bin/filter_ready
                /usr/bin/desktop_ready

                set +e

                if [ -n "${URL:-}" ]; then
                    "${START_COMMAND}" ${ARGS} "${URL}"
                else
                    "${START_COMMAND}" ${ARGS}
                fi

                set -e

            fi

            sleep 1

        done

        set -x

    fi
}

if [ -n "${GO:-}" ] || [ -n "${ASSIGN:-}" ]; then
    kasm_exec
else
    kasm_startup
fi

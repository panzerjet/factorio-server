#!/bin/bash
set -eoux pipefail

FACTORIO_VOL=/factorio
VERSION=${VERSION:latest}
LOAD_LATEST_SAVE="${LOAD_LATEST_SAVE:-true}"
GENERATE_NEW_SAVE="${GENERATE_NEW_SAVE:-false}"
SAVE_NAME="${SAVE_NAME:-""}"
BIND="${BIND:-""}"
CONSOLE_LOG_LOCATION="${CONSOLE_LOG_LOCATION:-""}"

mkdir -p "$FACTORIO_VOL"
mkdir -p "$SAVES"
mkdir -p "$CONFIG"
mkdir -p "$MODS"
mkdir -p "$SCENARIOS"
mkdir -p "$SCRIPTOUTPUT"


curl -sSL "https://www.factorio.com/download/sha256sums/" -o "sha256sums.txt" --retry 8
LATEST=`awk '$2==/factorio_headless_x64_.+/ {print $2; exit}' "sha256sums.txt"
LATEST_SHA=`awk '{print $1}' $LATEST`
LATEST_VER=`sed "s/factorio_headless_x64_\([0-9]\+\.[0-9]\+\.[0-9]\+\)\.tar\.xz/\1/"`
rm "sha256sums.txt"
echo "Latest version available is $LATEST_VER $LATEST_SHA"


if [[ -f $FACTORIO_APP/.sha256sum ]]; then
  # Read checksum of last installation
  SHA256=`cat .sha256sum`
fi
SHA256="${SHA256:-""}"

if [[ "$SHA256" != "$LATEST_SHA" ]] then
  ./docker-update-game.sh $LATEST_VER
  echo "$LATEST_SHA" > .sha256sum
fi

if [[ ! -f $CONFIG/rconpw ]]; then
  # Generate a new RCON password if none exists
  pwgen 15 1 >"$CONFIG/rconpw"
fi

if [[ ! -f $CONFIG/server-settings.json ]]; then
  # Copy default settings if server-settings.json doesn't exist
  cp "$FACTORIO_APP/data/server-settings.example.json" "$CONFIG/server-settings.json"
fi

if [[ ! -f $CONFIG/map-gen-settings.json ]]; then
  cp "$FACTORIO_APP/data/map-gen-settings.example.json" "$CONFIG/map-gen-settings.json"
fi

if [[ ! -f $CONFIG/map-settings.json ]]; then
  cp "$FACTORIO_APP/data/map-settings.example.json" "$CONFIG/map-settings.json"
fi

NRTMPSAVES=$( find -L "$SAVES" -iname \*.tmp.zip -mindepth 1 | wc -l )
if [[ $NRTMPSAVES -gt 0 ]]; then
  # Delete incomplete saves (such as after a forced exit)
  rm -f "$SAVES"/*.tmp.zip
fi

if [[ ${UPDATE_MODS_ON_START:-} == "true" ]]; then
  ./docker-update-mods.sh
fi

if [[ $(id -u) = 0 ]]; then
  # Update the User and Group ID based on the PUID/PGID variables
  usermod -o -u "$PUID" factorio
  groupmod -o -g "$PGID" factorio
  # Take ownership of factorio data if running as root
  chown -R factorio:factorio "$FACTORIO_VOL"
  # Drop to the factorio user
  SU_EXEC="su-exec factorio"
else
  SU_EXEC=""
fi

sed -i '/write-data=/c\write-data=\/factorio/' "$FACTORIO_APP/config/config.ini"

NRSAVES=$(find -L "$SAVES" -iname \*.zip -mindepth 1 | wc -l)
if [[ $GENERATE_NEW_SAVE != true && $NRSAVES ==  0 ]]; then
    GENERATE_NEW_SAVE=true
    SAVE_NAME=_autosave1
fi

if [[ $GENERATE_NEW_SAVE == true ]]; then
    if [[ -z "$SAVE_NAME" ]]; then
        echo "If \$GENERATE_NEW_SAVE is true, you must specify \$SAVE_NAME"
        exit 1
    fi
    if [[ -f "$SAVES/$SAVE_NAME.zip" ]]; then
        echo "Map $SAVES/$SAVE_NAME.zip already exists, skipping map generation"
    else
        $SU_EXEC "$FACTORIO_APP/bin/x64/factorio" \
            --create "$SAVES/$SAVE_NAME.zip" \
            --map-gen-settings "$CONFIG/map-gen-settings.json" \
            --map-settings "$CONFIG/map-settings.json"
    fi
fi

FLAGS=(\
  --port "$PORT" \
  --server-settings "$CONFIG/server-settings.json" \
  --server-banlist "$CONFIG/server-banlist.json" \
  --rcon-port "$RCON_PORT" \
  --server-whitelist "$CONFIG/server-whitelist.json" \
  --use-server-whitelist \
  --server-adminlist "$CONFIG/server-adminlist.json" \
  --rcon-password "$(cat "$CONFIG/rconpw")" \
  --server-id /factorio/config/server-id.json \
)

if [ -n "$CONSOLE_LOG_LOCATION" ]; then
  FLAGS+=( --console-log "$CONSOLE_LOG_LOCATION" )
fi

if [ -n "$BIND" ]; then
  FLAGS+=( --bind "$BIND" )
fi

if [[ $LOAD_LATEST_SAVE == true ]]; then
    FLAGS+=( --start-server-load-latest )
else
    FLAGS+=( --start-server "$SAVE_NAME" )
fi

# shellcheck disable=SC2086
exec $SU_EXEC "$FACTORIO_APP/bin/x64/factorio" "${FLAGS[@]}" "$@"
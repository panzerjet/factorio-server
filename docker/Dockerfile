FROM frolvlad/alpine-glibc:alpine-3.12

LABEL maintainer="https://github.com/factoriotools/factorio-docker"

ARG USER=factorio
ARG GROUP=factorio
ARG PUID=845
ARG PGID=845

# version checksum of the archive to download
ARG VERSION

ENV PORT=34197 \
    RCON_PORT=27015 \
    VERSION=${VERSION} \
    FACTORIO_APP=/opt/factorio \
    SAVES=/factorio/saves \
    CONFIG=/factorio/config \
    MODS=/factorio/mods \
    SCENARIOS=/factorio/scenarios \
    SCRIPTOUTPUT=/factorio/script-output \
    PUID="$PUID" \
    PGID="$PGID"
    
# SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
RUN set -x \
    && if [[ "${VERSION}" == "" ]]; then \
        echo "build-arg VERSION is required" \
        && exit 1; \
    fi 

RUN set -x \
    && mkdir -p /opt /factorio \
    && apk add --update --no-cache --no-progress bash binutils curl file gettext jq libintl pwgen shadow su-exec \

RUN set -x \
    && chmod ugo=rwx ${FACTORIO_APP} \
    && ln -s "$SCENARIOS" "${FACTORIO_APP}/scenarios" \
    && ln -s "$SAVES" "${FACTORIO_APP}/saves" \
    && mkdir -p "${FACTORIO_APP}/config/" \
    && addgroup -g "$PGID" -S "$GROUP" \
    && adduser -u "$PUID" -G "$GROUP" -s /bin/sh -SDH "$USER" \
    && chown -R "$USER":"$GROUP" "${FACTORIO_APP} /factorio"

COPY files/*.sh /
COPY files/config.ini "${FACTORIO_APP}/config/config.ini"

VOLUME /factorio
EXPOSE $PORT/udp $RCON_PORT/tcp
ENTRYPOINT ["/docker-entrypoint.sh"]

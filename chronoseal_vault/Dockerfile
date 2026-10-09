ARG BUILD_ARCH=amd64
FROM ghcr.io/home-assistant/${BUILD_ARCH}-base:3.21
ARG BUILD_VERSION=3.4.0-alpha6
ARG BUILD_ARCH
LABEL io.hass.version="${BUILD_VERSION}" io.hass.type="app" io.hass.arch="${BUILD_ARCH}"

# Runtime only. Java is retained for an optional, explicitly SHA-256-pinned
# external OtsCli.jar; the full development/source _crypto archive is not
# shipped in the Home Assistant image.
RUN apk add --no-cache nodejs npm openjdk17-jre-headless openssl ca-certificates
WORKDIR /opt/pasevsu

COPY package.json /opt/pasevsu/package.json
RUN npm install --omit=dev --no-audit --no-fund --save-exact

COPY app /opt/pasevsu/app
RUN mkdir -p /opt/pasevsu/app/vendor && \
    cp /opt/pasevsu/node_modules/openpgp/dist/openpgp.min.js /opt/pasevsu/app/vendor/openpgp.min.js && \
    sha256sum /opt/pasevsu/app/vendor/openpgp.min.js | awk '{print $1}' > /opt/pasevsu/app/vendor/openpgp.min.js.sha256

# Only the tiny runtime trust/metadata directory is part of the image.
# Source checkouts remain optional and may be supplied outside the HA app.
COPY _crypto /opt/pasevsu/_crypto
COPY tools/generate_crypto_manifest.js tools/verify_crypto_manifest.js tools/runtime_selftest.js tools/RUNTIME_CONTRACT.json /opt/pasevsu/
COPY tools/fixtures /opt/pasevsu/tools/fixtures
RUN node /opt/pasevsu/generate_crypto_manifest.js /opt/pasevsu/_crypto && \
    node /opt/pasevsu/verify_crypto_manifest.js /opt/pasevsu/_crypto && \
    apk del npm

COPY server.js pgp-network-api.js tsa-engine.js pki-engine.js git-provenance.js chain-orchestrator.js /opt/pasevsu/
RUN set +e; \
    node /opt/pasevsu/runtime_selftest.js /opt/pasevsu > /opt/pasevsu/RUNTIME_SELFTEST.json 2>&1; \
    rc=$?; \
    echo "===== CHRONOSEAL RUNTIME SELFTEST ====="; \
    cat /opt/pasevsu/RUNTIME_SELFTEST.json; \
    echo "===== EXIT CODE: ${rc} ====="; \
    test "$rc" -eq 0
COPY rootfs /
RUN chmod a+x /etc/services.d/pasevsu/run
EXPOSE 8099

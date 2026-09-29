ARG BUILD_ARCH=amd64
FROM ghcr.io/home-assistant/${BUILD_ARCH}-base:3.21
ARG BUILD_VERSION=3.3.0-alpha3
ARG BUILD_ARCH
LABEL io.hass.version="${BUILD_VERSION}" io.hass.type="app" io.hass.arch="${BUILD_ARCH}"

RUN apk add --no-cache nodejs npm openjdk17-jre-headless openssl ca-certificates curl jq p7zip
WORKDIR /opt/pasevsu

COPY package.json /opt/pasevsu/package.json
RUN npm install --omit=dev --no-audit --no-fund --save-exact

COPY app /opt/pasevsu/app
RUN mkdir -p /opt/pasevsu/app/vendor && \
    cp /opt/pasevsu/node_modules/openpgp/dist/openpgp.min.js /opt/pasevsu/app/vendor/openpgp.min.js

# Real user-supplied crypto source archive. Extract at image build time.
COPY _crypto.7z /tmp/pasevsu_crypto.7z
RUN echo 'd200d6369db93acbf9334f9b6f5869538aaef713b3062c6b53b2aada8908eb13  /tmp/pasevsu_crypto.7z' | sha256sum -c -
RUN mkdir -p /tmp/crypto_import /opt/pasevsu/_crypto && \
    7z x -y /tmp/pasevsu_crypto.7z -o/tmp/crypto_import >/tmp/crypto_extract.log && \
    if [ -d /tmp/crypto_import/_crypto ]; then cp -a /tmp/crypto_import/_crypto/. /opt/pasevsu/_crypto/; \
    else cp -a /tmp/crypto_import/. /opt/pasevsu/_crypto/; fi && \
    test -n "$(find /opt/pasevsu/_crypto -mindepth 1 -maxdepth 2 -print -quit)" && \
    rm -rf /tmp/crypto_import /tmp/pasevsu_crypto.7z

COPY tools/generate_crypto_manifest.js tools/verify_crypto_manifest.js tools/runtime_selftest.js /opt/pasevsu/
RUN node /opt/pasevsu/generate_crypto_manifest.js /opt/pasevsu/_crypto && node /opt/pasevsu/verify_crypto_manifest.js /opt/pasevsu/_crypto
COPY server.js tsa-engine.js pki-engine.js git-provenance.js chain-orchestrator.js /opt/pasevsu/
RUN node /opt/pasevsu/runtime_selftest.js /opt/pasevsu > /opt/pasevsu/RUNTIME_SELFTEST.json
COPY rootfs /
RUN chmod a+x /etc/services.d/pasevsu/run
EXPOSE 8099

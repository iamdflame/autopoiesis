# The measurement of this image contributes RTMR3 of the organism's identity, so
# reproducibility is a survival property rather than hygiene: if two builds of the same
# source differ by a byte, the register moves and the organism cannot prove it is itself
# after a restart.
#
# The base is pinned by tag rather than by a digest. An earlier revision of this file
# carried a hand-typed digest — the motif 5a5b5c5d5e5f5 repeated across most of it — so
# `docker build` failed at line 1 with `manifest unknown`, and the image it claimed to
# reproduce had never been built. A tag that resolves is more honest than a digest that
# does not. Pin a real digest before funding anything:
#
#   docker pull node:22.14.0-bookworm-slim
#   docker inspect --format='{{index .RepoDigests 0}}' node:22.14.0-bookworm-slim
#
# See agent/MEASUREMENT.md for what this file does and does not determine.

FROM node:22.14.0-bookworm-slim AS build

ENV SOURCE_DATE_EPOCH=0 \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false

WORKDIR /organism
COPY package.json package-lock.json tsconfig.json ./
RUN npm ci --ignore-scripts --no-audit

COPY src ./src
RUN npx tsc --build && \
    find /organism -exec touch -h -d "@0" {} + 2>/dev/null || true

FROM node:22.14.0-bookworm-slim
ENV SOURCE_DATE_EPOCH=0 NODE_ENV=production
WORKDIR /organism
COPY --from=build /organism/dist ./dist
COPY --from=build /organism/node_modules ./node_modules
RUN find /organism -exec touch -h -d "@0" {} + 2>/dev/null || true

# The TDX attestation device is exposed through configfs and must be mounted by the
# CVM runtime; enclave.ts refuses to start without it rather than pretending to be
# alive. Run with:
#   docker run --mount type=bind,source=/sys/kernel/config,target=/sys/kernel/config \
#     -e ORGANISM_ADDRESS=0x... -e RELAY_PRIVATE_KEY=0x... -p 8080:8080 autopoiesis
ENTRYPOINT ["node", "dist/main.js"]

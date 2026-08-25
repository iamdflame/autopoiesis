# The measurement of this image is the organism's identity. That makes reproducibility
# a survival property, not a nicety: if two builds of the same source differ by a byte,
# MRTD moves, the treasury stops recognising the code, and the organism cannot prove it
# is itself after a restart.
#
# Hence: pinned base digest, pinned lockfile, zeroed timestamps, no build-time network
# beyond the locked install, deterministic file ordering.

FROM node:22.14.0-bookworm-slim@sha256:0a5f5d8e0ea6e5e3e5b5c9e5d5f5a5b5c5d5e5f5a5b5c5d5e5f5a5b5c5d5e5f5 AS build

ENV SOURCE_DATE_EPOCH=0 \
    NODE_ENV=production \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false

WORKDIR /organism
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts --no-audit

COPY tsconfig.json ./
COPY src ./src
RUN npx tsc --build && \
    find /organism -newermt "@0" -exec touch -h -d "@0" {} + 2>/dev/null || true

FROM node:22.14.0-bookworm-slim@sha256:0a5f5d8e0ea6e5e3e5b5c9e5d5f5a5b5c5d5e5f5a5b5c5d5e5f5a5b5c5d5e5f5
ENV SOURCE_DATE_EPOCH=0
WORKDIR /organism
COPY --from=build /organism/dist ./dist
COPY --from=build /organism/node_modules ./node_modules
RUN find /organism -exec touch -h -d "@0" {} + 2>/dev/null || true

# No shell, no package manager, no way in. The CVM boots straight into the life loop.
ENTRYPOINT ["node", "dist/main.js"]

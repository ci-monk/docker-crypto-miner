FROM alpine:3.14 as base

# Build stage
FROM base as build

ARG XMRIG_VERSION=v6.15.3
ARG XMRIG_URL="https://github.com/xmrig/xmrig.git"
ARG XMRIG_BUILD_ARGS="-DXMRIG_DEPS=scripts/deps -DBUILD_STATIC=ON"

RUN set -ex && \
      apk add --no-cache git make cmake \
        libstdc++ gcc g++ automake libtool \
        autoconf linux-headers

WORKDIR /tmp/install

RUN set -ex; \
      git clone --single-branch --depth 1 --branch=$XMRIG_VERSION $XMRIG_URL && \
      mkdir ./xmrig/build && \
      sed -i "s/kDefaultDonateLevel = 1;/kDefaultDonateLevel = 0;/g" ./xmrig/src/donate.h && \
      sed -i "s/kMinimumDonateLevel = 1;/kMinimumDonateLevel = 0;/g" ./xmrig/src/donate.h && \
      cd xmrig/scripts && ./build_deps.sh && cd ../build && \
      cmake .. $XMRIG_BUILD_ARGS && \
      make -j$(nproc)

# Final stage
FROM base

RUN set -ex && \
      apk add --no-cache bash screen cpulimit && \
      addgroup --gid 1000 xmrig && \
      adduser --uid 1000 -H -D -G xmrig -h /bin/xmrig xmrig

COPY --from=build --chown=xmrig:xmrig [ "/tmp/install/xmrig/build/xmrig", "/bin" ]

WORKDIR /usr/src/mining

COPY [ "./src", "." ]

RUN set -ex; \
  chown -R xmrig:xmrig /usr/src/mining; \
  chmod +x entrypoint.sh

USER xmrig

CMD [ "bash", "/usr/src/mining/entrypoint.sh" ]

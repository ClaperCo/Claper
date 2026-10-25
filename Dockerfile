ARG BUILDER_IMAGE="hexpm/elixir:1.18.4-erlang-28.0.1-ubuntu-noble-20250619"
ARG RUNNER_IMAGE="ubuntu:24.04"
# Base of the final image. Defaults to the `runtime` stage below; CI passes a
# prebuilt runtime image so the large system packages layer keeps the same
# digest across releases and servers only pull the application layer.
ARG RUNTIME_BASE_IMAGE="runtime"

# System packages needed at runtime (LibreOffice, Ghostscript, ImageMagick, fonts)
FROM ${RUNNER_IMAGE} AS runtime

RUN apt-get update -y \
  && apt-get install -y curl libstdc++6 openssl locales ghostscript imagemagick \
  && apt-get install -y --no-install-recommends libreoffice-impress \
  && apt-get install -y \
    fonts-dejavu \
    fonts-freefont-ttf \
    fonts-liberation \
    fonts-droid-fallback \
    ttf-mscorefonts-installer \
    fontconfig \
  && fc-cache -f \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV MIX_ENV="prod"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    bash \
    ca-certificates \
    nodejs \
    npm \
    openssl \
    libncurses5-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV NODE_VERSION 22.17.0
ENV PRESENTATION_STORAGE_DIR /app/uploads

# custom ERL_FLAGS can be passed for multi-platform builds under QEMU
# to fix qemu segfault, more info: https://github.com/erlang/otp/pull/6340
ARG ERL_FLAGS
ENV ERL_FLAGS=$ERL_FLAGS

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# install npm packages before copying sources so code changes reuse this layer
COPY assets/package.json assets/package-lock.json assets/
RUN cd assets && npm install

COPY priv priv

COPY lib lib

RUN mix compile

COPY assets assets

RUN mix assets.deploy

COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNTIME_BASE_IMAGE}

# Only copy the final release from the build stage
COPY --from=builder --chmod=a+rX /app/_build/prod/rel/claper /app
COPY --from=builder /app/priv/repo/seeds.exs /app/priv/repo/
RUN mkdir /app/uploads && chmod -R 777 /app/uploads

EXPOSE 4000
WORKDIR "/app"
USER root
CMD ["sh", "-c", "/app/bin/claper eval 'Claper.Release.migrate(); Claper.Release.seeds()' && /app/bin/claper start"]

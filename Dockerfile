ARG BUILDER_IMAGE="hexpm/elixir:1.18.4-erlang-28.0.1-ubuntu-noble-20250619"
ARG RUNNER_IMAGE="ubuntu:24.04"

FROM ${BUILDER_IMAGE} as builder

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

# custom ERL_FLAGS are passed for (public) multi-platform builds
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

COPY priv priv

COPY assets assets

COPY lib lib

RUN mix compile

RUN mix assets.deploy

COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y curl libstdc++6 openssl locales ghostscript default-jre libreoffice-java-common \
  && apt-get install -y libreoffice --no-install-recommends && apt-get clean && rm -f /var/lib/apt/lists/*_*
# RUN apk add --no-cache curl libstdc++ openssl ncurses ghostscript openjdk11-jre

# Install LibreOffice & Common Fonts
RUN apt-get update && apt-get install -y \
    libreoffice \
    fonts-dejavu \
    fonts-freefont-ttf \
    fonts-liberation \
    fonts-droid-fallback \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Microsoft Core Fonts
RUN apt-get update && apt-get install -y \
    ttf-mscorefonts-installer \
    fontconfig \
    && fc-cache -f \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV MIX_ENV="prod"


# Only copy the final release from the build stage
COPY --from=builder --chmod=a+rX /app/_build/prod/rel/claper /app
COPY --from=builder /app/priv/repo/seeds.exs /app/priv/repo/
RUN mkdir /app/uploads && chmod -R 777 /app/uploads

EXPOSE 4000
WORKDIR "/app"
USER root
CMD ["sh", "-c", "/app/bin/claper eval Claper.Release.migrate && /app/bin/claper eval Claper.Release.seeds && /app/bin/claper start"]

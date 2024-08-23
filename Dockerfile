# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20210902-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.13.2-erlang-24.2.1-debian-bullseye-20210902-slim
#
ARG BUILDER_IMAGE="hexpm/elixir:1.16.0-erlang-26.2.1-alpine-3.18.4"
ARG RUNNER_IMAGE="alpine:3.18.4"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
# RUN apt-get update -y && apt-get install -y curl build-essential git \
#     && apt-get clean && rm -f /var/lib/apt/lists/*_*
RUN apk add --no-cache -U build-base git curl bash ca-certificates nodejs npm openssl ncurses

ENV NODE_VERSION 16.20.0
ENV PRESENTATION_STORAGE_DIR /app/uploads

# custom ERL_FLAGS are passed for (public) multi-platform builds
# to fix qemu segfault, more info: https://github.com/erlang/otp/pull/6340
ARG ERL_FLAGS
ENV ERL_FLAGS=$ERL_FLAGS

# Install nvm with node and npm
# RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
#     && . $HOME/.nvm/nvm.sh \
#     && nvm install $NODE_VERSION \
#     && nvm alias default $NODE_VERSION \
#     && nvm use default

# ENV NODE_PATH $HOME/.nvm/versions/node/v$NODE_VERSION/lib/node_modules 
# ENV PATH      $HOME/.nvm/versions/node/v$NODE_VERSION/bin:$PATH

# RUN ln -sf $HOME/.nvm/versions/node/v$NODE_VERSION/bin/npm /usr/bin/npm
# RUN ln -sf $HOME/.nvm/versions/node/v$NODE_VERSION/bin/node /usr/bin/node

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

# note: if your project uses a tool like https://purgecss.com/,
# which customizes asset compilation based on what it finds in
# your Elixir templates, you will need to move the asset compilation
# step down so that `lib` is available.
COPY assets assets

# Compile the release
COPY lib lib

RUN mix compile

RUN npm install -g sass
RUN cd assets && npm i && \
    sass --no-source-map --style=compressed css/custom.scss ../priv/static/assets/custom.css

# compile assets
RUN mix assets.deploy.nosass

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

# RUN apt-get update -y && apt-get install -y curl libstdc++6 openssl libncurses5 locales ghostscript default-jre libreoffice-java-common \
#   && apt-get install -y libreoffice --no-install-recommends && apt-get clean && rm -f /var/lib/apt/lists/*_*
RUN apk add --no-cache curl libstdc++6 openssl ncurses ghostscript openjdk11-jre

# Install LibreOffice & Common Fonts
RUN apk --no-cache add bash libreoffice util-linux libreoffice-common \
  font-droid-nonlatin font-droid ttf-dejavu ttf-freefont ttf-liberation && \
  rm -rf /var/cache/apk/*

# Install Microsoft Core Fonts
RUN apk --no-cache add msttcorefonts-installer fontconfig && \
  update-ms-fonts && \
  fc-cache -f && \
  rm -rf /var/cache/apk/*

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

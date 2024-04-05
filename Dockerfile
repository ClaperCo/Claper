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
ARG BUILDER_IMAGE="hexpm/elixir:1.13.2-erlang-24.2.1-debian-bullseye-20210902-slim"
ARG RUNNER_IMAGE="debian:bullseye-20210902-slim"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y curl build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

ENV NODE_VERSION 16.20.0
ENV PRESENTATION_STORAGE_DIR /app/uploads

# Install nvm with node and npm
RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash \
    && . $HOME/.nvm/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH $HOME/.nvm/versions/node/v$NODE_VERSION/lib/node_modules 
ENV PATH      $HOME/.nvm/versions/node/v$NODE_VERSION/bin:$PATH

RUN ln -sf $HOME/.nvm/versions/node/v$NODE_VERSION/bin/npm /usr/bin/npm
RUN ln -sf $HOME/.nvm/versions/node/v$NODE_VERSION/bin/node /usr/bin/node

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

# compile assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y curl libstdc++6 openssl libncurses5 locales ghostscript \
  && apt-get install -y libreoffice --no-install-recommends && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV HOME "/home/nobody"

RUN mkdir /home/nobody && chown nobody /home/nobody

WORKDIR "/app"
RUN mkdir /app/uploads
RUN chown -R nobody /app

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/claper ./

RUN chmod +x /app/bin/*

USER nobody

EXPOSE 4000

CMD ["sh", "-c", "/app/bin/claper eval Claper.Release.migrate && /app/bin/claper start"]

# Appended by flyctl
#ENV ECTO_IPV6 true
#ENV ERL_AFLAGS "-proto_dist inet6_tcp"

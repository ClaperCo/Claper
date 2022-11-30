# Deployment

## Prerequisites

To run Claper on your production environment you need to have:
* Postgres >= 9
* Elixir >= 1.13.2
* Erlang >= 24
* NPM >= 6.14.17
* NodeJS >= 14.19.2
* Ghostscript >= 9.5.0 (for PDF support)
* Libreoffice >= 6.4 (for PPT/PPTX support)


## Steps (without docker)

1. Clone the repo
   ```sh
   git clone https://github.com/ClaperCo/Claper.git
   ```
2. Install dependencies
   ```sh
   mix deps.get --only prod
   ```
3. Migrate your database
   ```sh
   mix ecto.migrate
   ```
4. Compile assets
   ```sh
   MIX_ENV=prod mix compile
   ```
5. Deploy assets
   ```sh
   MIX_ENV=prod mix assets.deploy
   ```
6. Start Phoenix endpoint with
   ```sh
   MIX_ENV=prod mix phx.server
   ```

You can follow the steps from the official Phoenix guide for further details and release management: [Introduction to Deployement](https://hexdocs.pm/phoenix/deployment.html) and [Deploying with Releases](https://hexdocs.pm/phoenix/releases.html).

## Steps (with docker)

You can follow the same steps as in the [installation guide](/installation.html#using-docker) to run Claper with Docker.

## Behind Nginx

This an example of Nginx configuration file to run Claper behind Nginx.

```nginx
server {
   listen 80;
	server_name app.claper.co; # Your own domain

	location / {
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header Host $http_host;
		proxy_pass http://localhost:4000;
		proxy_http_version 1.1;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection "upgrade";
	}
}
```

## Behind Traefik

Here is a docker-compose example to run Claper behind Traefik.

```yaml
version: "3.0"
services:
  db:
    image: postgres:9
    environment:
      POSTGRES_PASSWORD: claper
      POSTGRES_USER: claper
      POSTGRES_DB: claper
  app:
    build: .
    environment:
      DATABASE_URL: postgres://claper:claper@db:5432/claper
      SECRET_KEY_BASE: 0LZiQBLw4WvqPlz4cz8RsHJlxNiSqM9B48y4ChyJ5v1oA0L/TPIqRjQNdPZN3iEG
      MAIL_TRANSPORT: local
      ENDPOINT_HOST: claper.local
      ENDPOINT_PORT: 4000
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.claper.rule=Host(`claper.local`)"
      - "traefik.http.routers.claper.entrypoints=web"
    depends_on:
      - db
      - traefik

  traefik:
    image: traefik
    command:
      #- "--log.level=DEBUG"
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    ports:
      - "80:80"
      - "8080:8080"
```

## Behind Kubernetes

Change the `rel/env.sh.eex` file to uncomment:

```sh
export POD_A_RECORD=$(echo $POD_IP | sed 's/\./-/g')
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=<%= @release.name %>@$(echo $POD_A_RECORD).$(echo $NAMESPACE).pod.cluster.local
```

and comment as follows:

```sh
#export RELEASE_DISTRIBUTION=sname
#export RELEASE_NODE=<%= @release.name %>
```

In Kubernetes, you have to use `libcluster` to make the nodes discoverable. You can use the following configuration in your `config/prod.exs`:

```elixir
config :libcluster,
  topologies: [
    default: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [
        mode: :dns,
        kubernetes_node_basename: "claper",
        kubernetes_selector: "app=claper",
        kubernetes_namespace: "default",
        polling_interval: 10_000
      ]
    ]
  ]
```

### Helm chart

You can check the [Claper Helm chart](https://github.com/ClaperCo/Claper/tree/main/charts/claper) to deploy Claper on Kubernetes.

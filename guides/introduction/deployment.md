# Deployment

## Prerequisites

To run Claper on your production environment you need to have:

- Postgres >= 9
- Elixir >= 1.13.2
- Erlang >= 24
- NPM >= 6.14.17
- NodeJS >= 14.19.2
- Ghostscript >= 9.5.0 (for PDF support)
- Libreoffice >= 6.4 (for PPT/PPTX support)

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
services:
  db:
    image: postgres:15
    ports:
      - 5432:5432
    volumes:
      - "claper-db:/var/lib/postgresql/data"
    healthcheck:
      test:
        - CMD
        - pg_isready
        - "-q"
        - "-d"
        - "claper"
        - "-U"
        - "claper"
      retries: 3
      timeout: 5s
    environment:
      POSTGRES_PASSWORD: claper
      POSTGRES_USER: claper
      POSTGRES_DB: claper
    networks:
      - claper-net

  app:
    build: .
    healthcheck:
      test: curl --fail http://localhost:4000 || exit 1
      retries: 3
      start_period: 20s
      timeout: 5s
    volumes:
      - "claper-uploads:/app/uploads"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.claper.co`)" # change to your domain
      - "traefik.http.routers.app.tls.certresolver=myresolver"
      - "traefik.http.routers.app.entrypoints=web"
      - "traefik.http.services.app.loadbalancer.server.port=4000"
    env_file: .env
    depends_on:
      - db
      - traefik
    networks:
      - claper-net

  traefik:
    image: traefik
    command:
      #- "--log.level=DEBUG"
      #- "--api.dashboard=true"
      - "--accesslog.filepath=/var/log/traefik/access.log"
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:443"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=yourmail@example.com"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    volumes:
      - "../letsencrypt:/letsencrypt"
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "/var/log/traefik:/var/log/traefik/"
    ports:
      - "443:443"
    networks:
      - claper-net

  volumes:
    claper-db:
      driver: local
    claper-uploads:
      driver: local
  networks:
    claper-net:
      driver: bridge
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

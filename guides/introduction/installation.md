# Installation

## Prerequisites

To run Claper on your local environment you need to have:
* Postgres >= 9
* Elixir >= 1.13.2
* Erland >= 24
* NPM >= 6.14.17
* NodeJS >= 14.19.2
* Ghostscript >= 9.5.0 (for PDF support)
* Libreoffice >= 6.4 (for PPT/PPTX support)

You can also use Docker to easily run a Postgres instance:
```sh
  docker run -p 5432:5432 -e POSTGRES_PASSWORD=claper -e POSTGRES_USER=claper -e POSTGRES_DB=claper --name claper-db -d postgres:9
  ```

1. Clone the repo
   ```sh
   git clone https://github.com/ClaperCo/Claper.git
   ```
2. Install dependencies
   ```sh
   mix deps.get
   ```
3. Migrate your database
   ```sh
   mix ecto.migrate
   ```
4. Install JS dependencies
   ```sh
   cd assets && npm i
   ```
5. Allow execution of startup file
   ```sh
   chmod +x ./start.sh
   ```
6. Start Phoenix endpoint with
   ```sh
   ./start.sh
   ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

If you have configured `MAIL` to `local`, you can access to the mailbox at [`localhost:4000/dev/mailbox`](http://localhost:4000/dev/mailbox).


## Using Docker

You can build the app with Docker:
```sh
docker build -t claper .
docker run -p 4000:4000 claper
```

or you can use the official Docker image:

```sh
docker run -p 4000:4000 ghcr.io/claperco/claper:main
```

### ARM architecture

If you are using an ARM architecture (like Apple M1), the original Docker image won't work. You can build the image yourself by replacing the `BUILDER_IMAGE` argument in the `Dockerfile` with `ARG BUILDER_IMAGE="hexpm/elixir-arm64:1.13.2-erlang-24.2.1-debian-bullseye-20210902-slim"` and then build the image as described above.

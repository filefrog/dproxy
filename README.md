dproxy - Docker Proxy
=====================

dproxy is an nginx-based reverse proxy for a single Docker host.
Containers opt in by setting labels; dproxy picks them up automatically
and reconfigures nginx within a second of each container start or stop.
TLS is handled by a single wildcard certificate.

How it works
------------

A single container runs nginx and a Python supervisor. The supervisor
mounts the Docker socket read-only and streams `docker events`. When a
labeled container starts or stops it rewrites the nginx config and sends
nginx a reload signal. nginx is babysit by the supervisor and restarted
automatically if it exits.

Route discovery is event-driven — no polling loop, no cron job, no
external script.

Installation
------------

Pull the image and extract the controller script:

```sh
docker pull filefrog/dproxy
docker run --rm filefrog/dproxy cat /usr/local/bin/dproxy > dproxy
chmod +x dproxy
```

Then obtain a wildcard TLS certificate for your domain (Let's Encrypt
DNS-01 challenge works well) and start dproxy:

```sh
DPROXY_DOMAIN=example.com \
  ./dproxy start
```

`dproxy start` looks for `dproxy.cert` and `dproxy.key` in the current
directory by default (override with `DPROXY_CERT` / `DPROXY_KEY`).

Routing
-------

To route traffic to a container, set two labels on it:

| Label | Value |
|-------|-------|
| `com.huntprod.docker.route` | hostname to match (e.g. `myapp.example.com`) |
| `com.huntprod.docker.port`  | host loopback port the container listens on |

With `DPROXY_DOMAIN=example.com` set, short names expand automatically:

```sh
docker run \
  --label com.huntprod.docker.route=myapp \
  --label com.huntprod.docker.port=3000 \
  -p 127.0.0.1:3000:3000 \
  myimage
```

…routes `https://myapp.example.com` to `127.0.0.1:3000`.

Additional labels:

| Label | Effect |
|-------|--------|
| `com.huntprod.docker.host` | upstream host (default `127.0.0.1`) |
| `com.huntprod.docker.header.X-Foo` | add response header `X-Foo` |

Automatic certificates (ACME / Let's Encrypt)
---------------------------------------------

dproxy can obtain and renew a wildcard certificate automatically using
[acme.sh](https://acme.sh) and a DNS-01 challenge. This requires no
port 80 access and works behind firewalls.

**Setup:**

1. Create `acme.env` in the directory where you run `./dproxy start`
   and put your DNS provider credentials in it:

   ```sh
   # Cloudflare example
   CF_Token=your-api-token
   CF_Account_ID=your-account-id
   ```

   `acme.env` is gitignored. See the
   [acme.sh DNS API docs](https://github.com/acmesh-official/acme.sh/wiki/dnsapi)
   for the full list of providers and their required variables.

2. Start with ACME enabled:

   ```sh
   DPROXY_ACME_DOMAIN=example.com \
   DPROXY_ACME_PROVIDER=cf \
   DPROXY_ACME_EMAIL=you@example.com \
     ./dproxy start
   ```

   On first run the supervisor obtains `*.example.com` from Let's Encrypt
   before starting nginx. Certificate state is stored in `./acme/`
   (gitignored, persists across container restarts). Renewal runs every
   12 hours; nginx is reloaded automatically when a cert is renewed.

   `DPROXY_CERT` / `DPROXY_KEY` are not needed in ACME mode.

Environment variables
---------------------

Set these before calling `./dproxy start`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DPROXY_NAME` | `dproxy` | Container name; set to run multiple instances |
| `DPROXY_HTTP_PORT` | `80` | HTTP listen port |
| `DPROXY_HTTPS_PORT` | `443` | HTTPS listen port |
| `DPROXY_NETWORK` | `host` | `host` or `bridge` |
| `DPROXY_BACKEND_HOST` | `127.0.0.1` / `host.docker.internal` | Default upstream host |
| `DPROXY_CERT` | `./dproxy.cert` | Path to TLS certificate (manual mode) |
| `DPROXY_KEY` | `./dproxy.key` | Path to TLS private key (manual mode) |
| `DPROXY_ACME_DOMAIN` | _(unset)_ | Enable ACME; issues `*.DOMAIN` automatically |
| `DPROXY_ACME_PROVIDER` | _(unset)_ | DNS provider slug (e.g. `cf`, `aws`, `dgon`) |
| `DPROXY_ACME_EMAIL` | _(unset)_ | Account email for expiry notifications |
| `DPROXY_ACME_CA` | `letsencrypt` | ACME certificate authority |
| `DPROXY_DOMAIN` | _(unset)_ | Root domain for short-name label expansion |
| `DPROXY_PREFIX` | `com.huntprod.docker` | Docker label prefix |
| `DPROXY_IMAGE` | `filefrog/dproxy` | Image to use |

Running a test instance
-----------------------

To run a second dproxy alongside production — different port, different
label prefix, different domain:

```sh
DPROXY_NAME=dproxy-test \
DPROXY_HTTP_PORT=8080 \
DPROXY_HTTPS_PORT=8443 \
DPROXY_PREFIX=test.docker \
DPROXY_DOMAIN=test.example.com \
DPROXY_CERT=./test.cert \
DPROXY_KEY=./test.key \
  ./dproxy start
```

Containers opt in to the test instance with `test.docker.route` /
`test.docker.port` labels and are completely invisible to the production
proxy.

The `./test` script in this repo does exactly this with a self-signed
wildcard cert generated on first run.

Network modes
-------------

**Host networking (default):** dproxy shares the host network stack.
Backend containers expose ports with `-p 127.0.0.1:PORT:PORT`; nginx
reaches them at `127.0.0.1:PORT`. Works on any Linux Docker host.

**Bridge networking:** set `DPROXY_NETWORK=bridge`. dproxy gets `-p`
mappings and `--add-host=host.docker.internal:host-gateway`. Backend
containers must bind to `0.0.0.0` (not loopback) so that
`host.docker.internal:PORT` is reachable. Useful on Docker Desktop.

No-route page
-------------

Requests for unconfigured hostnames get a branded HTML page instead of
a TLS error. To replace it with a custom page:

```sh
-v /path/to/custom.html:/etc/dproxy/404.html:ro
```

dproxy commands
---------------

```
./dproxy start    - Start the container
./dproxy stop     - Stop and remove the container
./dproxy restart  - Stop then start
./dproxy status   - Show routes, cert info, config, and event log
./dproxy check    - Force an immediate reconfigure
./dproxy dump     - Raw route JSON from running containers
./dproxy reload   - Send nginx a reload signal
./dproxy nginx    - Run nginx -T (full config dump)
./dproxy update   - Pull latest image and restart
./dproxy help     - Full usage with all env vars
```

The status file is also readable directly:

```sh
docker exec dproxy cat /var/run/dproxy/status
```

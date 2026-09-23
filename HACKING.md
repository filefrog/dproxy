Hacking on dproxy
=================

Building the image
------------------

```sh
make build
```

The Makefile target builds the image and runs `nginx -v` inside it to
confirm the binary is present.

Key scripts inside the image
-----------------------------

`/bin/dproxy-supervisor` — the main process (PID 1 equivalent). Starts
nginx, watches `docker events`, and debounces reconfigure calls. Both
nginx and the event watcher are restarted automatically on failure.
Also owns ACME certificate issuance and renewal.

`/bin/dump-docker` — queries the Docker socket for containers carrying
the route label prefix and emits newline-delimited JSON, one object per
container.

`/bin/reconfigure-nginx` — reads that JSON on stdin, writes
`/etc/nginx/conf.d/routes.conf`, and sends nginx a reload signal if the
file changed (SHA1 comparison, so it's safe to call in a tight loop).

`/bin/reload-nginx` — scans `/proc/*/cmdline` for the nginx master
process and sends it SIGHUP. Runs inside the container's own PID
namespace so the scan is always correct.

`/bin/entrypoint` — pre-flight checks (docker socket, TLS certs, port
availability, DPROXY_DOMAIN hint), then `exec`s into the supervisor.

`/usr/local/bin/dproxy` — the host-side controller script, also baked
into the image so it can be installed with:
`docker run --rm filefrog/dproxy cat /usr/local/bin/dproxy > dproxy`

Testing routing locally
-----------------------

`./test` spins up a second dproxy instance (`dproxy-test`) on ports
8080/8443 with a self-signed wildcard cert for `*.test.example.com`,
generated in `./tmp/` on first run. Point a labeled container at the
`test.docker` prefix to exercise routing without touching the production
instance.

proxy.defaults — the copy-on-start pattern
-------------------------------------------

nginx includes `/etc/nginx/proxy.defaults` inside every proxied
`location /` block. The file controls upstream connection settings,
header forwarding, body size limits, and anything else that should apply
to all backends uniformly.

There are two copies of this file:

| Path | Role |
|------|------|
| `/opt/proxy.defaults` (inside image) | Factory defaults — never changes at runtime |
| `./proxy.defaults` (host working directory) | Operator's editable copy — bind-mounted over the image copy at runtime |

On the first `./dproxy start`, the controller runs:

```sh
docker run --rm $image cat /opt/proxy.defaults > ./proxy.defaults
```

and then mounts the result:

```sh
-v "$PWD/proxy.defaults:/etc/nginx/proxy.defaults:ro"
```

Subsequent starts reuse the existing `./proxy.defaults`, so operator
edits survive container restarts and image updates. Pulling a new image
will update `/opt/proxy.defaults` inside the image but will **not**
touch the host-side copy.

To reset to factory defaults and pick up any changes introduced by a new
image release:

```sh
rm ./proxy.defaults && ./dproxy restart
```

The `/opt/proxy.defaults` file ships with common customizations
commented out (timeouts, streaming, security headers, real-IP
passthrough). Read it for a guided tour of what's available.

Certificates
------------

dproxy expects a single wildcard TLS certificate covering all routed
hostnames.

**ACME (recommended):** set `DPROXY_ACME_DOMAIN`, `DPROXY_ACME_PROVIDER`,
and put provider credentials in `acme.env`. The supervisor obtains and
renews the cert automatically. State persists in `./acme/`.

**Manual:** place cert and key at `./dproxy.cert` and `./dproxy.key`, or
point `DPROXY_CERT` / `DPROXY_KEY` at arbitrary paths.

**Testing:** `./test` generates a self-signed wildcard cert in `./tmp/`
on first run.

The cert and key paths inside the container are always:

```
/etc/nginx/tls/wildcard.crt
/etc/nginx/tls/wildcard.key
```

(In ACME mode these are symlinked into `/var/lib/acme/live/`.)

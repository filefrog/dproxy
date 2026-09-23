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

`/bin/dump-docker` — queries the Docker socket for containers carrying
the route label prefix and emits newline-delimited JSON.

`/bin/reconfigure-nginx` — reads that JSON on stdin, writes
`/etc/nginx/conf.d/routes.conf`, and sends nginx a reload signal if the
file changed (SHA1 comparison, so it's safe to call in a tight loop).

`/bin/reload-nginx` — scans `/proc/*/cmdline` for the nginx master
process and sends it SIGHUP. Dumb but reliable inside a container.

`/bin/entrypoint` — pre-flight checks (docker socket, TLS certs, port
availability, DPROXY_DOMAIN hint), then `exec`s into the supervisor.

Testing routing locally
-----------------------

`./test` spins up a second dproxy instance (`dproxy-test`) on ports
8080/8443 with a self-signed wildcard cert for `*.test.example.com`,
generated in `./tmp/` on first run.

`./util/auxiliary` runs a stock nginx container with the right labels to
create a test route pointing at it.

`./util/selfsign` generates a self-signed wildcard cert (edit the domain
first). Output is a key + cert on stdout.

Certificates
------------

dproxy expects a single wildcard TLS certificate covering all routed
hostnames. For production use Let's Encrypt with the DNS-01 challenge.
For local testing, `./util/selfsign` or the auto-generation in `./test`.

The cert and key paths inside the container are always:

```
/etc/nginx/tls/wildcard.crt
/etc/nginx/tls/wildcard.key
```

Override the host-side source paths with `DPROXY_CERT` / `DPROXY_KEY`.

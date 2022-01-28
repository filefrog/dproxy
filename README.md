dproxy - A ~Dumb~ Docker Proxy
==============================

This is dproxy, a ridiculously stupid nginx-based proxy for a
single Docker host to use labels to set up front-end, TLS routes.
It is designed to be used with Let's Encrypt using something like
the DNS-01 challenge (to get a wildcard certificate).

It has two interesting parts:

`/bin/dump-docker` is meant to be run outside of the dproxy
container, where it is safe to access the Docker socket (by
running `docker` commands).  Its output gets piped into...

`/bin/reconfigure-nginx`, which is meant to be run from _inside_
the dproxy container.  It reads the JSON produced by
`dump-docker`, writes a new configuration for nginx, and then
either reloads nginx to pick up the changes, or scraps it as a
no-op.

Reloading nginx is done via the `bin/reload-nginx` program, which
just trawls through `/proc/*/cmdline` looking for the nginx:
master process string.  It's dumb, but it works when nginx itself
is containerized (and therefore /proc/$pid is fairly small).

It is safe to run this process from the Docker host on a fairly
agressive schedule.  Doing so will exercise the Docker daemon
itself, but the built-in safeguards of dproxy will prevent wild
thrashing of the nginx process–unless you are wildly spinning up
new (labeled) containers.

That brings us to the routing itself.  To get dproxy to start
routing traffic to a container, add the following labels:

*com.huntprod.docker.route* - the Host: header you want to route
to this container, and

*com.huntprod.docker.port* - the port, forwarded on loopback, that
will respond to the host-bound nginx process.

Here's a sketch of an operational deployment of dproxy:

```
#!/bin/sh
set -eu

docker run \
  --restart=always \
  --name dproxy \
  --network host \
  huntprod/dproxy &

docker run --rm huntprod/dproxy \
  cat /usr/bin/dump-docker \      # from inside the image
    > /usr/bin/dump-docker        #    ... to the outside!
chmod 0755 /usr/bin/dump-docker

# assuming jq is already installed...

while true; do
  sleep 1
  dump-docker | docker exec -i dproxy reconfigure-nginx
done
```

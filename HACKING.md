Hacking on dproxy
=================

These are my notes from the nights I implemented dproxy.
Hopefully we will find them useful one day.

It's a bad idea to run this from outside of a container; the
`reconfigure-nginx` script has a nasty habit of targeting the
wrong nginx process if run on a busy Docker host.

If you need a wildcard certificate, feel free to modify the
`utils/selfsign` script to your liking.  It generates self-signed
things, but that's fine for dev / testing of routing.

There is also a utility called `utils/auxiliary` that runs a stock
nginx container, on 8033, and sets the appropriate labels for
dproxy to route to it.  That is super useful for spinning up lots
of test routes.

Finally, `utils/run` instantiates the dproxy container, mapping
cert.pem and key.pem into the default locations for a wildcard TLS
certificate.  Again, use `./utils/selfsign` to generate the key
and its certificate to populate those.

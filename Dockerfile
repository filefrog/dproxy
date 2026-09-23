FROM docker:cli AS docker-cli

FROM nginx
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
RUN apt-get update \
 && apt-get install -yy python3 jq curl \
 && curl -fsSL https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh \
    -o /usr/local/bin/acme.sh \
 && chmod +x /usr/local/bin/acme.sh \
 && apt-get clean
COPY bin /bin
COPY etc /etc
COPY opt /opt
COPY dproxy /usr/local/bin/dproxy
ENTRYPOINT ["/bin/entrypoint"]

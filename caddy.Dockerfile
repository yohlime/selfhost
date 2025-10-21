FROM docker.io/caddy:2.10-builder AS builder

RUN xcaddy build \
  # --with github.com/caddy-dns/porkbun \
  --with github.com/caddy-dns/cloudflare \
  --with github.com/mholt/caddy-webdav

FROM caddy:2.10

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

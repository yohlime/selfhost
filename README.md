# Home Server

Personal self-hosted stack. Everything runs as Docker Compose services behind
[Traefik](https://traefik.io/) and is reached over a private
[Tailscale](https://tailscale.com/) network.

## Architecture

- **Compose layout.** Root `docker-compose.yml` pulls in every `*.yml` via the
  `include:` directive (requires Docker Compose v2.20+) and defines the shared
  `traefik` and `postgres` services. Each file owns one app and its `*.yml`
  siblings own supporting services (databases, caches, workers).
- **Reverse proxy.** Traefik v3.6 terminates TLS on `websecure` (443), redirects
  HTTP to HTTPS, and discovers routes from container labels. Certificates come
  from Let's Encrypt via the Cloudflare DNS-01 challenge. The dashboard is at
  `traefik.${DOMAIN}`.
- **Networking.** Every service joins the **external** `yohnet` network; it must
  exist on the host or `docker compose up` fails.
- **Remote access.** Cloudflare A/AAAA records for `home.<zone>` and
  `*.home.<zone>` point at this host's Tailscale IPs. `newt` is the
  [Pangolin](https://pangolin.net/) tunnel client for public/external access.
- **Auth.** [Pocket ID](https://pocket-id.org/) is the OIDC provider and
  [Tinyauth](https://github.com/steveiliop56/tinyauth) serves as the forward-auth
  gate for protected apps.

## Services

URLs follow the `Host(<sub>.${DOMAIN})` label in each file.

| Service | URL | Compose file | Notes |
| --- | --- | --- | --- |
| Traefik | `traefik.${DOMAIN}` | `docker-compose.yml` | proxy + dashboard |
| Pi-hole | `pihole.${DOMAIN}` | `pihole.yml` | DNS (port 53) + ad-blocking (Unbound) |
| Pocket ID | `pocketid.${DOMAIN}` | `auth.yml` | OIDC provider |
| Tinyauth | `tinyauth.${DOMAIN}` | `auth.yml` | forward-auth |
| Vikunja | `vikunja.${DOMAIN}` | `vikunja.yml` | task management |
| ntfy | `notify.${DOMAIN}` | `ntfy.yml` | push notifications |
| SFTPGo | `sftpgo.${DOMAIN}`, `webdav.${DOMAIN}` | `sftpgo.yml` | SFTP / WebDAV |
| Syncthing | `sync.${DOMAIN}` | `syncthing.yml` | file sync |
| Actual Budget | `budget.${DOMAIN}` | `actualbudget.yml` | budgeting |
| Ghostfolio | `folio.${DOMAIN}` | `ghostfolio.yml` | investment tracking |
| CouchDB | `couchdb.${DOMAIN}` | `couchdb.yml` | database |
| Immich | `photos.${DOMAIN}` | `immich.yml` | photo library (VAAPI transcode) |
| Vaultwarden | `vw.${DOMAIN}` | `vaultwarden.yml` | password manager |
| Karakeep | `karakeep.${DOMAIN}` | `karakeep.yml` | bookmarks + search |
| Miniflux | `miniflux.${DOMAIN}` | `miniflux.yml` | RSS reader |
| Matrix (Synapse) | `matrix.${DOMAIN}` | `matrix.yml` | homeserver + mautrix bridges |
| LiteLLM | `litellm.${DOMAIN}` | `litellm.yml` | LLM gateway |
| Open WebUI | `chatai.${DOMAIN}` | `open-webui.yml` | LLM chat UI |
| SnapOtter | `snapotter.${DOMAIN}` | `vert.yml` | image tools |
| BentoPDF | `bentopdf.${DOMAIN}` | `vert.yml` | PDF toolkit |
| Dawarich | `dawarich.${DOMAIN}` | `dawarich.yml` | location history |
| Yamtrack | `yamtrack.${DOMAIN}` | `yamtrack.yml` | media tracker |
| Remark42 | `remark42.${DOMAIN}` | `blog.yml` | comment engine |
| Uptime Kuma | `status.${DOMAIN}` | `monitor.yml` | uptime monitoring |
| Prometheus | `prometheus.${DOMAIN}` | `monitor.yml` | metrics |
| Grafana | `grafana.${DOMAIN}` | `monitor.yml` | dashboards |
| Newt | — | `newt.yml` | Pangolin tunnel client |

## Getting started

Prerequisites: Docker Engine with Compose v2.20+, the external network, and the
env files described below.

```sh
docker network create yohnet   # one-time, on the host
docker compose pull
docker compose up -d
docker compose logs -f <service>
docker compose down            # stop everything
```

Deployment is manual on the host — there is no CI or build step.

## Configuration & secrets

No `.env.example` is committed; `.env` files are untracked.

- **Root `.env`** supplies shared values: `DOMAIN`, `POSTGRES_USER`,
  `POSTGRES_PASSWORD`, `CF_API_EMAIL` + Cloudflare token, and provider API keys.
- **Per-service `./<service>/.env`** files are merged in alongside the root
  `.env` via `env_file` (e.g. `pocketid/`, `immich/`, `synapse/`, `litellm/`).
- **`litellm/config.yaml`** defines the model list (`store_model_in_db: true`).
- **`traefik/traefik.yml`** is the static Traefik config; dynamic config,
  `acme.json`, and logs live under `traefik/` but are untracked.

## Adding a service

1. Create `<name>.yml` and add it to the `include:` list in
   `docker-compose.yml`.
2. Attach it to the `yohnet` network.
3. Add the standard Traefik labels:

   ```yaml
   labels:
     - traefik.enable=true
     - traefik.http.routers.<name>.rule=Host(`<sub>.${DOMAIN}`)
     - traefik.http.routers.<name>.entrypoints=websecure
     - traefik.http.routers.<name>.tls.certresolver=letsencrypt
     - traefik.http.services.<name>.loadbalancer.server.port=<port>
   ```

   The provider sets `exposedByDefault: false`, so a `loadbalancer.server.port`
   label is required for Traefik to route to the container.

> **.gitignore caveat:** the repo ignores `*` and tracks only `README.md`,
> `*.yml`, `litellm/config.yaml`, and `traefik/traefik.yml`. Any new non-`.yml`
> file (including `.yaml` or shell scripts) stays untracked until you add an
> explicit `!path` rule.

## DNS

`scripts/update_cf_record.sh` reads `.env` (`CF_API_TOKEN`, `ZONE_NAME`,
`ZONE_ID`), detects the host's Tailscale IPv4/IPv6 addresses, and upserts
Cloudflare `A`/`AAAA` records for `home.<zone>` and `*.home.<zone>`.

## Hardware acceleration

`immich.yml` uses `extends` to pull in `immich.hwaccel.transcoding.yml`. It is
currently set to `vaapi`; change the `service:` key to `nvenc`, `quicksync`,
`rkmpp`, or `cpu` for other GPUs. See `immich.hwaccel.ml.yml` for accelerated
machine-learning inference.

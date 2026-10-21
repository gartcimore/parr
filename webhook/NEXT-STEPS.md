# parr-webhook — next steps

Follow-up work deferred until the new Traefik hostname/TLS configuration has
been deployed and verified on the host. Do these in order.

## 1. Verify the new Traefik config (prerequisite)

The `feat/parr-webhook` branch also introduces hostname-based HTTPS routing for
the *arr services (radarr/sonarr/bazarr/jellyfin/seerr) using the wildcard
`*.${DOMAIN}` certificate. Confirm this works before touching the webhook route,
since the webhook HTTPS work depends on the same cert plumbing.

Checklist:

- [ ] `.env` has `DOMAIN` and `CERTS_DIR` set, and `CERTS_DIR` contains
      `fullchain.pem` + `key.pem` from the external acme/Let's Encrypt container.
- [ ] `docker compose up -d traefik` starts cleanly (check `docker logs traefik`
      for file-provider and cert-load errors).
- [ ] `https://radarr.${DOMAIN}` (and the other services) serves the wildcard
      cert with no name mismatch, and plain HTTP redirects to HTTPS.
- [ ] The path-based routes (`http://${HOSTNAME}/radarr`, `/jellyfin`, etc.)
      still work for backward compatibility.

## 2. Put the webhook behind HTTPS (the actual deferred task)

**Problem:** the webhook route is currently HTTP-only. See
`traefik/dynamic/webhook.yml` — the `parr-webhook` router is on the `web`
(port 80) entrypoint with no `tls`. That means the `X-Auth-Token` secret, which
can **reboot or power off the host**, is sent in cleartext. This is the weakest
link in the design and must be fixed once TLS is confirmed working.

**Chosen approach (option B — consistent with the *arr services):** give the
webhook its own hostname route on `websecure` so the wildcard cert matches the
name cleanly, plus an HTTP→HTTPS redirect. A path-only route on `websecure`
would serve the default cert but trip a cert-name mismatch unless accessed via a
`*.${DOMAIN}` host, so a dedicated hostname is cleaner.

Edit **both** `traefik/dynamic/webhook.yml` and
`traefik/dynamic/webhook.yml.template` (install.sh renders the latter) to
something like:

```yaml
http:
  routers:
    parr-webhook:
      rule: "Host(`webhook.${DOMAIN}`) && PathPrefix(`/webhook`)"
      entryPoints:
        - websecure
      tls: true
      service: parr-webhook
    parr-webhook-http:
      rule: "Host(`webhook.${DOMAIN}`) && PathPrefix(`/webhook`)"
      entryPoints:
        - web
      middlewares:
        - redirect-https@file
      service: parr-webhook

  services:
    parr-webhook:
      loadBalancer:
        servers:
          # rendered copy uses the literal port; template keeps __WEBHOOK_PORT__
          - url: "http://host.docker.internal:__WEBHOOK_PORT__"
```

Note: Traefik's file provider does **not** expand `${DOMAIN}` on its own. Either
hardcode the final hostname in the rendered `webhook.yml`, or have `install.sh`
template `__DOMAIN__` the same way it already templates `__WEBHOOK_PORT__`
(preferred — keeps it in sync with `.env`).

Then update:

- [ ] `webhook/install.sh` — template `__DOMAIN__` into the rendered
      `webhook.yml` (read `DOMAIN` from `.env` alongside `WEBHOOK_PORT`).
- [ ] `webhook/README.md` — change the "Test through Traefik" and Homarr
      examples to `https://webhook.${DOMAIN}/webhook/<action>`.
- [ ] `.env.sample` — note that the webhook is reachable at
      `webhook.${DOMAIN}` once TLS is enabled.
- [ ] Local DNS — add a `webhook.${DOMAIN}` record pointing at the host
      (or rely on the wildcard if one exists).

## 3. Re-validate end to end

- [ ] `curl -sS -X POST -H "X-Auth-Token: $TOKEN" https://webhook.${DOMAIN}/webhook/restart-docker`
      returns the expected response message over HTTPS.
- [ ] Plain HTTP to the same URL redirects to HTTPS (token never sent in clear).
- [ ] Homarr tile updated to the HTTPS URL and triggers the action.
- [ ] Firewall confirms `WEBHOOK_PORT` on the host is not reachable from the
      general LAN — access should come through Traefik only.

## 4. Optional hardening (stretch)

- [ ] Consider dropping the `docker compose restart` sudo grant in favour of
      adding `parr-webhook` to the `docker` group (same effect, no sudo rule).
- [ ] Add a simple rate limit / fail2ban on the webhook route, since the token
      is the only auth factor.

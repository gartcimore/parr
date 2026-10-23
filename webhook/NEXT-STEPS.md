# parr-webhook — status & remaining work

## Done (deployed and verified on heimdall)

- **Hostname/TLS routing for the *arr services** — `radarr/sonarr/bazarr/
  jellyfin/seerr` (and later lidarr/prowlarr/homarr) serve HTTPS at
  `https://<service>.${DOMAIN}` with the wildcard `*.${DOMAIN}` Let's Encrypt
  cert; plain HTTP redirects to HTTPS. Path routes still work for back-compat.
- **Webhook behind HTTPS** — the webhook is served at
  `https://webhook.${DOMAIN}/webhook/<action>` on the `websecure` entrypoint
  with an HTTP→HTTPS redirect, so the `X-Auth-Token` is never sent in cleartext.
  `install.sh` templates `__DOMAIN__` and `__WEBHOOK_PORT__` into `webhook.yml`.
  DNS record `webhook.${DOMAIN}` → heimdall exists in UniFi Local DNS.
- **`restart-docker` action corrected** — it restarts the Docker **daemon**
  (`systemctl restart docker`), which Homarr can't do on its own, rather than a
  compose project. Action scripts use `setsid` so the delayed command survives
  the webhook hook's process-group teardown (an earlier version logged success
  but never executed).
- **Homarr tile** — a Custom Widget ("Restart parr stack") on the Becquerel
  board POSTs to the HTTPS webhook with the token stored as an encrypted Homarr
  secret (entered via the Homarr UI, never in the definition).

## Remaining / optional

- [ ] **reboot / shutdown Homarr tiles** — clone the restart-docker widget for
      the other two actions. The HTTP source + token secret already exist, so no
      new credential entry is needed; just add two more `action` requests/tiles.
      Both scripts are already fixed (setsid), so they will fire reliably.
- [ ] **qbittorrent HTTPS route** — deferred. qbit runs behind gluetun's netns
      and its WebUI does host-header validation, so exposing it at
      `qbittorrent.kornoglab.fr` needs `traefik.enable=true` on gluetun plus a
      qbit host-header/whitelist change. DNS already resolves (returns 404 until
      a router exists).
- [ ] **Firewall `WEBHOOK_PORT` to the docker bridge only** — the daemon binds
      `0.0.0.0:9000`, so it is reachable directly on the LAN, bypassing Traefik.
      Access should come through `https://webhook.${DOMAIN}` only.
- [ ] **Longer-term auth** — for any WAN exposure, replace the single bearer
      token with forward-auth/SSO (Authelia/Authentik) or a tunnel
      (Cloudflare/Tailscale). The current token is LAN-appropriate only.

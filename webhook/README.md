# parr-webhook

Host-side webhook daemon that exposes a few host-level actions (reboot, shutdown,
restart the parr docker stack) so a Homarr tile can trigger them with one click.

Runs on the host, not in a container. A container cannot reboot its host without
becoming effectively root on the box, which is worse than this.

## How it works

```
Browser ──> Homarr ──> Traefik (/webhook/*) ──> host:9000 (adnanh/webhook) ──> action script
```

The daemon ([adnanh/webhook](https://github.com/adnanh/webhook)) runs as a
non-privileged `parr-webhook` user on the host. Each action is a tiny shell
script; the user is granted `NOPASSWD` sudo only for the exact commands those
scripts need.

Auth is a single bearer token (`WEBHOOK_TOKEN` in `.env`), checked against the
`X-Auth-Token` header. Token mismatch = 200 with no execution. Keep the token
private and the daemon on the LAN.

## Actions shipped by default

| ID              | What it does                                          | Sudo command(s)                                      |
| --------------- | ------------------------------------------------------ | ----------------------------------------------------- |
| `reboot`        | Reboots the host (3s delay so the HTTP reply lands)    | `/sbin/reboot`                                        |
| `shutdown`      | Powers off the host (3s delay)                         | `/sbin/poweroff`                                      |
| `restart-docker`| Restarts the parr docker compose stack                 | `docker compose -f <parr>/docker-compose.yml restart` |

## Install

From the parr project root, after `setup.sh` has generated `.env` (which now
includes `WEBHOOK_TOKEN`):

```bash
sudo ./webhook/install.sh
```

The installer is idempotent. It will:

1. Install the `webhook` binary via `apt` if not present
2. Create the `parr-webhook` system user
3. Render `/etc/parr-webhook/hooks.json` from `hooks.json.template` with your token
4. Copy action scripts to `/usr/local/bin/parr-webhook-*`
5. Drop a `visudo`-validated sudoers file at `/etc/sudoers.d/parr-webhook`
6. Install and enable the `parr-webhook.service` systemd unit

## Test from the host

```bash
TOKEN=$(grep ^WEBHOOK_TOKEN= .env | cut -d= -f2)
curl -X POST -H "X-Auth-Token: $TOKEN" http://localhost:9000/hooks/reboot
```

## Test through Traefik

Once Traefik is up with the new dynamic config and `extra_hosts` entry:

```bash
curl -X POST -H "X-Auth-Token: $TOKEN" http://${HOSTNAME}/webhook/reboot
```

## Wire it into Homarr

Edit the board, add a **Custom Widget** (or app tile that POSTs):

- URL: `http://${HOSTNAME}/webhook/reboot`
- Method: `POST`
- Headers: `X-Auth-Token: <your WEBHOOK_TOKEN>`

Repeat for `shutdown` and `restart-docker` if you want tiles for those.

## Adding a new action

1. Drop a script at `webhook/scripts/<action>.sh`
2. Add an entry to `webhook/hooks.json.template` mirroring the existing ones
3. If the script needs privileged commands, add them to `webhook/sudoers/parr-webhook`
4. Re-run `sudo ./webhook/install.sh`

## Uninstall

```bash
sudo ./webhook/uninstall.sh
```

Removes the service, user, sudoers drop-in, scripts, and config. Does not touch
your Traefik dynamic config or `.env`.

## Security notes

- The token is the only thing between a network scan and a reboot. Don't expose
  port 9000 publicly. The Traefik route is fine on the LAN.
- `/etc/parr-webhook/hooks.json` is mode 0640, owned by `root:parr-webhook`.
- The `parr-webhook` user has nologin shell and no home directory.
- Sudoers grants exactly three commands, nothing else.
- A misclick reboots your stack. Label your Homarr tiles clearly.

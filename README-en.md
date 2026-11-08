# singbox-tools

English overview of the project. The main documentation is in Chinese, see [README.md](README.md).

## What it is

`singbox-tools` is a collection of auditable, self-contained bash installers for
self-hosted network tooling built on [sing-box](https://github.com/SagerNet/sing-box),
MTProxy and the Linux kernel. Everything is a plain shell script downloaded from
a pinned URL and run on **your own** server: no account, no control panel, no
service operated by the project.

| Script | Purpose |
| --- | --- |
| `sb.sh` | One-shot installer/manager for sing-box nodes: Hysteria2, VLESS-Reality, TUIC, AnyTLS, VMess/Trojan/VLESS over WebSocket+TLS (optionally behind Argo tunnels or a CDN), plus Socks5 with IP allow-list, nginx subscription output, renew/upgrade/delete/list actions |
| `mtp-new.sh` | MTProxy installer (Go build / Telemt), quota, expiry, rate limit, multi-user management |
| `mtp-old.sh` | Previous MTProxy installer, kept for existing deployments |
| `socks5.sh` / `socks5-noauth.sh` | Standalone sing-box Socks5 installers |
| `bbr.sh` | Kernel/BBR + queueing-discipline tuning helper |
| `fs-onlyforme.sh` | Personal maintenance/utility script |
| `init.js` | Dependency and release synchronisation helpers used by the CI workflows |

Around the scripts, two companion projects are maintained by the same author:

- [singbox-tools-interface](https://github.com/jyucoeng/singbox-tools-interface) —
  an online command generator (single static `index.html`) so users do not have
  to memorise the installer parameters.
- [sub_merge](https://github.com/jyucoeng/sub_merge) — a node-subscription
  aggregator for people running several machines.

## How it is used

```bash
curl -fsSL https://raw.githubusercontent.com/jyucoeng/singbox-tools/main/sb.sh -o sb.sh
bash sb.sh
```

Every script is `bash -n` clean, prints its own version, and can be re-run to
upgrade or uninstall. Releases are tagged and the GitHub Actions workflows only
sync upstream dependency versions (`sync-deps.yml`, `sync-singbox.yml`).

## What a hosted server would be used for

The project today documents everything in very long Markdown files and hosts the
command generator on a third-party static host. A server would let the project
stop depending on that and keep three things online for its users:

1. **Documentation site** — `README-sb.md` alone is ~150 KB of options and
   examples, currently only readable inside the GitHub file viewer. A server
   renders it as a real, searchable documentation site versioned by script
   version.
2. **Online demo** — the command generator, plus a server-side preview endpoint
   that takes the selected parameters and returns the resulting sing-box
   configuration JSON, so a user can verify a command before running it on their
   own machine. This is pure computation; it needs a small HTTP service, which a
   static host cannot provide.
3. **Release/changelog feed** — a machine-readable endpoint with the current
   script version and its changes, so installed scripts can report whether an
   update exists.

No proxy node, no subscription service, no relay and no traffic is served from
the hosted server. It serves static pages and one read-only computation
endpoint. The project has no commercial offer: no paid tier, no support
contract, no advertising.

## License

MIT — see [LICENSE](LICENSE). The scripts are the author's own work; the
software they install (sing-box, MTProxy, nginx, …) is downloaded at runtime and
stays under its own license.

## Maintainer

LittleDoraemon ([@jyucoeng](https://github.com/jyucoeng)) — sole maintainer and
point of contact.

## Disclaimers

The scripts install software on servers the user controls. Users are responsible
for complying with the laws and the terms of service that apply to them. The
project ships no hosted service and holds no user data.

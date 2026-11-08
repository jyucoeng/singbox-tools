# singbox-tools

**English** | [中文](README-zh.md)

A collection of self-contained bash installers for self-hosted network tooling
built on [sing-box](https://github.com/SagerNet/sing-box), MTProxy and the Linux
kernel. Every script is downloaded from a pinned URL and run on **your own**
server: no account, no control panel, no service operated by the project.

> The per-script documentation below is written in Chinese. This page covers what
> the project is, what each script does and how to run it.

## Scripts

| Script | Purpose | Documentation |
| --- | --- | --- |
| `sb.sh` | One-shot installer/manager for sing-box nodes: Hysteria2, VLESS-Reality, TUIC, AnyTLS, VMess/Trojan/VLESS over WebSocket+TLS (optionally behind an Argo tunnel or a CDN), plus Socks5 with an IP allow-list, nginx subscription output, and `rep`/`ins`/`del`/`delall`/`list`/`ups` actions | [README-sb.md](README-sb.md) |
| `mtp-new.sh` | MTProxy installer (interactive / Go build / Telemt), with quota, expiry, rate limit and multi-user management | [README-mtp-new.md](README-mtp-new.md) |
| `mtp-old.sh` | Previous MTProxy installer, kept for existing deployments | [README-mtp-old.md](README-mtp-old.md) |
| `socks5.sh` / `socks5-noauth.sh` | Standalone sing-box Socks5 installers | [README-sb.md#socks5](README-sb.md#socks5) · [README-socks5-old.md](README-socks5-old.md) |
| `bbr.sh` | Kernel / BBR and queueing-discipline tuning helper | [README-bbr.md](README-bbr.md) |
| `fs-onlyforme.sh` | Personal maintenance and utility script | — |
| `init.js` | Dependency and release synchronisation helpers used by the CI workflows | — |

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/jyucoeng/singbox-tools/main/sb.sh -o sb.sh
bash sb.sh
```

Each script is `bash -n` clean, prints its own version, and can be re-run to
upgrade or uninstall. Releases are tagged; the GitHub Actions workflows only sync
upstream dependency versions (`sync-deps.yml`, `sync-singbox.yml`).

## Companion projects

Maintained by the same author, not part of this repository:

- [singbox-tools-interface](https://github.com/jyucoeng/singbox-tools-interface) —
  online command generator (a single static `index.html`) so users do not have to
  memorise the installer parameters.
- [sub_merge](https://github.com/jyucoeng/sub_merge) — node-subscription
  aggregator for people running several machines.

## What a hosted server would be used for

The project documents everything in very long Markdown files and hosts the
command generator on a third-party static host. A server would let the project
keep three things online for its users without that dependency:

1. **Documentation site** — `README-sb.md` alone is ~150 KB of options and
   examples, currently readable only inside the GitHub file viewer. A server
   renders it as a real, searchable documentation site, versioned by script
   version.
2. **Online demo** — the command generator, plus a server-side preview endpoint
   that takes the selected parameters and returns the resulting sing-box
   configuration JSON, so a user can verify a command before running it on their
   own machine. That is pure computation and needs a small HTTP service, which a
   static host cannot provide.
3. **Release/changelog feed** — a machine-readable endpoint with the current
   script version and its changes, so installed scripts can report whether an
   update exists.

No proxy node, no subscription service, no relay and no traffic is served from
the hosted server. It serves static pages and one read-only computation endpoint.
The project has no commercial offer: no paid tier, no support contract, no
advertising.

## License

[MIT](LICENSE) © LittleDoraemon ([@jyucoeng](https://github.com/jyucoeng)). The
scripts are the author's own work; the software they install (sing-box, MTProxy,
nginx, …) is downloaded at runtime and stays under its own license.

## Maintainer

LittleDoraemon ([@jyucoeng](https://github.com/jyucoeng)) — sole maintainer and
point of contact.

## Disclaimers

The scripts install software on servers the user controls. Users are responsible
for complying with the laws and the terms of service that apply to them. The
project ships no hosted service and holds no user data.

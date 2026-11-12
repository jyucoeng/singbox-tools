[简体中文](README-mtp-new.md) | **English**

## mtp-new.sh Usage

`mtp-new.sh` is an MTProxy management script that supports both an **interactive menu** and **non-interactive installation via arguments**.

### 1. Interactive menu (run with no arguments; this is the recommended way to run it, since there are quite a few installation parameters and the interactive mode is friendlier)

```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh)
```

Menu features at a glance:

| Option | Function |
|---|---|
| 1 | Install the Go version (mtg) |
| 2 | Install the Telemt high-performance version (multi-user/quota/expiry/rate limit) |
| 3 | View connection info |
| 4 | Modify configuration (port/domain; the Go version includes the listen mode) |
| 5 | Delete configuration |
| 6 | Telemt multi-user management |
| 7 | TG push configuration |
| 8 | Traffic statistics |
| 9 | TG notification options |
| 10 | View running status |
| 11 | View logs |
| 12/13/14 | Start/Stop/Restart the service |
| 15 | Uninstall everything and clean up |

### 2. Non-interactive installation (via environment variables; if the parameters are hard to remember, use the interactive menu instead.)

#### Install the Go version (mtg)

```
PORT=20301 DOMAIN='www.apple.com' IP_MODE='v4' bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh) rep
```

#### Install the Telemt high-performance version (Note: add a \ after every environment variable, and make sure there is no extra space before the \ at the end of each line)

```
INSTALL_MODE=telemt \
PORT=20301 \
DOMAIN='www.apple.com' \
SECRET='a3f8b2e1c9d04716e5f2a8b3c7d9e0f1' \
IP_MODE='dual' \
TELEMT_USER='admin' \
TELEMT_QUOTA=100 \
TELEMT_EXPIRE='2026-12-31' \
TELEMT_SPEED_UP=1.5 \
TELEMT_SPEED_DOWN=5.0 \
TELEMT_RESET_DAY=1 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh) rep
```

**MTProxy Telemt full creation workflow example** (main account + sub-users + viewing links)

```
Step 0: first generate a SECRET on the VPS, copy it and fill it into the TELEMT_SECRET variable in Step 1
head -c 16 /dev/urandom | od -A n -t x1 | tr -d ' \n'
```

```
Step 1: main account (administrator) with 100GB, auto-refresh on the 1st of every month, no upload/download speed limits

INSTALL_MODE=telemt \
PORT=443 \
DOMAIN='www.apple.com' \
TELEMT_SECRET='your_secret' \
IP_MODE='v4' \
TELEMT_USER='admin' \
TELEMT_QUOTA=100 \
TELEMT_EXPIRE='2099-12-31' \
TELEMT_RESET_DAY=1 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh) rep
```

```
Step 2: sub-user doraemon with 50GB per month, auto-refresh on the 1st, no upload/download speed limits

TELEMT_USER=doraemon \
TELEMT_DEDICATED_PORT=54001 \
TELEMT_QUOTA=50 \
TELEMT_EXPIRE="2099-12-31 23:59:59" \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh) adduser
```

```
Step 3: view everyone's tg links

bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh) users

```

#### More demo examples (Note: add a \ after every environment variable, and make sure there is no extra space before the \)

The examples below all use the variable `URL` to stand for the script URL; replace it with the full URL when copying:

```
URL='https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh'
```

**① Go version - basic installation (custom secret; the link stays identical across repeated installations)**

```
PORT=443 \
DOMAIN='www.apple.com' \
IP_MODE='v4' \
SECRET='a3f8b2e1c9d04716e5f2a8b3c7d9e0f1' \
bash <(curl -Ls $URL) rep
```

**② Telemt - basic installation (single user, no restrictions at all)**

```
INSTALL_MODE=telemt \
PORT=443 \
DOMAIN='www.apple.com' \
IP_MODE='v4' \
TELEMT_USER='admin' \
bash <(curl -Ls $URL) rep
```

**③ Telemt - traffic quota demo (100GB per month, auto-reset on the 1st of every month)**

```
INSTALL_MODE=telemt \
PORT=443 \
DOMAIN='www.apple.com' \
IP_MODE='v4' \
TELEMT_USER='vip01' \
TELEMT_QUOTA=100 \
TELEMT_RESET_DAY=1 \
bash <(curl -Ls $URL) rep
```

**④ Telemt - expiry demo (valid only until 23:59:59 on 2026-12-31; traffic is cut off afterwards)**

```
INSTALL_MODE=telemt \
PORT=443 \
DOMAIN='www.apple.com' \
IP_MODE='v4' \
TELEMT_USER='trial' \
TELEMT_EXPIRE='2026-12-31 23:59:59' \
bash <(curl -Ls $URL) rep
```

**⑤ Telemt - traffic + time dual-limit demo (100GB quota and expiry on 2026-12-31; traffic is cut off as soon as either limit is exceeded)**

```
INSTALL_MODE=telemt \
PORT=443 \
DOMAIN='www.apple.com' \
IP_MODE='v4' \
TELEMT_USER='vip01' \
TELEMT_QUOTA=100 \
TELEMT_RESET_DAY=1 \
TELEMT_EXPIRE='2026-12-31 23:59:59' \
TELEMT_SPEED_UP=1.5 \
TELEMT_SPEED_DOWN=5.0 \
bash <(curl -Ls $URL) rep
```

> After installation, the script directly outputs the `tg://proxy?...` share link; afterwards you can also use the `users` / `adduser` commands or the interactive menu [6] "Telemt multi-user management" to view/add more users.

### 3. Management commands

Commands are case-insensitive; `del` deletes the script itself and the global `mtp` command, while `rep` does not. Grouped by function:

**① Install / Uninstall**

```
bash <(curl -Ls .../mtp-new.sh) ins      # install (does not clean up the old configuration)
bash <(curl -Ls .../mtp-new.sh) rep      # overwrite reinstall (cleans up the service configuration first, keeps the script itself and the mtp command)
bash <(curl -Ls .../mtp-new.sh) del      # full uninstall and cleanup
```

**② Service control**

```
bash <(curl -Ls .../mtp-new.sh) start    # start the service
bash <(curl -Ls .../mtp-new.sh) stop     # stop the service
bash <(curl -Ls .../mtp-new.sh) restart  # restart the service
bash <(curl -Ls .../mtp-new.sh) list     # view the connection info of the installed service
```

**③ User management** (used together with the `TELEMT_*` environment variables, see the examples below)

```
bash <(curl -Ls .../mtp-new.sh) adduser   # add a Telemt user non-interactively
bash <(curl -Ls .../mtp-new.sh) users     # view the Telemt user list and their dedicated share links non-interactively
bash <(curl -Ls .../mtp-new.sh) getuser   # query the current configuration of the specified user non-interactively (specified via TELEMT_USER)
bash <(curl -Ls .../mtp-new.sh) moduser   # modify the configuration of the specified user non-interactively (quota/expiry/rate limit/port/secret)
bash <(curl -Ls .../mtp-new.sh) deluser   # delete the specified user non-interactively (specified via TELEMT_USER)
```

**④ Traffic quota reset**

```
bash <(curl -Ls .../mtp-new.sh) check_reset   # called silently by Cron; quotas are reset automatically (no need to run it manually)
bash <(curl -Ls .../mtp-new.sh) force_reset   # trigger a quota reset immediately, manually
```

**⑤ Traffic statistics** (this month's usage report + per-user exhaustion times)

```
bash <(curl -Ls .../mtp-new.sh) usage             # view this month's traffic usage statistics (including per-user exhaustion times)
bash <(curl -Ls .../mtp-new.sh) traffic_snapshot  # record a traffic snapshot right away (called automatically by Cron every hour)
bash <(curl -Ls .../mtp-new.sh) usage_total       # total traffic usage statistics (historical cumulative, sorted by usage from high to low)
```

> Aliases: `usage` can also be written as `traffic` / `stats`, and `usage_total` as `traffic_total` / `total`; the behavior is exactly the same.

**⑥ Telegram push** (daily statistics report)

```
bash <(curl -Ls .../mtp-new.sh) tg_config     # configure Telegram statistics push (non-interactive; requires TELEMT_TG_TOKEN/TELEMT_TG_CHAT or reuses the existing configuration; for interactive mode use main menu [7])
bash <(curl -Ls .../mtp-new.sh) tg_userconf   # push the user configuration list to TG (no arguments = all users, or specify a username / TELEMT_USER)
bash <(curl -Ls .../mtp-new.sh) tg_report     # manually send this month's statistics to Telegram right away
bash <(curl -Ls .../mtp-new.sh) tg_autopush   # scheduled timing-check command (called by Cron every hour; pushes only when the Beijing time is due)
```

> **Implementation note**: traffic statistics / Telegram push / per-user usage display (`usage`, `usage_total`, `traffic_snapshot`, `tg_*`, `users`, `getuser`) are implemented by an embedded Python module (automatically written and synced to `/opt/mtproxy/mtp_stats.py` on every invocation). **python3** is required and is installed automatically during `ins`/`rep` installation (`apk add python3` on Alpine); all command entry points and Cron behavior remain unchanged.

**Non-interactive user addition examples:**

```
# Add the username only (secret generated automatically)
TELEMT_USER=vip01 bash mtp-new.sh adduser

# Specify the secret and quota (once the secret is fixed, the share link no longer changes across reinstalls)
TELEMT_USER=vip01 TELEMT_SECRET=aabbccdd00112233aabbccdd00112233 TELEMT_QUOTA=100 bash mtp-new.sh adduser

# Full restrictions: dedicated port + quota + expiry + upload/download rate limits
TELEMT_USER=vip01 TELEMT_DEDICATED_PORT=20443 TELEMT_QUOTA=50 TELEMT_EXPIRE="2026-12-31 23:59:59" \
  TELEMT_SPEED_UP=1.5 TELEMT_SPEED_DOWN=5.0 bash mtp-new.sh adduser
```

> On success, the Telemt service is restarted automatically so the change takes effect immediately, and the user's communication secret is echoed in the terminal.

**Non-interactive user modification examples (`moduser`; the target is specified via `TELEMT_USER`; only the fields you provide are changed):**

```
# Query a user's current configuration
TELEMT_USER=vip01 bash mtp-new.sh getuser

# Delete a user (the dedicated port/quota/expiry/rate limit and billing records are cleaned up as well)
TELEMT_USER=vip01 bash mtp-new.sh deluser

# Change the traffic quota only (clears the used billing records)
TELEMT_USER=vip01 TELEMT_QUOTA=100 bash mtp-new.sh moduser

# Change the expiry time (0 removes the expiry and restores permanent validity)
TELEMT_USER=vip01 TELEMT_EXPIRE="2027-03-01 12:00:00" bash mtp-new.sh moduser

# Change quota + expiry + upload/download rate limits at once
TELEMT_USER=vip01 TELEMT_QUOTA=200 TELEMT_EXPIRE="2027-06-30" \
  TELEMT_SPEED_UP=2 TELEMT_SPEED_DOWN=8 bash mtp-new.sh moduser

# Change the dedicated port (0 removes the dedicated port and restores the shared port)
TELEMT_USER=vip01 TELEMT_DEDICATED_PORT=20555 bash mtp-new.sh moduser

# Change the communication secret (the share link changes accordingly)
TELEMT_USER=vip01 TELEMT_SECRET=aabbccdd00112233aabbccdd00112233 bash mtp-new.sh moduser

# Remove all restrictions for this user in one go
TELEMT_USER=vip01 TELEMT_QUOTA=0 TELEMT_EXPIRE=0 TELEMT_SPEED_UP=0 TELEMT_DEDICATED_PORT=0 bash mtp-new.sh moduser
```

> Rule: `0` = remove/lift that restriction; if not provided, it stays unchanged. Exit code convention: **2** = usage error (empty/invalid `TELEMT_USER`, malformed field value, or no field provided at all); **1** = business failure (user does not exist/already exists, port conflict).

**The interactive menu "Telemt advanced multi-user management"** (the corresponding main-menu entry) covers all of the above capabilities:

```
1. View all users and their dedicated share links    2. Query the configuration of a specified user (fuzzy match)
3. Add a new user                    4. Kick out (delete) a specified user
5. Manage quota/expiry/rate limit/secret/port   6. Auto-reset configuration (Cron monthly rotation)
7. Look up a user from a TG share link
0. Return to the main menu
```

> "Query a specified user" supports fuzzy matching by keyword, listing numbered results to choose from when there are multiple hits; inside "Manage quota/expiry/rate limit/secret/port" you can change the quota, expiry, upload/download rate limits, communication secret and dedicated port; "7" can look up a user from a TG share link. Traffic statistics and TG push have moved to main menu [8] "Traffic statistics" (this month's report / user list / user details / total traffic ranking) and [9] "TG notification options" (message sending toggles; push the list/details/monthly report/all immediately).

### 4. Traffic statistics and exhaustion time records

After Telemt is installed, the script automatically registers an **hourly traffic snapshot Cron** and refreshes it in sync every time the user list is viewed / a user is queried / statistics are displayed. Related files:

| File | Purpose |
|---|---|
| `/etc/telemt_exhausted.json` | Records the point in time when each user's traffic ran out **this month** (records become invalid automatically when the month rolls over) |
| `/var/log/telemt_traffic.log` | Append-only per-user traffic log with a timestamp at the end of each line (including `quota exhausted` events and hourly usage snapshots) |
| `/opt/mtproxy/exhausteddata/telemt_total.json` | Historical cumulative total traffic cache (maximum snapshot per user per month + log offset, incrementally updated) |

Run `mtp usage` or main menu [8] "Traffic statistics" → "View this month's statistics report" to see:

```
==================================================
       Telemt Traffic Usage This Month (2026-08)
==================================================
  Username      Used     Quota    Remaining  Usage%  Exhausted At
  ----------------------------------------------------------------
  admin         512.0MB   1.00GB   512.0MB   50.0%   -
  alice         2.00GB    2.00GB   0B        100.0%  2026-08-03 10:00:12
  ----------------------------------------------------------------
  Total this month: 2.50GB    Total quota: 3.00GB    Over-quota/exhausted users: 1
==================================================
  Recent traffic records this month (by user, timestamp at end of line):
alice | quota exhausted: used 2.00GB / quota 2.00GB | 2026-08-03 10:00:12
alice | used 2.00GB / quota 2.00GB | 2026-08-03 10:00:12
```

- **Exhaustion time**: recorded once, when the user's traffic runs out for the first time in the month (as a `quota exhausted: ...` line in `/var/log/telemt_traffic.log`); it is not overwritten repeatedly, and it is recalculated after the month rolls over.
- **Monthly cycle**: both the report and "recent traffic records this month" count only records of the **current month** (filtered by the `YYYY-MM` at the end of the timestamp); records from the previous month and earlier are not shown. The log file itself is append-only and accumulates across months; it is never cleared automatically.

**Total traffic usage statistics (historical cumulative)**

Run `mtp usage_total` or main menu [8] "Traffic statistics" → "View total traffic statistics (historical cumulative)" to see the cross-month cumulative usage ranking:

```
==================================================
       Total Traffic Usage (historical cumulative, sorted by usage)
==================================================
  Rank  Username       Cumulative   Months Counted
  ----------------------------------------------------------------
  1      alice            2.00GB       2
  2      bob              2.00GB       1
  3      carol            500.0MB      1
  ----------------------------------------------------------------
  Historical cumulative total: 4.49GB    Users with traffic records: 3
==================================================
```

- **Calculation basis**: historical cumulative = the **sum across months of each user's maximum monthly traffic snapshot** (derived from `/var/log/telemt_traffic.log`); monthly auto-reset, manual reset and uninstalling all do **not** affect the historical traffic already accumulated.
- **Incremental cache**: results are cached in `/opt/mtproxy/exhausteddata/telemt_total.json` (the directory is created automatically); only the **new** log lines since the last offset are parsed, so there is no full scan from scratch every time. If the cache is deleted or the log is truncated, the next run automatically rebuilds it from the complete log.
- **Sorting**: by historical cumulative usage, from high to low.
- **Dependency**: the traffic snapshot must be enabled (it is enabled automatically at installation) and keep running; the statistics are accurate only when the traffic log is complete.
- **Automatic cleanup**: when a quota is reset manually, the quota is changed via `moduser`, a user is deleted, or the monthly auto-reset runs, that user's exhaustion record is cleared in sync.
- Uninstalling (`del`) also removes the snapshot Cron, the traffic log, the historical cumulative cache and the exhaustion records.

**Telegram daily report push**

- Configuration: main menu [7] "TG push configuration" (interactive) or the environment variables `TELEMT_TG_TOKEN` / `TELEMT_TG_CHAT` (non-interactive `tg_config` / enabled automatically at installation).
- **Can be changed at any time**: the interactive menu can modify the Token / Chat ID / push time; pressing Enter keeps the current value. Non-interactive `tg_config` accepts passing only one of `TELEMT_TG_TOKEN=` or `TELEMT_TG_CHAT=` (items not provided keep the existing configuration).
- Push time: by default **09:00 Beijing time every day** (controlled by the global variable `TG_PUSH_TIME`, overridable via `TELEMT_TG_TIME`), determined through a UTC+8 conversion and independent of the server time zone.
- Manual send: `mtp tg_report` pushes the current statistics once at any time.
- **When `TELEMT_TG_TOKEN` / `TELEMT_TG_CHAT` are not configured, no statistics are sent at all** (the scheduled job skips silently).

### 5. Environment variables

| Variable | Description | Default | Example |
|---|---|---|---|
| `INSTALL_MODE` | Installation backend: `go` / `telemt` | go | `telemt` |
| `PORT` | Listening port | 443 | `20301` |
| `DOMAIN` | Disguise domain | www.apple.com | `www.apple.com` |
| `IP_MODE` | Listen mode: `v4` / `v6` / `dual` | v4 | `dual` |
| `SECRET` | Communication secret (must be 32-character hex; generated automatically if omitted) | auto-generated | `aabbccdd00112233aabbccdd00112233` |
| `TELEMT_USER` | Telemt initial administrator username | admin | `admin` |
| `TELEMT_QUOTA` | Initial user's monthly traffic quota (GB, decimals supported) | unlimited | `100` / `25.5` |
| `TELEMT_EXPIRE` | Initial user's forced expiry date (UTC+8, accurate to the second) | permanent | `2026-12-31` / `2026-12-31 23:59:59` |
| `TELEMT_SPEED_UP` | Initial user's upload rate limit (MB/s, decimals supported) | unlimited | `1.5` |
| `TELEMT_SPEED_DOWN` | Initial user's download rate limit (MB/s; defaults to the upload value if omitted) | same as upload | `5.0` |
| `TELEMT_RESET_DAY` | Monthly quota auto-reset day (effective only when `TELEMT_QUOTA` is set) | disabled | `1` |
| `TELEMT_SECRET` | Communication secret for the specified user (must be 32-character hex; used by `adduser`/`moduser`) | auto-generated | `aabbccdd00112233aabbccdd00112233` |
| `TELEMT_DEDICATED_PORT` | Assign a dedicated independent port to the user (used by `adduser`/`moduser`) | shared port | `20443` |
| `TELEMT_TG_TOKEN` | Telegram Bot Token (enables push at installation or via `tg_config`) | no push | `123456:ABC...` |
| `TELEMT_TG_CHAT` | Telegram Chat ID that receives the statistics messages | no push | `123456789` |
| `TELEMT_TG_TIME` | Daily report push time (Beijing time HH:MM; overrides the global variable `TG_PUSH_TIME`) | `09:00` | `08:30` |
| `DEBUG_FLAG` | Debug log switch; when set to `1`, troubleshooting information is printed to stderr (entry arguments, parse results, the target of each command, etc.) | 0 | `1` |

> **Global variable `TG_PUSH_TIME`**: located at the top of the script; controls the default push time of the Telegram daily report (Beijing time HH:MM, default `09:00`), and can be overridden by the environment variable `TELEMT_TG_TIME`. If `TELEMT_TG_TOKEN` / `TELEMT_TG_CHAT` are not configured, the script sends no statistics to Telegram.

> **Secret consistency**: as long as `SECRET` is customized (and passed in via environment variables), the generated connection secret and share link are exactly the same no matter how many times you reinstall (even better when combined with the same `DOMAIN`/`PORT`). If `SECRET` is omitted, a brand-new secret is generated automatically at each installation. If `SECRET` is invalid (not 32-character hex), the script aborts with an error.

### 6. Notes

- Must run with **root** privileges
- Installation flow: prebuilt binaries in the same local directory are preferred (`mtg-go-<arch>` / `telemt-linux-<arch>` / `telemt`); if they are not found, they are downloaded from the `Go-Rust` Release of this project [singbox-tools](https://github.com/jyucoeng/singbox-tools)
- Supported systems: Debian/Ubuntu (systemd), CentOS/RHEL (systemd), Alpine (OpenRC)
- Telemt multi-user features: dedicated ports, traffic quotas, expiry dates, independent rate limits, monthly auto-reset (Cron)
- Traffic statistics: automatic hourly snapshots + this month's usage report + per-user traffic exhaustion time records

## Version History

### v2.0.2 (2026-09-05) — Fixed IPv6 listener failure in Telemt v6/dual mode

**Symptom**: after installing with `IP_MODE=v6` / `IP_MODE=dual` on a pure-IPv6 or dual-stack server, the generated `tg://proxy?server=<IPv6>&port=...` link does not work (the TCP connection is refused outright / `Connection refused`).

**Root cause**: telemt's `[network].ipv6` defaults to `false` (`DEFAULT_NETWORK_IPV6 = Some(false)` in the source file `src/config/defaults.rs`). Merely writing the following in the configuration:

```toml
[[server.listeners]]
ip = "::"
```

is not enough to make telemt actually listen on IPv6 — it skips the IPv6 listener outright before binding. The old version of the script omitted `[network] ipv6 = true` when generating `/etc/telemt.toml`, which caused:

- `ss -tlnp` only showed `0.0.0.0:<PORT>`, with no `[::]:<PORT>` listener at all;
- IPv6 client connections were refused directly by the kernel;
- on a **pure-IPv6 VPS** (eth0 has no public IPv4, and IPv4 actually goes through the Cloudflare WARP `172.16.0.2` private egress with inbound from the outside impossible), the proxy was effectively completely unusable.

**Fix**: when generating the configuration, `IP_MODE=v6` / `IP_MODE=dual` now automatically writes:

```toml
[network]
ipv6 = true
```

so that telemt binds `[::]:<PORT>` normally (while keeping the `0.0.0.0:<PORT>` listener).

**Already-deployed servers**: they will not receive this fix automatically; patch the configuration manually and then restart:

```bash
sed -i '/^\[server\]/i [network]\nipv6 = true\n' /etc/telemt.toml
systemctl restart telemt
```

(The script regenerates the complete configuration with the new logic on subsequent `rep` reinstalls.)

**Verification**: after restarting, confirm that both listeners exist:

```bash
ss -tlnp | grep <PORT>
# Both 0.0.0.0:<PORT> and [::]:<PORT> should appear
```

**Share link caveat**: when telemt probes the public IP internally, it may pick up the WARP private address (`172.16.0.2`) and generate the share link based on it; such links are **unusable from the outside**. Always generate/share links using the server's real public IPv6.

## Acknowledgements

This project is a modified fork of [0xdabiaoge/MTProxy](https://github.com/0xdabiaoge/MTProxy); thanks to the original author for the excellent work. Building on it, this script rewrites the install/uninstall, service management, multi-user management, traffic statistics, quota reset and Telegram push logic, while the binary dependencies still use the compiled artifacts from the original repository.

[简体中文](README-sb.md) | **English**

# sing-box One-Click Installation Script

Two installation methods are supported:

- **Interactive**: run `bash sb.sh` directly (without arguments) and follow the menu prompts to complete installation, uninstallation, viewing, and other operations.
- **Non-interactive**: complete it in one line with environment variables + arguments (see examples below); you can also pair it with the [command generator UI](https://github.com/jyucoeng/singbox-tools-interface) (access via your own domain after deployment).

After installation, the **`sb` shortcut** is available: `sb` opens the main menu, while `sb ins` / `sb rep` / `sb list` / `sb rt` / `sb node` / `sb sub` / `sb del` jump straight to the corresponding features (see the full list in [sb Shortcuts](#26-sb-shortcut-commands)).

<a id="c1"></a>

#### 📌 Quick Navigation
#### [**① Basic Commands**](#mod-1)　[**② Direct Connection Protocol Snippets**](#mod-2)　[**③ Argo Protocol Snippets**](#mod-3)　[**④ Origin Relay Protocol Snippets**](#mod-4)　[**⑤ Nginx Module**](#mod-5)
#### [**Combined Examples (Direct + Argo + Origin Relay All Enabled)**](#full-example)　[**How to Uninstall**](#uninstall)　
#### [**🌐 CF (Cloudflare) Origin Relay Rule Deployment**](#cf-origin)　[**Chapter 1 · Installation and Uninstallation**](#c1)　[**Chapter 2 · Other Notes**](#c2)

# 1、 sing-box Installation and Uninstallation
## Supported Protocols

vmess / trojan / vless (via Argo, multi-select supported) + Hysteria2 + VLESS-Reality + TUIC + AnyTLS + Socks5, plus ws_cdn CDN origin relay for vmess / vless / trojan; these protocols can be freely combined.

All environment variables are listed below in the form of "basic commands + protocol snippets".

> **⚠️ Quoting rule**: wrap non-numeric values in **single quotes**, e.g. `name='my-node'`, `socks5_password='a@b#c'`. This way characters like `$`, `!`, `#` in passwords are not expanded early by the shell; pure numbers (ports, `ippz`, `DEBUG_FLAG`) need no quotes.

**Usage: write the basic command only once, and prepend protocol snippets above the basic command as needed.** Once joined, it becomes one complete command; deleting a line disables the corresponding protocol.

> The ②③④ snippets list variables only, with the last line ending in `\`, so they connect directly to the variable block of ① (the ending is still `bash ... rep`).

<a id="mod-1"></a>
## ① Basic Commands (shared by all protocols; the trailing `bash <(...) rep` appears only here)

```bash
uuid=00000000-0000-4000-8000-000000000000 \
ippz=4 \
name='my-node-us-california' \
nginx_pt=41007 \
subscribe=true \
DEBUG_FLAG=0 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

> Optional variables (add them before `DEBUG_FLAG` when needed; omit them otherwise):
> - `out_ip='216.166.22.30'`: when the egress IP differs from the SSH IP, specify the IP shown in the node
> - `direct_host='node.example.com'`: replace the IP in direct-connection protocol links with a domain (you need to add the DNS record and disable the orange cloud yourself)

> **Basic command variable reference:**
>
> - `uuid`: node UUID; auto-generated if not provided
> - `ippz`: egress IP preference (`4`=IPv4 only, `6`=IPv6 only; if omitted = automatic, IPv4 preferred)
> - `name`: node name prefix
> - `subscribe` / `nginx_pt`: enable the subscription and the subscription port (`nginx_pt` is also the ws_cdn origin relay port)
> - `out_ip`: special egress IP (only when the egress IP differs from the server IP, used together with `ippz`; usually left empty)
> - `direct_host`: public-facing domain for direct-connection protocols (replaces the IP in direct-connection protocol links with this domain; you need to add an A/AAAA record in Cloudflare DNS yourself and disable the "orange cloud")
> - `DEBUG_FLAG`: log debug switch (`0`=off, `1`=on; debug output is written to `doraemon/debug.log`)
>
> Item-by-item details:

### 1、 Command arguments: rep / del / delall / list / list key

| Argument | Effect |
|---|---|
| `rep` | Reinstall (uninstall first, then install) |
| `del` | Uninstall, keeping binaries such as sing-box / cloudflared |
| `delall` | Complete uninstall, removing binaries and configuration as well |
| `list` | View nodes |
| `list key` | View nodes + VLESS Reality private key |

- No arguments = enter the interactive menu.
- `list key` passes the two arguments `list` and `key` together, not two separate commands.

### 2、 uuid (node UUID, optional)

**Meaning**
- Omit `uuid` → generated automatically by the script
- Provide `uuid` → use the UUID you specify


### 3、 ippz and out_ip (IP display policy and special egress IP, optional)

| ippz | Meaning |
|---|---|
| `4` | IPv4 only |
| `6` | IPv6 only |
| Omitted | Automatic (IPv4 preferred; fall back to IPv6 if no IPv4) |

`ippz` decides whether the node entry contains IPv4 or IPv6, and also affects whether sing-box / nginx listen on IPv6 (no `[::]` listening when `ippz=4`).

`out_ip` handles the case where "the IP you SSH into" and "the egress IP detected by the script" differ: by default the script writes the detected egress IP into the node, but what the client connects to is the IP you SSH into; in that case use `out_ip` to specify the latter:

- IPv4: `out_ip='216.166.22.30' ippz=4`
- IPv6: `out_ip='2602:294:0:b7:1234:1234:d9d4:0001' ippz=6`


 <img width="602" height="132" alt="CleanShot 2026-01-26 at 12 57 34" src="https://github.com/user-attachments/assets/57c1a329-9292-45b5-aa23-3c59cd3e3356" />


### 4、 direct_host (public-facing domain for direct-connection protocols, masks the IP, optional)

👉 `direct_host='your-domain.com'`: the script replaces the host in direct-connection protocol (hy2/tuic/vless-reality/anytls/socks5) links from "server IP" with this domain.

**Prerequisites (the script does not handle DNS; complete these yourself):**
1. In the DNS settings of the corresponding domain in the [Cloudflare dashboard](https://dash.cloudflare.com/), add a DNS record for the domain pointing to the server's **actually bound public IP**: use an A record for IPv4 and an AAAA record for IPv6 (the `direct_host` prompt during installation automatically computes the address to bind based on out_ip / the detected IP);
2. **Be sure to disable the "orange cloud" (Proxy / orange cloud) and keep the gray cloud (DNS only)**; otherwise UDP direct connections (hy2/tuic) cannot pass through and the node is unreachable;
3. Ports unchanged = each direct-connection protocol's own local listening port (`hypt`/`vlrt`/`tupt`/`anypt`/`socks5pt`).

👉 If omitted, direct-connection links keep showing the real server IP without affecting service operation. This variable **only affects the output of direct-connection protocol links**; Argo / CDN origin relay links are unaffected. After installation, you can view, modify, or clear it via the menu `node → 直连对外域名 (掩盖IP)` (node → direct public domain, mask IP).


### 5、 nginx_pt (nginx subscription port, default 8080)

- Omitted: defaults to 8080
- Provided: the nginx subscription listens on that port

❗`nginx_pt` must not be the same as `argo_pt`. `argo_pt` defaults to 8001, so unless you change `argo_pt`, do not set `nginx_pt` to 8001.


### 6、 subscribe (subscription switch, default false, i.e. no nginx subscription)

- `false` (default): no subscription is generated; but if Argo is enabled, Nginx is still installed for origin relay reverse proxying
- `true`: generate a subscription; specifying `nginx_pt` (subscription port, default 8080 if unspecified) at the same time is recommended



### 7、 name (node name prefix)

- Omitted → defaults to hostname
- Provided → the node name gets the prefix

**Example:**
- name=HK
- ➡ HK-vmess / HK-vless


### 8、 DEBUG_FLAG debug log switch (default 0)

- `0` (default) → disable debug output
- `1` → enable debug mode; the script writes entry arguments, parsing results, targets of each command, and other debug information into `doraemon/debug.log` for troubleshooting

Example:
```bash
DEBUG_FLAG=1 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```
<a id="mod-2"></a>
## ② Direct Connection Protocol Snippets (VLESS-Reality + Hysteria2 + TUIC + AnyTLS + Socks5)

> Prepend above the basic command (the last line of this snippet ends with `\`, connecting directly to the first variable line of the basic command); deleting a port line (`vlrt / hypt / tupt / anypt / socks5pt`) = the corresponding protocol is not installed; fill in `socks5_*` only when Socks5 is enabled. `out_ip` / `direct_host` belong to the basic command (①) and are not placed here.

```bash
vl_sni='www.apple.com' \
vl_sni_pt=443 \
vlrt=41003 \
reality_private='GHxxxxxxxxxxxxx-xxxxxx-VnXH6FjxxA' \
hy_sni='www.apple.com' \
hypt=41004 \
tu_sni='www.apple.com' \
tupt=41005 \
any_sni='www.apple.com' \
anypt=41006 \
socks5pt=41017 \
socks5_username='your-username' \
socks5_password='your-{{PASSWORD}}' \
socks5_wl_flag=true \
socks5_ips='1.2.3.4,5.6.7.0/24' \
```

> **Direct connection snippet variable reference (grouped by protocol):**
> - VLESS-Reality: `vl_sni` / `vl_sni_pt` / `vlrt` / `reality_private`
> - Hysteria2: `hy_sni` / `hypt`
> - TUIC: `tu_sni` / `tupt`
> - AnyTLS: `any_sni` / `anypt`
> - Socks5: `socks5pt` / `socks5_username` / `socks5_password` / `socks5_wl_flag` / `socks5_ips`
> - **Deleting a port line (`vlrt / hypt / tupt / anypt / socks5pt`) = the corresponding protocol is not installed**
>
> Item-by-item details:

### 1、 General notes on disguise SNI (hy_sni / vl_sni / tu_sni / any_sni)

Overview of the disguise SNI for each direct-connection protocol (if unsure, leave it empty or delete the line; the script uses default values):

| Variable | Protocol | Description | Default |
|------|------|------|--------|
| `hy_sni` | Hysteria2 | hy2's disguise domain, customizable | `www.apple.com` |
| `vl_sni` | VLESS-Reality | vless's disguise domain, customizable | `www.apple.com` |
| `vl_sni_pt` | VLESS-Reality | handshake port bound to the vless disguise domain, fixed at install time (https-family: pick any of 443,2053,2083,2087,2096,8443); do not change it arbitrarily on the client | 443 |
| `tu_sni` | TUIC | tuic's disguise domain, customizable | `www.apple.com` |
| `any_sni` | AnyTLS | anytls's disguise domain, customizable | `www.apple.com` |

**SNI best practices** (do not use domains that malicious scanners treat as unlimited-traffic forwarding ports; if you don't know what to write, leave it empty — the script has built-in defaults):
- ❌ Cloudflare-related: `www.cloudflare.com`, `dash.cloudflare.com`
- ❌ CDN services: `www.akamai.com`, `www.fastly.com`
- ❌ Proxy / VPN services: the domain of any proxy service
- ❌ Your own server's domain (creates a loop)
- ✅ Recommended: `www.apple.com` (default) / `www.yahoo.com` / `www.google.com` / any large, normal website

### 2、 VLESS-Reality

- `vl_sni` / `vl_sni_pt`: disguise SNI / SNI port (default 443)
- `vlrt`: VLESS-Reality port
- `reality_private`: Reality private key. Providing it keeps the vless node consistent across installation/reinstallation, avoiding repeated imports; if omitted it is generated automatically and printed once when installation or reinstallation completes. If you forget to save it, reinstall, or run `sb list key` to print it again; do not fill in arbitrary values — the correct value must be 43 characters long.
- `reality_public` (optional): the public key exposed by the Reality node. Usually omitted — the script derives the matching public key from `reality_private` automatically; it is only needed when you already hold a public key and want to force it. When `reality_private` is provided, the value derived from the private key takes precedence.

### 3、 Hysteria2 (hy2)

- `hy_sni`: disguise SNI
- `hypt`: Hysteria2 port

### 4、 TUIC

- `tu_sni`: disguise SNI
- `tupt`: TUIC port

### 5、 AnyTLS

- `any_sni`: disguise SNI
- `anypt`: AnyTLS port

<a id="socks5"></a>
### 6、 Socks5

- `socks5pt`: Socks5 port; socks5 is not enabled if omitted. If `socks5_username` / `socks5_password` are omitted, they are generated randomly.
- ⚠️ If `socks5_password` contains special characters such as `!`, `#`, `$`, the entire password string must be wrapped in single quotes `'...'`.
- `socks5_wl_flag` / `socks5_ips` (IP whitelist, optional):

| Argument | Description | Default |
|------|------|--------|
| `socks5_wl_flag` | Whitelist switch; `true`/`1`/`True`/`TRUE` all work (case-insensitive); empty or any other value = off | Empty (off) |
| `socks5_ips` | Source IP list allowed to access Socks5, comma-separated, supporting single IPs and CIDR (e.g. `1.2.3.4,5.6.7.0/24`); both IPv4/IPv6 supported | Empty |

  - Omit both arguments → Socks5 is open to all IPs (default behavior); provide `socks5_wl_flag=true` with a non-empty `socks5_ips` → only whitelisted IPs can connect.
  - **How it works**: when the whitelist is enabled, in the iptables/ip6tables INPUT chain — whitelisted IPs are ACCEPTed (allowed, marked `socks5_rule`), everything else is DROPped (blocked, marked `socks5_rule`); other protocol ports are ACCEPTed and marked `doraemon_singbox_rule`. Uninstallation/reinstallation cleans up only this script's rules and does not affect other programs.
  - After installation, manage it via the interactive menu → 「Socks5 IP白名单管理」 (Socks5 IP Whitelist Management); in the node output the whitelist status is shown right below the link:

```
🧦【 Socks5 】(do not connect to this protocol directly from a client)
socks5://user:pass@ip:port#name
   ↳ inbound whitelist enabled, allowed only: 1.2.3.4,5.6.7.0/24
```

### 7、 Port naming and port line conventions

- `hypt` / `vlrt` / `tupt` / `anypt` / `socks5pt`: correspond to the ports of hy2 / vless-reality / tuic / anytls / socks5 respectively; `pt` is short for port, and `rt` is short for reality port.
- ⚠️ Whether vmess / trojan / vless are enabled is decided by `argo` (multi-select supported, comma-separated, e.g. `argo=vmess,vless`); their local origin relay ports are not configurable (the old variables `trpt` / `vmpt` / `vlpt` are deprecated), and the ports are chosen by the script automatically at random or by reusing the persisted file.
- **Deleting a port line (`vlrt / hypt / tupt / anypt / socks5pt`) = the corresponding protocol is not installed**




### Combination Examples
> Common combination examples: each block can be copied and run as-is; deleting a line disables the corresponding feature.

### Combination 1: install only 1 direct-connection protocol (pick one of `hypt` / `vlrt` / `tupt` / `anypt`)

#### hy2 protocol only

```bash
hypt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### vless Reality protocol only

```bash
vlrt=2083 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### tuic protocol only

```bash
tupt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### anytls protocol only

```bash
anypt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### socks5 protocol only

```bash
# Passwords containing special characters (!#$ etc.) must be wrapped in single quotes; socks5_wl_flag (optional): enable IP whitelist; socks5_ips (optional): whitelist IPs in CIDR
socks5pt=31017 \
socks5_username='your-socks5-username' \
socks5_password='your-socks5-{{PASSWORD}}' \
socks5_wl_flag=true \
socks5_ips='1.2.3.4,5.6.7.0/24' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

### Combination 2: install 2 direct-connection protocols (write both `hypt` and `vlrt`)

```bash
hypt=2082 \
vlrt=2083 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

<a id="mod-3"></a>
## ③ Argo Protocol Snippets (VMess-WS-TLS / Trojan-WS-TLS / VLESS-WS-TLS via Cloudflare Tunnel)

> Prepend above the basic command; if Argo is not enabled, do not paste this block at all; `argo` supports multi-select: `'vmess'` / `'trojan'` / `'vless'`, combined with commas like `'vmess,vless,trojan'`.

```bash
argo='vmess,vless,trojan' \
argo_cf_host='saas.sin.fan' \
argo_cf_pt=443 \
argo_pt=8001 \
agn='your-fixed-argo-domain' \
agk='your-tunnel-token' \
argo_vmess_cf_host='vm.example.com' \
argo_vmess_cf_pt=443 \
argo_vless_cf_host='vl.example.com' \
argo_vless_cf_pt=443 \
argo_trojan_cf_host='tr.example.com' \
argo_trojan_cf_pt=443 \
```

- The first 6 lines are shared by the three Argo protocols; the last 6 lines override the shared `argo_cf_host` / `argo_cf_pt` per protocol; if omitted, the shared values are used.
- `agn` / `agk` left empty = temporary trycloudflare tunnel; `agk` is a token or Auth JSON (the string starting with `ey` is the token).

Details item by item below.

### 1、 argo_cf_host / argo_cf_pt (shared public domain/port)

- The public domain and port shared by the three Argo protocols; defaults to `saas.sin.fan` / `443`; the port must be https-family: 443, 2053, 2083, 2087, 2096, 8443.
- You can also fill in your own domain or an optimized IP (e.g. `www.visa.com`); if omitted, the default is used.

### 2、 Per-protocol specification (optional; falls back to the shared values when unset)

- `argo_vmess_cf_host` / `argo_vmess_cf_pt`, `argo_vless_cf_host` / `argo_vless_cf_pt`, `argo_trojan_cf_host` / `argo_trojan_cf_pt`

### 3、 Legacy names

- `cdn_host` / `cdn_pt` still work (`argo_cf_host` / `argo_cf_pt` take precedence, legacy names as fallback), so old commands can be reused directly.
- For example, `cdn_host` / `cdn_pt` in an old command are treated as `argo_cf_host` / `argo_cf_pt`:
```
trojan://00000000-0000-4000-8000-000000000001@cdns.doon.eu.org:8443?...
```

### 4、 argo (Cloudflare Argo switch, multi-select supported)

- `argo=vmess` enables VMess Argo; `argo=trojan` enables Trojan Argo; `argo=vless` enables VLESS Argo
- Multi-select: any combination such as `argo=vmess,vless`, `argo=vmess,trojan,vless`; empty or omitted → Argo is not enabled
- ⚠️ Argo only applies to VMess / Trojan / VLESS, multi-select is supported, and it can coexist with ws_cdn; it has no effect on `hypt / vlrt / tupt`
- ⚠️ argo values are validated after being normalized to lowercase (any vmess / vless / trojan combination is accepted); the old values `vmpt / trpt / vlpt` are deprecated; whether these three protocols are enabled is decided entirely by `argo=`, and their local origin relay ports are not configurable (random automatically / reused from the persisted file)

### 5、 argo_pt (Argo local origin relay port)

- The local listening port defaults to 8001 and usually stays unchanged. If you hard-coded `http://localhost:8001` in the Public Hostname of your Cloudflare Tunnel, update it there in sync after changing this.

<img width="1514" height="621" alt="CleanShot 2026-01-25 at 12 50 32" src="https://github.com/user-attachments/assets/ec1d2396-4832-4b1b-9da7-cbda4e9c56f1" />

### 6、 agn / agk (Argo fixed tunnel)

- `agn='fixed tunnel domain'`, `agk='tunnel token or Auth JSON'`; omitted = temporary trycloudflare tunnel (requires `argo` to be enabled).
- Only needed if you have your own CF Tunnel.
- **JSON format**: the JSON itself contains double quotes, so it must be wrapped in **single quotes**, e.g. `agk='{"AccountTag":"...","TunnelID":"..."}'`; a plain token works with either single or double quotes.



#### Appendix: how to obtain a JSON-format Argo Tunnel
- Generate online: <https://fscarmen.cloudflare.now.cc>
- Illustrated guide: <https://github.com/fscarmen/sing-box/blob/main/README.md#5json-argo-tunnel-%E8%8E%B7%E5%8F%96-%E6%8E%A8%E8%8D%90>


### Combination 3: single Argo protocol (choose VMess / Trojan / VLESS)

#### Using VMess Argo

```bash
ippz=4 \
argo=vmess \
agn='test-vmess.xxxx.xyz' \
agk='the-string-starting-with-ey' \
name='my-node-kr-chuncheon-vmess' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### Using Trojan Argo

```bash
ippz=4 \
argo=trojan \
agn='test-trojan.xxxx.xyz' \
agk='the-string-starting-with-ey' \
name='my-node-kr-chuncheon-trojan' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### Using VLESS Argo

```bash
ippz=4 \
argo=vless \
agn='test-vless.xxxx.xyz' \
agk='the-string-starting-with-ey' \
name='my-node-kr-chuncheon-vless' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

### Combination 3 (multi-select): enable multiple Argo protocols simultaneously

```bash
ippz=4 \
argo=vmess,trojan \
argo_cf_host='saas.sin.fan' \
argo_cf_pt=443 \
agn='test-xxx.xxxx.xyz' \
agk='the-string-starting-with-ey' \
name='my-node-kr-chuncheon' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

> `argo_cf_host` / `argo_cf_pt` are shared values (default `saas.sin.fan` / `443`); each protocol can also override them individually with `argo_vmess_cf_host` / `argo_trojan_cf_host` and the like.

### Combination 4: VMess(Argo) + Hysteria2 + VLESS-Reality

```bash
ippz=4 \
hypt=41001 \
vlrt=41002 \
argo=vmess \
agn='test-vmess.xxxx.xyz' \
agk='the-string-starting-with-ey' \
name='my-node-kr-chuncheon' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```


#### JSON token scenario (the JSON must be wrapped in single quotes)

```bash
uuid=00000000-0000-4000-8000-000000000001 \
ippz=4 \
vlrt=41003 \
hypt=41004 \
tupt=41005 \
argo='trojan' \
agn='northCarolina.xxxx.xyz' \
agk='{"AccountTag":"xxxxxxxxxxxxxx","TunnelSecret":"xxxxxxxxxxxxxx","TunnelID":"xxxxxxxxxxxxxx","Endpoint":""}' \
name='my-node-us-north-carolina' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

<a id="mod-4"></a>

## ④ Origin relay protocol snippet (ws_cdn: vmess / vless / trojan relayed through your own CDN back to nginx)

> Append it above the base command; if you do not enable the origin relay, skip this whole snippet (or delete the lines starting with `ws_cdn`); `ws_cdn` supports multiple selections (it can coexist with Argo). The subscription switch `subscribe` / subscription port `nginx_pt` have been moved into the "① Basic command".

```bash
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='cdn.example.com' \
ws_cdn_sni='cdn.example.com' \
ws_cdn_cf_pt=443 \
```

Each item is explained below.

### 1、 ws_cdn (VMess / VLESS / Trojan WS through CDN origin relay, without Argo)

Lets the WS nodes of vmess / vless / trojan go directly through your own **CDN / reverse proxy** to the server nginx (relaying to the server's `nginx_pt`, usually 8080), **without enabling cloudflared**.

```
client --wss--> CDN (ws_cdn_cf_pt, default 443) --http--> server nginx_pt --http--> sing-box ws port
```

- **Switch**: `ws_cdn=vmess,vless,trojan` (comma-separated, multiple selections allowed)
- **Each protocol can use a different domain** (applies to a Cloudflare origin rule wildcard domain + multiple origin domains sharing one A record); priority: `protocol-specific > shared ws_cdn_* > default saas.sin.fan/443`

| Variable | Description | Default |
|------|------|------|
| `ws_cdn` | Switch: vmess/vless/trojan, comma-separated | Empty (disabled) |
| `ws_cdn_vmess_cf_host` etc. | Per-protocol CF optimized domain (the connection address add) | Falls back to the shared `ws_cdn_cf_host` when empty |
| `ws_cdn_vmess_sni` etc. | Per-protocol origin domain (host/SNI) | Falls back to the shared `ws_cdn_sni` when empty |
| `ws_cdn_vmess_cf_pt` etc. | Per-protocol CF optimized port | Falls back to the shared `ws_cdn_cf_pt` when empty |
| `ws_cdn_cf_host` | Shared CF optimized domain (the fallback **connection address add** for each protocol; can be an optimized IP/domain) | Falls back to the default `saas.sin.fan` when empty |
| `ws_cdn_sni` | Shared origin domain (the real origin domain; used as the node host/SNI and as the **subscription URL** domain; Cloudflare matches its origin rule on this domain and forwards to your `nginx_pt`) | Falls back to that protocol's `ws_cdn_*_cf_host` when empty (ultimately `saas.sin.fan`; no fallback when the host is an IP) |
| `ws_cdn_cf_pt` | Shared CDN port (https-family ports only) | 443 |

### 2、 Full example (shared + per-protocol mix)

> vless and trojan use different CF domains (which also serve as the origin SNI), vmess uses the shared one:

```bash
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='cdn.example.com' \
ws_cdn_vless_cf_host='vless.example.com' \
ws_cdn_trojan_cf_host='trojan.example.com' \
subscribe=true \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) ins
```

### 3、 Origin port

The CDN relays to the server's `nginx_pt` (default 8080); in the Cloudflare dashboard point the origin to that port (or use an origin rule wildcard-domain origin relay).

### 4、 Which domain does the subscription URL use (automatic decision)

In the order ①→②→③→④→⑤, the first available one is used:

```
① Fixed Argo tunnel domain (not trycloudflare, and the tunnel is alive) → https://fixed-Argo-domain/sub/{uuid}
 ↓ No fixed Argo or the tunnel is dead
② Shared origin domain ws_cdn_sni → https://shared-origin-domain:port/sub/{uuid}
 ↓ Not configured
③ Per-protocol origin domain (vmess → vless → trojan, the first non-empty one) → https://per-protocol-origin-domain:port/sub/{uuid}
 ↓ Not configured
④ Temporary Argo domain (xxx.trycloudflare.com, tunnel alive) → https://temporary-domain/sub/{uuid}
 ↓ No Argo
⑤ http://server-IP:nginx_pt/sub/{uuid} (plaintext, contains the node secret; recommended only on trusted networks)
```

- **When a fixed Argo exists, none of ②③④ needs to be configured**: the subscription URL is simply `https://fixed-Argo-domain/sub/{uuid}`.
- The purpose of the origin domains (②③): when there is no fixed Argo, they let the subscription go through a stable https domain instead of plaintext HTTP.

- **Why any one of the origin domains works**: in Cloudflare, the origin domains all relay via an Origin Rule/DNS to **the same nginx port (nginx_pt, default 8080)**, and nginx uses `server_name _` (it does not distinguish hostnames and works by path). So `vmess.example.com/sub/{uuid}`, `vless.example.com/sub/{uuid}`, `trojan.example.com/sub/{uuid}` — **any one of them can reach the subscription**; whichever you use, it works.

**How ②③ fall through to the next non-empty one** (assuming ws_cdn is enabled):

| Origin domains you configured | Domain used by the subscription URL | Notes |
|---|---|---|
| `ws_cdn_sni=cdn.example.com`, any protocol has a per-protocol one | `cdn.example.com` | **Shared takes priority** (②), the per-protocol one is unused |
| Shared empty, `ws_cdn_vmess_sni=vm.example.com` set | `vm.example.com` | ③ the first non-empty in the fixed order |
| Shared empty, vmess empty, `ws_cdn_vless_sni=vl.example.com` set | `vl.example.com` | **Skips the empty vmess and falls through to vless** |
| Shared empty, both vmess/vless empty, `ws_cdn_trojan_sni=tr.example.com` set | `tr.example.com` | Falls through to trojan |
| Shared + all three per-protocol empty | (no origin domain) → falls through to ④⑤ | Only when every origin domain is empty does it keep falling |

> It does not matter how many of these parameters you set or in which order: **as long as one origin domain is non-empty that is enough**; the rule is always "shared ws_cdn_sni → vmess → vless → trojan, take the first non-empty"; only when all origin domains are empty does it move on to "④ temporary Argo → ⑤ http".

**Coexisting with Argo**: you can enable `ws_cdn` and `argo` at the same time; nodes from both are output (they share the same local ws port and the nginx reverse proxy; only the client handshake domain differs).

<a id="cf-origin"></a>
### 5、 🌐 How to configure the CF (Cloudflare) origin rule? (⚠️ all three steps are required)

> [!IMPORTANT]
> **All three steps are required: ① Origin Rules to change the origin port → ② add DNS records → ③ set the SSL mode to "Flexible".**
> The easiest one to miss is ③: if you miss it, all WS-CDN nodes go down (525), while Argo / direct connections stay fine.

| Step | What to do | What happens if missed |
|---|---|---|
| **①** | Origin Rules: change the origin port of `*node.yourdomain` to `nginx_pt` | **521 / 522 / 523** |
| **②** | Add an **A record** for every domain used as SNI | **530 (Origin DNS Error)** |
| **③** | The node subdomain's **SSL/TLS = Flexible** | **525 (SSL Handshake Failed)** |

WS-CDN origin relay chain: `client → CDN(ws_cdn_cf_pt) → server nginx_pt (default 8080)`.

#### Step 1: 🟦 Add the origin port rule (Origin Rules)

Go into Cloudflare, click the specific domain (e.g. `xxxx.nyc.mn`) → **Rules** → **Page Rules**; in the **traffic sequence** on the right side of the page find **Origin Rules · change the target origin server**, click it → click **+ Create rule** at the top right (the blue button) → select **origin server rules** to enter **Origin Rules**:

- Fill in a rule name, e.g. `xxxx.nyc.mn-31007`
- Select **custom filter expression**:
  - **Field** choose **Hostname**
  - **Operator** choose **Wildcard**
  - **Value** enter `*node.xxxx.nyc.mn`
- Then rewrite the **destination port** below to **31007** (this 31007 port is the value of your **nginx subscription port `nginx_pt`**; fill in your actual `nginx_pt`)

> The `*node.xxxx.nyc.mn` wildcard in the rule covers the three origin domains you actually use: `vmess` / `vless` / `trojan` (these 3 protocols can share one origin domain, or use three different domains).

#### Step 2: 🟩 Add DNS records

Add the following three **A records**, where `192.9.100.***` is the IPv4 of your VPS (server):

```
vmess-node.xxxx.nyc.mn    →  192.9.100.***   (the little orange cloud can be on or off)
vless-node.xxxx.nyc.mn    →  192.9.100.***   (the little orange cloud can be on or off)
trojan-node.xxxx.nyc.mn   →  192.9.100.***   (the little orange cloud can be on or off)
```

- You can use one DNS record per protocol, or one DNS record shared by all 3 protocols; this subdomain record points to **the same IPv4** (the same server), and together with the Origin Rules wildcard above it relays to `nginx_pt`.
- The `little orange cloud` (Cloudflare's orange-cloud proxy) can be on or off — on = goes through the CDN with CDN TLS termination, off = the CDN still reverse-proxies to nginx just the same.
- **⚠️ The origin domains used as SNI must have DNS records**: the `sni/host` in the node comes from `ws_cdn_vmess_sni` / `ws_cdn_vless_sni` / `ws_cdn_trojan_sni` (falling back to `ws_cdn_sni` when no per-protocol one is set). Whichever record is missing, the corresponding node reports **530 (Origin DNS Error)**.

#### Step 3: 🟥 The SSL encryption mode must be set to "Flexible" (otherwise the origin relay always gets 525)

> [!CAUTION]
> **This is the easiest step to miss, and if missed all three CDN nodes become unreachable.**
> Symptom: Argo / direct connections are all fine, only the WS-CDN nodes fail — come back here and check first.

As long as the A record has the **orange cloud (Proxied)** enabled, Cloudflare first terminates TLS for the client, then **opens another connection to the origin**. Which protocol that second connection uses is decided by this domain's (or subdomain's) **SSL/TLS encryption mode**:

| Encryption mode | Connection from the edge → origin nginx_pt | Result |
|---|---|---|
| Full / Full (strict) | Connects to nginx_pt with **TLS**, but nginx only speaks HTTP | ❌ Handshake fails → **525** |
| **Flexible** | Connects to nginx_pt with **plaintext HTTP** | ✅ Works |

**Method A (recommended; only affects the node subdomain, leaves the rest of the site alone): configure a rule**

1. Cloudflare dashboard → select the domain `xxxx.nyc.mn` → left side **Rules** → top tab select **Configuration Rules** (⚠️ not **Page Rules**, and not the **Origin Rules** used above)
2. Click **Create rule**
   - **Rule name**: anything, e.g. `node-origin-relay-plaintext`
   - **Expression** (custom filter expression): Field choose **Hostname**, Operator choose **Wildcard**, Value enter `*node.xxxx.nyc.mn`
   - **Then** action: choose **SSL**, value choose **Flexible**
3. **Save / Deploy**

**Method B (simple, applies to the whole zone)**: `domain → SSL/TLS → Encryption mode → Flexible`. If other services live under this domain, prefer Method A to avoid affecting them.

> Whichever you choose, **the client → Cloudflare leg is always HTTPS** (the node links stay unchanged); only the Cloudflare → your server leg becomes plaintext HTTP. If you must keep the whole chain encrypted (Full / Full strict), you would have to configure a TLS certificate for the server's nginx_pt (which means modifying the script — much more work), otherwise "Flexible" is the only option.

#### Step 4: 🔎 Quick mapping to the script parameters

| Where you set it | Corresponding script variable | Notes |
|---|---|---|
| The origin domain in the A record | `ws_cdn_vmess_sni` / `ws_cdn_vless_sni` / `ws_cdn_trojan_sni` (you can also fill the same value into the matching `_cf_host`) | Serves as the node SNI and usually also as the client connection address |
| The destination port in Origin Rules | `nginx_pt` (default 8080) | The port the CDN relays to on the server nginx |
| The port the client uses to reach the CDN | `ws_cdn_cf_pt` (default 443) | The CDN's external HTTPS port |
| Per-protocol / shared SNI (real domain) | `ws_cdn_vmess_sni` etc. / `ws_cdn_sni` | One of the origin domains from the A records above |
| CF's SSL/TLS encryption mode | No script variable (Cloudflare dashboard) | The node subdomain must be "Flexible", otherwise the origin relay gets 525 |

### 6、 Troubleshooting: the three CDN nodes are unreachable? Match the error first

> Typical symptom: **the Argo nodes and the direct-connection protocols all work fine, only the 3 WS-CDN nodes are unreachable**. Just work through the error codes below step by step.

| Symptom | Cloudflare error code | Cause | Fix |
|---|---|---|---|
| 🔴 vmess/vless/trojan-WS-CDN all down, Argo/direct fine | **525** | Orange-cloud record + SSL mode "Full / Full (strict)": Cloudflare relays with TLS while nginx_pt only speaks HTTP | Per **Step 3** above, set the node subdomain's SSL encryption mode to "Flexible" |
| 🟠 Only trojan-WS-CDN (or a single protocol) is down | **530** (Origin DNS Error) | The origin domain used as SNI by that protocol (e.g. `trojan-cdn-node.xxxx.nyc.mn`) **has no DNS record** | Add an A/CNAME record in DNS; see the warning in **Step 2** |
| 🟡 All WS / Argo are down | 521 / 522 / 523 | nginx is not running, the origin port is blocked by the firewall, or the Origin Rules port does not match | Check the `nginx` status, allow `nginx_pt` through the firewall, and verify the Origin Rules destination port is correct |



### Combination examples
> Common combination examples: each snippet can be copied whole and run as-is; delete a line to disable the corresponding feature.

### Combination 5: WS-CDN direct connection (no Argo; the client goes through your own CDN reverse proxy to the server nginx)

#### One shared CF optimized domain + shared origin domain for all three protocols

```bash
# ws_cdn_cf_host = shared CF optimized domain (the fallback connection address add for each protocol); ws_cdn_sni = shared origin domain (the real origin domain, also the subscription URL domain)
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='saas.sin.fan' \
ws_cdn_sni='cdn.example.com' \
subscribe=true \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### A different per-protocol domain for each protocol (CF optimized domain + origin domain, Cloudflare origin rule wildcard domain + multiple origin domains sharing one A record)

```bash
# Each protocol may use its own CF optimized domain (connection address) and its own origin domain (Host/SNI)
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='saas.sin.fan' \
ws_cdn_sni='cdn.example.com' \
ws_cdn_vmess_cf_host='vm.example.com' \
ws_cdn_vmess_sni='vm-cdn.example.com' \
ws_cdn_vless_cf_host='vl.example.com' \
ws_cdn_vless_sni='vl-cdn.example.com' \
ws_cdn_trojan_cf_host='tr.example.com' \
ws_cdn_trojan_sni='tr-cdn.example.com' \
subscribe=true \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

> The CDN origin port = the server's `nginx_pt` (default 8080). You can configure a fixed Argo alongside (both sets of nodes are output); if a fixed Argo exists the subscription URL uses it directly, and only when it does not does it use the origin domain `ws_cdn_sni` (or the per-protocol `ws_cdn_{p}_sni`).

> **The full command = ① the base command + any combination of protocol snippets** (append the chosen snippets in order above the base command, keeping only the `bash <(...) rep` line from the base command at the end). For example "direct + origin relay": ② the direct snippet + ④ the origin snippet + ① the base command, joined into one; "Argo only" is ③ the Argo snippet + ① the base command.




<a id="mod-5"></a>
## ⑤ Nginx module (when Nginx is installed · reverse proxy path overview)

### 1、 When is Nginx installed (quick reference)

Nginx is installed/configured only when any of the following holds:

| Scenario | subscribe subscription | argo | Nginx installed? |
|---|---|---|---|
| Pure direct connection (hy2/vless-reality/tuic/anytls/socks5) | Off | Off | ❌ Not installed |
| Argo only (argo=vmess/trojan/vless, multiple selections allowed) | Off | On | ✅ Installed (the Argo origin relay goes through the Nginx reverse proxy) |
| Subscription only | On | Off | ✅ Installed (serves the subscription URL externally) |
| Both Argo + subscription | On | On | ✅ Installed |

> Even without the subscription, enabling Argo alone installs Nginx: because the Argo data path is
> `cloudflared → 127.0.0.1:8001(Nginx) → the sing-box ws port`, and Nginx handles the path-based reverse proxying.

### 2、 Overview of the Nginx reverse proxy paths for each protocol

One Nginx configuration listens on `nginx_pt` (default 8080, external) and `127.0.0.1:argo_pt` (default 8001, local only, for the cloudflared origin relay); with `server_name _` it dispatches by path to each protocol's local sing-box port:

| Scenario | Nginx location path | Proxy target (sing-box local port) | Notes |
|---|---|---|---|
| VMess-WS (Argo origin relay) | `/{uuid}-vm` | `http://127.0.0.1:{vm_port}` | `{vm_port}` = `port_vm_ws`; path: cloudflared → 127.0.0.1:argo_pt → `/{uuid}-vm` |
| VLESS-WS (Argo origin relay) | `/{uuid}-vl` | `http://127.0.0.1:{vl_port}` | `{vl_port}` = `port_vl_ws` |
| Trojan-WS (Argo origin relay) | `/{uuid}-tr` | `http://127.0.0.1:{tr_port}` | `{tr_port}` = `port_tr` |
| VMess-WS (ws_cdn origin relay) | `/{uuid}-vm-cdn` | `http://127.0.0.1:{cdn_vm_port}` | `{cdn_vm_port}` = `port_vmess_ws_cdn`; path: CDN → nginx_pt → `/{uuid}-vm-cdn` |
| VLESS-WS (ws_cdn origin relay) | `/{uuid}-vl-cdn` | `http://127.0.0.1:{cdn_vl_port}` | `{cdn_vl_port}` = `port_vless_ws_cdn` |
| Trojan-WS (ws_cdn origin relay) | `/{uuid}-tr-cdn` | `http://127.0.0.1:{cdn_tr_port}` | `{cdn_tr_port}` = `port_trojan_ws_cdn` |
| Subscription output | `^~ /sub/{uuid}` | alias `/var/www/singbox/sub.txt` | Generated only when subscribe=true; external URL `http://IP:nginx_pt/sub/{uuid}` |
| All other paths | `/` | None (`return 404`) | Catch-all, prevents port scanning |

> `{uuid}` is the UUID assigned at install time; `port_vm_ws / port_vl_ws / port_tr` are the local ws ports of the Argo protocols, and `port_vmess_ws_cdn / port_vless_ws_cdn / port_trojan_ws_cdn` are the separate ws_cdn origin relay ports (all auto-randomized by the script or reused from the on-disk file, never exposed publicly).
> The direct-connection protocols (VLESS-Reality / Hysteria2 / TUIC / AnyTLS / Socks5) **do not go through Nginx**; the client connects straight to their own ports `vlrt / hypt / tupt / anypt / socks5pt`.


<a id="c2"></a>
# 2、 Full example

<a id="full-example"></a>
## 2.1 Aggregated node file (every selected protocol is written to jh.txt)

> Below, the base command + direct + Socks5 + Argo + origin relay are written together, purely as a variable-list reference. **`out_ip`, `direct_host`, `agn`, `agk`, `reality_private` are placeholder values and must be replaced with real values or the whole line deleted**, otherwise the installation fails; delete unneeded lines (including the trailing `\`) outright.

```bash
uuid=00000000-0000-4000-8000-000000000000 \
ippz=4 \
name='Doraemon-US California' \
nginx_pt=41007 \
subscribe=true \
out_ip='special-egress-IP' \
direct_host='your-external-domain' \
DEBUG_FLAG=0 \
hy_sni='www.apple.com' \
vl_sni='www.apple.com' \
vl_sni_pt=443 \
tu_sni='www.apple.com' \
any_sni='www.apple.com' \
vlrt=41003 \
hypt=41004 \
tupt=41005 \
anypt=41006 \
reality_private='GHxxxxxxxxxxxxx-xxxxxx-VnXH6FjxxA' \
socks5pt=41017 \
socks5_username='zhangsan' \
socks5_password='password' \
socks5_wl_flag=true \
socks5_ips='1.2.3.4,5.6.7.0/24' \
argo='vmess,vless,trojan' \
argo_cf_host='saas.sin.fan' \
argo_cf_pt=443 \
argo_pt=8001 \
agn='fixed-Argo-tunnel-domain' \
agk='fixed-Argo-tunnel-token' \
argo_vmess_cf_host='vm.example.com' \
argo_vmess_cf_pt=443 \
argo_vless_cf_host='vl.example.com' \
argo_vless_cf_pt=443 \
argo_trojan_cf_host='tr.example.com' \
argo_trojan_cf_pt=443 \
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='cdn.example.com' \
ws_cdn_sni='cdn.example.com' \
ws_cdn_cf_pt=443 \
ws_cdn_vmess_cf_host='vm-cdn.example.com' \
ws_cdn_vmess_sni='vm-cdn.example.com' \
ws_cdn_vmess_cf_pt=443 \
ws_cdn_vless_cf_host='vl-cdn.example.com' \
ws_cdn_vless_sni='vl-cdn.example.com' \
ws_cdn_vless_cf_pt=443 \
ws_cdn_trojan_cf_host='tr-cdn.example.com' \
ws_cdn_trojan_sni='tr-cdn.example.com' \
ws_cdn_trojan_cf_pt=443 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```





<a id="uninstall"></a>
## 2.2 How to uninstall
```bash
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) delall
```

> `delall`: similar in effect to `del`, but it **completely deletes** the sing-box folder (keeping no binary / configuration), i.e. a full uninstall.




### 3、 Service hosting and auto-start of the sandbox Nginx

The sandbox Nginx is installed under `$SINGBOX_FOLDER_PATH/nginx` (default `/root/doraemon/nginx`), using jirutka's static binaries; it **never touches the system `nginx` package and never writes `/etc/nginx`**. It can coexist with the system Nginx, each managing its own ports.

Since v3.2.24, the sandbox Nginx is hosted by the system service manager and no longer relies on a cron watchdog as a fallback:

| Item | systemd | openrc |
|---|---|---|
| Service name | `sb-nginx.service` | `/etc/init.d/sb-nginx` |
| Start at boot | `systemctl is-enabled sb-nginx` | `rc-update show default \| grep sb-nginx` |
| Process type | `Type=forking` + `PIDFile` | `supervise-daemon` (`command_background` if absent) |
| Auto-restart after being killed | `Restart=always`, `RestartSec=10s` | `respawn_delay=10` |
| Circuit breaker | `StartLimitBurst=5` / `StartLimitIntervalSec=300` | `respawn_max=5` / `respawn_period=300` |

A few design trade-offs:

- **The service name is fixed as `sb-nginx`**, so it never collides with the system's `nginx.service`, and `cleanup_nginx` deletes only this one file when uninstalling
- **`Restart=always` with a circuit breaker instead of infinite restarts**: Nginx failures (port occupied, bad configuration) are mostly persistent, and infinite restarts would only flood `error.log`; after 5 consecutive failures it stops in `failed` awaiting manual intervention, and starting it manually from the menu first runs `reset-failed` to clear the state
- **A manual stop is not auto-reverted**: after `systemctl stop sb-nginx` / `sb nginx_stop` the service stays `inactive`; this is normal systemd semantics — `Restart=always` only covers abnormal exits
- **The watchdog steps aside**: once the unit exists, the cron `singbox-watchdog.sh` that runs every 2 minutes skips its Nginx branch, avoiding both sides racing to start it and colliding on ports
- **The unit file carries a `# unit-rev: 2` marker**: on machines where an older version was installed, running the script again automatically rewrites the unit — no manual deletion needed

Common operations:

```bash
sb nginx_status     Check the Nginx status
sb nginx_start      Start (equivalent to systemctl start sb-nginx)
sb nginx_stop       Stop (Restart=always will not pull it back up)
sb nginx_restart    Restart
```

Field-tested (Debian 13): after `kill -9` on the master, it came back automatically at the 11th second; after `systemctl stop` it stayed down; after a full-machine `reboot` it started with the system, `NRestarts=0`, succeeding in one shot.


## 2.3 Protocol combination quick reference

| What you set | Nodes actually generated |
|---|---|
| A single direct connection (`hypt` / `vlrt` / `tupt` / `anypt` / `socks5pt`) | 1 |
| Multiple direct connections | Number of direct-connection protocols |
| `argo=vmess,trojan` etc. | Number of Argo protocols selected (1–3) |
| `ws_cdn=vmess,vless` etc. | Number of CDN origin relay protocols selected (1–3) |
| Direct + Argo + ws_cdn mixed | The three added together (no conflicts) |
| Example: `hypt` + `vlrt` + `argo=vmess,vless` + `ws_cdn=vmess` | 5 (2 direct + 2 Argo + 1 CDN) |
| Example: `argo=vmess` + `ws_cdn=vmess` | 2 (the same protocol can go through both Argo and CDN) |

## 2.4 Viewing logs

When sing-box or cloudflared fails to start, use the commands below to locate the problem.

> The following `doraemon` is the default install directory; if you changed `sb_dir` at install time, substitute the actual directory.

### Shortcut commands (recommended)

```bash
sb logs              Open the log menu (Sing-box / Argo / Nginx / install log)
sb log_sb 100        View the Sing-box run log (last 100 lines)
sb log_argo 100      View the Argo tunnel log (last 100 lines)
sb log_ins           View the most recent install log (full text)
sb log_stop          View the service-stop reason log (for crash troubleshooting)
```

### Manual viewing

```bash
# Follow the sing-box run log live (works in all modes)
tail -f /root/doraemon/logs/singbox.log

# View the latest 200 lines
tail -200 /root/doraemon/logs/singbox.log

# Follow the cloudflared run log live (nohup / temporary tunnel mode)
tail -f /root/doraemon/logs/argo.log

# View the latest 200 lines
tail -200 /root/doraemon/logs/argo.log
```


## 2.5 Firewall rule inspection (Debian/Ubuntu/Alpine universal)

### Viewing this script's rules

The script tags all rules via `--comment`, with two tags:

| Tag | Description |
|------|------|
| `doraemon_singbox_rule` | ACCEPT rules for all protocol ports (vmess/trojan/vless/socks5) |
| `socks5_rule` | Socks5 whitelist only (ACCEPT allow + DROP block) |

**IPv4:**
```bash
# View all script rules
iptables -S | grep -E "socks5_rule|doraemon_singbox_rule"

# View the full rule chains (with packet/byte counters)
iptables -L INPUT -n -v --line-numbers | grep -E "socks5_rule|doraemon_singbox_rule"

# View only the socks5 whitelist rules
iptables -S | grep socks5_rule
```

**IPv6:**
```bash
ip6tables -S | grep -E "socks5_rule|doraemon_singbox_rule"
ip6tables -L INPUT -n -v --line-numbers | grep -E "socks5_rule|doraemon_singbox_rule"
```

### What a healthy rule state looks like

- **Whitelist off**: every port has only ACCEPT rules tagged `doraemon_singbox_rule`
  - TCP protocols (vmess/trojan/vless/anytls/socks5) → TCP rules
  - UDP protocols (hy2/tuic) → UDP rules
- **Whitelist on**:
  - `doraemon_singbox_rule`: ACCEPT rules for the other protocol ports (the socks5 port excluded)
  - `socks5_rule`: ACCEPT rules for the socks5 port (one TCP rule per whitelisted IP) + one DROP default rule (TCP)

### Checking rule persistence

After a reboot the rules are restored automatically by systemd/OpenRC. Check the persistence files:

```bash
# Debian/Ubuntu
cat /etc/iptables/rules.v4
cat /etc/iptables/rules.v6

# Alpine (same paths)
cat /etc/iptables/rules.v4
cat /etc/iptables/rules.v6
```

### Checking the whitelist state

```bash
# View the whitelist switch
cat /root/doraemon/socks5_wl_flag

# View the whitelist IP list
cat /root/doraemon/socks5_ips

# View the socks5 port
cat /root/doraemon/port_socks5
```


## 2.6 sb shortcut commands

After installation the system gets the `sb` shortcut command; the common commands are:

```
sb                 Open the main menu
sb ins             Install nodes
sb rep             Overwriting install / reset
sb list            View node information
sb list key        View nodes + the vless Reality private key
sb res             Restart sing-box and cloudflared
sb rt              Routing management
sb node            Node configuration edit (ports/subscription/SNI/Argo/identity/server address)
sb sub             Subscription management
sb report          Report nodes to sub-merge (the automatic report layer)
sb report status   View the report status (switch / most recent time and result / address / credential)
sb report on|off   Turn automatic reporting on/off
sb rstatus         Same as sb report status
sb del             Uninstall (keeps the binaries)
sb delall          Uninstall everything and clean up
sb ups             Update the sing-box kernel
sb opt             System optimization (auto-selects the Alpine/Debian/Ubuntu backend per OS; leaves SSH alone by default)
sb opt upgrade     Optimize + upgrade system packages (apk / apt)
sb opt menu        Open the system optimization submenu (same as the main menu [14])
sb sc              Create/refresh this shortcut command
sb sc_off          Delete this shortcut command
sb autostart       Enable start at boot
sb autostart_off   Disable start at boot
sb nginx_start     Start Nginx
sb nginx_stop      Stop Nginx
sb nginx_restart   Restart Nginx
sb nginx_status    Check the Nginx status
sb logs            Open the log menu (Sing-box/Argo/Nginx/install log)
sb log_sb 100      View the Sing-box run log (last 100 lines)
sb log_argo 100    View the Argo tunnel log (last 100 lines)
sb log_ins         View the most recent install log (full text)
sb log_stop        View the service-stop reason log (for crash troubleshooting)
```

## 2.6.1 Reporting nodes to sub-merge (added in v3.2.29)

Uploads every node link from the local `jh.txt` to your own subscription aggregation service (sub-merge); the server stores it as this machine's "automatic report" layer and it enters the merged subscription immediately; the local manual layer is unaffected. Both `sb.sh` and `sb00.sh` support this (identical except for `SB_SCRIPT_NAME`).

**Reporting is off by default**. Two ways to use it:

```
sb report           # One manual report (one command when the configuration already exists)
sb                  # Main menu → [13] Report to sub-merge (config / preview / report / automatic switch)
```

Automatic reporting is controlled by `REPORT_FLAG`; it pushes only when it equals `1`, after each node generation:

```bash
# Carry the trio along with the install and configure everything in one go (the values are persisted; you won't need them next time)
REPORT_FLAG=1 \
REPORT_BASE=https://your-sub-merge-domain \
REPORT_TOKEN=<report-credential> \
bash <(curl -Ls ...)    # or configure it by hand in sb report
```

- `REPORT_BASE` **has no default**: everyone's sub-merge domain is different, so you must fill in your own; if left empty, the upload is skipped outright with a notice (it is never silently sent to someone else's domain)
- Machine-name resolution priority: `REPORT_MACHINE` (delivered by the web UI, whose value is ④'s `name`) > `SUBMERGE_MACHINE` in the config file > `/root/doraemon/name` (the node-name prefix entered at install time) > the server hostname. In other words, **only when `REPORT_MACHINE` is missing or empty does it fall back to `name`**
- Source can be left empty by default (the server records an empty source as `default` anyway); fill it in only when one machine must be split into several data sets
- `REPORT_FLAG` unset or `0` → after generating nodes, do nothing (the default behavior)
- `REPORT_FLAG=1` → after each `sb ins / rep / sub` node generation, one push is made automatically; a failure is only a yellow notice at the end and does not affect node generation
- You can also skip the environment variables and enter the `sb report` submenu, choosing `2) Turn on automatic reporting`; the switch is written into the config file
- Every report (manual / automatic) records its result in `/root/doraemon/submerge.state`; check anytime with `sb report status` or submenu item `1)`

#### A complete copy-paste-ready form (the four variables, line by line)

```bash
REPORT_FLAG='1' \
REPORT_BASE='sub.******.de5.net' \
REPORT_TOKEN='6a4a254255397ced700008cc9fd7df958035be1df0000ad' \
REPORT_EXCLUDE='socks5' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

| Variable | Meaning |
| --- | --- |
| `REPORT_FLAG='1'` | **The master switch for automatic reporting**: `1`=on, `0`/unset=off (default). When on, every `sb ins` / `sb rep` / `sb sub` node generation pushes once to sub-merge automatically; a failed push is only a yellow notice at the end and does not affect node generation. |
| `REPORT_BASE='sub.******.de5.net'` | **Your own sub-merge domain** (not the sing-box node domain — the aggregation subscription site). The script has no default at all; if you leave it empty, the report is skipped. **Writing `https://` or not both work**: the script normalizes before persisting — trims surrounding whitespace and the trailing slash; **when no scheme is written** it auto-adds `https://`; **if you wrote `http://` yourself it is used as-is, with no forced upgrade** (self-hosted reverse proxies and intranet http environments work; but sub-merge on Cloudflare Workers only accepts https — with `http://` you would be rejected by a 301, the script fixes it for you, so write it correctly yourself). The reason for adding the scheme: the report always uses `curl -sS -m 20 -X POST`, without `-L` (`-L` would downgrade the POST to a GET); a bare domain is sent by curl as `http://`, and after the server 301-redirects to https the script only gets the 301, which it judges as `❌ Report failed (HTTP 301)`. |
| `REPORT_TOKEN='6a4a…0000ad'` | **The report credential**, the `REPORT_TOKEN` that sub-merge gives you. Note: **do not use the main subscription token** — calling the report API with it returns 401. The credential is persisted with 600 permissions to `/root/doraemon/submerge.conf`, after which `sb report status` shows only the first few masked digits. |
| `REPORT_EXCLUDE='socks5'` | **Node types excluded from reporting**, comma-separated in English. **If left empty = nothing is intercepted, everything is reported** (the script applies no default exclusions; but **when the web UI generates the command it pre-checks Socks5 by default**, and accordingly delivers `REPORT_EXCLUDE='socks5'` explicitly — the filter scope follows the UI's checkboxes; run the script by hand without it and nothing is filtered at all). The `socks5` in the example above is just an example — most clients cannot consume socks5 nodes, and mixing them into the subscription spams the client with errors, so you may uncheck them as needed. Allowed values: `vless` `vmess` `trojan` `hysteria2` (also accepts `hy2`/`hy`/`hysteria`) `tuic` `anytls` `socks5`, plus the per-generated-form variants `vless-reality` `vless-argo` `vless-cdn` `vmess-argo` `vmess-cdn` `trojan-argo` `trojan-cdn`; writing `vless` excludes all three vless forms at once. To go back to "report everything": omit the variable, or clear the exclusion items in the `sb report` menu — either works; passing an empty string `` also works, and the script treats it as "not filled". |

A few additions:

- Wrap all four values in single quotes: only then do characters like `#` `?` `&` inside the token survive the shell intact. Note that an empty string `REPORT_XXX=''` equals "not passed" — the script tests emptiness with `-n`, and an empty value is never written to the config file (which is exactly why clearing the exclusion list requires the `-` placeholder, see above).
- This command only needs to run once: as long as a `REPORT_*` value is non-empty it is written to `/root/doraemon/submerge.conf` (root:root, 600); next time a plain `sb rep` needs none of them; to change a value, pass the new one again, or enter the `sb report` submenu and choose `3)`.
- Order does not matter, and the variables need not sit on the same line as `bash <(...)` (the `\` continuations are just for readability); but under `sudo` the environment variables get dropped by sudo, so run it directly as root, or write `sudo REPORT_FLAG=1 … bash <(...)`.

Submenu:

```
1) View the report status (switch / most recent time and result / address / credential)
2) Report the current nodes immediately
3) Edit the report configuration (address / credential / machine name / source)
4) View the report configuration (masked credential + automatic report switch state)
5) Preview before upload (node count / base64 length / target address)
6) Toggle the automatic report switch (on / off, written into the config file)
7) Clear the report configuration (the state record is cleared with it)
```

### Report status query (added in v3.2.31)

Report results are persisted to disk, and automatic reports triggered by install / overwriting install / config changes are recorded the same way:

```bash
sb report status     # or sb rstatus, or main menu [13] → 1)
```

Example output:

```
========= Report status =========
  Automatic reporting: on (1)
    Switch source: SUBMERGE_AUTO in /root/doraemon/submerge.conf
  Report address: https://sub.yourdomain/api/v1/report/Doraemon-Dan-US North Carolina
  Report credential: 6a4a25****44ad
  Machine name　: hk-1    Source: airportA

  Most recent: 2026-11-02 18:53:55  Success (HTTP 200)
    Result: content updated, 6 nodes (automatic 6 + manual 0)
    Nodes: 6
    Target: https://sub.yourdomain/api/v1/report/Doraemon-Dan-US North Carolina
  Last success: 2026-11-02 18:53:55
  State file: /root/doraemon/submerge.state
  Config file: /root/doraemon/submerge.conf
```

- Switch: shows on/off and where the value came from (the environment variable `REPORT_FLAG` takes priority over the config file)
- Address: the full report path (including `?source=`, ready to copy for other machines)
- Credential: masked display (first 6 digits + last 4 digits)
- Most recent: time + success/failure + HTTP code + result note + node count; the "last success" time is stored separately and a failure does not overwrite it
- State file `/root/doraemon/submerge.state` (root:root, 600, re-`chmod 600` after every script write), keys: `LAST_TIME` `LAST_RESULT` `LAST_HTTP` `LAST_MSG` `LAST_NODES` `LAST_MACHINE` `LAST_SOURCE` `LAST_URL` `LAST_OK_TIME`
- Automatic reports are recorded too: after `sb ins` / `sb rep` / `sb sub` / a config change, as long as the switch is on, a result entry is written

The configuration is persisted in `/root/doraemon/submerge.conf` (owner root, permissions 600, readable only by root; it contains the report credential, so keep it private. Changing the credential, toggling reporting, or changing the address rewrites this file, and the script re-`chmod 600`s it after every write, so a loose umask never loosens it):

```
SUBMERGE_BASE=https://your-sub-merge-domain   # Required, no default
SUBMERGE_TOKEN=<report credential REPORT_TOKEN>      # Required, only REPORT_TOKEN is accepted
SUBMERGE_MACHINE=Doraemon-Dan-US North Carolina    # Optional: defaults to name from the global config
SUBMERGE_SOURCE=                            # Optional: empty means default; fill it only for multiple sources
SUBMERGE_AUTO=0                  # Automatic report switch: 0 off (default) / 1 on
```

Mapping between the environment variables and what gets persisted (any value you provide is written to the file above, and then it takes effect even without the environment variables):

| Environment variable | Persisted key | Notes |
| --- | --- | --- |
| `REPORT_FLAG` | `SUBMERGE_AUTO` | Only `1` enables automatic reporting; default `0` |
| `REPORT_BASE` | `SUBMERGE_BASE` | Your own sub-merge domain (required, no default; the `https://` may be omitted — the script adds it) |
| `REPORT_TOKEN` | `SUBMERGE_TOKEN` | Report credential (only `REPORT_TOKEN` is accepted; the main token gets 401) |
| `REPORT_MACHINE` | `SUBMERGE_MACHINE` | Machine name; the web UI delivers ④'s `name` as its value. It falls back to `name` only when missing/empty, then to the hostname |
| `REPORT_EXCLUDE` | `SUBMERGE_EXCLUDE` | Protocols excluded from reporting (**if the script is not given it = nothing filtered, everything reported**; the UI pre-checks Socks5 and delivers it explicitly), comma-separated in English; allowed `hysteria2 tuic anytls socks5 vless-reality vless-argo vmess-argo trojan-argo vless-cdn vmess-cdn trojan-cdn` (prefixes like `vless`/`trojan` are also accepted and exclude every form of that protocol at once); empty = report everything |
| `REPORT_SOURCE` | `SUBMERGE_SOURCE` | Source name, default `default` |
| `REPORT_CLEAR` | — | When `1`, first wipes `submerge.conf` back to defaults (address/credential/machine name/source emptied, exclusions back to `socks5`, automatic reporting off), then applies the overwriting logic above. To "clear", use this — not an empty string. **Never put it in a persistent environment variable** (e.g. a workflow's `env:`) — that would wipe once on every run and the configuration would never stick; within a single process it takes effect only once |

Priority: environment variables > config file > defaults (any value you provide is written back to `submerge.conf`, so a new value is never suppressed by an old one).

Two things that "passing an empty string" cannot express, worth stating separately:

- **Clearing**: `REPORT_TOKEN=""` and not passing `REPORT_TOKEN` at all are indistinguishable under the `[ -n "${REPORT_TOKEN:-}" ]` check; and in CI, an unconfigured `secrets.REPORT_TOKEN` is exactly an empty string, so using an empty string to mean "clear it" would break other people's workflows. That is why clearing goes through `REPORT_CLEAR=1`: `REPORT_CLEAR=1 bash <(curl -Ls ...) rep`. Passing `REPORT_*` in the same command clears first, then fills
- **Uninstalling keeps this file**: `sb del`'s whitelist includes `submerge.conf` (kept along with `sing-box`/`cloudflared`/`logs`/`nginx`), because `SUBMERGE_TOKEN` can only be re-created in the sub-merge dashboard — of everything, it is the hardest to restore after a reinstall. `submerge.state` (last report time etc.) is still deleted, avoiding stale records after a reinstall. To wipe everything, use `sb delall` (deletes the whole directory), or enter `-` in the address field of submenu item `3) Edit the configuration`, or run `REPORT_CLEAR=1` once

- **Credential**: only sub-merge's `REPORT_TOKEN` is accepted; reporting with the main subscription token gets a 401 rejection (a leaked subscription link also grants write access to nothing)
- **Content**: the script base64-encodes the whole `jh.txt` and POSTs it automatically — no manual encoding; if `jh.txt` does not exist it is regenerated from the current configuration first
- **Idempotency**: when the content is unchanged the server returns `changed:false` and skips the database write; the script states clearly that "the content is identical to last time"
- **Chinese machine names supported**: internally percent-encoded, so names like `Doraemon-Dan-US North Carolina` can be filled in as-is
- **Failure notices**: HTTP 401 (bad credential), 400 (bad machine name / content), 413 (over 512 KB), or an unreachable domain each produce their corresponding notice

## 2.7 Changelog

v3.2.76 (2026-11-09)
 > The system optimization submenu was collapsed to two items based on actual usage: `[1]` optimize now (default, does not change the SSH login policy), `[2]` optimize + upgrade system packages (apk / apt), plus `[0]` back. The dry run and "allow changing SSH" options were removed from the menu and the shortcut commands (`sb opt dry` / `sb opt ssh` still work, they are just no longer listed publicly).

v3.2.75 (2026-11-09)
 > System optimization was upgraded from a "one-shot direct command" to a "submenu": the main menu [14] now offers Optimize now / Dry run / Optimize + upgrade packages / Allow changing SSH.

- add `os_tune_menu()`: the main menu `[14] System Optimization (opt)` no longer starts directly, instead it enters a submenu (1 optimize now, 2 dry run, 3 optimize + upgrade, 4 optimize and change SSH, 0 back)
- add the shortcut command `sb opt menu` (equivalent to main menu [14]); the existing `sb opt` / `sb opt dry` / `sb opt upgrade` / `sb opt ssh` behavior is completely unchanged
- choosing 4 (change SSH) adds an extra `y/N` confirmation to avoid accidentally enabling password login
- on non-Alpine/Debian/Ubuntu systems, entering the submenu immediately reports that the system is out of scope
- sync: the "sb shortcut command quick reference" table in `singbox-tools-interface` gains these 5 entries

v3.2.74 (2026-11-09)
 > Fix the download order introduced in 3.2.73: the CDN behind raw direct links keeps stale copies for a long time and even `?ts=` cannot suppress it, resulting in "an old vps-tune being downloaded".

- tested in practice: `https://raw.githubusercontent.com/jyucoeng/vps-tune/main/vps-tune.sh?ts=…` still returned v1.0.0 on Debian 12 (md5 mismatch), and because the file was syntactically valid, the `bash -n` check passed too → it was treated as a "successful download" and silently ran the old logic
- fix: `os_tune_fetch()` now prefers the **GitHub API `contents` endpoint** (`Accept: application/vnd.github.raw`, which bypasses that CDN cache layer); if the API fails (rate limit / 403) it falls back to the raw direct link; it still only writes to disk after the `grep vps-tune` + `bash -n` double validation
- sync: `vps-tune`'s own backend downloads (`tune-alpine.sh` / `tune-debian.sh`) were also switched to API-first (vps-tune v1.0.2), and the bug where the download progress written to stdout polluted `$(resolve_backend)` was fixed (v1.0.3)

v3.2.73 (2026-11-09)
 > System optimization expanded from "Alpine only" to "auto-selected by OS": the external link now points to the new repo jyucoeng/vps-tune, and Debian / Ubuntu automatically get sysctl / BBR / journald / limits tuning too.

- the new repo [jyucoeng/vps-tune](https://github.com/jyucoeng/vps-tune) (v1.0.0) merges the two scripts into a single entry point: `vps-tune.sh` detects Alpine / Debian / Ubuntu → `tune-alpine.sh` (formerly alpine-onekey v2.1) / `tune-debian.sh` (formerly ovz-tune v1.1.0)
- renames on the sb side: `ALPINE_OPT_URL/FILE/ARGS/ON_INSTALL` → `OS_TUNE_URL` / `OS_TUNE_API` / `OS_TUNE_FILE` (`$SINGBOX_FOLDER_PATH/vps-tune.sh`) / `OS_TUNE_ARGS` / `OS_TUNE_ON_INSTALL`; `is_alpine` + `alpine_optimize` → `is_tunable_os` + `os_tune`. The old variables `ALPINE_OPT_ARGS` / `ALPINE_OPT_ON_INSTALL` remain compatible as default values
- `is_tunable_os()` recognizes both `/etc/alpine-release` and the `ID`/`ID_LIKE` (debian / ubuntu families) of `/etc/os-release`; anything outside these three families is skipped directly
- the download still has two paths: raw direct link (with `?ts=` to bypass the CDN) → on failure the GitHub API `contents` endpoint (`Accept: application/vnd.github.raw`) → then falls back to the local cache; before writing to disk, the `grep vps-tune` + `bash -n` double validation runs, and HTML error pages are rejected
- semantic change: `os_tune run` passes `--apply`, and `os_tune dry-run` passes `--dry-run` (vps-tune defaults to a dry run, the opposite of the old script's default of applying); `--ssh` still needs to be given explicitly and sshd is not touched by default
- the menu [14] and `sb opt` wording changed to "System Optimization"; the item now also appears on Debian / Ubuntu machines; `sb opt upgrade` upgrades packages on both systems (apk / apt)
- compatibility: the four subcommands `sb opt` / `opt dry` / `opt upgrade` / `opt ssh` behave unchanged

v3.2.72 (2026-11-09)
 > Third fix for the openrc `sb-nginx` service: `status` still reported stopped, and `stop` crashed start-stop-daemon.

- two pitfalls of this machine's `start-stop-daemon` (openrc 0.62.6) found in testing:
  - it does not support `--remove-pidfile` → `unrecognized option` + usage printed
  - using `--test --stop --retry 10` together causes a **Segmentation fault**
  3.2.71's `stop()` used both, so `rc-service sb-nginx restart` spewed a pile of usage lines + `Segmentation fault`
- openrc's `rc-service X status` does not call our overridden `started()` and still reports `stopped`; `status()` must be overridden explicitly too
- the final 3.2.72 shape (`unit-rev: 5`): `started()` first checks whether the pidfile exists before running `--test --stop --quiet`; `status()` directly does `echo "status: started|stopped"` and returns 0/3; `start()` returns 0 idempotently if already running, otherwise it first removes a leftover pidfile and then starts with `eval set -- $command_args`; `stop()` only sends SIGTERM (no --retry/--remove-pidfile) + `rm -f` on the pidfile; `reload()` sends HUP based on the pidfile

v3.2.71 (2026-11-09)
 > Finishing what 3.2.70 left behind: under openrc, `sb-nginx`'s `status` / `stop` / `start` still failed to recognize nginx.

- after 3.2.70 removed `supervise-daemon`, openrc's built-in `started()` cannot recognize daemons where "the command forked and exited but the process is still alive", producing a triple failure:
  - `rc-service sb-nginx status` → `stopped` (while actually running)
  - `rc-service sb-nginx stop` → `WARNING: sb-nginx is already stopped` (fails to stop the real master)
  - `rc-service sb-nginx start` → `start-stop-daemon: nginx is already running` → `Failed to start`
  In testing, `start-stop-daemon --test --stop --pidfile … --exec …` returned 0 (deemed running), proving that only openrc's detection logic was wrong
- fix: in `/etc/init.d/sb-nginx` explicitly override `started()` / `start()` / `stop()`, all switched to `start-stop-daemon --pidfile … --exec …` for detection and signaling; `reload()` likewise sends HUP based on the pidfile. If `start()` finds it already running it returns 0 directly (idempotent)
- the template marker `unit-rev: 3` → `unit-rev: 4`; on old machines the next `ins`/`rep`/`sb nginx_start` rewrites the unit automatically
- Alpine's official `main/nginx/nginx.initd` also follows the "only command + pidfile" approach, but its stop relies on openrc's default `started()`; in our script nginx is a standalone sandboxed instance run with `-p`, so the override is explicit

v3.2.70 (2026-11-09)
 > Fix the Alpine(openrc) `sb-nginx` service always showing `stopped` and the nginx error.log being flooded with `bind() ... failed (98: Address in use)`.

- root cause: the openrc template attached `supervisor="supervise-daemon"` to nginx, but nginx.conf contains `daemon on;` — the nginx parent process exits immediately after forking, supervise-daemon considers it crashed and re-pulls it every 10 seconds (`respawn_max=5`); each re-pull collides with ports `31007`/`8001` already held by the real master, so after
  `[emerg] bind() to [::]:31007 failed (98: Address in use)` × 5 it gives up. End result: `rc-service sb-nginx status` = **stopped** (while actually running), error.log gains 15 junk lines per install, and `rc-service sb-nginx stop` cannot stop the real master
- reproduction: Alpine 3.22 on a 122MB small box; on machines with `sb-nginx` installed, `grep -c 'Address in use' /root/doraemon/nginx/logs/error.log` grows by +15 on every `ins`/`rep`
- fix: the openrc template now follows Alpine's official `main/nginx/nginx.initd` approach — **only `command` + `pidfile`, no supervisor and no command_background**; nginx writes its own pid file and openrc uses the pidfile to determine start/stop/status; also adds `reload()` (`start-stop-daemon --signal HUP`)
- template marker `unit-rev: 2` → `unit-rev: 3`; on old machines the next `ins`/`rep`/`sb nginx_start` rewrites `/etc/init.d/sb-nginx` automatically
- trade-off: no more automatic restart (upstream nginx has none either), in exchange for accurate status, a stop that really stops, and clean logs; the systemd side was already `Type=forking` + `PIDFile` and is unchanged
v3.2.69 (2026-11-09)
 > GitHub's `releases/download` path intermittently returns **504 Gateway Time-out** (an HTML error page), leaving `rep` stuck downloading the sing-box binary. Downloads now use a three-level fallback: this repo's direct link → this repo's **REST API asset endpoint** → the upstream `SagerNet/sing-box` asset with the same name. cloudflared is handled the same way.

- symptom: on an Alpine machine running `rep`, `update_singbox` printed `❌ downloaded content is abnormal (suspected HTML error page)`, and the same URL might not open in a browser or from other machines either; all 3 retries got `http=504`
- root cause: `https://github.com/<repo>/releases/download/<tag>/<file>` 302-redirects to `objects.githubusercontent.com`, and this CDN path was persistently 504-ing this time. The **same asset** fetched via `https://api.github.com/repos/<repo>/releases/assets/<id>` (with `Accept: application/octet-stream`) returned the full 22.6 MB with 200 — proving the file was not lost and the repo was fine; only the direct link's redirect path was broken
- add `dl_result_ok()` / `gh_asset_id()` / `dl_github_release()`: after a direct link failure, automatically query `releases/tags/<tag>` (or `/releases/latest`) for the asset id, then download via the API; every candidate is validated as "non-empty + not an HTML/gateway error page"
- `update_singbox` three-level fallback: this repo's direct link → this repo's API asset → **upstream SagerNet asset with the same name** (the packages in this repo are mirrored from upstream anyway; the `sing-box-<ver>-linux-<arch>[-musl].tar.gz` naming and content match)
- `ensure_cloudflared` three-level fallback: `cloudflare/cloudflared`'s `latest` direct link → its API asset → this repo's pinned-version `cloudflared` asset (2025.11.1)
- also: the failure hint now adds "you can retry later / manually place the file at `/tmp/<archive>` and rerun", instead of a bare one-line `❌ download failed`

v3.2.68 (2026-11-09)
 > Alpine machines finally get kernel-level tuning: after installation completes, it automatically calls the `alpine-optimize-safe.sh` from [jyucoeng/alpine-onekey](https://github.com/jyucoeng/alpine-onekey) (locking the apk mirrors to the current branch, common tools, timezone, sysctl+BBR, replay at boot). It runs with `--no-ssh` by default and does **not** touch sshd.

- background: `low_mem_tune()` only took effect under systemd (it returns directly on non-systemd), and `sb.sh` contains no `sysctl -w` / `/etc/sysctl.d` writes at all, so Alpine / LXC / OpenVZ small boxes never got BBR or that batch of kernel parameters after installation
- why the sysctl rules were not copied into sb: the external script carries its own version evolution (apk mirror branch locking, a whitelist of writable container sysctl keys, `/etc/local.d` replay at boot); copying it would mean maintaining a fork. sb only handles **download → `sh -n` validation → invocation**
- new constants: `ALPINE_OPT_URL` (raw URL by default), `ALPINE_OPT_FILE` (defaults to `$SINGBOX_FOLDER_PATH/alpine-optimize-safe.sh`, doubling as the local cache when download fails), `ALPINE_OPT_ARGS` (extra passthrough arguments), `ALPINE_OPT_ON_INSTALL` (default `1`, runs automatically in the install flow; set `0` to disable and keep it manual only)
- new functions: `is_alpine()`, `alpine_opt_fetch()`, `alpine_opt_supports()`, `alpine_optimize()`
- **`--no-ssh` is a hard requirement**: the external script runs `ensure_kv PasswordAuthentication yes` / `PermitRootLogin yes` and restarts sshd afterwards. Most sb machines use key-based login, and automatically enabling direct password login is a security downgrade → `--no-ssh` is always passed by default; if the fetched script is an old version that does not recognize this parameter, it **aborts with a message** and never force-feeds it
- new commands: `sb opt` (run), `sb opt dry` (dry-run), `sb opt upgrade` (also runs `apk upgrade`), `sb opt ssh` (explicitly allow changing sshd, use with caution); the menu gains an extra item `[14] Alpine System Optimization` on Alpine
- install/reinstall flow: runs once automatically after `install_deps` finishes; on failure it only warns and does not block (`ALPINE_OPT_ON_INSTALL=0` disables it)
- matching changes on the alpine-onekey side (v2.1, same day): add `--no-ssh` / `--no-tools` / `--no-tz` / `--sysctl-only`, freely combinable

v3.2.67 (2026-11-08)
 > Fix `argo.log` always being 0 bytes on openrc machines: cloudflared logs go to **stderr**, but the template only redirected stdout, so everything ended up in `/dev/null`. Now `output_log` and `error_log` both point to the same file.

- symptom: on Alpine machines `/root/doraemon/logs/argo.log` and `supervise-argo.log` stayed 0 bytes all the time; restarting argo produced nothing, looking like "cloudflared has no logs / the tunnel is not connected"
- root cause: the init script managed by `supervise-daemon` only set `output_log="..."` (fd 1). Testing showed `ls -l /proc/<cloudflared pid>/fd/1` → `argo.log`, `fd/2` → `/dev/null`, and cloudflared's logrus defaults to **stderr**: all `INF/WRN/ERR` go to fd 2 → all lost. Only fatal usage errors like bad tokens go through `fmt` to stdout (which is why "a bad token produced 15 KB of output")
- fix: the openrc argo template gains a line `error_log="'"$LOGS_DIR"'/argo.log"'`; nginx's `supervise-daemon` template likewise gains `error_log=.../nginx-supervise.log`. The systemd branch is unaffected (`StandardOutput`/`StandardError` already both go to journal)
- verified live (122 MB Alpine box): after adding `error_log`, `rc-service argo restart`, `argo.log` immediately reached 6110 bytes and all four `Registered tunnel connection` lines with `connIndex=0/1/2/3` landed on disk — which also confirmed that v3.2.65's 4 connections really took effect
- temporary fix on old openrc machines (no reinstall needed): add `error_log="<the same path>"` below `output_log=` in `/etc/init.d/argo`, then `rc-service argo restart`

v3.2.66 (2026-11-08)
 > Fill in the two spots v3.2.65 missed: the same "downgrade to 1 connection on low memory" was still present in `sb-bak.sh`, and the nohup branch of `argorestart()` never carried the parameter at all. All three scripts and four paths are now of the same origin.

- `sb-bak.sh` synced to v3.2.66 (it has long tracked the main script but always lagged one version behind, so this round's constant block, `argo_ha_flag()`, and the three call sites were added all together)
- **`argorestart()` patch**: on machines without an init system (Alpine / LXC etc. without systemd or openrc), restarting Argo via `sb res` used hand-written command lines for the JSON fixed tunnel and the token fixed tunnel, which previously did not carry `--ha-connections` → they fell back to cloudflared's default 4 connections, making `ARGO_HA_CONNECTIONS=2` effectively unset on that path. Now changed to `${_argo_ha}`, same origin as the other three paths
- the three `--url` (trycloudflare temporary tunnel) branches are deliberately untouched: temporary tunnels do not need edge redundancy, and it avoids introducing an unverified parameter into that path
- repo-wide recheck: `grep 'ha-connections 1'` now hits zero times in `sb.sh` / `sb00.sh` / `sb-bak.sh`; `sb.sh` and `sb-bak.sh` are byte-for-byte identical except for line 9's `SB_SCRIPT_NAME`
- the old v3.2.5x changelog entries in `README-sb.md` are kept as-is: those entries record the behavior at that time, not the current documentation

v3.2.65 (2026-11-08)
 > Change the Argo edge connection count from "hardcoded 1 on low memory" to the top-level constant `ARGO_HA_CONNECTIONS` (default 4): the "degraded" badge on the Cloudflare dashboard can be cleared with one click, and stepping through 1 / 2 / 3 / 4 for debugging becomes easy.

- background: cloudflared by default opens one QUIC connection to each of 4 edge nodes, and Cloudflare judges tunnel health purely by whether edge redundancy is sufficient — **1 connection = degraded**, 4 / 8 connections = healthy. Previously the script hardcoded `--ha-connections 1` for machines with `MemTotal < 1048576` (i.e. < 1 GiB), while boxes nominally labeled 1 GB measured `MemTotal` at only about 0.96–1.0 million KB, inevitably below 1048576, so every one of them showed degraded
- new constant (at the top of the script, in the same block as `ARGO_DEFAULT_PORT`): `export ARGO_HA_CONNECTIONS="${ARGO_HA_CONNECTIONS:-4}"`, read uniformly by all three install paths (systemd / openrc / nohup); for debugging change this line, or override temporarily on the command line with `ARGO_HA_CONNECTIONS=2 bash sb.sh`
- add `argo_ha_flag()`: accepts only plain digits 1–8; empty / non-numeric / 0 / out of range all return an empty string → the parameter is omitted and cloudflared's default applies, avoiding writing a unit that "fails on startup"
- the memory branch is kept unchanged: when `MemTotal < 1 GiB` it still writes `GOMEMLIMIT=25%MiB` / `GOGC=40` / `GOMAXPROCS=1` / `MemoryHigh=30%` / `MemoryMax=40%`; it just no longer changes the connection count along with it
- measured cost: on a 1500 MB machine, cloudflared with 4 connections had an RSS of only 24.5 MB; going 1 → 4 adds "a few MB to a dozen or so MB", and `MemoryMax` at 40% is more than enough; "degraded" is only a dashboard label — it does not affect origin relay, does not rate-limit, and does not lower priority
- to make the dashboard turn healthy immediately on old machines: for units that already contain `--ha-connections 1`, change it to 4 and run `systemctl daemon-reload && systemctl restart argo`; units that never had the parameter already use the default 4 connections and need no change

v3.2.63 (2026-11-05)
 > Fix "IPv6-only machines with WARP providing IPv4 printing an extra unreachable `-IPv4` node": CDN / CGNAT / private ranges are no longer treated as node addresses, and IPv4 is no longer wrapped in square brackets.

- symptom: when a machine has only public v6 with v4 provided by WARP, `Hysteria2 - IPv4` printed `@[104.28.204.144]:31004` — that address is a Cloudflare edge IP that clients can never connect back to; and because the IPv4 was wrapped in `[]`, most clients judged it outright invalid
- root cause: the `ip_v4` file only checked "format valid and is v4" (`is_valid_ip_simple`), without checking whether the address could accept inbound traffic; the WARP egress (`104.28.x`) is an "egress IP" but does not accept inbound connections on this machine's ports
- add `_ipv4_in_cidr()` (pure awk integer arithmetic, works with busybox awk), `_ipv4_is_public()`, `_ipv6_is_global()`: purely local computation, no network needed
- `_ipv4_is_public()` excludes the ranges: `0/8`, `10/8`, `100.64/10`, `127/8`, `169.254/16`, `172.16/12`, `192.0.0/24`, `192.0.2/24`, `192.88.99/24`, `192.168/16`, `198.18/15`, `198.51.100/24`, `203.0.113/24`, `224/4`, `240/4`, plus all Cloudflare ranges (`104.16/13`, `104.24/14`, **`104.28/14`**, `172.64/13`, `162.158/15`, `173.245.48/20` … etc.) and Fastly's mainstream ranges (`151.101/16`, `199.232/16`)
- `pick_server_ip_for_install` filters before writing `ip_v4` / `ip_v6`: invalid values are **not written and the old file is `rm -f`-ed**, so after an overwrite install the old values no longer feed node generation
- `alt_family_addr()` filters again before printing (for compatibility with `ip_v4` files left by old installs): invalid values simply omit that line; on return, **only IPv6 gets `[]`, IPv4 never gets brackets**
- old machines do not need a reinstall: `sb rep` / regenerating the subscription already goes through the new logic, and bad files invalidate automatically

v3.2.62 (2026-11-05)
 > Fix "the nginx process is clearly running and the subscription works, yet the panel shows ■ stopped": after the service manager deletes the pid file, the script claims surviving instances by exe and writes the pid back.

- how it happened in the field: the install both ran `nginx -p … -c conf/nginx.conf` directly and enabled openrc's `sb-nginx` (`supervise-daemon`); when the service copy started a second instance the port was already taken → `bind() failed (98: Address in use)` → it retried until `respawn_max` gave up and the service went stopped; openrc then deleted **the pid file shared by both copies** according to the `pidfile=` in the init script, while the service copy's master was untouched
- `sb_nginx_running()` used to start with `[ -s "$SB_NGINX_PID" ] || return 1`, so once the file disappeared it permanently reported "stopped"; `singbox-watchdog.sh` also hardcoded "no pid file = stopped by the user, leave it alone" → nobody could recover it
- add `_sb_nginx_master_pids()`: only accepts processes whose `/proc/<pid>/exe` equals `$SB_NGINX_BIN` and whose cmdline contains `master process` (BT Panel/system nginx exe is not this binary, so they can never be caught by mistake)
- `sb_nginx_running()` changed to: use the pid file when valid; when missing/invalid, claim by the method above and **write the pid back** to `$SB_NGINX_PID` along the way, so the panel / watchdog / `nginx_stop` immediately line up again
- add `_sb_nginx_reap_stray()`: after `nginx_stop()` and `_sb_nginx_stop_raw()` (both systemd / openrc branches) finish stopping, a final sweep kills any still-alive masters of this project with TERM→KILL, eliminating "reported stopped but the process is still running"
- watchdog template synced: when the pid file is missing it first claims by exe; on a hit it writes back and logs one line `nginx: pid file missing but process running (pid=…), pid file written back`, instead of treating it as a manual stop
- verified on a real machine (Alpine + openrc): `stop` → instances 0 / ports 0; `start` → instances 2 (master+worker) / pid file correct; `restart` → reload only, `error.log` gains zero lines, subscription 200

v3.2.61 (2026-11-05)
 > When both v4 / v6 are valid, the direct-connection node output additionally prints one "other address family" node; switching address families on the same machine can also connect.

- a primary node link can only carry one address; when an IPv6 machine needs to connect to a v4 address, or the client's network is single-stack, the link often had to be edited by hand to work
- during installation, the detected public v4 / v6 are written to `ip_v4` and `ip_v6` respectively; when printing nodes, if both families have values, a second node of the same protocol is generated with the **other family**, named with a `-IPv4` / `-IPv6` suffix
- it is printed right after the output of **its own protocol** (the added Hysteria2 goes under Hysteria2), labeled `🎯【 Hysteria2 - IPv6 】(direct protocol, other address family)`
- priority follows print order `Hysteria2 → TUIC → VLESS-Reality-Vision → AnyTLS`, and **only one extra node is added** (marked by `_ALT_DONE`); its parameters (port/sni/pinSHA256/pbk/sid) are identical to the primary node, so the two are directly interchangeable in the client
- when writing to `jh.txt` it uses `prepend_jh` to place it on the **first line**; the nginx subscription (`sub.txt`, derived from jh.txt via base64) likewise puts it first, visible at a glance in the client list
- it is not added in these cases: only one family was detected, `direct_host` is set (the public-facing domain mask — the address is not an IP, so there is no "other family"), or there is no direct protocol at all (socks5 only)

v3.2.60 (2026-11-04)
 > Add a blank line after the Argo node block finishes printing, so the last `trojan-ws-tls-argo` link no longer sticks to the log that follows.

- the three argo protocols (vmess/trojan/vless) print within the same loop, and blocks were separated only by the next round's `green ""` → the last block had no trailing blank line
- after the loop ends, one `echo` is emitted based on `_argo_printed`, and only when argo nodes were actually printed

v3.2.59 (2026-11-04)
 > `sb report` → 4) View details: the status / configuration / preview sections no longer repeat each other; preview items are numbered with blank lines between them.

- the original "status" crammed address/credentials/machine name/not reporting/will report/node distribution together, duplicating "configuration" and "preview" three times; the status page now keeps only the switches, the most recent report / most recent success, the state file, and the config file
- the "configuration" page distinguishes two concepts: `report address` = your sub-merge domain, `report URL` = the actual `/api/v1/report/<machine name>` being POSTed to; the internal value `default` is displayed as "(default)"
- the configuration page drops the duplicated "auto reporting" and "config file" lines (the status page already has them)
- preview: the duplicated "source" is removed, the heading line is uniformly indented, each node gets a `1) 2) 3)` number and a blank line after it, so long links no longer smear into one blob

v3.2.58 (2026-11-04)
 > `sb report` → 3) becomes a second-level menu with per-item editing and `0` to return to the parent at any time.

- originally it asked 5 questions in one pass, and even if you wanted to change nothing you had to press Enter all the way through; now it is a list: `1) Report address 2) Report credentials 3) Machine name 4) Source 5) Protocols not reported 6) Clear all configuration 0) Return to parent menu`, each item showing its current value beside it (credentials masked)
- after editing an item the result is printed and you return to this level and can edit the next; `0` or `q`/`b`/`exit` returns to the parent menu
- during a single item's input, `q`/`b`/`0` = abandon that item, nothing written to disk
- "clear all configuration" becomes its own item 6, with a `(y/N)` second confirmation; the `-` clear shortcut at the address prompt is kept
- source display: the internal value `default` is uniformly shown as "(default)"

v3.2.57 (2026-11-04)
 > `sb report` → 3) Edit configuration supports canceling midway; after canceling, no changes are written.

- originally the 5 prompts had to be walked through with Enter to the end, with no way to back out to the menu; now entering `q` at any step (`quit` / `exit` / `b` / `back` / `0` equally valid) cancels and returns to the menu directly
- changed to "ask everything first, write to disk last": previously it ran `submerge_conf_set` while asking, and a midway cancel left half a configuration behind; now values accumulate in local variables and are written in one shot at the end
- all-Enter = no change, with an explicit message "No changes (all-Enter keeps the original values)", no more false "saved" reports
- the `-` at the address prompt (clear all configuration) and `-` at the excluded-protocols prompt (clear exclusions) keep their semantics

v3.2.56 (2026-11-04)
 > The report time gets its own line labeled with its purpose: `Report time: 2026-11-04 12:04:20 (UTC)`.

- originally the time was appended to the end of the same line as `✅ report succeeded: N nodes (…)`, easily squeezed together with the node count; now it starts a new line, indented two spaces, prefixed with `Report time: `
- the three cases `✅ report succeeded`, `✅ report succeeded, but content identical to last time`, `❌ report failed (HTTP xxx)` are handled the same way (for failures the time goes on the immediately following line)
- the auto-report summary filter adds `report time`, otherwise the newly added line would be filtered out by grep; on failure `tail -n 4` becomes `tail -n 6`, so the time and the suggestion are not truncated

v3.2.55 (2026-11-04)
 > The report preview prints node links in full, no longer truncated to 72 characters + `...`.

- `submerge_preview` originally used `sed -n '1,5p'` to take only the first 5 entries and then `cut -c1-72` with `...` appended, so during verification you could not see key fields like uuid / pbk / sni / path
- now the raw string is output line by line in full, with no entry limit (`while IFS= read -r` reads the file directly to avoid a pipeline subprocess); the preview is still filtered by "protocols not reported" before listing

v3.2.54 (2026-11-04)
 > After a successful auto report, the report time is printed directly, exactly matching what the `sb report` menu shows.

- the `✅ report succeeded: N nodes (auto a + manual b)` line gains `YYYY-MM-DD HH:MM:SS (UTC)` at its end; `✅ report succeeded`, `✅ report succeeded, but content identical to last time`, and `❌ report failed (HTTP xxx)` get the same addition
- add `submerge_now_utc()`; `submerge_report` captures the timestamp once on entry, and the console output and the state file's `LAST_TIME` share this value (`submerge_record` gains a 5th optional parameter to pass the time in), so the console line and the menu's "last report" are always the same instant
- times are uniformly taken as UTC, consistent with v3.2.53's `date -u`

v3.2.53 (2026-11-04)
 > Report times are uniformly labeled UTC, eliminating cross-timezone misreading.

- `submerge_record()` now records with `date -u`: times in the state file are henceforth explicitly UTC (server timezones vary; previously written in the local timezone, someone seeing `11:51:11` would take it as their own local time)
- display spots add `(UTC)`: the interactive menu's `Last report: … (UTC) success/failure`, and the status page's `Most recent: … (UTC)` and `Most recent success: … (UTC)`
- compatible with old records: times in old state files are the server's local time at that moment and are not converted (most machines are UTC anyway)

v3.2.52 (2026-11-03)
 > Temporary argo tunnels gain auto-start and domain tracking; when the domain changes, nodes are regenerated and reported.

- trycloudflare gets a new domain on every start and the old domain dies permanently; the watchdog gains a section dedicated to temporary tunnels (detection: `argoport` exists with neither `tunnel.yml` nor `sbargotoken`); if the process is absent it directly launches `cloudflared tunnel --url`
- the new domain is captured from `argo.log` and written to `argo_domain`; when the domain changes, argo nodes are regenerated and reporting is triggered; fixed tunnels are managed by `argo.service` with a stable domain, and this logic never touches them

v3.2.51 (2026-11-03)
 > On report failure, print the server-side message / hint too.

- originally only `error` was printed, so key explanations like `D1_ERROR: no such table: machine_former` were lost and the user saw only a 500
- now it parses `message` and `hint`: when present it prints `Server message: …` / `Suggestion: …`; for a 500 without a hint it notes that the cause is most likely D1 tables not created — rerun the report once or visit `/api/v1/admin/schema`

v3.2.50 (2026-11-03)
 > No longer inferring startup failure from "empty log", eliminating false alarms after installation.

- originally an empty `singbox.log` directly triggered `⚠ singbox.log is empty, sing-box may have failed to start`; but openrc/supervise buffers output and sing-box often writes its first line only after the first connection — a successful install could still trigger it
- now it first runs `pgrep -f "$SINGBOX_FOLDER_PATH/sing-box"`: process running → only a debug log line `✓ sing-box is running (log still empty, which is normal)`; process confirmed absent → `⚠ sing-box is not running; use sb log_stop to see why it stopped` (pointing to the entry point that can actually diagnose it)

v3.2.49 (2026-11-03)
 > The report summary's colors and alignment are unified with the other lines of "Install Parameters".

- changed from yellow (same color as warnings) to green; only genuinely abnormal values (not enabled / not configured) use yellow
- indentation changed to two spaces, colons to half-width, key names to `Node reporting / Report domain / Report credentials / Report machine name / Excluded protocols`, aligned in one column with `Subscription:` and `Node name prefix:`

v3.2.48 (2026-11-03)
 > The report configuration summary moves inside the "========= Install Parameters =========" block.

- position changed from `set_sbyx()` (after the "all node name prefix" line, outside the install-parameters block) to the end of the install-parameters block, between `Node name prefix` and the separator line, so ports/protocols can be reviewed in one pass
- printed only when "there is report configuration" (`SUBMERGE_CONF` exists, or `REPORT_BASE`/`REPORT_TOKEN`/`REPORT_FLAG` was passed); users with nothing configured see the install-parameters block unchanged
- the machine name prefers the `name` passed this time: at the install-parameters stage `$SINGBOX_FOLDER_PATH/name` has not been written yet, and the old logic showed the hostname, which differs from the machine name actually used for reporting

v3.2.47 (2026-11-03)
 > Cleanup of orphan sandbox Nginx is now silent, no longer spraying yellow warnings during uninstall/reinstall.

- previously after cleanup it printed `↳ found sandbox Nginx leftovers not managed by the pid file (pid: …), cleaning them before continuing`, easily mistaken for an error; now it only writes to the debug log (visible via `sb log_ins` / debug mode), and the normal flow keeps only `▸ terminating process... ✓ process terminated`
- the cleanup logic itself is unchanged: still judged by `/proc/<pid>/exe`, TERM first then KILL

v3.2.46 (2026-11-03)
 > The report configuration summary gains an "excluded protocols" line.

- add `Excluded protocols: socks5 (these types are not reported, the rest as usual)` / `Excluded protocols: none (everything reported)`
- the value matches `sb report status`'s "not reporting": it goes through `submerge_exclude_list()`, recognizes `hysteria2/socks5/tuic/anytls/vless-reality/vmess-argo/vless-argo/trojan-argo/*-cdn`, normalizes `hy2` to `hysteria2`, and silently ignores unrecognized spellings (it will not treat non-kind words like `vless` as exclusion items)

v3.2.45 (2026-11-03)
 > The install-parameters section also prints the node reporting (sub-merge) configuration, so you know right after install whether reporting will happen.

- **printed content**: `Node reporting: enabled/not enabled`, `Report domain: <address>/(not configured, will not report after install)`, `Report credentials: configured 6a4a25****44ad / not configured`, `Report machine name: <machine name>`, using the same value chain as `sb report status` (`REPORT_MACHINE` > config file > node name prefix > hostname > `sb-node`)
- **credentials show only head and tail** (first 6 + last 4), never writing the whole token into the install log
- **when nothing is configured at all** (no address, no credentials, auto report off) it prints a single line `Node reporting: not configured (to aggregate into your own sub-merge, see sb report)`, avoiding flooding users who do not use reporting
- position: in `set_sbyx()`, right after the "all node name prefix" line

v3.2.44 (2026-11-03)
 > Fix "the overwrite install's opening port check treating the sandbox Nginx it left behind as an external process and scaring the user with an alarm".

- **symptom**: the port check at the start of `sb rep` printed `⚠️ port 8001 (argo_pt=8001) is currently listened on by another process / occupying process: nginx (pid=...) / after confirming it is not a needed service, you can free the port manually: kill ...`, yet that nginx was actually the sandbox nginx left by the script's previous install round (its pid file lost, see v3.2.43), and the cleanup phase right after killed it anyway — a friendly-fire false alarm
- **fix**: the port ownership check `_p_listener_kind()` gains channel 2.5 — judge by the real path in `/proc/<pid>/exe`; if the exe equals `$SB_NGINX_BIN` (including the `... (deleted)` form after the binary was replaced) it is treated as **this script's own stack** and no longer alarms; it still does not judge by process name, so BT Panel/system nginx (`/usr/sbin/nginx`) remains an external process with the usual hint
- **behavior**: our own sandbox nginx holding the port → silent (the cleanup phase will kill it); a genuine external process → alarm as before with the kill hint

v3.2.43 (2026-11-03)
 > Fix "after uninstall/reinstall the sandbox Nginx becomes an orphan holding the ports, so the next install cannot start".

- **add `sb_nginx_kill_orphan()`**: judged by the real path in `/proc/<pid>/exe`; it only cleans processes whose exe equals this project's `$SB_NGINX_DIR/sbin/nginx` and that are not managed by the pid file (system/BT Panel nginx exe is `/usr/sbin/nginx` etc., never caught by mistake). TERM first, then KILL; managed instances (the pid file points at them) are skipped and left to `nginx_stop`
- **trigger scenario**: the old uninstall only stopped nginx by the pid file, but the pid file had often already been deleted in an earlier cleanup → the master became an orphan still holding `nginx_pt` / `argo_pt`; the next install failed to bind when it needed `listen 127.0.0.1:${argo_pt}` → nginx exited immediately at start, while `sb nginx_status` showed "not running" and the log kept only one line "exited right after startup", which was hard to diagnose
- **three call sites**: before `start_nginx_service()` starts, after `cleanup_nginx()` stops, and in `uninstall()`'s process-termination block (which previously only `pkill`-ed sing-box / cloudflared and missed nginx)

v3.2.42 (2026-11-03)
 > The report address auto-fills https; exclusions change to "empty = no filtering".

- **`REPORT_BASE` may omit `https://`**: add `submerge_norm_base()`, applied uniformly in four places — config read, environment variables, menu input, writing to disk — trimming leading/trailing whitespace and trailing slashes, auto-adding `https://` when no scheme is written, using `http://` as-is when written (no forced upgrade, so self-hosted reverse proxies / intranet http environments keep working), and only adding `https://` when "no scheme at all is written". Reason: reporting always uses `curl -sS -m 20 -X POST` without `-L` (`-L` would downgrade the POST to a GET); a bare domain would be sent as `http://` by curl, the server's 301 redirect to https would leave the script with only the 301, judged outright as "report failed (HTTP 301)" — so bare domains must get https; but an explicitly written scheme is respected
- **empty `REPORT_EXCLUDE` = no protocol is intercepted**: removed the "default to socks5 when unconfigured" injection, and the `REPORT_CLEAR` branch now empties the exclusions too (it previously reset them to socks5). To exclude a protocol type, write `REPORT_EXCLUDE='socks5'` explicitly; otherwise everything is reported — the default-value behavior described in v3.2.41's notes is void
- **a blank line before "auto reported to sub-merge"**: this notice sits right against the node link output and was cramped and hard to read

v3.2.41 (2026-11-02)
 > Uninstall keeps the report configuration; add REPORT_CLEAR for explicit clearing; config display shows the value precedence.

- **`sb del` no longer deletes the report configuration**: `cleandel`'s whitelist gains `submerge.conf` alongside `sing-box|cloudflared|logs|nginx`. Originally `del` (which claims to "keep binaries for easy reinstall") `rm`-ed `submerge.conf` too, and the `SUBMERGE_TOKEN` inside can only be recreated in the sub-merge backend — precisely the hardest thing to restore on reinstall. `submerge.state` (last report time and other history) is still deleted; keeping it would show "reported successfully 3 days ago" after reinstall and mislead. `delall` behavior is unchanged, wiping the whole directory
- **add `REPORT_CLEAR=1`**: once the config file is kept, "I want to clear the report configuration" had no outlet — `REPORT_TOKEN=""` is indistinguishable from "not passed" under a `[ -n ]` check, and in CI an unset `secrets.REPORT_TOKEN` is an empty string, so expressing "clear" with an empty string would backfire. Now a dedicated switch: `REPORT_CLEAR=1 bash <(curl -Ls ...) rep` empties `submerge.conf` and returns to defaults (address/credentials/machine name/source cleared, exclusions back to `socks5`, auto report off). In the same command, any `REPORT_*` variables clear first and fill after
- **fix the exclusions default when clearing**: after clearing, if `SUBMERGE_EXCLUDE` was set empty, the later check "an existing `SUBMERGE_EXCLUDE` line in conf means no default injection" would leave this run with an empty value (= no filtering at all, even socks5 reported). The clear block now sets `socks5` directly, consistent with "socks5 by default when unconfigured"
- **two lines added to config display**: `sb report → 4) View details` adds `Value precedence: environment variables REPORT_* > config file > defaults (passing arguments writes back to the config file)` and `Clear configuration: reinstall once with REPORT_CLEAR=1, or sb report → 3) enter - at the address prompt`, resolving "I passed it, did it actually take effect?"
- **the uninstall prompt states the delete/keep list**: before `[11] Uninstall` it prints "Will delete: node configuration, uuid, reality keys, argo credentials, report state records / Will keep: binaries, logs, report configuration", and `[12] Uninstall everything` notes "the entire directory will be deleted". Originally there was only "Confirm uninstall? (y/N)", and users had no idea the report credentials would be wiped along with it

v3.2.40 (2026-11-02)
 > The report menu directly shows "what is excluded / what will be reported"; fix SNI containing -tr being misjudged as trojan-argo.

- **visible in the menu**: `sb report`'s submenu and `sb report status` gain two lines — `Not reported: <exclusion list>`, `Will report: <the forms that will actually be sent>`; when the machine has `jh.txt` there is one more line `Current nodes: vless-argo×2 trojan-argo×1 … (N total, M reported after exclusion)`, so you can see at a glance what will be reported this time and how many are missing
- **the `3) Edit configuration` prompt is completed**: it originally listed only the six `vless,vmess,trojan,hysteria2,tuic,anytls`; now the `socks5` and the 8 fine-grained forms (`vless-reality vless-argo vless-cdn vmess-argo vmess-cdn trojan-argo trojan-cdn`) are listed too, along with the forms that would currently be reported
- **fix the misjudgment**: `submerge_kind_of()` originally matched the whole link against `*-tr*`; when a user filled the SNI/host with `xxx-tr.example.com`, a vless link was judged as `trojan-argo`, so checking "exclude trojan" threw it away too. Now the form marker is taken only from the `path=` parameter, while `security=reality` is still judged from the query string
- **vmess compatibility with `#fragment`**: for `vmess://<base64>#name` links written by hand or imported externally, feeding the whole string into base64 decoding used to fail and degrade to coarse `vmess`; now the part after `#` is stripped before decoding, and `-vm` / `-vm-cdn` are recognized correctly (vmess links generated by the script itself carry no fragment and are unaffected)

v3.2.39 (2026-11-02)
 > Socks5 not reported by default; checkboxes aligned on a grid.

 - **socks5 excluded by default**: when neither the environment variables nor `submerge.conf` contains a `SUBMERGE_EXCLUDE` line, `submerge_load()` sets it to `socks5` automatically (most clients do not consume this protocol)
 - **to report everything**: `sb report` → `3) Edit configuration` → press Enter at the protocols-not-reported prompt and then enter `-`, or hand-write `SUBMERGE_EXCLUDE=` (an empty value also counts as "explicitly choosing not to filter" and will not be overwritten by the default)
 - tested: empty config → `Not reported: socks5`; an empty line in conf → `(no filtering, everything reported)`; `REPORT_EXCLUDE=trojan` → environment variables take precedence
 - UI: in `singbox-tools-interface` the Socks5 checkbox is checked by default, with the three rows aligned to a 60px-label + 3-equal-column grid

v3.2.38 (2026-11-02)
 > Exclusions are subdivided by the node forms sb00.sh actually generates, instead of only looking at the scheme.

 - **subdivision basis** (against the script's generation logic): direct `hysteria2 / tuic / vless-reality (security=reality) / anytls / socks5`; Argo `vless-argo / vmess-argo / trojan-argo` (path `<uuid>-vl|-vm|-tr`); CDN origin relay `vless-cdn / vmess-cdn / trojan-cdn` (path `-vl-cdn|-vm-cdn|-tr-cdn`)
 - **`submerge_kind_of()`**: vless/trojan look at `security=reality` and the path marker; vmess's path is inside the base64 JSON, so decode with `base64 -d` first, then match; other schemes return themselves directly
 - **prefix matching**: `submerge_kind_excluded()` recognizes prefixes in addition to exact equality; `vless` excludes all three vless forms; `vmess-cdn` excludes only vmess's CDN form
 - the **whitelist** expands to 14 tokens in sync; unknown values like `ss`/`foo` are still silently dropped
 - **UI**: the checkboxes in `singbox-tools-interface` become 11, grouped by "Direct / Argo / CDN origin relay"

v3.2.37 (2026-11-02)
 > Support "protocols not reported": checked protocols do not participate in reporting.

 - **configuration**: `REPORT_EXCLUDE` (environment variable, delivered by the UI) → `SUBMERGE_EXCLUDE` (`submerge.conf`); values like `vless,trojan`
 - **normalization**: `submerge_exclude_list()` lowercases uniformly, strips spaces, deduplicates, keeps only known protocols (`vless vmess trojan hysteria2 tuic anytls`), and accepts the `hy2`/`hysteria` aliases; unknown values (e.g. `ss`) are silently dropped
 - **filtering**: `submerge_filter_nodes()` matches by link scheme exactly (`^scheme://`), discarding empty lines along the way; both reporting and preview go through it
 - **behavior**: `submerge_report()` re-encodes after filtering, and the "📤 reporting" line shows "excluded …"; if everything is excluded it errors out directly and records a failure state (`no nodes left after excluding protocols`), never sending an empty body
 - **visibility**: `View details`/`View configuration`/`View status` each gain a line "Not reported: vless,trojan" or "(no filtering, everything reported)"; `3) Edit configuration` adds the item (enter `-` to clear)
 - tested: 6 nodes (hy2/tuic/vless/vmess/trojan/anytls) with `vless,trojan` excluded → 4 reported; the server accepting only 3 was because that vmess was a hand-built broken sample (missing port/id) that failed to parse, not an anytls problem — reporting anytls alone or socks5 alone both inserted fine

v3.2.36 (2026-11-02)
 > The machine name is delivered uniformly by `REPORT_MACHINE`, and the script only falls back to `name` when it is empty.

 - **value chain**: `REPORT_MACHINE` (environment variable) > `SUBMERGE_MACHINE` (`submerge.conf`) > `$SINGBOX_FOLDER_PATH/name` > `hostname` > `sb-node`
 - **how to name**: recommend `<region>-<serial>`, e.g. `hk-1`, `圣何塞-1` (San Jose), `jp-osaka`. `sub_merge` recognizes the region in the machine name (Chinese region words or two-letter country codes both work) to decide the default sort order; machines it cannot recognize are sorted last and labeled "no region" in the UI. The machine name and the node name are two different things: it is only a reporting identifier, and changing it does not affect the node names shown in clients.
 - **whitespace tolerance**: `REPORT_MACHINE="   "` used to be treated as "has a value" and written into conf (while the machine name fell back to name, leaving the two inconsistent); now it is trimmed first and only non-whitespace is written to disk; `REPORT_MACHINE=` (empty string) likewise
 - **UI counterpart**: card ⑧ of `singbox-tools-interface` delivers the machine name (following ④'s `name`) together as `REPORT_MACHINE=…`, so both sides always agree
 - tested: not passed → `Doraemon-US-North-Carolina`; `REPORT_MACHINE=HK-2` → `HK-2` and written into conf; whitespace → falls back to `name` and conf not written; no name either → `hostname`

v3.2.35 (2026-11-02)
 > The report submenu is cut from 7 items to 4, and the header squeezed to three lines.

```
========= Report to sub-merge =========

  Auto report: enabled (auto-push after nodes are generated)
  Server: https://your-domain    Credentials: configured
  Last report: 2026-11-02 19:10 success

  1) Report once now
  2) Turn off auto report          ← the label switches automatically when toggled
  3) Edit configuration (address / credentials / machine name / source / clear)
  4) View details (status / configuration / preview)
```

 - merge: the original "view report status" / "view report configuration" / "preview before upload" are merged into `4) View details`; "clear report configuration" is folded into `3)` (enter `-` at the address prompt)
 - the toggle item's label follows the state (`Turn on auto report` / `Turn off auto report`), so you no longer need to remember "current: on/off"
 - the header keeps only three lines: the toggle state, server+credentials, and the last report result
 - when unconfigured, the hint uses a guiding color (yellow "Not configured (choose 3 to fill in your own sub-merge domain)")

v3.2.34 (2026-11-02)
 > The report submenu no longer shows blanks when "no address is configured / source is empty".

 - the header's "Server: " becomes the yellow "Not configured (choose 3 to fill in your own sub-merge domain)" when unconfigured; when "Source: " is empty it shows "Default"; when the toggle is on but no address has been filled in yet, it hints "choose 3 to fill it in before anything is actually pushed"
 - menu structure unchanged: `1 Status / 2 Report now / 3 Edit configuration (address·credentials·machine name·source) / 4 View configuration / 5 Preview / 6 Toggle auto report / 7 Clear configuration`

v3.2.33 (2026-11-02)
 > The status page shows the config file's real permissions; fix mojibake caused by full-width parentheses immediately following a variable name.

 - **bug fix**: a construct like `State file: $SUBMERGE_STATE（600）` — "full-width parenthesis directly after a variable name" — makes bash swallow the first byte of `（` into the variable name during parsing, producing a missing `submerge.state` plus mojibake (`：��600）`). Changed to `${SUBMERGE_STATE}（600）` / `${SUBMERGE_CONF}（…）`, and the whole file was swept for the same pattern
 - **permissions visible**: add `submerge_conf_perm()` (`ls -l` reads the actual permission bits; `-rw-------` → "600, only root can read/write", never created → "not created"); both the status page and "view report configuration" show it, noting that it re-runs `chmod 600` after rewrites
 - tested: not created → `(not created)`; created → `(600, only root can read/write)`; writes under `umask 000` still produce `-rw-------` (`submerge_conf_set` writes a temp file + `mv`, then uniformly `chmod 600`); the directory `/root/doraemon` stays 755, but only root can read the file content

v3.2.32 (2026-11-02)
 > The report address no longer ships with a built-in default domain; the machine name auto-derives from the global config's name; source defaults to empty.

 - **background**: the previous version shipped a fixed example domain as the default value, so everyone pushed to that domain; the machine name also had to be filled separately, even though the `name` in the ④ global config is the node name prefix and should serve as the machine name anyway; the source is not needed by the vast majority of users
 - **change**: `SUBMERGE_DEFAULT_BASE=""`; when the address is empty, `submerge_report()` and `submerge_auto_report()` give a Chinese hint and skip (recording a failure state `report address not configured`); in `submerge_load()` the machine name defaults to reading `/root/doraemon/name` (trailing `-` stripped), falling back to hostname only when never filled; `SUBMERGE_SOURCE` no longer falls back to `default`, and no `?source=` is appended when empty
 - **UI**: `singbox-tools-interface` removes the "machine name" and "source" input boxes (replaced by read-only notes: machine name comes from ④'s name, source defaults to empty), keeping only the toggle / report address / report credentials; the address placeholder becomes "your own sub-merge domain (required)"; when the toggle is on but the address or credentials are empty, both input boxes turn red with a hint

v3.2.31 (2026-11-02)
 > Report results persisted + status queries: the toggle, the most recent time and result, the target URL and credentials, queryable from both the menu and the command line.

 - **background**: auto reporting was "push right after install, then stay silent"; to find out afterwards "was it pushed at all, did it succeed, and to which address" you had to dig through logs yourself
 - **recording**: every report (manual / auto / failed) writes `/root/doraemon/submerge.state` (600): `LAST_TIME` / `LAST_RESULT`(`ok|fail`) / `LAST_HTTP` / `LAST_MSG` / `LAST_NODES` / `LAST_MACHINE` / `LAST_SOURCE` / `LAST_URL` / `LAST_OK_TIME` (most recent success time, not overwritten by failures)
 - **trigger surface**: every exit path of `submerge_report()` records — credentials unconfigured, empty node file, base64 failure, HTTP 200 (`changed:true/false` recorded as "content updated" / "content unchanged" + node count), non-200 (HTTP code + the server-side error text)
 - **menu**: `[13] Report to sub-merge` gains a top line "Last report: <time> success/failure"; a new `1) View report status`, with the remaining options shifted (report now→2, edit config→3, view config→4, preview→5, toggle→6, clear config→7, and clearing also deletes the state)
 - **command line**: `sb report status` (aliases `sb rstatus` / `sb reportstatus`) prints status; `sb report on|off` toggles auto reporting directly; unknown arguments get a usage hint
 - **status page content**: toggle + value source (environment variable `REPORT_FLAG` takes precedence over conf), the full report address (including `?source=`), masked credentials, machine name/source, the most recent attempt (time/success-failure/HTTP/message/node count/target URL), most recent success time, and the state/config file paths
 - **tested** (extracted functions run against the live service): unconfigured shows "off + no report records yet"; after configuration, a manual report writes `ok 200 content updated, 2 nodes`; a wrong credential writes `fail 401 unauthorized` while "most recent success" stays unchanged; with auto report on, `submerge_auto_report` triggers the same recording (`content unchanged`); `sb report status` / `sb report bogus` output as expected

v3.2.30 (2026-11-02)
 > Reporting defaults to off: only `REPORT_FLAG=1` auto-reports; the address and credentials are persisted to `submerge.conf`.

 - **background**: the previous version made "reporting" a manual command, but the user wanted "auto-push right after install, while never sending data out secretly by default"
 - **changes**: add `submerge_auto_flag()` / `submerge_auto_enabled()` / `submerge_auto_report()`, hooked at the end of `regenerate_links_and_sub()` (reached by `sb ins` / `sb rep` / `sb sub` / configuration changes); by default, with `REPORT_FLAG` unset or `0`, it stays fully silent; only `1` pushes
 - **persistence**: `submerge_load()` supports the environment variables `REPORT_BASE` / `REPORT_TOKEN` / `REPORT_MACHINE` / `REPORT_SOURCE` / `REPORT_FLAG`; given a value it writes into `/root/doraemon/submerge.conf` (600), so it persists even without the variables next time; once credentials are configured, even the default address and the auto toggle get solidified
 - **interaction**: the submenu adds `5) Toggle auto report` (writes `SUBMERGE_AUTO`), and `3) View configuration` shows "Auto report: on/off"; when `REPORT_FLAG` exists, toggling reminds that environment variables take precedence
 - **failure does not affect installation**: a failed auto report only emits a few yellow lines; node generation/subscription refresh completes as usual
 - **tested**: no `REPORT_FLAG` → silent; `REPORT_FLAG=0` → no report; `REPORT_FLAG=1` → auto-push succeeded and `SUBMERGE_BASE/TOKEN/MACHINE/SOURCE/AUTO` all persisted; after removing the environment variables, the conf alone still determines it as enabled

v3.2.29 (2026-11-02)
 > Add "report nodes to sub-merge": a single `sb report` command pushes all of this machine's nodes to your own subscription aggregation service.

 - **background**: when managing subscriptions with sub-merge yourself, after installing a machine's nodes you still had to paste links into the web page by hand, and with many nodes some got missed
 - **changes**: add a group of functions like `submerge_report()` (`submerge_load` / `submerge_conf_set` / `submerge_b64_file` / `submerge_urlencode` / `submerge_report` / `submerge_preview` / `submerge_conf_show` / `submerge_configure` / `interactive_submerge_menu`), the main menu gains `[13] Report to sub-merge`, and the command line gains `sb report` (alias `sb up`)
 - **implementation**: reads `/root/doraemon/jh.txt` → base64 the whole thing (openssl first, busybox/GNU base64 as fallback) → `POST /api/v1/report/<machine name>` + `Authorization: Bearer <REPORT_TOKEN>`; the machine name is percent-encoded byte-wise, so Chinese names work
 - **configuration**: `/root/doraemon/submerge.conf` (600) stores `SUBMERGE_BASE` / `SUBMERGE_TOKEN` / `SUBMERGE_MACHINE` / `SUBMERGE_SOURCE`; when `jh.txt` is missing it calls `regenerate_links_and_sub` first, then reports
 - **response handling**: no jq dependency; `grep -oE` extracts `changed` / `nodes` / `auto_nodes` / `manual_nodes` / `updated_at` / `error`; `changed:false` explicitly notes "content identical to last time", and 401/400/413/connection-failed each get their own Chinese troubleshooting hint
 - **tested** (on macOS, running the extracted functions against the live service): 4 nodes reported for the first time got `changed:true, nodes:4, auto_nodes:4`; re-reporting as-is got `changed:false`; after renaming one node `changed:true`; a wrong credential got `HTTP 401 unauthorized`; a Chinese machine name + a custom `source` both worked; the test machine was deleted from the live service afterwards

v3.2.28 (2026-11-02)
 > Node names no longer append the server hostname: the `-NC6KW8` in `Doraemon-US-North-Carolina-tuic-NC6KW8` is removed.

 - **background**: node names had always been `${sxname}<protocol>-${hostname}`, with `hostname` taken as the 2nd field of `uname -a`. The default hostnames cloud vendors assign are often random strings (`NC6KW8` in this example), so shared links grew an unintelligible tail and client lists looked dirty
 - **changes**: all 11 node name templates uniformly drop `-${hostname}`: hy2, tuic, vless-reality, anytls, socks5, vless-ws-cdn, vmess-ws-cdn, trojan-ws-cdn, plus argo's trojan/vless/vmess; those three argo spots also drop the port suffix, leaving just `-argo` (if one machine opens multiple argo ports, the node names would collide, and you would need to distinguish them yourself)
 - **kept**: the `hostname` variable itself was not removed (the `uname -a` line stays, to avoid affecting possible references elsewhere); it simply no longer participates in node naming
 - **tested** (`sxname=Doraemon-US-North-Carolina-`, `hostname=NC6KW8`, rendering all 11 templates): `…-hy2`, `…-tuic`, `…-vless-reality`, `…-anytls`, `…-socks5`, `…-vless-ws-cdn`, `…-vmess-ws-cdn`, `…-trojan-ws-cdn`, `…-trojan-ws-tls-argo`, `…-vless-ws-tls-argo`, `…-vmess-ws-tls-argo`, none with `-NC6KW8`, none with a port suffix

v3.2.26 (2026-10-31)
 > Unify sing-box's service name: `sb autostart` no longer spawns a unit with the same name as `sb.service` fighting over ports.

 - **background**: `sb autostart` (`enable_autostart`) had always used `singbox-service` as the service name, while the normal install path (`sbbout`) writes `sb.service`; their `ExecStart` is identical
 - **consequence 1 (verified on a real machine)**: after installing, running `sb autostart` once more left both units enabled. On reboot both started; the later one failed with `FATAL start service: start inbound/tuic[tuic-sb]: listen udp 0.0.0.0:31005: bind: address already in use` → `Restart=always` retried every 2 seconds, and after 5 attempts it hit `Failed with result 'exit-code'`, flooding the logs
 - **consequence 2**: `sb autostart_off` only deleted `singbox-service`, while `sb.service` kept auto-starting — the user thought it was off, but it was not
 - **fix**: extract `gen_sb_unit_systemd()` / `gen_sb_unit_openrc()` as two template functions, shared by `sbbout()` and `enable_autostart()`; the service name is unified as systemd's `sb` / openrc's `sing-box`
 - `enable_autostart` first cleans up leftover `singbox-service` units from history (disable + delete file + yellow notice); when a `sb.service` already exists it only adds `enable` (preserving sbbout's iptables restore / log redirection / memory limits), rebuilding from the template only when absent
 - `disable_autostart` cleans both names, and gives an explicit message when neither is found, instead of pretending success
 - **also fixes the same class of problem for argo**: `install_argo_service_systemd` and the openrc branch used `start`, which is a no-op on an already active unit — after an overwrite install changed the tunnel token, the old process kept running on the old config. Changed to `restart` (`sb.service` stepped on this same pit earlier)
 - **result checks added for `systemctl enable sb` / `enable argo` / `rc-update add`**: on failure a yellow warning is issued instead of staying silent
 - tested (Debian 13): `sb autostart` produces only `sb.service`; manually fabricating a leftover `singbox-service.service` gets it cleaned automatically; `sb autostart_off` shuts it down correctly; after reinstalling 3.2.26 and a full reboot, `sb` / `argo` / `sb-nginx` all auto-started, all three `NRestarts` were 0, and the subscription returned 200

v3.2.25 (2026-10-31)
 > The unit just added in 3.2.24 failed to start on real machines: systemd could not read the pid and hung in an `activating` loop.

 - **root cause 1 (fatal)**: `PIDFile="$SB_NGINX_PID"` carried quotes. Unlike `ExecStart`, `PIDFile=` does **no quote parsing**, so `"` was treated as a path character; systemd actually looked for `/run/"/root/doraemon/nginx/logs/nginx.pid"`, reporting `Can't open PID file (yet?)` → it waited out `TimeoutStartSec=30` → `Failed with result 'timeout'` → `Restart=always` restarted immediately → infinite loop. The surface is nasty: the process runs and the subscription returns 200, yet `ActiveState=activating` and `MainPID=0`
 - **fix 1**: `PIDFile=$SB_NGINX_PID` without quotes. The quotes on `ExecStart` / `ExecStop` / `ExecReload` are **kept** (systemd strips those normally, to support install paths containing spaces)
 - **root cause 2**: `_sb_nginx_stop_raw` only checked that the unit file existed before running `systemctl stop`. On the first upgrade from an old install, the unit was freshly created while nginx was still a process the script had started by hand (not in systemd's cgroup) — `systemctl stop` could not stop it, but it would execute `ExecStop=nginx -s quit`, using the pid file to **kill by mistake a process not managed by systemd**
 - **fix 2**: check `systemctl is-active` first; hand it to the service manager only when `active` / `activating` / `reloading`, otherwise fall back to stopping via the pid file
 - the unit template marker becomes `unit-rev: 2`; on machines that installed 3.2.24, the next script run rewrites the unit automatically, no manual file deletion needed
 - tested (Debian 13 / VPS): `kill -9` the master → auto-restart at second 11, subscription back to 200; 12s after `systemctl stop` still `inactive` (a manual stop does not resurrect); `systemctl start` restores; `systemctl reload` reloads smoothly with `MainPID` unchanged; after a full `reboot` the machine came up in 55s, `sb-nginx` auto-started, `NRestarts=0`

v3.2.24 (2026-10-31)
 > The sandbox Nginx joins service management: auto-start at boot + auto-relaunch after being killed.

 - **problem**: the sandbox nginx had been completely outside the service manager, with only the cron watchdog (every 2 minutes) as a fallback
   - after an OOM kill it could lie dead for up to 2 minutes
   - **it never came back after a full machine reboot**: the pid file was gone, and by design the watchdog "no pid file = stopped by the user, leave it alone" → the subscription entry stayed 404 until the user reran the script
 - **new unit**: systemd uses `sb-nginx.service`, openrc uses `/etc/init.d/sb-nginx`; the service name is fixed as `sb-nginx`, **never colliding with the system's `nginx.service`**
 - **`Type=forking` + `PIDFile`**: `nginx.conf` contains `daemon on;`; using `Type=simple` would require `-g 'daemon off;'`, but that collides with the config's `daemon on;` as `"daemon" directive is duplicate` and nginx refuses to start
 - **`Restart=always` with a fuse** (`RestartSec=10s` / `StartLimitBurst=5` / `StartLimitIntervalSec=300`): unlike sing-box, nginx failures such as a taken port or a broken config are **persistent** faults; infinite restarts would only flood `error.log`; after 5 attempts it stops at `failed` awaiting human attention, and when the user starts it manually from the menu, `reset-failed` resets it
 - **the openrc side** prefers `supervise-daemon` (`respawn_delay=10` / `respawn_max=5` / `respawn_period=300`), falling back to `command_background` when unavailable
 - `start_nginx_service` now goes through the unified entry `_sb_nginx_start_raw`; `nginx_stop` goes through the service manager (otherwise `Restart=always` would immediately pull the freshly stopped process back up)
 - **watchdog deference**: the script generated by `gen_watchdog_script` skips the nginx branch when the unit exists, avoiding both sides pulling up nginx and colliding on ports
 - `cleanup_nginx` first calls `remove_nginx_unit` (stop → disable → delete file → `daemon-reload`)
 - new functions: `_sb_nginx_unit_exists` / `install_nginx_unit` / `_sb_nginx_start_raw` / `_sb_nginx_stop_raw` / `remove_nginx_unit`

v3.2.23 (2026-10-31)
 > Self-healing when a legacy system Nginx grabs the ports — fixing the "subscription 200 false success".

 - **background**: in the 2.0.x era the script would `apt-get install -y nginx` / `yum install -y nginx` / `apk add nginx` and write the subscription site into `/etc/nginx/conf.d/singbox.conf` (or `/etc/nginx/http.d/`)
 - **root cause**: 3.2.22's `cleanup_legacy_system_nginx_conf` **only `rm`-ed without reloading**. The system nginx's in-memory old server block kept holding 31007 / 8001, and the old location happened to serve the newly generated `sub.txt` (same uuid) → **subscription HTTP 200, but served by the system nginx, not the sandbox nginx**. The user believed the install was done; once `systemctl restart nginx` or a machine reboot happened, the config reloaded, the old block vanished, and the subscription immediately 404-ed
 - **fix**: after deleting the leftover config, add one **smooth reload**, the ports are released immediately, and the sandbox nginx can start on its own
   - add `_system_nginx_bin()`: candidates `/usr/sbin/nginx`, `/usr/local/sbin/nginx`, `/usr/local/nginx/sbin/nginx`, `/www/server/nginx/sbin/nginx` (BT Panel)
   - add `_system_nginx_running()`: `pgrep` first, with `ps -A | grep 'nginx: master process'` as fallback (busybox)
   - add `_reload_system_nginx_if_safe()`: **run `nginx -t` first; if the config fails, never reload**; then a three-level fallback of `systemctl reload nginx` → `rc-service nginx reload` → `"$bin" -s reload`; **never stop / disable an external nginx**
 - `nginx_port_owner_diagnose` gains a self-healing branch: when the port holder is nginx, try one reload, then after `sleep 1` **re-check the port ownership**; only when truly released does it pass with `green`; if not released it is the user's own site, so the diagnosis is reported as before and the real conflict is not masked
 - **also fixes a display bug**: `_fcomm`'s sed expression `s/users:(("\([^"]*\)".*/\1/p` is "literal backslash + literal parentheses" on both GNU/BSD sed and can never match, so the whole `ss` line was printed as the process name: `occupying process: LISTEN 0 511 127.0.0.1:8001 ... nginx (pid=...)`. Switched to `grep -o` extraction, and with multiple pids it **prefers the `ppid=1` master** (in `ss` output workers often sort before the master, and the old logic would tell the user to kill a worker, wasted effort)
 - tested (Debian 13, system nginx `active+enabled`): the leftover-config scenario had zero `❌` with automatic takeover and subscription 200; the user's-own-site scenario correctly reported the diagnosis, the site still served its original content, and the system nginx stayed `active+enabled`; after `systemctl restart nginx` the sandbox nginx was unaffected and 31007's ownership unchanged

v3.2.22 (2026-10-31)
 > Fix port ownership detection: the sandbox nginx's workers are no longer misjudged as system nginx.

 - the moment 3.2.21 hit real machines, two bugs surfaced (macOS locally has no `ss` / `/proc`, so they could not be caught there)
 - **bug 1**: `ss -tln` **lacked `-p`** → no `users:(...)` segment at all → the pid was never parsed, always falling back to a full `/proc` scan. It produced results, so the problem was invisible locally, but it was clearly slower
 - **bug 2**: workers were misjudged. Real output `users:(("nginx",pid=510688,fd=5),("nginx",pid=510687,fd=5))` — **workers sort before the master** — and the worker's cmdline is only `nginx: worker process`, without the install path. Under the old logic "take the first pid + match cmdline prefix", once the ss branch was fixed, our own workers would be reported as "system / BT Panel Nginx", a daily false alarm
 - **fix**: `_listener_pid_of_port` → `_listener_pids_of_port`, returning **all** pids of that port; add `_pid_ppid()` (split after the last `) `, tolerant of comm containing spaces/parentheses); ownership passes when any of three conditions holds — the master itself matched / `_pid_ppid` equals the master (adopting the worker) / cmdline contains `$SB_NGINX_DIR`
 - tested: `_listener_pids_of_port 31007` returned `510687 510688`; `_pid_ppid 510688` = 510687; the diagnosis passed silently with zero false positives. After `apk add nginx` created a real system nginx, the diagnosis correctly reported "the occupier is 【system / BT Panel Nginx】"

v3.2.21 (2026-10-31)
 > A clear diagnosis when the system Nginx grabs the ports; subscription failure no longer interrupts installation.

 - **background**: on machines where an old version had installed system nginx, `nginx_pt` / `argo_pt` were taken → `ensure_nginx_if_needed || exit 1` in `ins()` aborted directly, and the user saw "installation failed", even though the sing-box nodes were actually already working and only the subscription 404-ed
 - add `_listener_pid_of_port()`: `ss` first, falling back to scanning `/proc/*/fd` for LISTEN inodes from `/proc/net/tcp` (minimalist environments without `ss`)
 - add `nginx_port_owner_diagnose()`: distinguishes system/BT Panel nginx from the sandbox nginx and offers a three-way resolution — `systemctl disable --now nginx` / `rc-update del nginx` / reinstall with a changed port via `nginx_pt=18080`
 - `start_nginx_service` inserts the diagnosis before bind, saying clearly "who holds the port" instead of dropping only one `error.log` line after the bind fails
 - **subscription failure no longer interrupts installation**: changed to `NGINX_SETUP_FAILED=1` + a yellow warning, with the `ins()` tail noting "sing-box is ready, but the subscription service (sandbox Nginx) is not", exit code 0
 - fixed a wording bug: `bash <(curl -Ls install URL) rep with nginx_pt set beforehand` → `nginx_pt=18080 bash <(curl -Ls install URL) rep` (`rep` does not take positional arguments, so the port can only come through an environment variable)

v3.2.20 (2026-10-29)
 > Argo token validation was too strict: **valid** tokens containing `=` were rejected.

 - **root cause**: `is_valid_argo_token` used the whitelist regex `^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$`. The token Cloudflare issues is `base64(base64url(JSON))`, and when the length is not divisible by 3 it carries `=` padding (the trailing `In0=` is the padding of `"}`); valid tokens were judged invalid outright, and `prepare_argo_credentials` aborted the install
 - **switched to a blacklist**: reject only the characters that would genuinely break where the token lands; everything else is allowed
   - whitespace / control characters (CR LF TAB): systemd `ExecStart` splits on whitespace; lines break when writing units and init scripts
   - `"` `'`: break quote wrapping (unit `ExecStart` / init's `command_args` / `--token "$token"`)
   - `` ` `` `$` `\`: treated as command substitution, variable expansion, and escapes in shells and init scripts
   - `%`: systemd unit specifier expansion (`%i` / `%n` etc.); `%` followed by an unknown letter makes the unit error out directly
   - allowed: `= + / @ : , . ; # ! * ? & | < > ( ) [ ] { } ~ ^ _ -` plus all letters and digits
 - **`argo.service`'s `ExecStart` quotes the token**: originally `--token ${token}` was unquoted — the only one of the three landing points (systemd / openrc / nohup) without quote protection
 - **writing `sbargotoken` switched from `echo` → `printf '%s\n'`**: when a token starts with `-n` / `-e`, `echo` swallows them as options and the file is written broken (the token loses its head when read back)
 - blast radius: `prepare_argo_credentials`, `install_argo_service` (systemd), `install_argo_service_openrc`, and `start_argo_no_daemon` all share this one validation function, so one change takes effect across the whole chain; `sb.sh` and `sb00.sh` were changed in sync

v3.2.19 (2026-10-23)
 - **`cron_running()` falsely reported "cron not running" on Alpine**: it used `pgrep -x cron/crond`, but busybox's `-x` means "exact match of the whole command line", and `crond`'s cmdline is `/usr/sbin/crond -c /etc/crontabs -f`, which can never match; the `ps -ef` fallback is also unavailable on busybox (it only supports `-o`/`-T`). Now it matches by `/proc/<pid>/comm`, and the `ps` fallback keeps both `ps -ef` and bare `ps` spellings

v3.2.18 (2026-10-23)
 > The status panel's "memory usage" was wrong (showed 1M on Alpine/OpenRC).

 - **root cause**: it originally used `pgrep -f "<install path>/sing-box"` to find the pid. OpenRC's `supervise-daemon` command line is `supervise-daemon --exec /root/doraemon/sing-box ...`, which also contains this path, and its pid is smaller than the real service process's, so `head -1` always picked it — the supervisor's RSS is only a few hundred KB, and the panel took 1M as the service memory
 - **fix**: match the process name exactly by `/proc/<pid>/comm` (`sing-box` / `cloudflared`), summing `VmRSS` across same-named processes; no longer relying on pgrep's matching semantics
 - **tested** (Alpine 3.22 / MemTotal 125MB): before the fix sing-box showed `1M` and cloudflared `1M`; after the fix `29M` / `28M`, consistent with `ps -o rss`
 - the "running / stopped" determination now uses the same pid snapshot, so it no longer falsely reports "running" just because the supervisor is alive
 - also noted: `pgrep -x sing-box` on busybox is "exact match of the whole command line" and can never match, so it cannot be used to find service processes

v3.2.17 (2026-10-23)
 > Alpine / OpenRC adaptation.

 - **the watchdog was a no-op on Alpine**: under OpenRC, `sb`'s service name is **`sing-box`** (`/etc/init.d/sing-box`), while under systemd it is `sb`. Both places originally passed `sb`, which never matched on Alpine. Now each init system is handled separately
 - **the OpenRC branch gains an "is auto-start on boot" check**: it judges via the `/etc/runlevels/default/<service>` symlink (equivalent to systemd's `is-enabled`), so services the user removed with `rc-update del` are not pulled back up by the watchdog
 - **`low_mem_tune` no longer prints a misleading banner on Alpine**: Alpine has neither journald nor apt timers, so it skips directly and only writes a debug log
 - the other changes are themselves unrelated to the init system (`GOMEMLIMIT` / `GOGC` / `GOMAXPROCS` are already written into OpenRC's init script as well, and `--ha-connections 1` works in all three places: systemd / openrc / nohup)

v3.2.16 (2026-10-23)
 > Getting OOM-killed is acceptable, but after being killed it must come back on its own.

 - **`sb.service` / `argo.service` gain `StartLimitIntervalSec=0`**: systemd's default "5 starts within 10 seconds" gives up and leaves the unit at `failed`, and afterwards nothing pulls it again. Set to 0 and combined with `Restart=always`, repeated OOM kills keep being retried, and once memory recovers the service comes back on its own
 - **add a service watchdog** `singbox-watchdog.sh` (cron every 2 minutes, pure sh + systemctl, footprint <2MB):
   - under systemd it only handles `failed`, under openrc only `crashed` — **anything manually `systemctl stop`-ed / `rc-service stop`-ed / `disable`-ed is never touched**
   - **the sandbox nginx is not in systemd**; once killed it lies there forever; the watchdog judges by the pid file: it restarts only when the pid file exists but the process is gone (OOM-killed), while `nginx_stop` deletes the pid file, so manual stops are unaffected; when the system reuses the pid for another process, `/proc/<pid>/comm` is validated first
   - logs go to `logs/watchdog.log` (auto-emptied beyond 128KB), and the crontab entry is cleaned up on uninstall

v3.2.15 (2026-10-23)
 - **`argo.service` no longer sets `OOMScoreAdjust=500`**: this key only participates in picking the victim during "machine-wide / container-level OOM"; when argo hits its own `MemoryMax` it is a cgroup-internal OOM, with only itself in the group, so with or without the setting it is argo that dies. What actually decides whether argo gets killed is `GOMEMLIMIT` / `MemoryMax` / `--ha-connections 1`, and all three are kept. To restore "sacrifice argo first when the machine is under pressure", just add the line back in the unit

v3.2.14 (2026-10-23)
 > Stability fixes aimed at 128MB low-memory machines. No protocols removed, no impact on Argo.

 - **no more bare `sniff`**: sing-box's sniff defaults to a 300ms timeout; on pure direct nodes without domain rules, every connection wastes 300ms waiting (in logs it shows as `inbound connection from` → `inbound connection to` fixed at 350~430ms, regardless of the target). `resolve` is kept and continues to carry `sbyx`'s IPv4/IPv6 policy
 - **editing the config no longer clears custom outbounds / routing rules**: `sbbout()` used to wholesale-overwrite `.outbounds = [direct, block]` and `.route.rules = [...]` — after an overwrite install, changing protocols, or toggling the subscription, the landing outbounds added in `[5] Routing Management` and the "attach protocol to proxy" rules were silently wiped and traffic fell back to `direct`. Now only `direct`/`block` are ensured, preserving existing outbounds and non-sniff/resolve rules
 - **removed the dangling reference of the leftover `.warp_config` branch**: rules pointed at `wireguard-out`, but it no longer existed in the outbound table and sing-box refused to start; now the corresponding rule is generated only when that outbound exists
 - **`sb.service` gains full memory constraints**: the systemd branch originally had none at all (only openrc wrote `GOMEMLIMIT`). Small-memory machines get `GOMEMLIMIT` / `GOGC=30` / `GOMAXPROCS=1` / `MemoryHigh` / `MemoryMax` injected by MemTotal, plus `LimitNOFILE=65535`; machines ≥1G are unaffected
 - **`argo.service` gains memory constraints likewise** (`OOMScoreAdjust=500` was removed in v3.2.15, see above)
 - **low-memory machines' Argo edge connections 4 → 1** (`--ha-connections 1`): each QUIC connection carries its own send/receive buffers and goroutines; it only affects edge redundancy, and reconnects happen automatically when broken
 - **the sandbox nginx's WS reverse proxy gains timeouts**: the six `/{uuid}-*` locations gain `proxy_read_timeout` / `proxy_send_timeout 3600s`, `proxy_buffering off`, `proxy_socket_keepalive on`, and `access_log off`. nginx's default 60s would cut idle VMess/VLESS/Trojan over WS outright (in tunnel mode only upstream reads/writes carry timers), showing up as "the connection drops while in use"
 - **nginx `worker_connections` 1024 → 512**: on 128MB, 1024 is waste, and 512 is far above actual concurrency even during reconnect storms
 - **default log level `info` → `warn`**: info writes 2 lines per connection plus N lines per DNS resolution, costing CPU and eating into a 768MB disk on small machines. To troubleshoot connection issues, switch back temporarily: `jq '.log.level="info"' /root/doraemon/sb.json > /tmp/sb.json && mv /tmp/sb.json /root/doraemon/sb.json && sb res`
 - **disk pre-check before downloads**: sing-box needs ≥120MB and cloudflared needs ≥80MB; when short, a cleanup command is given directly (on a 768MB disk, installing both binaries leaves almost nothing, and once full, sing-box crashes outright)
 - **auto-slimming on <256MB machines**: journald capped at 16MB, `apt-daily.timer` / `apt-daily-upgrade.timer` / `unattended-upgrades.service` stopped (apt peaks at 50MB+; many small machines were OOM-killed exactly in this early-morning window). All reversible; `systemctl enable --now` restores them

v3.2.12 (2026-10-21)
 - **the log-rotation cron now auto-installs and starts**: `install_deps` adds `crontab` to the dependency check — Debian/Ubuntu installs `cron`, RHEL-family installs `cronie`, Alpine installs `dcron` only when busybox lacks `crontab` (to avoid conflicting with busybox); after installation `install_log_rotate` pulls the daemon up
   - in containers, `apt install cron` is often blocked by policy-rc.d and does not auto-start; the old version only hinted "you need to arrange scheduled execution yourself"; now it falls back through systemd → openrc → sysvinit (`service cron start`) → launching the process directly, reverting to a manual hint only when all fail
   - users no longer need to run `crontab -e` themselves; log rotation works out of the box

v3.2.11 (2026-10-19)
 > Third batch of the health check (P2: low-frequency / experience / latent hazards). All verified on real VPS machines.

 - **the vless-ws port no longer changes on every overwrite install**: every other protocol reads back `port_vl_ws` first; only vless missed that step, so every `sb ins` re-randomized the port (all client nodes dead)
 - **nginx no longer persists a dirty value on port conflict**: `nginx_port` was written to disk **before** the "nginx_pt equals argo_pt" validation, so after a conflict-abort the dirty port was persisted
 - **`[4][5]` changes to the Argo protocol take effect immediately**: `_set_argo_proto` only wrote the file without `export argo`, while `argo_proto_list`/`need_argo` prefer environment variables → editing right after install from the menu would not stick (you had to restart the script)
 - **interactive installs no longer carry the previous round's protocol selections**: `vlrt/hypt/tupt/anypt/socks5pt` were only exported when selected and never cleaned up, so within one session, canceling an install and re-entering the menu would install the previous round's Hysteria2/TUIC/AnyTLS/Socks5 along with it
 - **the Socks5 password is no longer echoed in plaintext**: the prompt said "set (not echoed)" but used `reading`; changed to `reading_secret` (`read -s`)
 - **entering 0 as an index no longer deletes the wrong object**: `.[(($idx|tonumber)-1)]` turns `0` into `.[-1]` which grabs the last entry; both places (proxy index / rule number) now validate "must be ≥ 1"
 - **IPv6 proxy addresses parse correctly**: `socks5://[2001:db8::1]:1080` was split on `:` giving `_server="[2001"`; now it goes through the bracket branch
 - **no more bash 4.3 dependency**: `install_pkgs_resilient`'s `local -n` (nameref) errors outright on CentOS 7's bash 4.2, making dependency installs fail silently; changed to copy the array by value
 - **the UUID fallback no longer generates 35 characters**: the fallback concatenation when `/proc/sys/kernel/random/uuid` is unavailable missed positions 12 and 16, leaving the last segment with only 11 characters → an invalid UUID
 - **the online wrapper no longer leaks temp files**: `mktemp "${SB_FOLDER}/..."` was expanded to a relative path `doraemon/…` when generating the wrapper (wrong CWD dropped it into /tmp), and `exec bash` left a ~350KB script behind on every `sb` run. Now properly escaped to expand at runtime, with `trap` cleanup (0 leftovers measured)
 - **uninstall no longer deletes the user's own cron jobs**: `sed '/.*singbox.*/d'` deleted any unrelated cron containing `singbox` (e.g. the user's own `/root/backup-singbox-config.sh`); now only this script's `singbox-log-rotate` / `agsb` lines are deleted
 - **no more generating a certainly-unconnectable `pinSHA256` when the certificate is missing**: `openssl | sha256sum` on a missing `cert.pem` produced the fixed hash of empty input; now, without a certificate, `pinSHA256` is omitted
 - **dead code removed**: `edit_socks5_proxy` (defined but never called, and duplicating the `[5][4]` label)

v3.2.10 (2026-10-19)
 > Second batch of the health check (P1: silently broken features / security hazards). All verified on real VPS machines.

 - **`socks5_wl_flag=1` can now actually enable the whitelist**: the comment said `true/1=on`, but `is_true` only accepted `"true"`, so passing `1` left the whitelist entirely ineffective with the port open to the whole internet, while the UI still showed "enabled". `is_true` now accepts `true/1/yes/on`, and `init_socks5_whitelist` normalizes to `true`/`false` before writing to disk
 - **the whitelist switch can finally be turned off**: `init_socks5_whitelist` was originally "the file overrides the environment variable", so on already-installed machines `sb ins socks5_wl_flag=false` never worked. Now environment variables take precedence with the file as fallback
 - **overwrite installs no longer silently disable the subscription / reset ports**: `write2SingboxFolders` unconditionally wrote `"${subscribe}"`, `"${nginx_pt}"`, and `"${ws_cdn}"` to disk, and these three variables were assigned defaults at startup → `sb ins` would turn the subscription off and reset the port to 8080. Now they only overwrite on **explicitly passed arguments**, otherwise the persisted values are kept; the install banner also displays the effective values (no more "shows off, actually on")
 - **installation aborts when dependencies cannot be installed**: `install_deps`'s return code used to be discarded; missing jq/openssl still printed "installation complete"
 - **changing Argo credentials rebuilds the service unit**: the token is hardcoded in the unit / init.d's `ExecStart`; previously it only ran `argorestart`, so changing the token changed nothing; after token→JSON conversion the unit still pointed at the deleted `tunnel.yml`. Now everything goes through `rebuild_argo_service`
 - **failed Argo credential changes roll back**: previously it `rm -f`-ed the old credentials before validating, and a failed validation left both sides empty (old tunnel gone, new one not established). Now it backs up first and restores automatically on failure
 - **"canceling Argo" can actually cancel**: previously it only `pkill`-ed, and systemd's `Restart=always` / openrc's `supervise-daemon` pulled it back up 5 seconds later; besides, `argo`/`vlvm` were not cleared, so `need_argo()` stayed true. Now it stops+disables the service first, then kills the processes, then clears the protocol list, and finally regenerates the subscription
 - **after switching the Argo tunnel, nodes/subscription regenerate**: previously the domain changed but nothing refreshed, leaving the old domain in the subscription
 - **`sbrestart` validates the config before restarting**: the schema is checked with `sing-box check`, **and referential integrity is separately validated with jq** (when `route.final` / `rule.outbound` point to nonexistent outbounds, `check` returns 0 but runtime FATALs `default outbound not found`, then gets pulled into a crash loop by supervise). If validation fails it does not restart and keeps the current process; `SB_SKIP_CHECK=1` can force it
 - **deleting a socks5 proxy no longer breaks the config**: before deleting it checks whether `route.final` points at it (if so, reverts to `direct`), otherwise final dangles → sing-box cannot start
 - **changing a protocol's proxy no longer hurts other protocols in the same rule**: "change to direct" used to delete the entire inbound rule; with one rule carrying `hy2-sb` + `vless-reality-vision-sb`, changing hy2 flipped vless to direct too. Now only the target protocol is plucked from the `.inbound` array, and the rule is deleted only when the array is empty (same for changing proxies)
 - **the sandbox Nginx's pid is identity-checked**: originally only `kill -0`; after a reboot when the pid was reused by another process, `nginx_stop` would TERM/KILL an unrelated process as root. Now it validates that `/proc/<pid>/comm` contains `nginx`
 - **cloudflared downloads to a temp file + atomic replace after validation**: originally `curl -Lo` overwrote the running binary directly, and curl lacked `-f`, so a 404 HTML error page counted as a "successful download"; the failure branch even deleted the previously working file

v3.2.9 (2026-10-19)
 > The first batch of the full-script health check (P0: things that keep services from starting / corrupt configs / delete data). Every item verified in the code.

 - **fix the hazard that could delete the entire install directory**: in state collection, `_tmpd="$(mktemp -d 2>/dev/null || printf '%s' "$SINGBOX_FOLDER_PATH")"` fell back to the install directory when `mktemp` failed, and the function's end would `rm -rf "$_tmpd"` → the entire `doraemon/` wiped. Now a `mktemp` failure skips state collection entirely, and a whitelist check is added before `rm -rf` (never touching the install directory)
 - **fix value-return functions polluting return values by printing hints to stdout** (`get_short_id` / `normalize_cdn_pt` / `show_sub_url`): these functions are called in `$(...)`, and their `yellow`/`green` hints got captured along with it. When `get_short_id` triggered (after an upgrade, when sid and the private-key-derived value disagree — quite common) it returned "ANSI + Chinese + newline + sid", which `jq --arg` wrote into `short_id`; sing-box's hex validation failed and the box refused to start; `normalize_cdn_pt` likewise corrupted `cdn_pt`. All three hints now go to `>&2`
 - **fix `timeout` wrapping shell functions, permanently breaking features**: `timeout 8 _resolve_domain_ips_impl ...` and `timeout 6 query_ip_region ...` — `timeout` is an external command and cannot execute shell functions (execvp fails, exit 127 with stderr discarded), so **reverse DNS lookups and region queries always returned empty on all target machines**, and legitimate domains were perpetually flagged "not yet effective in DNS". Replaced with the homegrown "background execution + watchdog kill" timer `_sb_run_with_timeout`
   - also fixed local resolver addresses mixing into DNS reverse-lookup results (busybox nslookup prints `10.10.0.1:53` as a result); now only the real IPv4/IPv6 are kept
 - **fix new configs not taking effect after overwrite installs**: `sbbout` used `systemctl start sb` / `rc-service sing-box start`, and `start` is a no-op when the service is already running → the old process kept the old ports while nginx/subscription had been generated for the new ones, making all nodes 502. Changed to `restart`; the nohup branch `pkill`s first and then relaunches
 - **fix nginx config changes not taking effect**: `ensure_nginx_if_needed` called `start_nginx_service`, which directly `return 0`-ed when "already running". Changed to "reload via `nginx_restart` when already running, otherwise start", and **the failure code is now propagated** to `ins`'s `|| exit 1` (previously it unconditionally `return 0`-ed, and even when nginx could not start it still printed "installation complete")

v3.2.8 (2026-10-19)
 - **install-time `server_ip` selection also gains CDN ownership checks** (previously only `[4][10]` had them): if `pick_server_ip_for_install` finds the egress IPv4 belongs to Cloudflare / Fastly / Akamai, the v4 egress is being proxied by WARP / cloud-vendor NAT and the like, and using it as the node address means the client connects to a CDN edge node and the node can never work — it automatically switches to IPv6 in that case
   - **soft judgment**: it only replaces when the CDN vendor is positively identified **and** the machine has usable IPv6; when ip-api.com is unreachable it continues per the original logic, not affecting install success rates
   - explicit `ippz=4` respects the user's choice, keeps IPv4, and only warns
   - explicit `out_ip` is adopted directly, but a CDN ownership triggers a warning
   - **logging**: the judgment result goes into the install log (both `yellow`/`white` write to disk), e.g.
     `▸ egress IPv4 x.x.x.x did not match the three major CDNs (Cloudflare/Fastly/Akamai), using it per the original logic`,
     `⚠️ egress IPv4 x.x.x.x belongs to Cloudflare (CDN vendor), switched to IPv6 ...`,
     `⚠️ egress IPv4 x.x.x.x belongs to Cloudflare (CDN vendor), but this machine has no usable IPv6; keeping IPv4`,
     `⚠️ out_ip x.x.x.x belongs to Fastly (CDN vendor) ...`
   - plus `debug_log` branch-by-branch debug info (printed to the terminal when `DEBUG_FLAG=1`)

v3.2.7 (2026-10-19)
 - **`[4][10]` auto-detection gains CDN ownership checks**: if the egress IPv4 belongs to **Cloudflare / Fastly / Akamai**, the v4 egress is being proxied by WARP / cloud-vendor NAT and the like — using it as the node address means the client connects to a CDN edge node rather than this machine. It automatically switches to IPv6 in that case
   - detection goes through ip-api.com's ASN + organization name double insurance: Cloudflare (AS13335 / 132892 / 202623 / 203898 / 394536), Fastly (AS54113), Akamai (AS20940 / 16625 / 21342 / 18717 / 32787); if the ASN misses, it falls back on the name
   - **auto mode**: v4 hits a CDN and a usable v6 exists → use v6 with the reason stated; no v6 → keep v4 with a note of "which CDN it belongs to"
   - **explicit choice of 4**: the user's choice is respected and v4 is used, but with a note of which CDN the address belongs to
   - **manually specified IP**: also noted
   - when the query fails (ip-api.com unreachable) it does not block and falls back to the original logic

v3.2.6 (2026-10-19)
 - **fix the address-family selection of `[4][10]` auto-detection**: it used to guess by "the address family of the current server_ip" (if currently IPv6, prefer IPv6), which on a machine/egress change could quietly flip nodes configured with only a v4 egress to v6 addresses, leaving clients all unable to connect
   - now it **selects the address family on the spot**, with semantics matching install-time `ippz`: `4=IPv4 only` / `6=IPv6 only` / Enter=`auto` (prefer IPv4, fall back to v6 when no v4)
   - when detection fails, the stated reason matches the chosen family ("no IPv6 egress address detected" rather than a vague network error)
   - still not persisted: `ippz` is inherently an install-time parameter in the script, and persisting it would make later nginx regeneration's `listen [::]` judgment shift, easily breaking IPv6 origin relay

v3.2.5 (2026-10-19)
 - **add `[4][10] Server address (server_ip)`**: after changing machines / egress IPs you can directly change the address shown in nodes without reinstalling
   - `1) Auto re-detect`: goes through `check_ip_connectivity` for the egress IP, with the address family chosen on the spot (see v3.2.6)
   - `2) Manually specify IP`: accepts only IPv4 / IPv6 (for domains use `[4][6]`); IPv6 is auto-wrapped in `[]` when written to disk
   - after the change, node links and the subscription regenerate immediately; when the result equals the current value it directly notes "no change needed" and does not restart pointlessly
   - the menu also shows the current `direct_host` state and explains the relationship between the two (when `direct_host` is set, direct links use the domain and server_ip is only the fallback)
 - the `[4][6] Direct external domain` menu gains a guide line: to change "the real server IP" itself, go to `[4][10]`
 - note: `ippz` (IP preference 4/6/auto) is **not** made a menu item — it is install-time semantics, also deciding each inbound's `listen` in `sb.json` and whether nginx `listen [::]`; changing it after install easily breaks IPv6 origin relay; reinstall with the environment variable when needed

v3.2.4 (2026-10-19)
 - in `[4] Node configuration changes`, the title of `8) Identity information` adds "Reality keys", matching the newly added key rotation entry (`UUID / name prefix / Socks5 account / Reality keys`)

v3.2.3 (2026-10-19)
 - **`[4][8] Identity information` gains "Regenerate the Reality keypair"** (`reality_private` could previously only be passed at install time, with no way to rotate after a leak)
   - three spots must change in sync; missing one leaves clients unable to connect: `reality.key` (the `pbk` in links), the `short_id` file (the `sid` in links, derived by the private key sha256's first 8 hex chars), and `sb.json`'s `tls.reality.private_key` / `short_id`
   - it generates a new keypair first → writes a temp config and validates with `sing-box check` → only then writes to disk; on validation failure the live config is untouched
   - the old key is auto-backed-up to `reality.key.bak` (overwritten on each rotation)
   - like changing the UUID it requires typing `yes` for a second confirmation, and warns "all Reality nodes become invalid immediately; clients must re-import"
   - the menu directly shows the current public key for easy comparison with the client

v3.2.2 (2026-10-19)
 - **add `[4][9] WS-CDN origin relay protocol toggle`**: after install you can enable/disable vmess / vless / trojan's CDN origin relay directly (previously only a `ws_cdn=` reinstall was possible). CDN origin relay is a separate inbound (`*-ws-cdn-sb`) + a separate port file + a separate nginx location; enabling auto-assigns the relay port, appends the inbound, regenerates the nginx config, and refreshes the subscription; disabling removes the inbound / port file / location and the nodes go dead immediately
   - on enabling it states the relay address and this machine's nginx port; if the relay SNI is not yet configured it clearly notes "node links will not be generated for now" and guides you to configure it in `[4][3]`
 - install menu: Socks5 can choose an **IP whitelist** at install time (`socks5_wl_flag` / `socks5_ips`, supporting CIDR and comma-separated lists); previously this could only be configured in `[4][7]` after install
 - install menu: when **the subscription is off but Argo / WS-CDN origin relay is enabled**, it separately asks for the relay Nginx port (previously it silently used 8080, and changing it required first enabling the subscription)
 - fixed `ensure_nginx_if_needed` recognizing only the `ws_cdn` environment variable and not the persisted file (after changing ws_cdn from the menu, nginx preparation might not trigger)

v3.2.1 (2026-10-19)
 - **remove the script-name hardcoding; sb00.sh and sb.sh now differ only in the `SB_SCRIPT_NAME` line**:
   - the binary version cache file names derive from `SB_SCRIPT_NAME` (`${SB_SCRIPT_NAME%.sh}_sb_ver` / `_cf_ver` / `_ng_ver`), no longer hardcoded `sb00_*`. sb00.sh still lands in `sb00_*_ver` (no migration needed), sb.sh lands in `sb_*_ver`; both scripts in the same directory no longer overwrite each other's caches
   - the openrc unit's heredoc delimiter `OPENRC_SB00` → `OPENRC_UNIT`
   - the log-rotation script's header comments and routing-related comments change `sb00` to `$SB_SCRIPT_NAME` / neutral wording
   - audit result: the whole file contains no `sb00`/`SB00` literals except `SB_SCRIPT_NAME="sb00.sh"`, so moving to sb.sh only requires changing that one line
 - **upgrade note (sb.sh users only)**: old sb.sh versions wrote `sb00_*_ver`, and after upgrading they read `sb_*_ver`; on first open the status panel's version numbers may briefly be empty (with a `timeout 3` probe as fallback, functionality unaffected), and the next install/update fills them automatically. To show them immediately, run:
   ```bash
   cd /root/doraemon && for k in sb cf ng; do [ -f sb00_${k}_ver ] && cp -p sb00_${k}_ver sb_${k}_ver; done
   ```

v3.2.0 (2026-10-19)
 - **the `node` node configuration menu fills 5 gaps** (previously these variables could only be set via environment variables at install time, with no entry after install):
   - `[4][1] Port changes` adds the **Socks5 port** (`socks5pt`); also fixes the leftover-flag issue where "after changing the ws port, changing any other port also restarted nginx"
   - `[4][2] Subscription settings` adds **enable node subscription** (previously it could only be turned off, not on): it auto-installs/configures the sandbox Nginx, opens the port, generates `sub.txt`, and echoes the subscription address
   - add **`[4][8] Identity information`**: change UUID, node name prefix, Socks5 username/password
   - `[4][3] SNI / CDN settings` adds **per-protocol dedicated parameters** (14~25 items): `ws_cdn_{vmess,vless,trojan}_sni` / `_cf_pt`, `argo_{vmess,vless,trojan}_cf_host` / `_cf_pt`; leaving empty cancels, entering `-` clears and falls back to the shared value
   - the install menu completes the **AnyTLS disguise domain `any_sni`** and the **Socks5 port/username/password** (previously the socks5 port was always random and the credentials could only be auto-generated)
 - **changing the UUID requires a second confirmation**: the UUID affects user credentials, the ws transport path, the nginx reverse-proxy location, and the subscription address; after a change all already-delivered nodes become invalid immediately; it now states the impact scope first and executes only after typing `yes`
 - **fix the subscription port being quietly reset to 8080**: `setup_nginx_subscribe` used `${nginx_pt:-8080}`, but `nginx_pt` had already been assigned its default at startup, so any menu-triggered nginx regeneration wrote the subscription port back to 8080 (and the subscription address 404-ed immediately). Now uniformly resolved via `_eff_nginx_pt` / `_eff_argo_pt`: explicitly passed (non-default) > persisted `nginx_port` / `argoport` > default

v3.1.11 (2026-10-19)
 - log rotation extends to the sandbox Nginx's `access.log` / `error.log` and `logs/stop_reason.log`; the rotation script becomes `rotate_dir()` supporting multiple directories (nginx also opens logs with `O_APPEND`, so copy-truncate needs no USR1 reopen)

v3.1.10 (2026-10-19)
 - **the openrc service switches to `supervise-daemon`**: sing-box / cloudflared are auto-relaunched after crashes (previously only `command_background=yes`, and a dead process never restarted); the systemd unit's `Restart=on-failure` becomes `Restart=always`
 - low-memory machines (MemTotal < 1G) automatically export `GOMEMLIMIT` (50% of physical memory), lowering the chance of cgroup OOM
 - add log rotation: check the logs under `logs/` hourly, rotating with "copy + truncate" beyond `LOG_ROTATE_SIZE_KB` (default 10 MB), keeping only 1 historical copy

v3.1.8 (2026-09-23)
 - **fix install-flow exit code misreporting**: the script's redefined `echo` function, when not on a TTY (background/nohup runs), made the trailing `[ -t 1 ] && _log_write ...` return 1 overall, so the entire install/overwrite flow ended with "exit code 1" (on a terminal TTY it was normally 0). Now it force-`return 0`s, and background installs' exit codes are correct again

v3.1.7 (2026-09-23)
 - supplement the version-cache write in `ins`'s sing-box "already installed, skip download" branch (consistent with the `update_singbox` path)

v3.1.6 (2026-09-23)
 - **fix the status panel not showing Sing-box / Cloudflared versions**: versions are now "cached to disk on successful install/update"; the status panel reads the cache files first (`sb00_sb_ver` / `sb00_cf_ver` / `sb00_ng_ver`) and only runs binary probing when the cache is missing; this thoroughly avoids repeatedly running `version` against a running cloudflared tunnel (when the tunnel is running, that probe hangs/times out and leaves the version empty)

v3.1.5 (2026-09-23)
 - **fix status/menu freezing**: `menu_status_block` adds `timeout 3` protection to all version probes of sing-box / cloudflared / nginx, and uses "polling + total timeout 6s" instead of a bare `wait`. In practice, `cloudflared version` hangs permanently while the tunnel is running, and the old version left the status panel stuck at "fetching service status..."; now a timed-out probe is skipped automatically, delaying the status panel by at most 6 seconds
 - after a probe timeout, leftover probe processes are explicitly terminated, ensuring menus/status never get stuck in any situation

v3.1.4 (2026-09-23)
 - **the status panel gains memory usage display**: the Sing-box / Cloudflared / Nginx status lines each append "Memory: xM" (from `/proc/<pid>/status`'s VmRSS)
 - Nginx memory = master + all workers summed, strictly attributed by the pid file (only this sandbox nginx's pids count, no name matching, so the system nginx is never miscounted)

v3.1.3 (2026-09-23)
 - **port conflict hint upgrade**: when a port is held by an external process (not this script) during install/reinstall, it now shows "occupying process + pid + release command `kill <pid>`"; combined with `ss -tlnp | grep :<port>` you can locate and free it in one step

v3.1.2 (2026-09-23)
 - when Nginx fails to start, it automatically parses `bind() to <ip>:<port> failed (98: Address in use)` from error.log, pinpointing which port is taken and giving the release command (`ss -tlnp | grep :<port>` + `kill <pid>`, with lsof as fallback when ss is absent)

v3.1.1 (2026-09-23)
 - **fix port conflict detection misjudging system nginx as "our own"**: when looking up the process holding a port, it no longer matches by `comm=nginx`/cmdline containing `nginx` (it mistook system/BT Panel nginx for this script's sandbox nginx, so port conflicts were skipped); the sandbox nginx is attributed solely via the pid file

v3.1.0 (2026-09-23)
 - **sandbox Nginx dual-source download fallback**: when the primary source github.com (jirutka/nginx-binaries) fails or fails validation, it automatically switches to the backup source cdn.jsdelivr.net (content hash identical to the primary), with retries per source; only when both fail does it fall back to the old version
 - add `SB_NGINX_URL_BACKUP` to override the backup source wholesale

v3.0.9 (2026-09-23)
 - **sandbox Nginx downloads get pinned SHA256**: built-in static binary SHA256 for both x86_64 / aarch64 architectures, enforced validation after download, guarding against supply-chain poisoning/corrupted downloads; overridable wholesale via `SB_NGINX_SHA256`

v3.0.0 (2026-09-08)
 - **Naming refactor that completely eliminates the `cdn_host`/`cdn_pt` ambiguity**: Argo sharing becomes `argo_cf_host` / `argo_cf_pt` (dedicated `argo_vmess_cf_host` etc.); CDN origin relay sharing becomes `ws_cdn_cf_host` / `ws_cdn_cf_pt` / `ws_cdn_sni` (dedicated `ws_cdn_vmess_cf_host` / `ws_cdn_vmess_sni` etc.). **`cdn_host` / `cdn_pt` are officially retired**, kept only as legacy Argo compatibility aliases; new setups no longer use these two environment variables
 - **Zero-migration upgrade cost for existing users** (compatible with legacy `cdn_host` / `cdn_pt`):
   - Old commands passing `cdn_host=xxx cdn_pt=2083` keep working (→ `argo_cf_host` / `argo_cf_pt`, new names take precedence)
   - Legacy on-disk files `cdn_host` / `cdn_pt` / `vlvm` (single protocol) are read automatically by `cip`/`list` after upgrade, and **the printed node strings are exactly identical to the old version's**
   - On `rep` reinstall, config is not lost even when new names are not passed: old `cdn_host`/`cdn_pt` file values are migrated automatically to `argo_cf_*`
 - **Subscription URLs fully compatible**: the old subscription had only the "Argo / http" two branches; the new version adds the "CDN origin relay" subscription branch only when an origin relay domain `ws_cdn_sni` (or dedicated `ws_cdn_{p}_sni`) is configured — existing users (no ws_cdn files) are unaffected, and subscription links stay unchanged after upgrade
 - On-disk persistence switched to a "keep/migrate" policy (`fs_write_or_keep`): env value > existing file > legacy-name file migration > default, never overwriting the user's existing config

 - **New ws_cdn feature**: Vmess/Vless/Trojan WS direct connection through CDN (without Argo)
 - New switch `ws_cdn=vmess,vless,trojan` (comma-separated, multi-select); when coexisting with Argo, nodes of both kinds are printed
 - Domains can differ per protocol (suitable for Cloudflare origin rules with wildcard domains + multiple origin domains sharing one A record): `ws_cdn_vmess_cf_host` / `ws_cdn_vless_cf_host` / `ws_cdn_trojan_cf_host` (plus each one's `_sni`/`_pt`)
 - Shared fallback parameters: `ws_cdn_cf_host` / `ws_cdn_sni` / `ws_cdn_cf_pt` (default 443); priority "protocol-specific > shared > default saas.sin.fan/443"
 - Reuses the existing local ws ports (port_vm_ws / port_vl_ws / port_tr) and nginx reverse proxy (/${uuid}-vm/-vl/-tr), **no new port files / no new inbounds / no new nginx locations**
 - CDN origin relay port = server `nginx_pt` (default 8080); the nginx install condition and the 8080 firewall allowance now also cover the ws_cdn scenario
 - New subscription URL priority (show_sub_url): fixed Argo (tunnel alive) > shared origin relay domain ws_cdn_sni > dedicated origin relay domain ws_cdn_{p}_sni > temporary Argo > http; `sub_domain=argo/cdn` supported to force a choice
 - New effective-value resolution functions `ws_cdn_val / ws_cdn_eff_host/sni/pt / ws_cdn_proto_enabled`; config persisted to disk + environment variables take priority
 - The interactive menu adds a "Vmess/Vless/Trojan WS direct connection through CDN" selection block (multi-select protocols + per-protocol origin relay domain + shared host/sni/port)
 - Security: all dynamic assignments (disk persistence / menu injection) now use indirect expansion + `printf -v` instead of `eval`
 - Incidental fix: the port settings menu now checks `vmag` to decide whether the Argo port is needed (previously, ws_cdn triggering vmp/vlp/trp would wrongly ask for the Argo port)

 - **Argo protocols upgraded from "pick one of three" to "multi-select"**: `argo=vmess,vless` and any other combination (comma-separated); cip display / jh.txt / subscription / nginx reverse proxy all print the corresponding nodes per the selected protocols, and each node can use a different preferred domain/port
 - New per-protocol Argo dedicated preferred domains/ports: `argo_vmess_cf_host` / `argo_vmess_cf_pt`, `argo_vless_cf_host` / `argo_vless_cf_pt`, `argo_trojan_cf_host` / `argo_trojan_cf_pt`; fall back to the shared `argo_cf_host` / `argo_cf_pt` when unset
 - The shared CF preferred domain/port variables are renamed from `cdn_host` / `cdn_pt` to `argo_cf_host` / `argo_cf_pt` (legacy names `cdn_host` / `cdn_pt` remain compatible, new names take precedence); internal node generation/fallback logic still uses the normalized values
 - Fix: WS-CDN origin relay node links had a path missing the `-cdn` suffix (previously mismatched with the nginx reverse proxy / inbound `/{uuid}-{p}-cdn`, so ws_cdn nodes could not reach the origin)
 - CLI interactive menu: Argo selection supports multi-select (f/g/v combinations), plus a new "Argo CF preferred domain/port — unified or separate" input step; the Argo protocol switch menu becomes a per-protocol toggle
 - Routing management (socks/http attached protocols, viewing the proxy exit) adds support for WS-CDN standalone inbounds (`vmess-ws-cdn-sb` / `vless-ws-cdn-sb` / `trojan-ws-cdn-sb`)

v2.0.2 (2026-09-07)
 - **Security hardening**
 - New root privilege check: running as non-root is rejected outright (the script writes to /root, /etc/systemd, (openrc) init.d, /etc/iptables and other system directories)
 - Install log permissions tightened: `logs/` directory 700, `install.log` 600 (the logs contain UUID / reality private key / socks5 password; the old version defaulted to 644, world-readable)
 - Fix: maintenance commands polluting the install log — scenarios like `list`/`cip` that wrote directly to `install.log` are now gated by `INSTALL_LOGGING`, preserving "only the most recent install is kept"
 - Argo token file permissions tightened: systemd `/etc/systemd/system/argo.service` / openrc `/etc/init.d/argo` are now chmod 600; the old version's 644 let any local user steal the tunnel token
 - **Fix: `sb.json` permissions fell back to 644 after rewrites**: the 25+ `jq > tmp && mv` write-backs in routing management / port changes / SNI changes / adding-removing proxies are unified through the new `sbj_save()` (validates the tmp file is legal JSON + forces chmod 600); `sb.json` contains all protocol credentials
 - uuid gains a character-set validation (only `[0-9a-fA-F-]` allowed): a user-supplied uuid gets interpolated into nginx locations and subscription paths, so this guards against config injection via newlines/control characters
 - Shortcut command wrapper hardening (`gen_online_wrapper()`): before execution it validates that the fetched script contains a `VERSION` declaration (intercepting error pages / tampered content), and warns when the version differs from the one at generation time (catches raw.githubusercontent CDN caching / fetch anomalies); also fixes a bug where the `singbox` wrapper, lacking the exported `SINGBOX_FOLDER_PATH`, always fell through to online fetching
 - Removed the logic that "sent proxy URLs containing account passwords to a third-party checking API (check.socks5.cmliussss.net)", replaced with a local curl self-test through the proxy; credentials reach only the proxy itself
 - New optional download checksums: setting the `SINGBOX_ARCHIVE_SHA256` / `CLOUDFLARED_SHA256` environment variables enforces checksum validation of the sing-box / cloudflared downloads (when unset, the original content-sniffing + structure + version checks remain)
 - Region lookup (ip-api.com) now prefers https with fallback to http on failure
 - **Features / Bug fixes**
 - The nginx subscription port joins the firewall: `apply_singbox_iptables_rules` adds an ACCEPT for nginx_pt when subscribe=true or Argo is enabled; a unified `refresh_firewall_rules()` is added (flush + replay + whitelist + save), called uniformly by `ins`, the port-change menu, and the subscription-port menu, fixing "after a port change the firewall does not refresh — the new port is blocked while the old port stays open"
 - Port-taken detection made memory-resident: `SB_TAKEN_PORTS` now uses an associative array for O(1) lookups; `rand_port` pre-filters with an ss snapshot taken at startup plus a live ss fallback (centralized allocation flows like install skip repeated forking; long-lived scenarios like interactive menus still check live for accuracy)
 - Fix: when not installed, maintenance commands like `list`/`sub`/`node`/`rt`/`logs` were wrongly blocked by the "set at least one protocol variable" guard (only ins/rep enforce it)
 - Fix: an edge bug where vless-ws port reuse produced an empty port when the `port_vm_ws` file was empty, and jq `tonumber("")` failed, silently dropping the vless-ws inbound

v2.0.1 (2026-09-06)
 - argo values changed to `vmess / vless / trojan` (multi-select supported, comma-separated, e.g. `argo=vmess,vless`); the old values `vmpt/trpt/vlpt` are fully deprecated and no longer read
 - Invalid external argo values (including legacy ones) prompt and exit immediately during install/overwrite install; already-persisted config (vlvm) is still honored
 - Enabling vmess/trojan/vless is decided entirely by `argo=`; the three protocols' local origin relay ports no longer accept external specification and are randomized automatically by the script (or reuse persisted port_*), naturally fitting NAT machines
 - New port-taken registration mechanism: random ports automatically avoid "explicit ports / service ports (nginx_pt/argo_pt) / persisted port_* / ports currently listening on this machine", eliminating multi-protocol port collisions
 - The interactive menu's Argo protocol selection now sets the new argo value directly; the port settings no longer ask for the three Argo ports
 - The install log adds a printed `Argo协议: xxx` (Argo protocol: xxx) line; protocol ports print with their on-disk file hints when `DEBUG_FLAG=1`
 - Nginx install condition made explicit: Nginx is installed when subscribe=true **or** Argo is enabled (Argo origin relay goes through the Nginx reverse proxy)
 - README synced with the new values and examples; a new quick-reference table for "when Nginx gets installed" is added
 
v1.0.30 (2026-09-05)
 - **Security hardening**
 - **Fix: reality_private being ignored**: local public-key derivation no longer depends on `xxd` (since Debian 12/13, `/usr/bin/xxd` is a standalone `xxd` package and `vim-common` no longer provides it), switching to `openssl pkey -inform DER` to read PKCS#8 DER directly — derivation works as long as openssl is present. In the old version, environments without xxd failed derivation → silently generated a new keypair, so passing `reality_private` yielded inconsistent nodes
 - Removed the online Reality private key derivation fallback: the old version, on local derivation failure, sent the private key in plaintext to a third party via `?privateKey=` (realitykey.cloudflare.now.cc); it now fails outright and falls back to generating a new keypair — the private key is never sent out
 - Argo credential/domain validation: new `is_valid_domain` / `is_valid_argo_token` (including embedded newline/CR checks to prevent grep cross-line bypass); invalid tokens/domains are refused from being written into systemd ExecStart / openrc command_args / tunnel.yml (preventing command and config injection)
 - Runtime integrity validation of binary downloads: sing-box (intercepts HTML error pages, validates the archive contains the sing-box binary, version must equal 1.13.14); cloudflared (intercepts HTML error pages, `--version` must parse)
 - Credential files uniformly chmod 600: tunnel.json / tunnel.yml / sbargotoken / argo_domain / reality.key / uuid / sb.json / jh.txt
 - Socks5 whitelist IP/CIDR format validation (`is_valid_cidr`): invalid entries are skipped with a warning; if all entries are invalid it errors out, ending the "shows enabled but actually has no effect" behavior
 - A risk warning prints when the subscription goes over plain HTTP (the subscription URL contains all node credentials; recommended only on trusted networks)
 - `setenforce 0` runs only when SELinux=Enforcing and prints a notice, no longer silently disabling SELinux
 - Interactive input of Argo token / reality_private now uses `read -s` silent input to prevent terminal echo
 - pkill/pgrep matching narrowed to this script's install path, avoiding killing unrelated same-named processes on the system
 - crontab cleanup switched to a `mktemp` temporary file, eliminating the symlink attack surface of the fixed path `/tmp/crontab.tmp`
 - **Bug fixes**
 - Fix: Alpine(openrc) `sb autostart` generated a broken init script: inside the heredoc, `${name}`/`$command`/`$pidfile`/`$command_args`/`$?` were expanded to empty by bash too early, so start/stop both failed
 - Random ports avoid TCP/UDP ports already listening (ss detection + up to 20 retries)
 - Port-conflict detection gains a "system already listening" notice (the sing-box/cloudflared/nginx listeners belonging to this script's own stack are not counted as conflicts, avoiding false reports on rep overwrite installs against old instances)
 - Node link fragments uniformly URL-encoded: spaces / `#` / `?` / `&` in `name` no longer break links; vmess nodes' `ps`/`add`/`host`/`sni` fields get JSON escaping
 - `append_jh` switched to `printf` when writing the subscription file, preventing `\n`/`\x` escape injection into subscription content; node names are stripped of CR/LF
 - Dead code removed: `setup_warp_config` / `singbox_status` / `interactive_uninstall_menu`
 - Version bumped to 1.0.30

v1.0.29 (2026-08-27)
 - **Fix: overwrite installs wiped all iptables rules** — in the old version, `iptables -F` inside `install_step()` forcibly cleared every firewall rule (including those added by other programs); it now clears only rules tagged by this script
 - New iptables/ip6tables rule tagging system: all protocol ports are tagged `doraemon_singbox_rule`, whitelist socks5 is tagged `socks5_rule`, precisely identified via `--comment`
 - New `apply_singbox_iptables_rules()`: adds iptables ACCEPT rules for all protocol ports (vmess/trojan/vless/socks5)
 - Refactored `flush_singbox_iptables_rules()`: uniformly clears all rules carrying either tag, so uninstall/overwrite installs no longer affect other programs
 - Whitelist implementation moved from sing-box `route.rules` to iptables/ip6tables: connections from non-whitelisted IPs are blocked directly at the TCP layer, supporting IPv4/IPv6 simultaneously
 - Version bumped to 1.0.29

v1.0.26 (2026-08-26)
 - New Socks5 IP whitelist feature: controlled via `socks5_wl_flag` (switch) and `socks5_ips` (IP list); only whitelisted source IPs can reach the Socks5 inbound
 - Passed in via environment variables at install; after install it can be toggled and the IP list edited through the interactive menu `node → Socks5 IP Whitelist Management`
 - Case-insensitive: `true`/`True`/`TRUE`/`1` are all recognized as enabled

v1.0.24 (2026-08-25)
 - **Fix: Reality private keys in base64 encoding broke sing-box startup** — the old reality.key used standard base64 (`+`/`/` with `=` padding), while sing-box 1.13+ expects URL-safe base64 (`-`/`_` without padding); the `+` character in keys was rejected at decode
 - New `_to_urlsafe_base64()` conversion helper: keys are automatically converted from standard base64 to URL-safe base64 when read
 - Covers all key-reading paths: `init_reality_keypair()` / `ensure_and_print_reality_private_for_cip()` / `regenerate_links_and_sub()`
 - `sbbout()` pre-creates singbox.log before startup, then checks 3 seconds after startup whether the log file was generated


v1.0.23 (2026-08-25)
 - sbbout() pre-creates singbox.log before startup, ensuring the file exists when sing-box starts
 - 3 seconds after startup it checks whether the log file was generated; if empty, a yellow warning is shown

v1.0.22 (2026-08-25)
 - Fix sbrestart/argorestart: under systemd, manual pkill is no longer used, avoiding processes escaping the cgroup so the service shows "stopped" after restart
 - New capture_stop_reason(): when a service stops abnormally, the cause is captured automatically from journalctl/dmesg/app logs and written to `doraemon/logs/stop_reason.log`
 - New `sb log_stop` shortcut command + menu item to view the stop reason
 - cleandel optimization: `systemctl stop` gets a timeout 5 safeguard, and each cleanup stage adds progress hints (▸→✓)

v1.0.21 (2026-08-25)
 - New log-viewing shortcut commands: `sb logs` (menu), `sb log_sb`, `sb log_argo`, `sb log_ins` (optionally with a line count, e.g. `sb log_sb 100`)
 - Extracted show_log_file() as a shared function used by both the menu and CLI
 - cleandel removed the redundant /proc/[0-9]* iteration loop (2 forks per process caused a ~6s stall), already covered equivalently by pkill

v1.0.20 (2026-08-25)
 - All logs consolidated into the `doraemon/logs/` subdirectory (install.log / singbox.log / argo.log / deps_failed.log / nginx_install.log)
 - New migrate_logs_dir(): old installs automatically migrate logs scattered in the root directory into logs/, with systemd handles carried over seamlessly
 - cleandel's keep list changed from `sing-box|cloudflared|install.log` to `sing-box|cloudflared|logs` (the whole log directory is kept)
 - The menu's log submenu updated in sync

v1.0.19 (2026-08-25)
 - New script install logging system (records the whole ins/rep/menu install flow), zero pipes, zero terminal interference
 - Color-function hooks + echo hooks dual-write plain text to `doraemon/install.log`
 - Log menu refactored: filter by time/line count/keyword, with clear and copy-path actions
 - New `DEBUG_FLAG=1` environment variable enables debug mode; all debug output goes to `doraemon/debug.log`
 - cleandel keeps install.log from being cleaned up
 - install_deps switched to real-time line-by-line output (de-piped), with failed dependencies recorded in the log

v1.0.15 (2026-08-08)
 - The Argo tunnel protocol upgraded from vmess/trojan pick-one to vmess/trojan/vless pick-one-of-three
 - New vless argo support: enable with `argo=vless` (vless-ws goes through Argo)
 - The install menu / port-change menu / Argo protocol switch menu / routing management all support vless
 - The nginx subscription adds a `/${uuid}-vl` reverse proxy; vless argo links are printed automatically to the subscription and jh.txt

v1.0.14 (2026-08-07)
 - Interactive menu operation supported
 - `sb` shortcut commands supported: after install, run `sb` directly for the main menu, or one-step shortcuts like `sb ins`/`sb rep`/`sb list`/`sb rt`/`sb node`/`sb sub`/`sb del`
 - Built-in proxy / routing management supported
 - Easy pairing with the proxy [jyucoeng/aimili-vpngate](https://github.com/jyucoeng/aimili-vpngate), whose proxy exits are home-broadband IPs, letting nodes use a residential exit

v1.0.13
 - sing-box kernel (1.13.14) download source switched to this repo jyucoeng/singbox-tools (release: v1.13.14)
 - New .github/workflows/sync-singbox.yml: manually triggered, mirrors 4 linux binary packages (amd64/arm64 and their musl variants) from upstream to this repo's release

v1.0.12
 - `del` now keeps the sing-box/cloudflared binaries (removing config only), with a new `delall` command for full removal
 - `rep` reuses existing binaries instead of re-downloading every time; `upsingbox` gains version detection, skipping the download when versions match
 - New Alpine auto-adaptation: automatically installs bash, downloads the musl sing-box build, and manages services with OpenRC
 - Optimized geo IP lookup: v4/v6 concurrent probing, timeout reduced from 5s→3s, no longer stalling later steps

v1.0.11
 - hy2 protocol gains fingerprint pinning to prevent tampering

v1.0.10
 -  singbox kernel version file adaptation

v1.0.9
 - Switched to official sing-box 1.13.14 (WireGuard included by default)
 - Removed `sniff: true` to adapt to the new sing-box 1.13+
 - Renamed the socks5_username and socks5_password environment variables (previously missing the socks5 prefix)
 - socks5 password auto-generation switched to alphanumerics only, no special characters

v1.0.8
 - New socks5 protocol support, freely combinable with other protocols, and some sni defaults changed from  www.microsoft.com to www.apple.com 

v1.0.7
 - New anytls protocol support, freely combinable with other protocols

v1.0.6  
 - Removed the agsb shortcut command, and renamed the main directory from agsb to doraemon; when uninstalling a previously deployed setup with the new script, both the /root/doraemon and /root/agsb folders get deleted.

---

## 2.8 Thanks to the following developers for their contributions

- [77160860 (the contributor)](https://github.com/77160860/proxy)

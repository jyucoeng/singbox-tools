#  singbox 一键安装脚本

> 本脚本支持两种安装方式：
> - **交互式菜单安装**：直接运行 `bash sb.sh`（不带参数），通过菜单引导完成安装/卸载/查看等操作。
> - **非交互式安装**：以环境变量 + 参数命令的方式一行完成（见下方示例）。可以搭配 [命令生成版界面](https://singbox.dingdang.de5.net/) 使用
>
> 安装后支持 **`sb` 快捷指令**：直接执行 `sb` 打开主菜单，或用 `sb ins` / `sb rep` / `sb list` / `sb rt` / `sb node` / `sb sub` / `sb del` 等一步直达对应功能（完整清单见「[sb 快捷指令](#sb-快捷指令)」）。

# 0、sb 快捷指令

安装后会在系统创建 `sb` 快捷命令，常用指令如下：

```
sb                 打开主菜单
sb ins             安装节点
sb rep             覆盖式安装/重置
sb list            查看节点信息
sb list key        查看节点 + vless Reality 私钥
sb res             重启 sing-box 和 cloudflared
sb rt              分流管理
sb node            节点配置修改 (端口/订阅/SNI/Argo)
sb sub             订阅管理
sb del             卸载（保留二进制）
sb delall          卸载全部并清理
sb ups             更新 sing-box 内核
sb sc              创建/刷新本快捷命令
sb sc_off          删除本快捷命令
sb autostart       开启开机自启
sb autostart_off   关闭开机自启
sb nginx_start     启动 Nginx
sb nginx_stop      停止 Nginx
sb nginx_restart   重启 Nginx
sb nginx_status    查看 Nginx 状态
```

在服务器上执行 `sb sc` 创建快捷命令后即可使用以上指令。

# 1、 singbox 安装以及卸载
## singbox 一键安装脚本（vmess argo/trojan argo/vless argo 可多选 + hy2+vless-Reality+tuic+anytls+socks5 + ws_cdn 三协议 CDN 回源，这些协议可自由组合）

举个例子🌰说明（这里会列出所有支持的环境变量）：

> **⚠️ 为了统一，sb.sh 仅接受单引号包裹的字符串值，也就是说不是数字时，强烈建议使用英文输入法的单引号包裹整个字符串起来。请不要使用双引号，因为socks5_password有些人用了特殊字符，特殊字符遇到双引号或者没加任何引号会有问题，所以这里规定只能用英文输入法的单引号包裹字符串** 
```
########## A. 直连协议（可不选任意，端口可改） ##########
# ---- 各协议 SNI（伪装域名，默认 www.apple.com） ----
hy_sni='www.apple.com' \
vl_sni='www.apple.com' \
vl_sni_pt=443 \
tu_sni='www.apple.com' \
# ---- UUID / IP 策略 ----
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed200 \
ippz=4 \
out_ip='你的特殊出口ip(仅当你的出口ip和服务器ip不一致时有效，需配合ipzz使用，一般情况下留空或者不传值)' \
# ---- 各协议监听端口：vlrt=Vless-Reality / hypt=Hysteria2 / tupt=TUIC / anypt=AnyTLS / socks5pt=Socks5 ----
vlrt=41003 \
hypt=41004 \
tupt=41005 \
anypt=41006 \
socks5pt=41017 \
# ---- Socks5 认证（密码含特殊字符必须用单引号包裹） ----
socks5_username='你的socks5自定义用户名' \
socks5_password='你的s5密码含特殊字符(!#$等)必须用单引号包裹整个密码串' \
socks5_wl_flag=true \
socks5_ips='1.2.3.4,5.6.7.0/24' \
# ------------------------------------------------------------------------

########## B. Argo 隧道（可多选，任意组合） ##########
argo="trojan,vless" \
# 共享 CF 优选域名/端口（所有 Argo 协议共用；未填默认 saas.sin.fan / 443）
argo_cf_host='saas.sin.fan' \
argo_cf_pt=8443 \
# 也可分开设置（未填回退共享）：argo_vmess_cf_host / argo_vmess_cf_pt、argo_vless_cf_host / argo_vless_cf_pt、argo_trojan_cf_host / argo_trojan_cf_pt
# agn = Argo 固定隧道域名；agk = Argo Token / JSON 凭据；argo_pt 为 Argo 本地回源端口（一般不改）
agn="california.xxxx.xyz" \
agk='ey开头的那一大串' \
argo_pt=8001 \
# ------------------------------------------------------------------------

########## C. CDN 回源 ws_cdn（经你自己的 CDN 反代到服务器 nginx，不使用 Argo；可多选） ##########
# ws_cdn 支持 vmess/vless/trojan 任意多选；共享参数是所有协议兜底，专属参数未填回退共享
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='cdn.example.com' \
ws_cdn_sni='cdn.example.com' \
ws_cdn_cf_pt=443 \
# 每协议可选不同专属回源域名（Cloudflare origin rule 多回源域名同 A 记录）：
# ws_cdn_vless_cf_host='vless.example.com' 或 ws_cdn_trojan_cf_host='trojan.example.com'，对应再配 ws_cdn_vless_sni / ws_cdn_trojan_sni
ws_cdn_vless_cf_host='vless.example.com' \
ws_cdn_trojan_cf_host='trojan.example.com' \
# ------------------------------------------------------------------------

########## D. 订阅 / 其他 ##########
nginx_pt=41007 \
subscribe=true \
reality_private=GHxxxxxxxxxxxxx-xxxxxx-VnXH6FjxxA \
name="小叮当-美国加州" \
DEBUG_FLAG=0 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep

```
# 环境变量说明

##  1、 如果bash后面跟了一个参数 rep，代表覆盖式安装（会卸载后再安装），你可以用这个改成其他功能，比如del 代表 卸载(保留二进制文件，比如singbox/cloudflared等的安装二进制文件),dellall 代表全部卸载+删除二进制文件, list 代表 查看节点，具体有哪些值你可以跑一次安装脚本你就知道怎么用了。
### bash  sb.sh list key 这里有2个参数 list key，代表显示节点的同时会显示vless Reality的密钥。如果不加key 参数，就只显示节点

## 2、 uuid=XXXX-xxx-XXXX（可传，也可不传）

**含义**
- 不传uuid → 脚本自动生成 UUID
- 传uuid → 使用你指定的 UUID

## 3、 argo_cf_host、argo_cf_pt、hy_sni、tu_sni、vl_sni、vl_sni_pt、any_sni、argo_pt、socks5pt（以及cdn域名 和 各协议的伪装域名，可选）

❗注意：这几个值不会填的话就不要瞎传（可直接留空或者干脆删去这个变量）
-----
 ## 最佳实践
### 不要用以下域名作为 sni(❗❗❗这点非常重要，不然你的vps小鸡端口被恶意扫描到的时候，将会被作为无限制流量转发端口，你的节点的流量会嗖嗖被刷，反正你不知道该写什么域名作为sni，那比较明智的做法是留空，我已经内置了sni默认值)：

  ❌ Cloudflare 相关：www.cloudflare.com、dash.cloudflare.com

  ❌ CDN 服务：www.akamai.com、www.fastly.com

  ❌ 代理/VPN 服务：任何代理服务的域名

  ❌ 你自己的服务器域名（会形成循环）

  ### 推荐用：
  ✅ www.apple.com (默认)

  ✅ www.yahoo.com

  ✅ www.google.com

  ✅ www.apple.com

  ✅ 任何大型正常网站


------------------


     
👉 argo_cf_host、argo_cf_pt 用在以下地方（Argo 场景的对外端口为 argo_cf_pt，默认值 443，可自定义为 https 系端口中的一个：443,2053,2083,2087,2096,8443 [任选]）：

—— VMess Argo：
"add":"${argo_cf_host}"

——  Trojan Argo：
trojan://${uuid}@${argo_cf_host}:${argo_cf_pt}?...

——  Vless Argo：
vless://${uuid}@${argo_cf_host}:${argo_cf_pt}?...

👉 每协议也可分别指定（分开设置，未填回退共享 `argo_cf_host`/`argo_cf_pt`）：
`argo_vmess_cf_host` / `argo_vmess_cf_pt`、`argo_vless_cf_host` / `argo_vless_cf_pt`、`argo_trojan_cf_host` / `argo_trojan_cf_pt`

👉 兼容旧名：`cdn_host` / `cdn_pt` 仍可用（`argo_cf_host`/`argo_cf_pt` 优先，旧名兜底），方便旧命令直接复用。

举🌰：
```
trojan://0631a7f3-09f8-4144-acf2-a4f5bd9ed281@cdns.doon.eu.org:8443?...
```

👉  vl_sni_pt 为vless Reality协议节点的伪装域名对应的https系端口，可以在安装时自定义，可自定义为https系端口中的任意一个(443,2053,2083,2087,2096,8443)，不能在客户端随便乱改（因为是安装时绑定）

- argo_cf_host 指的是用 argo 时的 cf 域名，缺省值为 saas.sin.fan，你可以自己传你要的值，比如 www.visa.com 。argo_cf_pt 是 cf 域名对应的端口。 不传就会使用缺省值做兜底。

- hy_sni 指的是用hy2协议的sni（伪装域名），缺省值为www.apple.com，你可以自己传你要的值,不传就会使用缺省值做兜底。

- tu_sni 指的是用tuic协议的sni(伪装域名)，缺省值为www.apple.com，你可以自己传你要的值，比如 www.yahoo.com 。 不传就会使用缺省值做兜底。

- vl_sni 指的是用vless协议的sni(伪装域名)，缺省值为www.apple.com，你可以自己传你要的值，比如 www.yahoo.com 。 不传就会使用缺省值做兜底。

- vl_sni_pt 指的是vless协议的sni(伪装域名)对应的握手端口，默认是443，你可在安装时自定义为https系那几个中的一个。

- any_sni 指的是用anytls协议的sni(伪装域名)，缺省值为www.apple.com，你可以自己传你要的值，比如 www.yahoo.com 。 不传就会使用缺省值做兜底。

- argo的对外默认优选端口为443（可自行修改 argo_cf_pt 参数），同样argo_pt对本地的监听端口为8001.也可以自定义（但是不建议改，不然你就要同时去把CF里面的对应的HTTP改成你自定义的端口。）

<img width="1514" height="621" alt="CleanShot 2026-01-25 at 12 50 32" src="https://github.com/user-attachments/assets/ec1d2396-4832-4b1b-9da7-cbda4e9c56f1" />


##  4、 ippz和out_ip（IP显示策略和特殊出口ip，可选）
## 👇 👇 👇
| ippz值 |    含义        |
|--------|---------------|
| 4      | 强制使用 IPv4  |
| 6      | 强制使用 IPv6  |
| 空     | 自动判断       |

 👉 ippz只影响 节点输出，不影响服务运行

 👉 out_ip='你的特殊出口ip(仅当你的出口ip和服务器ip不一致时有效，需配合ipzz使用)' ，比如：

 - 出口为ipv4, out_ip='216.166.22.30',ippz=4(当服务器的 ssh ip和出口ip不一致，比如vps里面获取到ip为216.166.22.250（出口ip）时，但是你ssh ip为216.166.22.30，正常情况下，脚本会默认使用250这个ip作为出口ip，但是你节点出来之后如果用250会不通，因为跟你ssh ip不一致，你需要手动改成30这个ip才通，针对你这个需求，你就可以设置这个out_ip变量来解决这个设定出口为30的特殊要求)
 
- 出口为ipv6, out_ip='2602:294:0:b7:1234:1234:d9d4:0001',ippz=6 (当服务器ip为2602:294:0:b7:1234:1234:d9d4:2600时，你的出口ip由于某个原因被分给了2602:294:0:b7:1234:1234:d9d4:0001，正常情况下，脚本会默认使用2600这个ip作为出口ip，针对你这个需求，你就可以设置这2个变量来解决这个设定出口为0001的特殊要求)


 <img width="602" height="132" alt="CleanShot 2026-01-26 at 12 57 34" src="https://github.com/user-attachments/assets/57c1a329-9292-45b5-aa23-3c59cd3e3356" />


  
 ## 👆 👆 👆

 ## 5、 各种端口

   ```bash
   hypt=41001 \
   vlrt=41002 \
   tupt=41005 \
   anypt=41006 \
   socks5pt=31017 \
   nginx_pt=31007 \
   ```
   这些分别为hy2、vless-reality、tuic、anytls、socks5、nginx订阅地址的端口.
   - pt为 port的简写
   - rt为 reality port的简写
   - ⚠️ vmess/trojan/vless 这三个协议的启用由 argo 决定（可多选，逗号分隔，如 `argo=vmess,vless`），其本地回源端口不接受指定（旧变量 trpt/vmpt/vlpt 已废弃），端口由脚本自动随机或复用落盘文件。

## 6、 nginx_pt=? nginx订阅端口，默认值为 8080。

- 不传 → 默认 8080
- 传 → nginx订阅使用的监听端口

❗注意：nginx_pt与argo_pt的值不能同时为8001，不然会导致监听混乱(换句人话：如果你不改argo_pt的值，nginx_pt就不能设置为8001)。

### 6.1、 什么时候会安装 Nginx（速查）

Nginx 只在以下任一情况满足时才安装/配置：

| 场景 | subscribe 订阅 | argo | 是否安装 Nginx |
|---|---|---|---|
| 纯直连（hy2/vless-reality/tuic/anytls/socks5） | 关 | 关 | ❌ 不安装 |
| 只开 Argo（argo=vmess/trojan/vless，可多选） | 关 | 开 | ✅ 安装（argo 回源走 Nginx 反代） |
| 只开订阅 | 开 | 关 | ✅ 安装（对外提供订阅地址） |
| Argo + 订阅都有 | 开 | 开 | ✅ 安装 |

> 即使不开启订阅，只要启用 Argo 就会安装 Nginx：因为 Argo 的数据链路是
> `cloudflared → 127.0.0.1:8001(Nginx) → sing-box 对应 ws 端口`，Nginx 负责按路径反代。

## 7、 subscribe 订阅开关，默认值为false，即不需要nginx订阅。

- false → 默认 不生成订阅；但若启用了 Argo，Nginx 仍会因回源反代被安装
- true →  会生成订阅。当设置为true时，需要同时设置nginx的订阅端口参数：nginx_pt=?


## 8、 argo（Cloudflare Argo 开关，可多选）

- `argo=vmess` 启用 Vmess Argo
- `argo=trojan` 启用 Trojan Argo
- `argo=vless` 启用 Vless Argo
- 可多选：`argo=vmess,vless`、`argo=vmess,trojan,vless` 等任意组合
- 留空或不传 → 不启用 Argo

⚠️ Argo 只能用于 VMess / Trojan / Vless，**支持多选**（逗号分隔任意组合），可与 ws_cdn 同时存在

❌ 对 hypt / vlrt / tupt无效（vless 走的是 vless-ws，即 argo=vless）

> ⚠️ argo 值统一转小写后校验，安装/覆盖安装时接受任意 vmess / vless / trojan 组合（逗号分隔，如 `argo=vmess,vless`），或留空。
> 旧值 vmpt / trpt / vlpt 已废弃，外界传入会被判非法并退出；已落盘配置（vlvm/argo 文件）依然认可。
> 这三个协议的启用完全由 `argo=` 决定，本地回源端口不接受指定（自动随机/复用文件），无需再传 trpt/vmpt/vlpt 端口变量。

## 8.5、 ws_cdn（Vmess/Vless/Trojan WS 走 CDN 回源，不使用 Argo）

让 vmess / vless / trojan 的 WS 节点直接经过你自己的 **CDN / 反代** 转发到服务器 nginx（回源到服务器 `nginx_pt`，通常 8080），**不启用 cloudflared**。

```
客户端 --wss--> CDN(ws_cdn_cf_pt, 默认443) --http--> 服务器 nginx_pt --http--> sing-box ws 端口
```

**开关**：`ws_cdn=vmess,vless,trojan`（逗号分隔，可多选）

**域名支持每个协议不同**（适用于 Cloudflare origin rule 泛域名 + 多回源域名同 A 记录），优先级：`协议专属 > 共享 ws_cdn_* > 默认 saas.sin.fan/443`

| 变量 | 说明 | 默认 |
|------|------|------|
| `ws_cdn` | 开关：vmess/vless/trojan 逗号分隔 | 空（不启用） |
| `ws_cdn_vmess_cf_host` 等 | 各协议专属 CF 优选域名（连接地址 add） | 回退共享 ws_cdn_cf_host |
| `ws_cdn_vmess_sni` 等 | 各协议专属回源域名（host/SNI） | 回退共享 ws_cdn_sni |
| `ws_cdn_vmess_cf_pt` 等 | 各协议专属 CF 优选端口 | 回退共享 ws_cdn_cf_pt |
| `ws_cdn_cf_host` | 共享 CF 优选域名（各协议**连接地址 add** 兜底；可填优选 IP/域名） | 回退默认 saas.sin.fan |
| `ws_cdn_sni` | 共享回源域名（真实回源域名；作为节点 host/SNI 与**订阅地址**域名，Cloudflare 按此域名匹配回源规则转发到你的 nginx_pt） | 回退 ws_cdn_eff_host |
| `ws_cdn_cf_pt` | 共享 CDN 端口（仅限 https 系端口） | 443 |

**示例**（vless 和 trojan 用不同回源域名，vmess 用共享）：
```bash
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='cdn.example.com' \
ws_cdn_vless_cf_host='vless.example.com' \
ws_cdn_trojan_cf_host='trojan.example.com' \
subscribe=true \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) ins
```

**回源端口**：CDN 回源到服务器 `nginx_pt`（默认 8080），去 Cloudflare 后台把 origin 指向该端口（或用 origin rule 泛域名回源）。

**订阅地址域名（show_sub_url）取值顺序**（自动判定，不接受 sub_domain 手动强制）：

```
① 固定 Argo 隧道域名（不以 trycloudflare.com 结尾，且隧道存活）        ← 第一顺位
② 共享回源域名 ws_cdn_sni
③ 专属回源域名（固定顺序 vmess→vless→trojan，取第一个非空）
④ 临时 Argo 域名（含 trycloudflare，隧道存活才用）
⑤ http://服务器IP:nginx_port（兜底，含节点口令，仅建议可信网络使用）
```

> 脚本自动按 ①→②→③→④→⑤ 判定，没有手动强制项；选哪个、填不填取决于你实际配置了哪些域名。
>
> **✅ 有固定 Argo 隧道时，后面全部不用填**：一旦配了固定 Argo（①），订阅地址自动就是 `https://固定Argo域名/sub/{uuid}`，`ws_cdn_sni` 和 `ws_cdn_vmess_sni`/`ws_cdn_vless_sni`/`ws_cdn_trojan_sni` 这些回源域名**一个都不用写**，省心。
> 回源域名（②③）唯一的意义是：**没有固定 Argo 时**（或想强制走 CDN）也能让订阅走一个稳定 https 域名，而不是跌到明文 HTTP。
>
> **完整顺延链路**（不足一级就顺延到下一级）：
>
> ```
> ① 固定 Argo 隧道域名（如 argo.example.com，非 trycloudflare）  → https://固定Argo域名/sub/{uuid}
>  ↓ 无固定 Argo 或隧道未存活
> ② 共享回源域名 ws_cdn_sni                                  → https://共享回源域名:pt/sub/{uuid}
>  ↓ 无共享
> ③ 专属回源域名（ws_cdn_vmess_sni→ws_cdn_vless_sni→ws_cdn_trojan_sni，取第一个非空）→ https://专属回源域名:pt/sub/{uuid}
>  ↓ 无任何回源域名
> ④ 临时 Argo 域名（形如 xxx.trycloudflare.com，隧道存活）    → https://临时域名/sub/{uuid}
>  ↓ 无 Argo
> ⑤ http://服务器IP:nginx_port/sub/{uuid}（明文 HTTP，含节点口令，仅建议可信网络）
> ```
>
> > ①~② 手动强制可在默认顺序前"插队"：`sub_domain=argo` 直接取 Argo 域名；`sub_domain=cdn` 直接取 ②③ 的回源域名（共享→专属顺延，取到任一非空即用）。
>
> **为什么任意一个回源域名都行**：回源域名在 Cloudflare 里按 Origin Rule/DNS 回源到**同一个 nginx 端口（nginx_pt，默认 8080）**，而 nginx 是 `server_name _`（不分 hostname、按路径干活）。所以 `vmess.example.com/sub/{uuid}`、`vless.example.com/sub/{uuid}`、`trojan.example.com/sub/{uuid}` **任何一个都能访问订阅**——用哪个都通。
>
> **②③ 顺延到下一个非空举例**（假设均已启用 ws_cdn）：
>
> | 你配置的回源域名 | 订阅 URL 用的域名 | 说明 |
> |---|---|---|
> | `ws_cdn_sni=cdn.example.com`，任意协议有专属 | `cdn.example.com` | **共享优先**（②），专属不用 |
> | 共享空，`ws_cdn_vmess_sni=vm.example.com` 有值 | `vm.example.com` | ③ 固定顺序第一个非空 |
> | 共享空，vmess 空，`ws_cdn_vless_sni=vl.example.com` 有值 | `vl.example.com` | **跳过空的 vmess，顺延到 vless** |
> | 共享空，vmess/vless 都空，`ws_cdn_trojan_sni=tr.example.com` 有值 | `tr.example.com` | 顺延到 trojan |
> | 共享 + 三个专属全空 | （无回源域名）→ 顺延 ④⑤ | 只有回源域名全空才会继续跌 |
>
> 参数里写几个、写哪个的顺序都无所谓：**只要回源域名有一个非空就够**，规则永远是「共享 ws_cdn_sni → vmess → vless → trojan，取第一个非空」；回源域名全部为空才继续走「④ 临时 Argo → ⑤ http」。

**与 Argo 并存**：可同时开 `ws_cdn` 和 `argo`，两者节点都输出（共用同一本地 ws 端口与 nginx 反代，仅客户端握手域名不同）。

### 8.5.1、 CF（Cloudflare）回源规则如何配置？

WS-CDN 回源链路：`客户端 → CDN(ws_cdn_cf_pt) → 服务器 nginx_pt(默认 8080)`。要让 Cloudflare 把你的回源域名请求回源到你服务器的 nginx，需要三步：**Origin Rules（回源端口）** + **DNS 记录** + **SSL 加密模式设为「灵活」**，缺一不可。

#### 1、如何添加一个回源端口规则（Origin Rules）？

进入 Cloudflare，点击具体域名（如 `xxxx.nyc.mn`）→ **规则** → **页面规则**，在页面右侧**流量序列**里找到 **Origin Rules · 更改目标源服务器**，点击它 → 点右上角**+ 创建规则**（蓝色按钮）→ 选中**源服务器规则**，进入 **Origin Rules**：

- 填写规则名称，如 `xxxx.nyc.mn-31007`
- 选中**自定义筛选表达式**：
  - **字段** 选 **主机名**
  - **运算符** 选 **通配符**
  - **值** 填 `*node.xxxx.nyc.mn`
  - 点击 **And**，再选 **SSL/HTTPS**，**等于**，**确保这一行后面的开关要选上（打勾）**
- 然后下面的**目标端口** 重写到 **31007**（这个 31007 端口就是你的 **nginx 订阅端口 nginx_pt** 的值，按你实际配置的 `nginx_pt` 填写）

> 规则里的 `*node.xxxx.nyc.mn` 通配符要能覆盖你实际用的三个回源域名：`vmess` / `vless` / `trojan`（这3个协议可以共用一个回源域名，也可以用三个不同的域名）。

#### 2、域名 `xxxx.nyc.mn` 的 DNS 记录

添加下面三条 **A 记录**，其中 `192.9.100.***` 为你的小鸡（服务器）的 IPv4：

```
vmess-node.xxxx.nyc.mn   →  192.9.100.***   （小黄云开不开都可以）

```

> 可以每个协议一个dns记录，也可以3个协议共用一个dns记录，这个子域名记录指向**同一个 IPv4**（同一台服务器），配合上面的 Origin Rules 泛域名回源到 nginx_pt；
> `小黄云`（Cloudflare 橙色云代理）开或不开都可以——开=走 CDN+CDN TLS 终结，关=仅 CDN 反代一样能到 nginx。

> **⚠️ 每个实际用到的 SNI 回源域名都必须有 DNS 记录**。节点里的 `sni/host` 用的分别是 `ws_cdn_vmess_sni` / `ws_cdn_vless_sni` / `ws_cdn_trojan_sni`（没设专属就回退共享 `ws_cdn_sni`），**凡是当 SNI 用的回源域名，每个都必须在 DNS 里有一条记录**，缺哪个哪个节点就是 **530（Origin DNS Error）**。

#### 3、SSL 加密模式必须设成「灵活（Flexible）」（否则回源必定 525）

⚠️ **这是最容易漏、漏了三个 CDN 节点全连不上的一步**（现象：Argo / 直连都正常，只有 WS-CDN 节点不通）。

只要 A 记录开了**橙云（已代理）**，Cloudflare 会先替客户端终止 TLS，然后**再向源站发起一次连接**。第二次连接用什么协议，由这个域名（或子域）的 **SSL/TLS 加密模式** 决定：

| 加密模式 | 边缘 → 源站 nginx_pt 的连接 | 结果 |
|---|---|---|
| 完全 / 完全（严格） Full | 用 **TLS** 去连 nginx_pt，但 nginx 只有 HTTP | ❌ 握手失败 → **525** |
| **灵活（Flexible）** | 用 **明文 HTTP** 去连 nginx_pt | ✅ 通 |

**做法 A（推荐，只影响 node 子域，不动整站）：配置规则**

1. Cloudflare 后台 → 选域名 `xxxx.nyc.mn` → 左侧 **规则（Rules）** → 顶部页签选 **配置规则（Configuration Rules）**（⚠️ 不是**页面规则**，也不是上面用到的 **Origin Rules**）
2. 点 **创建规则**
   - **规则名称**：随便填，如 `node-回源-明文`
   - **表达式**（自定义筛选表达式）：字段选 **主机名**，运算符选 **通配符**，值填 `*node.xxxx.nyc.mn`
   - **然后（Then）操作**：选 **SSL**，值选 **灵活（Flexible）**
3. **保存 / 部署**

**做法 B（简单，整站生效）：**
- `域名 → SSL/TLS → 加密模式 → 灵活（Flexible）`

> 无论选哪种，**客户端 → Cloudflare 这段始终是 HTTPS**（节点链接不变），只是 Cloudflare → 你服务器这段变成明文 HTTP。如果你必须保持全链路加密（完全/完全严格），则需给服务器的 nginx_pt 配 TLS 证书（属于改脚本，工作量更大），否则只能设「灵活」。

#### 4、与脚本参数对应关系速查

| 你在哪填 | 对应的脚本变量 | 说明 |
|---|---|---|
| 上面三条 A 记录的回源域名 | `ws_cdn_vmess_cf_host` / `ws_cdn_vless_cf_host` / `ws_cdn_trojan_cf_host` | 各协议的专属回源域名（连接地址 add 可以仍用优选域名/IP） |
| Origin Rules 的目标端口 | `nginx_pt`（默认 8080） | CDN 回源到服务器 nginx 的端口 |
| 客户端连 CDN 的端口 | `ws_cdn_cf_pt`（默认 443） | CDN 对外 HTTPS 端口 |
| 各协议/共享 SNI（真实域名） | `ws_cdn_vmess_sni` 等 / `ws_cdn_sni` | 对应上面 A 记录的某个回源域名 |
| CF 的 SSL/TLS 加密模式 | 无脚本变量（Cloudflare 后台） | node 子域必须「灵活」，否则回源 525 |

#### 8.5.2、排错：三个 CDN 节点连不上？先对号入座

> 典型现象：**Argo 节点、直连协议全部正常，唯独 3 个 WS-CDN 节点连不上**。按下面错误码一步步排除即可。

| 表现 | Cloudflare 错误码 | 原因 | 解决 |
|---|---|---|---|
| vmess/vless/trojan-WS-CDN 全不通，Argo/直连正常 | **525** | 橙云记录 + SSL 模式「完全/完全严格」，Cloudflare 用 TLS 回源，而 nginx_pt 只讲 HTTP | 按上面**第 3 步**把 node 子域 SSL 加密模式设成「灵活」 |
| trojan-WS-CDN（或某个协议）单独不通 | **530**（Origin DNS Error） | 该协议当 SNI 用的回源域名（如 `trojan-cdn-node.xxxx.nyc.mn`）**没有 DNS 记录** | 在 DNS 里补一条 A/CNAME 记录，见**第 2 步**警告 |
| 所有 WS / Argo 都不通 | 521 / 522 / 523 | nginx 没运行、回源端口被防火墙挡、Origin Rules 端口没对上 | 检查 `nginx` 状态、防火墙放行 nginx_pt、Origin Rules 目标端口是否正确 |

## 9、 agn / agk（Argo 固定隧道）

- agn="argo固定隧道域名"
- agk="argo隧道token"

- 当agk为普通字符串的场景：agk的值用英文双引号包裹""
- 当agk的值为json格式的时候，agk值只能用英文单引号包裹''

**是否必须？**
- ❌ 不传 → 临时 Argo（trycloudflare,前提是你必须指定argo开关）
- ✅ 只有你自己有 CF Tunnel才传


## 10、 name（节点名称前缀，后缀会用各协议简写区分）

- 不传 → 默认 hostname
- 传 → 节点名前加前缀

**例子：**
- name=HK
- ➡ HK-vmess / HK-vless

## 11、 reality_private  此为vless Reallity协议的密钥。
传这个值是为了你在安装和重装节点的时候，生成的vless节点保持一致,这样你就不用来回导入节点了，不加这个的话每次生成的证书都会不一样的。

如果不在意一致，你可以直接不用管。不传的时候，这个值会自动生成。
然后安装或者重装完成的时候，会打印一次给你，请自行保存这个值。

 如果你忘记了保存，可再次重装或者调用  bash sb.sh list key 即可再次打印出此reality_private 的值

- 不传 → 默认 生成
- 传 → 就能节点永远相同(请注意不要乱填，正确的值应该是43个字符)

## 12、 socks5pt 指的是socks5协议的端口，不传就不启用socks5。同时自定义 socks5_username / socks5_password 环境变量的值。用户名/密码不传就自动随机生成。

> **⚠️ 注意：如果 `socks5_password` 含 `!`、`#`、`$` 等特殊字符，必须用单引号 `'...'` 包裹整个密码串。**  
> 双引号或不加引号会导致 bash 把特殊字符解释掉，最终配置文件里的密码会被截断或出错。

### 12.1、 socks5_wl_flag / socks5_ips —— Socks5 IP白名单（可选）

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `socks5_wl_flag` | 白名单开关，`true`/`1`/`True`/`TRUE` 均可（大小写不敏感），空或其他值=关闭 | 空（关闭） |
| `socks5_ips` | 允许访问 Socks5 的源 IP 列表，逗号分隔，支持单个 IP 和 CIDR（如 `1.2.3.4,5.6.7.0/24`），IPv4/IPv6 均支持 | 空 |

- 不传这两个参数 → Socks5 对所有 IP 开放（默认行为）
- 传了 `socks5_wl_flag=true` 且 `socks5_ips` 非空 → 仅白名单中的 IP 可以连接 Socks5

> **实现原理**：白名单开启时，脚本通过 iptables/ip6tables 在 INPUT 链添加规则：
> 1. 白名单 IP 访问 socks5 端口 → ACCEPT（放行），标记 `socks5_rule`
> 2. 其余所有 IP 访问 socks5 端口 → DROP（拦截），标记 `socks5_rule`
>
> 同时，其他协议端口（vmess/trojan/vless 等）通过 iptables 添加 ACCEPT 规则，标记 `doraemon_singbox_rule`。
> 所有规则通过 `--comment` 标记精确识别，卸载/覆盖安装时仅清除本脚本的规则，不影响其他程序的防火墙配置。
>
> 关闭白名单时规则被移除，socks5 端口恢复为所有 IP 均可访问。

> 安装后也可以通过交互菜单管理白名单，见下方「交互菜单」说明。
>
> 节点信息显示效果（白名单状态在链接正下方单独一行展示）：
> ```
> 🧦【 Socks5 】(此协议请不要直接在客户端里直连使用)
> socks5://user:pass@ip:port#name
>    ↳ 入站白名单已开启，仅允许: 1.2.3.4,5.6.7.0/24
> ```

## 13、所有的协议都会输出到聚合节点文件中: cat /root/doraemon/jh.txt

### 这里给列出一些基础变量
```bash
# 所有已选协议的节点都会写入 /root/doraemon/jh.txt；Argo 支持多选（逗号分隔）
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed200 \
ippz=4 \
vlrt=41003 \
hypt=41004 \
tupt=41005 \
anypt=41006 \
# Argo 多选：vmess,trojan,vless 任意组合（下面示例同时启用 Vmess-Argo 和 Vless-Argo）
argo="vmess,vless" \
# Argo 共享 CF 优选域名/端口（所有 Argo 协议共用；或按协议分开填 argo_vmess_cf_host / argo_vmess_cf_pt 等）
argo_cf_host='saas.sin.fan' \
argo_cf_pt=8443 \
# ---- CDN 回源（ws_cdn，经你自己的 CDN 反代到服务器 nginx，不用 Argo；可多选） ----
# ws_cdn='vmess,trojan,vless' \
# ws_cdn_cf_host='saas.sin.fan' \              # 共享 CF 优选域名（各协议连接地址 add 兜底）
# ws_cdn_sni='cdn.example.com' \               # 共享回源域名（真实回源域名，也是订阅地址域名）
# ws_cdn_vless_cf_host='vless.example.com' \   # 每个协议可选不同专属 CF 优选域名
# ws_cdn_vless_sni='vless.example.com' \       # 各协议专属回源域名（Host/SNI，未填回退共享 ws_cdn_sni）
# ------------------------------------------------------------------------
nginx_pt=41007 \
socks5pt=31017 \
socks5_username='zhangsan' \
socks5_password='Zsztm4gdsg!' \
socks5_wl_flag=true \
socks5_ips='1.2.3.4,5.6.7.0/24' \
agn="california.xxxx.xyz" \
agk='ey开头的那一大串' \
subscribe=true \
reality_private=GHxxxxxxxxxxxxx-xxxxxx-VnXH6FjxxA \
name="小叮当-美国加州"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep

```

# 2、常见组合调用方式

## 组合1️⃣、 仅 1个直连协议（不走 Argo,hypt与vlrt、tupt这几个端口参数选一个来写）

### 仅hy2协议

```bash
hypt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

### 仅vless Reality协议

```bash
vlrt=2083 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

### 仅tuic协议

```bash
tupt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

### 仅anytls协议

```bash
anypt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

## 仅socks5 协议

```bash
# 密码含特殊字符(!#$等)必须用单引号包裹；socks5_wl_flag 可选：开启IP白名单；socks5_ips 可选：白名单IP，CIDR
socks5pt=31017 \
socks5_username='你的s5用户名' \
socks5_password='你的s5密码' \
socks5_wl_flag=true \
socks5_ips='1.2.3.4,5.6.7.0/24' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

## 组合2️⃣、 仅 2个直连协议（不走 Argo,hypt与vlrt参数都写，代表hy2和vless-reality 协议都会出来）

```bash
hypt=2082 \
vlrt=2083 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

## 组合3️⃣、 VMess  Argo/ Trojan  Argo / Vless Argo（可多选，任意组合）

### 当使用Vmess Argo时

```bash
ippz=4 \
argo=vmess \
agn="test-trojan.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川vmess"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  rep
```

## 当使用trojan Argo时

```bash
ippz=4 \
argo=trojan \
agn="test-vmess.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川trojanc"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  rep
```

## 当使用vless Argo时

```bash
ippz=4 \
argo=vless \
agn="test-vless.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川vless"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  rep
```

## 组合3️⃣多选、 Argo 多协议同时启用（如 vmess+trojan 同时走 Argo）

```bash
ippz=4 \
argo=vmess,trojan \
# 共享 CF 优选域名/端口（未填默认 saas.sin.fan / 443）；每协议也可分开填 argo_vmess_cf_host / argo_trojan_cf_host 等
argo_cf_host='saas.sin.fan' \
argo_cf_pt=443 \
agn="test-xxx.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  rep
```

## 4️⃣ 、VMess + Hysteria2+ vless

```bash
ippz=4 \
hypt=41001 \
vlrt=41002 \
argo=vmess \
agn="test-vmess.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  rep
```


### argo tunnel的json token的场景：（请一定要记得json格式的时候，要用英文单引号包裹起来）

```bash
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed281 \
ippz=4 \
vlrt=41003 \
hypt=41004 \
tupt=41005 \
argo="trojan" \
agn="northCarolina.xxxx.xyz" \
agk='{"AccountTag":"xxxxxxxxxxxxxx","TunnelSecret":"xxxxxxxxxxxxxx","TunnelID":"xxxxxxxxxxxxxx","Endpoint":""}' \
name="小叮当-美国北卡"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

## 组合5️⃣、WS-CDN 直连（不经 Argo，客户端经你自己的 CDN 反代到服务器 nginx，可多选）

### 三个协议用一个共享 CF 优选域名 + 共享回源域名

```bash
# ws_cdn_cf_host=共享 CF 优选域名（各协议连接地址 add 兜底）；ws_cdn_sni=共享回源域名（真实回源域名，也是订阅地址域名）
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='saas.sin.fan' \
ws_cdn_sni='cdn.example.com' \
subscribe=true \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

### 每个协议不同专属域名（CF 优选域名 + 回源域名，Cloudflare origin rule 泛域名 + 多回源域名同 A 记录）

```bash
# 各协议可选不同专属 CF 优选域名（连接地址）与专属回源域名（Host/SNI）
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

> CDN 回源端口 = 服务器 nginx_pt（默认 8080）。可同时配固定 Argo 并存（两者节点都输出）；订阅地址有固定 Argo 则直接用固定 Argo，没有才用回源域名 ws_cdn_sni（或专属 ws_cdn_{p}_sni）。

## 如何卸载呢？
```bash

bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  del

> `delall`：与 `del` 效果类似，但会**完全删除** sing-box 文件夹（不保留二进制文件 / 配置），相当于彻底卸载。
```


# 3、Json Argo Tunnel 获取 (推荐，token版就不用说了吧)
用户可以通过 Cloudflare Json 生成网轻松获取: https://fscarmen.cloudflare.now.cc

或者直接看fscarmen的说明: https://github.com/fscarmen/sing-box/blob/main/README.md#5json-argo-tunnel-%E8%8E%B7%E5%8F%96-%E6%8E%A8%E8%8D%90

## 以此类推，最后给一下协议组合吧

| 你设置了什么                   | 实际生成的节点                                          |
| ---------------------------- | ----------------------------------------------------- |
| hypt                         | 1（hy2）                                              |
| vlrt                         | 1（vless）                                            |
| tupt                         | 1（tuic）                                             |
| anypt                        | 1（anytls）                                           |
| socks5pt                     | 1（socks5）                                           |
| argo=vmess                    | 1（Argo-vmess）                                       |
| argo=trojan                   | 1（Argo-trojan）                                      |
| argo=vless                    | 1（Argo-vless）                                       |
| argo=vmess,vless              | 2（Argo-vmess + Argo-vless）                          |
| argo=vmess,trojan,vless       | 3（Argo 三协议全开）                                   |
| ws_cdn=vmess                  | 1（CDN-vmess 回源）                                   |
| ws_cdn=vmess,vless            | 2（CDN-vmess + CDN-vless 回源）                       |
| ws_cdn=vmess,vless,trojan     | 3（CDN 三协议回源）                                   |
| argo=vmess + ws_cdn=vmess     | **2（Argo-vmess + CDN-vmess 并存）**                  |
| argo=vmess,trojan + ws_cdn=vless | **3（Argo 两协议 + CDN-vless）**                    |
| hypt + vlrt                  | 2（hy2和vless-reality直连）                                   |
| hypt + vlrt + tupt           | 3（hy2、vless、tuic直连）                             |
| hypt + vlrt + tupt + anypt   | 4（hy2、vless、tuic、anytls直连）                     |
| hypt + vlrt + socks5pt       | 3（hy2、vless、socks5直连）                           |
| hypt + vlrt + tupt + anypt + socks5pt | 5（hy2、vless、tuic、anytls、socks5直连）     |
| hypt + vlrt + argo=vmess     | **3（hy2、vless直连+Argo-vmess）**                    |
| hypt + vlrt + argo=vmess,vless | **4（hy2、vless直连+Argo-vmess、Argo-vless）**      |
| hypt + vlrt + tupt + argo    | **4（hy2、vless、tuic直连+Argo 多协议）**            |
| hypt + vlrt + tupt + anypt + argo | **5（hy2、vless、tuic、anytls直连+Argo 多协议）** |
| hypt + vlrt + tupt + anypt + socks5pt + argo | **6（hy2、vless、tuic、anytls、socks5直连+Argo 多协议）** |
| hypt + vlrt + argo=vmess + ws_cdn=vmess,trojan | **5（hy2、vless直连 + Argo-vmess + CDN vm/trojan 回源）** |
| 全开（直连 + Argo 三选多 + ws_cdn 三选多） | **直连 n + Argo n + CDN n（总数为实际选中协议数）** |

## 日志查看

sing-box 和 cloudflared 启动失败时，可以通过下面命令定位问题。

> 以下 `doraemon` 为默认安装目录，若安装时改了 `sb_dir`，请替换成实际目录。

### 快捷命令（推荐）

```bash
sb logs              打开日志菜单（Sing-box / Argo / Nginx / 安装日志）
sb log_sb 100        查看 Sing-box 运行日志（最近100行）
sb log_argo 100      查看 Argo 隧道日志（最近100行）
sb log_ins 100       查看脚本安装日志（最近100行）
sb log_stop          查看服务停止原因日志（排查崩溃用）
```

### 手动查看

```bash
# 实时查看 sing-box 运行日志（通用所有模式）
tail -f /root/doraemon/logs/singbox.log

# 查看最新 200 行
tail -200 /root/doraemon/logs/singbox.log

# 实时查看 cloudflared 运行日志（nohup / 临时隧道模式）
tail -f /root/doraemon/logs/argo.log

# 查看最新 200 行
tail -200 /root/doraemon/logs/argo.log
```

## 感谢
感谢以下开发者的贡献：

- [77160860大佬](https://github.com/77160860/proxy)


## 防火墙规则排查（Debian/Ubuntu/Alpine 通用）

### 查看本脚本的规则

脚本通过 `--comment` 标记所有规则，有两种标记：

| 标记 | 说明 |
|------|------|
| `doraemon_singbox_rule` | 所有协议端口的 ACCEPT 规则（vmess/trojan/vless/socks5） |
| `socks5_rule` | Socks5 白名单专用（ACCEPT 放行 + DROP 拦截） |

**IPv4：**
```bash
# 查看所有脚本规则
iptables -S | grep -E "socks5_rule|doraemon_singbox_rule"

# 查看完整规则链（含包数/字节数）
iptables -L INPUT -n -v --line-numbers | grep -E "socks5_rule|doraemon_singbox_rule"

# 只看 socks5 白名单规则
iptables -S | grep socks5_rule
```

**IPv6：**
```bash
ip6tables -S | grep -E "socks5_rule|doraemon_singbox_rule"
ip6tables -L INPUT -n -v --line-numbers | grep -E "socks5_rule|doraemon_singbox_rule"
```

### 规则正常状态对照

- **未开启白名单时**：所有端口只有 `doraemon_singbox_rule` 标记的 ACCEPT 规则
  - TCP 协议（vmess/trojan/vless/anytls/socks5）→ TCP 规则
  - UDP 协议（hy2/tuic）→ UDP 规则
- **开启白名单后**：
  - `doraemon_singbox_rule`：其他协议端口的 ACCEPT 规则（不含 socks5 端口）
  - `socks5_rule`：socks5 端口的 ACCEPT 规则（每个白名单 IP 一条 TCP）+ 一条 DROP 默认规则（TCP）

### 持久化规则检查

重启后规则会由 systemd/OpenRC 自动恢复。检查持久化文件：

```bash
# Debian/Ubuntu
cat /etc/iptables/rules.v4
cat /etc/iptables/rules.v6

# Alpine（同路径）
cat /etc/iptables/rules.v4
cat /etc/iptables/rules.v6
```

### 白名单状态检查

```bash
# 查看白名单开关
cat /root/doraemon/socks5_wl_flag

# 查看白名单 IP 列表
cat /root/doraemon/socks5_ips

# 查看 socks5 端口
cat /root/doraemon/port_socks5
```


## 版本变更信息

v3.0.0 (2026-09-08)
 - **命名重构，彻底消除 `cdn_host`/`cdn_pt` 歧义**：Argo 共享改为 `argo_cf_host` / `argo_cf_pt`（专属 `argo_vmess_cf_host` 等）；CDN 回源共享改为 `ws_cdn_cf_host` / `ws_cdn_cf_pt` / `ws_cdn_sni`（专属 `ws_cdn_vmess_cf_host` / `ws_cdn_vmess_sni` 等）。**`cdn_host` / `cdn_pt` 正式退役**，仅作为旧 Argo 兼容别名，新版不再使用这两个环境变量
 - **旧用户升级零改造成本**（兼容旧版 `cdn_host` / `cdn_pt`）：
   - 旧命令传 `cdn_host=xxx cdn_pt=2083` 继续生效（→ `argo_cf_host` / `argo_cf_pt`，新名优先）
   - 旧落盘文件 `cdn_host` / `cdn_pt` / `vlvm`（单协议）升级后 `cip`/`list` 自动读取，**输出的节点串与旧版完全一致**
   - `rep` 重装时不传新名也不丢配置：旧 `cdn_host`/`cdn_pt` 文件值自动迁移到 `argo_cf_*`
 - **订阅地址完全兼容**：旧版订阅只有「Argo / http」两条分支，新版仅在配置了回源域名 `ws_cdn_sni`（或专属 `ws_cdn_{p}_sni`）时才新增「CDN 回源」订阅分支，旧用户（无 ws_cdn 文件）不受影响，订阅链接升级后保持不变
 - 落盘改为「保留/迁移」策略（`fs_write_or_keep`）：env 值>已有文件>旧名文件迁移>默认，不覆盖用户已有配置

 - **新增 ws_cdn 功能**：Vmess/Vless/Trojan WS 走 CDN 直连（不使用 Argo）
 - 新增开关 `ws_cdn=vmess,vless,trojan`（逗号分隔，可多选）；与 Argo 共存时节点两者都输出
 - 域名支持每个协议不同（适用 Cloudflare origin rule 泛域名 + 多回源域名同 A 记录）：`ws_cdn_vmess_cf_host` / `ws_cdn_vless_cf_host` / `ws_cdn_trojan_cf_host`（+ 各自 `_sni`/`_pt`）
 - 共享兜底参数：`ws_cdn_cf_host` / `ws_cdn_sni` / `ws_cdn_cf_pt`（默认 443）；优先级「协议专属 > 共享 > 默认 saas.sin.fan/443」
 - 复用现有本地 ws 端口（port_vm_ws / port_vl_ws / port_tr）与 nginx 反代（/${uuid}-vm/-vl/-tr），**不新增端口文件 / 不新增 inbound / 不新增 nginx location**
 - CDN 回源端口 = 服务器 `nginx_pt`（默认 8080）；nginx 安装条件与 8080 防火墙放行加入 ws_cdn 场景
 - 订阅地址新优先级（show_sub_url）：固定 Argo（隧道存活）> 共享回源域名 ws_cdn_sni > 专属回源域名 ws_cdn_{p}_sni > 临时 Argo > http；支持 `sub_domain=argo/cdn` 强制指定
 - 新增生效值解析函数 `ws_cdn_val / ws_cdn_eff_host/sni/pt / ws_cdn_proto_enabled`；配置落盘 + 环境变量优先
 - 交互菜单新增「Vmess/Vless/Trojan WS 走 CDN 直连」选择块（多选协议 + 逐协议回源域名 + 共享 host/sni/端口）
 - 安全：所有动态赋值（落盘/菜单注入）改用间接展开 + `printf -v`，不再用 `eval`
 - 顺带修复：端口设置菜单按 `vmag` 判断是否需要 Argo 端口（此前 ws_cdn 触发 vmp/vlp/trp 会误问 Argo 端口）

 - **Argo 协议由「三选一」升级为「可多选」**：`argo=vmess,vless` 等任意组合（逗号分隔）；cip 显示 / jh.txt / 订阅 / nginx 反代均按多协议输出对应节点，每个节点可用不同优选域名/端口
 - 新增每协议 Argo 专属优选域名/端口：`argo_vmess_cf_host` / `argo_vmess_cf_pt`、`argo_vless_cf_host` / `argo_vless_cf_pt`、`argo_trojan_cf_host` / `argo_trojan_cf_pt`；未填回退共享 `argo_cf_host` / `argo_cf_pt`
 - 共享 CF 优选域名/端口变量由 `cdn_host` / `cdn_pt` 更名为 `argo_cf_host` / `argo_cf_pt`（旧名 `cdn_host` / `cdn_pt` 继续兼容，新名优先），脚本内部节点生成/回退逻辑仍用归一化值
 - 修复 WS-CDN 回源节点链接 path 缺少 `-cdn` 后缀（此前与 nginx 反代 / inbound 的 `/{uuid}-{p}-cdn` 不匹配，导致 ws_cdn 节点无法回源）
 - CLI 交互菜单：Argo 选择支持多选（f/g/v 组合），新增「Argo CF 优选域名/端口 统一或分开」填写环节；Argo 协议切换菜单改为逐个 toggle
 - 分流管理（socks/http 附着协议、查看代理出口）补充支持 WS-CDN 独立 inbound（`vmess-ws-cdn-sb` / `vless-ws-cdn-sb` / `trojan-ws-cdn-sb`）

v2.0.2 (2026-09-07)
 - **安全加固**
 - 新增 root 权限检查：非 root 运行直接拒绝（脚本会写 /root、/etc/systemd、(openrc) init.d、/etc/iptables 等系统目录）
 - 安装日志权限收紧：`logs/` 目录 700、`install.log` 600（日志内含 UUID / reality 私钥 / socks5 口令，旧版默认 644 世界可读）
 - 修复维护命令污染安装日志：`list`/`cip` 等场景直写 `install.log` 改由 `INSTALL_LOGGING` 控制，不再破坏"仅保留最近一次安装"
 - Argo token 落盘权限收紧：systemd `/etc/systemd/system/argo.service` / openrc `/etc/init.d/argo` 现在 chmod 600，旧版 644 任何本地用户可窃取隧道 token
 - **修复 `sb.json` 改写后权限回落 644**：分流管理 / 改端口 / 改 SNI / 增删代理等 25+ 处 `jq > tmp && mv` 写回统一走新增的 `sbj_save()`（校验 tmp 为合法 JSON + 强制 chmod 600），`sb.json` 内含全部协议口令
 - uuid 增加字符集校验（仅允许 `[0-9a-fA-F-]`）：用户传入 uuid 会拼进 nginx location 与订阅路径，防换行/控制符配置注入
 - 快捷命令 wrapper 加固（`gen_online_wrapper()`）：执行前校验被拉取脚本含 `VERSION` 声明（拦截错误页/被篡改内容）、版本与生成时不一致给出提示（发现 raw.githubusercontent CDN 缓存 / 拉取异常）；顺带修复 `singbox` wrapper 依赖未导出 `SINGBOX_FOLDER_PATH` 导致永远走在线拉取的 bug
 - 移除"把含账号密码的代理 URL 发给第三方检测 API（check.socks5.cmliussss.net）"的逻辑，改本机 curl 穿代理自测，凭据只到达代理本身
 - 新增可选下载校验和：设置 `SINGBOX_ARCHIVE_SHA256` / `CLOUDFLARED_SHA256` 环境变量可强制校验 sing-box / cloudflared 下载文件（未设置则维持原有 内容嗅探 + 结构 + 版本号 校验）
 - 地区查询（ip-api.com）改为 https 优先、失败回退 http
 - **功能 / Bug 修复**
 - nginx 订阅端口加入防火墙：`apply_singbox_iptables_rules` 在 subscribe=true 或启用 Argo 时为 nginx_pt 添加 ACCEPT；新增统一 `refresh_firewall_rules()`（flush + 重放 + 白名单 + 保存），`ins`、端口修改菜单、订阅端口修改菜单统一调用，修复「改端口后防火墙不刷新、新端口被挡旧端口仍放行」的问题
 - 端口占用检测内存化：`SB_TAKEN_PORTS` 改用关联数组 O(1) 查重；`rand_port` 用启动时 ss 快照预筛 + 实时 ss 兜底（安装等集中分配流程省去重复 fork，交互菜单等长停留场景仍实时检测保证准确）
 - 修复未安装时 `list`/`sub`/`node`/`rt`/`logs` 等维护命令被"至少设置一个协议变量"守卫误拦的问题（仅 ins/rep 强制要求）
 - 修复 vless-ws 端口复用在 `port_vm_ws` 为空文件时端口为空、jq `tonumber("")` 失败导致 vless-ws 入站静默丢失的边界 bug

v2.0.1 (2026-09-06)
 - argo 取值变更为 `vmess / vless / trojan`（支持多选，逗号分隔，如 `argo=vmess,vless`）；旧值 `vmpt/trpt/vlpt` 彻底废弃，不再读取
 - 外部传入非法 argo（含旧值）在安装/覆盖安装时直接提示并退出；已落盘配置（vlvm）依然认可
 - vmess/trojan/vless 的启用完全由 `argo=` 决定；三个协议本地回源端口不接受外部指定，由脚本自动随机（或复用落盘 port_*），天然适配 NAT 机
 - 新增端口占用登记机制：随机端口自动避开「显式端口 / 服务端口(nginx_pt/argo_pt) / 已落盘 port_* / 本机正在监听的端口」，杜绝多协议端口互撞
 - 交互菜单 Argo 协议选择改为直接设置 argo 新值，端口设置不再询问 argo 三端口
 - 安装日志新增打印 `Argo协议: xxx`；协议端口打印在 `DEBUG_FLAG=1` 时附带其落盘文件提示
 - Nginx 安装条件明确：subscribe=true **或** 启用 Argo 都会安装 Nginx（Argo 回源走 Nginx 反代）
 - README 同步新取值与示例；新增 Nginx 何时安装速查表
 
v1.0.30 (2026-09-05)
 - **安全加固**
 - **修复 reality_private 被忽略的问题**：本地推导公钥不再依赖 `xxd`（Debian 12/13 起 `/usr/bin/xxd` 是独立 `xxd` 包，`vim-common` 不再提供），改用 `openssl pkey -inform DER` 直接读 PKCS#8 DER，只要 openssl 在即可推导。旧版在无 xxd 的环境会推导失败→静默生成新 keypair，导致传了 `reality_private` 却节点不一致
 - 删除 Reality 私钥在线推导兜底：旧版本地推导失败时会通过 `?privateKey=` 把私钥明文发给第三方（realitykey.cloudflare.now.cc），现改为直接失败并回退生成新 keypair，私钥不再外发
 - Argo 凭据/域名校验：新增 `is_valid_domain` / `is_valid_argo_token`（含嵌入换行/CR 校验，防 grep 跨行绕过），非法 token/域名拒绝写入 systemd ExecStart / openrc command_args / tunnel.yml（防命令与配置注入）
 - 二进制下载完整性运行时校验：sing-box（拦截 HTML 错误页、校验归档内含 sing-box 二进制、版本必须等于 1.13.14）、cloudflared（拦截 HTML 错误页、`--version` 必须可解析）
 - 凭据文件统一 chmod 600：tunnel.json / tunnel.yml / sbargotoken / argo_domain / reality.key / uuid / sb.json / jh.txt
 - Socks5 白名单 IP/CIDR 格式校验（`is_valid_cidr`）：非法条目跳过并警告；全部非法时报错，不再"显示已开启但实际未生效"
 - 订阅走明文 HTTP 时打印风险警告（订阅 URL 内含全部节点口令，仅建议可信网络使用）
 - `setenforce 0` 仅在 SELinux=Enforcing 时执行并打印提示，不再静默关掉 SELinux
 - 交互输入 Argo token / reality_private 改用 `read -s` 静默输入，防终端回显
 - pkill/pgrep 匹配收窄到本脚本安装路径，避免误杀系统中其他同名进程
 - crontab 清理改用 `mktemp` 临时文件，消除固定路径 `/tmp/crontab.tmp` 的符号链接攻击面
 - **Bug 修复**
 - 修复 Alpine(openrc) `sb autostart` 生成损坏的 init 脚本：heredoc 内 `${name}`/`$command`/`$pidfile`/`$command_args`/`$?` 被 bash 提前展开为空，start/stop 全部失效
 - 随机端口避开已在监听的 TCP/UDP 端口（ss 检测 + 最多重试 20 次）
 - 端口冲突检查新增"系统已监听端口"提示（本脚本栈自带的 sing-box/cloudflared/nginx 监听不计为冲突，避免 rep 覆盖安装时旧实例被误报）
 - 节点链接 fragment 统一 URL 编码：`name` 中的空格 / `#` / `?` / `&` 不再破坏链接；vmess 节点的 `ps`/`add`/`host`/`sni` 字段做 JSON 转义
 - `append_jh` 改用 `printf` 写订阅文件，防 `\n`/`\x` 转义注入订阅内容；节点名清洗掉 CR/LF
 - 删除死代码：`setup_warp_config` / `singbox_status` / `interactive_uninstall_menu`
 - 版本号推进为 1.0.30

v1.0.29 (2026-08-27)
 - **修复覆盖安装会清除所有 iptables 规则的 bug**：旧版 `install_step()` 中 `iptables -F` 会暴力清除所有防火墙规则（包括其他程序添加的），现改为仅清除本脚本标记的规则
 - 新增 iptables/ip6tables 规则标记体系：所有协议端口标记 `doraemon_singbox_rule`，白名单 socks5 标记 `socks5_rule`，通过 `--comment` 精确识别
 - 新增 `apply_singbox_iptables_rules()`：为所有协议端口（vmess/trojan/vless/socks5）添加 iptables ACCEPT 规则
 - 重构 `flush_singbox_iptables_rules()`：统一清除两种标记的所有规则，卸载/覆盖安装时不影响其他程序
 - 白名单实现从 sing-box `route.rules` 改为 iptables/ip6tables：在 TCP 层直接拦截非白名单 IP 的连接，同时支持 IPv4/IPv6
 - 版本号推进为 1.0.29

v1.0.26 (2026-08-26)
 - 新增 Socks5 IP白名单功能：通过 `socks5_wl_flag`（开关）和 `socks5_ips`（IP列表）控制，仅白名单中的源 IP 可访问 Socks5 入站
 - 安装时通过环境变量传入，安装后可通过交互菜单 `node → Socks5 IP白名单管理` 开关、修改 IP 列表
 - 大小写不敏感：`true`/`True`/`TRUE`/`1` 均可识别为开启

v1.0.24 (2026-08-25)
 - **修复 Reality 私钥 base64 编码不兼容导致 sing-box 启动失败**：旧版 reality.key 使用标准 base64（`+`/`/` + `=` 填充），sing-box 1.13+ 期望 URL-safe base64（`-`/`_` + 无填充），密钥中 `+` 字符在解码时被拒绝
 - 新增 `_to_urlsafe_base64()` 自动转换函数，读取密钥时自动将标准 base64 转为 URL-safe base64
 - 覆盖所有密钥读取路径：`init_reality_keypair()` / `ensure_and_print_reality_private_for_cip()` / `regenerate_links_and_sub()`
 - `sbbout()` 启动前预创建 singbox.log，启动后 3 秒检测日志文件是否生成


v1.0.23 (2026-08-25)
 - sbbout() 启动前预创建 singbox.log，确保 sing-box 启动时文件已存在
 - 启动后 3 秒检测日志文件是否生成，为空显示黄色警告提示

v1.0.22 (2026-08-25)
 - 修复 sbrestart/argorestart：systemd 下不再手动 pkill，避免进程脱离 cgroup 导致服务重启后显示"已停止"
 - 新增 capture_stop_reason()：服务异常停止时自动从 journalctl/dmesg/应用日志捕获原因，写入 `doraemon/logs/stop_reason.log`
 - 新增 `sb log_stop` 快捷命令 + 菜单项查看停止原因
 - cleandel 优化：systemctl stop 加 timeout 5 超时保护，清理流程每阶段添加进度提示（▸→✓）

v1.0.21 (2026-08-25)
 - 新增日志查看快捷命令：`sb logs`（菜单）、`sb log_sb`、`sb log_argo`、`sb log_ins`（可带行数，如 `sb log_sb 100`）
 - 提取 show_log_file() 公共函数供菜单与 CLI 共用
 - cleandel 删除冗余 /proc/[0-9]* 遍历循环（每个进程 2 次 fork 导致 ~6s 卡顿），已被 pkill 等效覆盖

v1.0.20 (2026-08-25)
 - 所有日志归拢到 `doraemon/logs/` 子目录（install.log / singbox.log / argo.log / deps_failed.log / nginx_install.log）
 - 新增 migrate_logs_dir()：老安装自动将根目录散落日志迁移到 logs/，systemd 句柄无缝衔接
 - cleandel 保留列表从 `sing-box|cloudflared|install.log` 改为 `sing-box|cloudflared|logs`（整个日志目录保留）
 - 菜单日志子菜单同步更新

v1.0.19 (2026-08-25)
 - 新增脚本安装日志系统（ins/rep/菜单安装全流程记录），零管道零终端干扰
 - 颜色函数钩子 + echo 钩子双写纯文本到 `doraemon/install.log`
 - 日志菜单重构：支持按时间/行数/关键字过滤查看，支持清空与复制路径
 - 新增 `DEBUG_FLAG=1` 环境变量开启调试模式，所有调试输出写入 `doraemon/debug.log`
 - cleandel 保留 install.log 不被清理
 - install_deps 改为实时逐行输出（去管道化），日志同步记录失败依赖

v1.0.15 (2026-08-08)
 - Argo 隧道协议由 vmess/trojan 二选一升级为 vmess/trojan/vless 三选一
 - 新增 vless argo 支持：`argo=vless` 启用（vless-ws 走 Argo）
 - 安装菜单 / 端口修改菜单 / Argo 协议切换菜单 / 分流管理均支持 vless
 - nginx 订阅新增 `/${uuid}-vl` 反代，vless argo 链接自动输出到订阅与 jh.txt

v1.0.14 (2026-08-07)
 - 支持交互式菜单操作
 - 支持 `sb` 快捷指令：安装后直接 `sb` 打开主菜单，或 `sb ins`/`sb rep`/`sb list`/`sb rt`/`sb node`/`sb sub`/`sb del` 等一步直达对应功能
 - 支持内置代理 / 分流管理
 - 方便对接代理 [jyucoeng/aimili-vpngate](https://github.com/jyucoeng/aimili-vpngate)，该项目的代理出口为家宽 IP，可让节点使用家宽出口

v1.0.13
 - sing-box 内核（1.13.14）下载源切换到本仓库 jyucoeng/singbox-tools（release: v1.13.14）
 - 新增 .github/workflows/sync-singbox.yml：手动触发，从上游镜像 4 个 linux 二进制包（amd64/arm64 及 musl 变体）到本仓库 release

v1.0.12
 - `del` 改为保留 sing-box/cloudflared 二进制（只删配置），新增 `delall` 命令完全删除
 - `rep` 复用已有二进制，不再每次重新下载；`upsingbox` 增加版本检测，版本一致则跳过下载
 - 新增 Alpine 自动适配：自动安装 bash、下载 musl 版 sing-box、使用 OpenRC 管理服务
 - 优化 geo IP 查询：v4/v6 并发探测，超时从 5s→3s，不再卡住后续流程

v1.0.11
 - hy2协议增加指纹锁定，防止被篡改

v1.0.10
 -  singbox 内核版本文件适配

v1.0.9
 - 改用官方 sing-box 1.13.14（默认含 WireGuard）
 - 移除 `sniff: true` 适配新版 sing-box 1.13+
 - 修改socks5的socks5_username 和socks5_password环境变量名称（之前没添加socks5前缀）
 - socks5 密码自动生成改为纯字母数字，不再含特殊符号

v1.0.8
 - 新增 socks5 协议支持，可与其他协议自由组合,把一些 sni的默认值由  www.microsoft.com 改为 www.apple.com 

v1.0.7
 - 新增 anytls 协议支持，可与其他协议自由组合

v1.0.6  
 - 去掉快捷指令agsb，以及将主目录名称由agsb 变更为doraemon，用新脚本卸载之前部署好的功能的时候，会把/root/doraemon 和/root/agsb文件夹都删除.

---

## 感谢以下开发者的贡献

- [77160860大佬](https://github.com/77160860/proxy)

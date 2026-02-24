#  singbox 一键安装脚本（可选nginx订阅与argo）
# 1、 singbox 安装以及卸载
## singbox 一键安装脚本（4协议，vmess argo/trojan argo +hy2+vless-Reality+tuic，这些协议可自由组合）
cloudflared和nginx 用不到的时候就不会下载，只有配置了相关参数才会自动下载和启动

举🌰说明：


```

uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed281 \
cdn_host="saas.sin.fan" \
cdn_pt=8443 \
hy_sni="time.js" \
vl_sni="www.yahoo.com" \
vl_sni_pt=443 \
tu_sni="time.js" \
ippz=4 \
out_ip='你的特殊出口ip(仅当你的出口ip和服务器ip不一致时有效，需配合ipzz使用，一般情况下留空或者不传值)' \
trpt=41002 \
vlrt=41003 \
hypt=41004 \
tupt=41005 \
nginx_pt=41006 \
subscribe=true \
argo="trpt" \
agn="california.xxxx.xyz" \
agk='ey开头的那一大串' \
name="小叮当-美国加州"  \
reality_private=GHxxxxxxxxxxxxx-xxxxxx-VnXH6FjxxA \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep

```
# 环境变量说明

##  1、 如果bash后面跟了一个参数 rep（如果没写这个参数默认视为安装），代表覆盖式安装（会卸载后再安装），你可以用这个改成其他功能，比如del 代表 卸载, list 代表 查看节点，具体有哪些值你可以跑一次安装脚本你就知道怎么用了。
 bash  agsb.sh list key 这里有2个参数 list key，代表显示节点的同时会显示vless Reality的密钥。如果不加key 参数，就只显示节点

## 2、 uuid=XXXX-xxx-XXXX（可传，也可不传）

**含义**
- 不传uuid → 脚本自动生成 UUID
- 传uuid → 使用你指定的 UUID

## 3、 cdn_host、cdn_pt、hy_sni、tu_sni、vl_sni、vl_sni_pt、argo_pt（以及cdn域名 和 各协议的伪装域名，可选)

❗除了vl_sni、vl_sni_pt 属于安装时自定义，其他几个都属于任何时候都可以在客户端 随便修改） 
❗注意：这几个值不会填的话就不要瞎传（可直接留空或者干脆删去这个环境变量）
-----
 ## 最佳实践
### 不要用以下域名作为 sni(❗❗❗这点非常重要，不然你的vps小鸡端口被恶意扫描到的时候，将会被作为无限制流量转发端口，你的节点的流量会嗖嗖被刷，反正你不知道该写什么域名作为sni，那比较明智的做法是留空，我已经内置了sni默认值)：

  ❌ Cloudflare 相关：www.cloudflare.com、dash.cloudflare.com

  ❌ CDN 服务：www.akamai.com、www.fastly.com

  ❌ 代理/VPN 服务：任何代理服务的域名

  ❌ 你自己的服务器域名（会形成循环）

  ### 推荐用：
  ✅ www.microsoft.com

  ✅ www.yahoo.com

  ✅ www.google.com

  ✅ www.apple.com

  ✅ 任何大型正常网站


------------------


     
👉 cdn_host、cdn_pt用在以下地方(argo场景的对外端口为cdn_pt，默认值为443端口，你可以自定义为https系端口中的一个：443,2053,2083,2087,2096,8443  [这几个端口任选] ):

—— VMess Argo：
"add":"${cdn_host}"

——  Trojan Argo：
trojan://${uuid}@${cdn_host}:${cdn_pt}?...

举🌰：
```
trojan://0631a7f3-09f8-4144-acf2-a4f5bd9ed281@cdns.doon.eu.org:8443?...
```

👉  vl_sni_pt 为vless Reality协议节点的伪装域名对应的https系端口，可以在安装时自定义，可自定义为https系端口中的任意一个(443,2053,2083,2087,2096,8443)，不能在客户端随便乱改（因为是安装时绑定）

- cdn_host 指的是用argo时的cf域名，缺省值为saas.sin.fan，你可以自己传你要的值，比如 www.visa.com 。cdn_pt是cf域名对应的端口。 不传就会使用缺省值做兜底。

- hy_sni 指的是用hy2协议的sni（伪装域名），缺省值为www.microsoft.com，你可以自己传你要的值,不传就会使用缺省值做兜底。

- tu_sni 指的是用tuic协议的sni(伪装域名)，缺省值为www.microsoft.com，你可以自己传你要的值，比如 www.yahoo.com 。 不传就会使用缺省值做兜底。

- vl_sni 指的是用vless协议的sni(伪装域名)，缺省值为www.microsoft.com，你可以自己传你要的值，比如 www.yahoo.com 。 不传就会使用缺省值做兜底。

- vl_sni_pt 指的是vless协议的sni(伪装域名)对应的握手端口，默认是443，你可在安装时自定义为https系那几个中的一个。

- argo的对外默认优选端口为443（可自行修改cdn_pt 参数），同样argo_pt对本地的监听端口为8001.也可以自定义（但是不建议改，不然你就要同时去把CF里面的对应的HTTP改成你自定义的端口。）

<img width="1514" height="621" alt="CleanShot 2026-01-25 at 12 50 32" src="https://github.com/user-attachments/assets/ec1d2396-4832-4b1b-9da7-cbda4e9c56f1" />


##  4、 ippz和out_ip（IP显示策略和特殊出口ip，可选）
## 👇 👇 👇
| ipzz值 |    含义        |
|--------|---------------|
| 4      | 强制使用 IPv4  |
| 6      | 强制使用 IPv6  |
| 空     | 自动判断       |

 👉 ipzz只影响 节点输出，不影响服务运行

 👉 out_ip='你的特殊出口ip(仅当你的出口ip和服务器ip不一致时有效，需配合ipzz使用)' ，比如：

 - 出口为ipv4, out_ip='216.166.22.30',ipzz=4(当服务器ip为216.166.22.250时，你的出口ip由于某个原因被分给了216.166.22.30，正常情况下，脚本会默认使用250这个ip作为出口ip，针对你这个需求，你就可以设置这2个变量来解决这个设定出口为30的特殊要求)
 

 <img width="602" height="132" alt="CleanShot 2026-01-26 at 12 57 34" src="https://github.com/user-attachments/assets/57c1a329-9292-45b5-aa23-3c59cd3e3356" />


  
  - 出口为ipv6, out_ip='2602:294:0:b7:1234:1234:d9d4:0001',ipzz=6 (当服务器ip为2602:294:0:b7:1234:1234:d9d4:2600时，你的出口ip由于某个原因被分给了2602:294:0:b7:1234:1234:d9d4:0001，正常情况下，脚本会默认使用2600这个ip作为出口ip，针对你这个需求，你就可以设置这2个变量来解决这个设定出口为0001的特殊要求)

 ## 👆 👆 👆

 ## 5、 各种端口

   ```bash
   trpt=41003 \
   hypt=41001 \
   vlrt=41002 \
   tupt=41005 \
   vmpt=41004 \
   nginx_pt=31006 \
   ```
   这4个分别为trojan、hy2、vless、tuic、vmess、nginx订阅地址的端口



## 6、 nginx_pt=? nginx订阅端口，默认值为 8080。

- 不传 → 默认 8080
- 传 → nginx订阅使用的监听端口

❗注意：nginx_pt与argo_pt的值不能同时为8001，不然会导致监听混乱(换句人话：如果你不改argo_pt的值，nginx_pt就不能设置为8001)。

## 7、 subscribe 订阅开关，默认值为false，即不需要nginx订阅。

- false → 默认 不生成订阅（也不会安装nginx）
- true →  会生成订阅。当设置为true时，需要同时设置nginx的订阅端口参数：nginx_pt=?


## 8、 argo（Cloudflare Argo 开关）

- 当argo=vmpt 表示启用vmess的argo
- 当argo=trpt 表示启用trojan的argo
- 或者这个argo参数留空，表示不启用argo

⚠️ Argo 只能用于 VMess / Trojan，是2选1的模式，暂时不支持同时argo

❌ 对 hypt / vlrt /tupt无效

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
传这个值是为了你在安装和重装节点的时候，生成的vless节点保持一致。

如果不在意一致，你可以直接不用管。不传的时候，这个值会自动生成。
然后安装或者重装完成的时候，会打印一次给你，请自行保存这个值。

 如果你忘记了保存，可再次重装或者调用  bash sb.sh list key 即可再次打印出此reality_private 的值

- 不传 → 默认 生成
- 传 → 就能节点永远相同(请注意不要乱填，正确的值应该是43个字符)


## 12、所有的协议都会输出到聚合节点文件中: cat /root/agsb/jh.txt

## 以下为 参数上面有红线代表可以不传的变量
<img width="1020" height="428" alt="CleanShot 2026-01-23 at 10 30 19" src="https://github.com/user-attachments/assets/bb336e89-df63-493d-8ee3-6c821870b36c" />



### 这里给列出一些基础变量
```bash
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed281 \
ippz=4 \
trpt=41002 \
vlrt=41003 \
hypt=41004 \
tupt=41005 \
argo="trpt" \
nginx_pt=41006 \
agn="california.xxxx.xyz" \
agk='ey开头的那一大串' \
subscribe=true \
reality_private=GHxxxxxxxxxxxxx-xxxxxx-VnXH6FjxxA \
name="小叮当-美国加州"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep

```

# 2、常见组合调用方式

## 组合1️⃣、 仅 1个直连协议（不走 Argo,hypt与vlrt、tupt这几个端口参数选一个来写）

### 只要hy2协议

```bash
hypt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

### 只要vless Reality协议

```bash
vlrt=2083 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

### 只要tuic协议

```bash
tupt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

## 组合2️⃣、 仅 2个直连协议（不走 Argo,hypt与vlrt参数都写，代表hy2和vless-reality 协议都会出来）

```bash
hypt=2082 \
vlrt=2083 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

## 组合3️⃣、 VMess  Argo/ Trojan  Argo（最常用，2个协议选一个）

### 当使用trojan Argo时

```bash
ippz=4 \
trpt=41003 \
argo=trpt \
agn="test-trojan.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  rep
```

## 当使用trojan Argo时

```bash
ippz=4 \
trpt=41003 \
argo=trpt \
agn="test-vmess.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  rep
```

## 4️⃣ 、VMess + Hysteria2+ vless

```bash
ippz=4 \
hypt=41001 \
vlrt=41002 \
vmpt=41003 \
argo=vmpt \
agn="test-vmess.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  rep
```


## 5️⃣、我自己的测试用例（4协议，hy2+vless+tuic+trojan Argo）

### argo tunnel的token为普通字符串的场景：
```bash
cdn_host="cdns.doon.eu.org" \
cdn_pt=8443 \
hy_sni="time.js" \
vl_sni="www.yahoo.com" \
vl_sni_pt=443 \
tu_sni="time.js" \
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed281 \
ippz=4 \
trpt=41002 \
vlrt=41003 \
hypt=41004 \
tupt=41005 \
argo="trpt" \
nginx_pt=41006 \
agn="california.xxxx.xyz" \
agk='ey开头的那一大串' \
subscribe=true \
reality_private=GHxxxxxxxxxxxxx-xxxxxx-VnXH6FjxxA \
name="小叮当-美国加州"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  rep
```



### argo tunnel的json token的场景：（请一定要记得json格式的时候，要用英文单引号包裹起来）

```bash
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed281 \
ippz=4 \
trpt=41002 \
vlrt=41003 \
hypt=41004 \
tupt=41005 \
argo="trpt" \
agn="northCarolina.xxxx.xyz" \
agk='{"AccountTag":"xxxxxxxxxxxxxx","TunnelSecret":"xxxxxxxxxxxxxx","TunnelID":"xxxxxxxxxxxxxx","Endpoint":""}' \
name="小叮当-美国北卡"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```


## 如何卸载呢？
```bash

bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  del

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
| vmpt                         | 0（无直连）                                           |
| trpt                         | 0（无直连）                                           |
| vmpt + argo=vmpt             | 1（Argo-vmess）                                       |
| trpt + argo=trpt             | 1（Argo-trojan）                                      |
| hypt + vlrt                  | 2（hy2和vless直连）                                   |
| hypt + vlrt + tupt           | 3（hy2、vless、tuic直连）                             |
| hypt + vlrt + argo           | **3（hy2、vless直连+Argo-vmess或者Argo-trojan）**         |
| hypt + vlrt + tupt + argo    | **4（hy2、vless、tuic直连+Argo-vmess或者Argo-trojan）**   |

## 感谢
感谢以下开发者的贡献：

- [77160860大佬](https://github.com/77160860/proxy)


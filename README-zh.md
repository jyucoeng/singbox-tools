# singbox-tools

[English](README.md) | **中文**

singbox 一键安装脚本、socks5 一键脚本、mtp 一键脚本。全部是自包含的 bash 脚本，从固定 URL 拉下来在**你自己的**服务器上执行：没有账号系统、没有控制面板、项目本身不运营任何服务。

## 快速开始

```bash
curl -fsSL https://raw.githubusercontent.com/jyucoeng/singbox-tools/main/sb.sh -o sb.sh
bash sb.sh
```

每份脚本都能通过 `bash -n` 检查、启动时打印自身版本号，重复执行可覆盖升级或卸载。

## 脚本一览

| 脚本 | 用途 | 说明文档 |
| --- | --- | --- |
| `sb.sh` | sing-box 节点一键安装与管理：Hysteria2、VLESS-Reality、TUIC、AnyTLS、VMess/Trojan/VLESS over WebSocket+TLS（可走 Argo 隧道或 CDN），含 IP 白名单的 Socks5、nginx 订阅输出，以及 `rep` / `ins` / `del` / `delall` / `list` / `ups` 动作 | [README-sb.md](README-sb.md#1-singbox-安装以及卸载) |
| `mtp-new.sh` | MTProxy 安装（交互菜单 / Go 版 / Telemt），含配额、到期、限速、多用户管理 | [README-mtp-new.md](README-mtp-new.md) |
| `mtp-old.sh` | 旧版 MTProxy 安装脚本，保留给既有部署 | [README-mtp-old.md](README-mtp-old.md) |
| `socks5.sh` / `socks5-noauth.sh` | 独立 sing-box Socks5 安装脚本 | [README-sb.md#socks5](README-sb.md#socks5) · [README-socks5-old.md](README-socks5-old.md) |
| `bbr.sh` | 内核 / BBR 与队列算法调优助手 | [README-bbr.md](README-bbr.md) |
| `fs-onlyforme.sh` | 自用维护与杂项脚本 | — |
| `init.js` | CI workflow 使用的依赖与版本同步辅助脚本 | — |

## 相关项目

同一作者维护，不在本仓库内：

- [singbox-tools-interface](https://github.com/jyucoeng/singbox-tools-interface)——在线命令生成界面（纯静态单文件 `index.html`），不用记参数，勾选后直接复制安装命令。
- [sub_merge](https://github.com/jyucoeng/sub_merge)——节点汇聚项目，部署后用自己的域名汇聚所有机器的节点。

## 许可证

[MIT](LICENSE) © LittleDoraemon ([@jyucoeng](https://github.com/jyucoeng))

脚本本身为作者原创；运行过程中下载安装的 sing-box / MTProxy / nginx 等组件遵循其各自许可证。

## 维护者

LittleDoraemon ([@jyucoeng](https://github.com/jyucoeng))，唯一维护者与对接人。

## 免责

脚本只在你自己的服务器上安装软件，使用时的合规责任由使用者承担。本项目不运营任何服务：没有账号系统、没有订阅服务、没有付费档位，也不收集用户数据。

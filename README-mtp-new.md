## mtp-new.sh 用法

`mtp-new.sh` 是 MTProxy 管理脚本，同时支持**交互式菜单**与**无交互参数安装**两种模式。

### 1、交互式菜单（无参数运行）

```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh)
```

菜单功能一览：

| 选项 | 功能 |
|---|---|
| 1 | 安装 Go 版 (mtg) |
| 2 | 安装 Telemt 高性能版（多用户/配额/到期/限速） |
| 3 | 查看连接信息 |
| 4 | 修改配置（端口/域名/监听模式） |
| 5 | 删除配置 |
| 6 | Telemt 多用户管理 |
| 7 | 查看运行状态 |
| 8 | 查看日志 |
| 9/10/11 | 启动/停止/重启服务 |
| 12 | 卸载全部并清理 |

### 2、无交互安装（环境变量方式）

#### 安装 Go 版（mtg）

```
PORT=20301 DOMAIN='www.apple.com' IP_MODE='v4' bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh) rep
```

#### 安装 Telemt 高性能版

```
INSTALL_MODE=telemt PORT=20301 DOMAIN='www.apple.com' IP_MODE='dual' \
TELEMT_USER='admin' TELEMT_QUOTA=100 TELEMT_EXPIRE='2026-12-31' \
TELEMT_SPEED_UP=1.5 TELEMT_SPEED_DOWN=5.0 TELEMT_RESET_DAY=1 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh) rep
```

#### 更多 Demo 示例

下面示例统一使用变量 `URL` 指代脚本地址，复制时换成完整地址即可：

```
URL='https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh'
```

**① Go 版 - 基础安装（自定义密钥，多次安装链接保持一致）**

```
PORT=443 DOMAIN='www.apple.com' IP_MODE='v4' \
SECRET='aabbccdd00112233aabbccdd00112233' \
bash <(curl -Ls $URL) rep
```

**② Telemt - 基础安装（单用户，无任何限制）**

```
INSTALL_MODE=telemt PORT=443 DOMAIN='www.apple.com' IP_MODE='v4' \
TELEMT_USER='admin' \
bash <(curl -Ls $URL) rep
```

**③ Telemt - 流量限制 Demo（每月 100GB，每月 1 号自动重置）**

```
INSTALL_MODE=telemt PORT=443 DOMAIN='www.apple.com' IP_MODE='v4' \
TELEMT_USER='vip01' TELEMT_QUOTA=100 TELEMT_RESET_DAY=1 \
bash <(curl -Ls $URL) rep
```

**④ Telemt - 时间限制 Demo（仅限到 2026-12-31 晚 23:59:59，过后断流）**

```
INSTALL_MODE=telemt PORT=443 DOMAIN='www.apple.com' IP_MODE='v4' \
TELEMT_USER='trial' TELEMT_EXPIRE='2026-12-31 23:59:59' \
bash <(curl -Ls $URL) rep
```

**⑤ Telemt - 流量 + 时间双重限制 Demo（100GB 且 2026-12-31 到期，任一超限即断流）**

```
INSTALL_MODE=telemt PORT=443 DOMAIN='www.apple.com' IP_MODE='v4' \
TELEMT_USER='vip01' TELEMT_QUOTA=100 TELEMT_RESET_DAY=1 \
TELEMT_EXPIRE='2026-12-31 23:59:59' TELEMT_SPEED_UP=1.5 TELEMT_SPEED_DOWN=5.0 \
bash <(curl -Ls $URL) rep
```

> 安装完成后，脚本会直接输出 `tg://proxy?...` 分享链接；后续也可用 `list` 命令或交互菜单的「Telemt 多用户管理」查看/添加更多用户。

### 3、管理命令

```
bash <(curl -Ls .../mtp-new.sh) ins      # 安装（不清理旧配置）
bash <(curl -Ls .../mtp-new.sh) rep      # 覆盖重装（先清理服务配置，保留脚本本体与 mtp 命令）
bash <(curl -Ls .../mtp-new.sh) list     # 查看已安装服务的连接信息
bash <(curl -Ls .../mtp-new.sh) del      # 全量卸载并清理
bash <(curl -Ls .../mtp-new.sh) start    # 启动服务
bash <(curl -Ls .../mtp-new.sh) stop     # 停止服务
bash <(curl -Ls .../mtp-new.sh) restart  # 重启服务
bash <(curl -Ls .../mtp-new.sh) check_reset   # Cron 静默调用，配额自动重置（无需手动执行）
bash <(curl -Ls .../mtp-new.sh) force_reset   # 手动立即触发配额重置
```

> 命令大小写不敏感；`del` 会删除脚本自身与全局 `mtp` 命令，`rep` 不会。

### 4、环境变量说明

| 变量 | 说明 | 默认值 | 举例 |
|---|---|---|---|
| `INSTALL_MODE` | 安装后端：`go` / `telemt` | go | `telemt` |
| `PORT` | 监听端口 | 443 | `20301` |
| `DOMAIN` | 伪装域名 | www.apple.com | `www.apple.com` |
| `IP_MODE` | 监听模式：`v4` / `v6` / `dual` | v4 | `dual` |
| `SECRET` | 通信密钥（必须为 32 位 hex，不填自动生成） | 自动生成 | `aabbccdd00112233aabbccdd00112233` |
| `TELEMT_USER` | Telemt 初始管理员用户名 | admin | `admin` |
| `TELEMT_QUOTA` | 初始用户月度流量配额（GB，支持小数） | 不限流 | `100` / `25.5` |
| `TELEMT_EXPIRE` | 初始用户强制到期日（东八区，可精确到秒） | 永久 | `2026-12-31` / `2026-12-31 23:59:59` |
| `TELEMT_SPEED_UP` | 初始用户上行限速（MB/s，支持小数） | 不限 | `1.5` |
| `TELEMT_SPEED_DOWN` | 初始用户下行限速（MB/s，不填默认同上行） | 同上行 | `5.0` |
| `TELEMT_RESET_DAY` | 配额月度自动重置日（仅在设置了 `TELEMT_QUOTA` 时生效） | 不启用 | `1` |

> **密钥一致性**：只要自定义了 `SECRET`（并通过环境变量传入），无论重复安装多少次，生成的连接密钥与分享链接都完全一致（配合相同的 `DOMAIN`/`PORT` 效果更佳）。不填 `SECRET` 时每次安装都会自动生成全新密钥。若 `SECRET` 非法（非 32 位 hex），脚本会报错中止。

### 5、注意事项

- 需要 **root** 权限运行
- 安装流程：优先使用本地同目录下的预编译二进制（`mtg-go-<arch>` / `telemt-linux-<arch>` / `telemt`），未找到则从 [0xdabiaoge/MTProxy](https://github.com/0xdabiaoge/MTProxy) 下载
- 支持系统：Debian/Ubuntu（systemd）、CentOS/RHEL（systemd）、Alpine（OpenRC）
- Telemt 多用户功能：专属端口、流量配额、到期日、独立限速、月度自动重置（Cron）

## 感谢

- [0xdabiaoge大佬](https://github.com/0xdabiaoge/MTProxy)

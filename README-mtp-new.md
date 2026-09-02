## mtp-new.sh 用法

`mtp-new.sh` 是 MTProxy 管理脚本，同时支持**交互式菜单**与**无交互参数安装**两种模式。

### 1、交互式菜单（无参数运行，推荐此运行方式，因为安装参数有点多，带交互方式比较友好）

```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh)
```

菜单功能一览：

| 选项 | 功能 |
|---|---|
| 1 | 安装 Go 版 (mtg) |
| 2 | 安装 Telemt 高性能版（多用户/配额/到期/限速） |
| 3 | 查看连接信息 |
| 4 | 修改配置（端口/域名；Go 版含监听模式） |
| 5 | 删除配置 |
| 6 | Telemt 多用户管理 |
| 7 | TG 推送配置 |
| 8 | 流量统计 |
| 9 | TG 通知细分 |
| 10 | 查看运行状态 |
| 11 | 查看日志 |
| 12/13/14 | 启动/停止/重启服务 |
| 15 | 卸载全部并清理 |

### 2、无交互安装（环境变量方式，如果记不住参数，请去使用交互式菜单操作。）

#### 安装 Go 版（mtg）

```
PORT=20301 DOMAIN='www.apple.com' IP_MODE='v4' bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh) rep
```

#### 安装 Telemt 高性能版 （注意：请在每一个环境变量之后都加一个 \，确保每行末尾 \ 前没有多余空格）

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

#### 更多 Demo 示例 （注意：请在每一个环境变量之后都加一个 \，确保 \ 前没有多余空格）

下面示例统一使用变量 `URL` 指代脚本地址，复制时换成完整地址即可：

```
URL='https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-new.sh'
```

**① Go 版 - 基础安装（自定义密钥，多次安装链接保持一致）**

```
PORT=443 \
DOMAIN='www.apple.com' \
IP_MODE='v4' \
SECRET='a3f8b2e1c9d04716e5f2a8b3c7d9e0f1' \
bash <(curl -Ls $URL) rep
```

**② Telemt - 基础安装（单用户，无任何限制）**

```
INSTALL_MODE=telemt \
PORT=443 \
DOMAIN='www.apple.com' \
IP_MODE='v4' \
TELEMT_USER='admin' \
bash <(curl -Ls $URL) rep
```

**③ Telemt - 流量限制 Demo（每月 100GB，每月 1 号自动重置）**

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

**④ Telemt - 时间限制 Demo（仅限到 2026-12-31 晚 23:59:59，过后断流）**

```
INSTALL_MODE=telemt \
PORT=443 \
DOMAIN='www.apple.com' \
IP_MODE='v4' \
TELEMT_USER='trial' \
TELEMT_EXPIRE='2026-12-31 23:59:59' \
bash <(curl -Ls $URL) rep
```

**⑤ Telemt - 流量 + 时间双重限制 Demo（100GB 且 2026-12-31 到期，任一超限即断流）**

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

> 安装完成后，脚本会直接输出 `tg://proxy?...` 分享链接；后续也可用 `users` / `adduser` 命令或交互菜单 [6]「Telemt 多用户管理」查看/添加更多用户。

### 3、管理命令

命令大小写不敏感；`del` 会删除脚本自身与全局 `mtp` 命令，`rep` 不会。按功能分组如下：

**① 安装 / 卸载**

```
bash <(curl -Ls .../mtp-new.sh) ins      # 安装（不清理旧配置）
bash <(curl -Ls .../mtp-new.sh) rep      # 覆盖重装（先清理服务配置，保留脚本本体与 mtp 命令）
bash <(curl -Ls .../mtp-new.sh) del      # 全量卸载并清理
```

**② 服务控制**

```
bash <(curl -Ls .../mtp-new.sh) start    # 启动服务
bash <(curl -Ls .../mtp-new.sh) stop     # 停止服务
bash <(curl -Ls .../mtp-new.sh) restart  # 重启服务
bash <(curl -Ls .../mtp-new.sh) list     # 查看已安装服务的连接信息
```

**③ 用户管理**（配合 `TELEMT_*` 环境变量，见下方示例）

```
bash <(curl -Ls .../mtp-new.sh) adduser   # 非交互添加 Telemt 用户
bash <(curl -Ls .../mtp-new.sh) users     # 非交互查看 Telemt 用户列表及专属分享链接
bash <(curl -Ls .../mtp-new.sh) getuser   # 非交互查询指定用户当前配置（TELEMT_USER 指定）
bash <(curl -Ls .../mtp-new.sh) moduser   # 非交互修改指定用户配置（配额/到期/限速/端口/密钥）
bash <(curl -Ls .../mtp-new.sh) deluser   # 非交互删除指定用户（TELEMT_USER 指定）
```

**④ 流量配额重置**

```
bash <(curl -Ls .../mtp-new.sh) check_reset   # Cron 静默调用，配额自动重置（无需手动执行）
bash <(curl -Ls .../mtp-new.sh) force_reset   # 手动立即触发配额重置
```

**⑤ 流量统计**（本月用量报表 + 各用户耗尽时间）

```
bash <(curl -Ls .../mtp-new.sh) usage             # 查看本月流量使用统计（含各用户耗尽时间）
bash <(curl -Ls .../mtp-new.sh) traffic_snapshot  # 立即记录一次流量快照（Cron 每小时自动调用）
bash <(curl -Ls .../mtp-new.sh) usage_total       # 总流量使用统计（历史累计，按已用从高到低排序）
```

> 别名：`usage` 亦可写作 `traffic` / `stats`，`usage_total` 亦可写作 `traffic_total` / `total`，行为完全一致。

**⑥ Telegram 推送**（统计日报）

```
bash <(curl -Ls .../mtp-new.sh) tg_config     # 配置 Telegram 统计推送（非交互，需 TELEMT_TG_TOKEN/TELEMT_TG_CHAT 或沿用已有配置；交互走主菜单 [7]）
bash <(curl -Ls .../mtp-new.sh) tg_userconf   # 推送用户配置清单到 TG（不带参数=全部用户，或指定用户名 / TELEMT_USER）
bash <(curl -Ls .../mtp-new.sh) tg_report     # 立即手动发送本月统计到 Telegram
bash <(curl -Ls .../mtp-new.sh) tg_autopush   # 定时判断命令（Cron 每小时调用，北京时间到点才推送）
```

> **实现说明**：流量统计 / Telegram 推送 / 用户用量展示（`usage`、`usage_total`、`traffic_snapshot`、`tg_*`、`users`、`getuser`）由内嵌的 Python 模块实现（每次调用自动写入并同步 `/opt/mtproxy/mtp_stats.py`）。需要 **python3**，`ins`/`rep` 安装时已自动安装（Alpine 为 `apk add python3`）；所有命令入口与 Cron 行为保持不变。

**非交互添加用户示例：**

```
# 仅添加用户名（密钥自动生成）
TELEMT_USER=vip01 bash mtp-new.sh adduser

# 指定密钥与配额（密钥固定后分享链接不随重装变化）
TELEMT_USER=vip01 TELEMT_SECRET=aabbccdd00112233aabbccdd00112233 TELEMT_QUOTA=100 bash mtp-new.sh adduser

# 完整限制：专属端口 + 配额 + 到期 + 上下行限速
TELEMT_USER=vip01 TELEMT_DEDICATED_PORT=20443 TELEMT_QUOTA=50 TELEMT_EXPIRE="2026-12-31 23:59:59" \
  TELEMT_SPEED_UP=1.5 TELEMT_SPEED_DOWN=5.0 bash mtp-new.sh adduser
```

> 添加成功会自动重启 Telemt 服务热生效，并在终端回显该用户通信密钥。

**非交互修改用户示例（`moduser`，以 `TELEMT_USER` 指定目标，提供哪项改哪项）：**

```
# 查询用户当前配置
TELEMT_USER=vip01 bash mtp-new.sh getuser

# 删除用户（连带清理专属端口/配额/到期/限速与账单）
TELEMT_USER=vip01 bash mtp-new.sh deluser

# 只改流量配额（清空已用账单）
TELEMT_USER=vip01 TELEMT_QUOTA=100 bash mtp-new.sh moduser

# 改到期时间（0 表示解除限期、恢复永久）
TELEMT_USER=vip01 TELEMT_EXPIRE="2027-03-01 12:00:00" bash mtp-new.sh moduser

# 同时改配额 + 到期 + 上下行限速
TELEMT_USER=vip01 TELEMT_QUOTA=200 TELEMT_EXPIRE="2027-06-30" \
  TELEMT_SPEED_UP=2 TELEMT_SPEED_DOWN=8 bash mtp-new.sh moduser

# 改专属端口（0 表示移除专属端口、恢复共享端口）
TELEMT_USER=vip01 TELEMT_DEDICATED_PORT=20555 bash mtp-new.sh moduser

# 改通信密钥（分享链接会随之变化）
TELEMT_USER=vip01 TELEMT_SECRET=aabbccdd00112233aabbccdd00112233 bash mtp-new.sh moduser

# 一键解除该用户的全部限制
TELEMT_USER=vip01 TELEMT_QUOTA=0 TELEMT_EXPIRE=0 TELEMT_SPEED_UP=0 TELEMT_DEDICATED_PORT=0 bash mtp-new.sh moduser
```

> 规则：`0` = 解除/移除该项限制；不提供则保持不变。退出码约定：**2** = 用法错误（`TELEMT_USER` 为空/非法、字段值格式错误、未提供任何字段）；**1** = 业务失败（用户不存在/已存在、端口冲突）。

**交互菜单「Telemt 高级多用户管理」**（主菜单对应入口）覆盖上述全部能力：

```
1. 查看所有用户及专属分享链接    2. 查询指定用户配置 (模糊匹配)
3. 添加新用户                    4. 踢出(删除)指定用户
5. 管理配额/到期/限速/密钥/端口   6. 自动重置配置 (Cron 月度轮转)
7. TG 分享链接反查用户
0. 返回主菜单
```

> 「查询指定用户」支持输入关键词模糊匹配，多结果时列出序号供选择；「管理配额/到期/限速/密钥/端口」内可改配额、到期、上下行限速、通信密钥与专属端口；「7」可通过 TG 分享链接反查用户。流量统计与 TG 推送已移至主菜单 [8]「流量统计」（本月月报 / 用户清单 / 用户详情 / 总流量排名）与 [9]「TG 通知细分」（消息发送开关、立即推送清单/详情/月报/全部）。

### 4、流量统计与耗尽时间记录

安装 Telemt 后，脚本会自动注册**每小时流量快照 Cron**，并在每次查看用户列表 / 查询 / 统计时同步刷新。相关文件：

| 文件 | 作用 |
|---|---|
| `/etc/telemt_exhausted.json` | 记录各用户**本月**流量耗尽的时间点（跨月记录自动失效） |
| `/var/log/telemt_traffic.log` | 按用户维度追加的流水日志，行尾为时间戳（含 `用尽流量` 事件与每小时用量快照） |
| `/opt/mtproxy/exhausteddata/telemt_total.json` | 历史累计总流量缓存（每月每用户最大快照 + 日志偏移，增量更新） |

运行 `mtp usage` 或主菜单 [8]「流量统计」→「查看本月统计月报」可查看：

```
==================================================
       Telemt 本月流量使用统计 (2026-08)
==================================================
  用户名        已用     限额     剩余     使用率 耗尽时间
  ----------------------------------------------------------------
  admin         512.0MB   1.00GB   512.0MB   50.0%   -
  alice         2.00GB    2.00GB   0B        100.0%  2026-08-03 10:00:12
  ----------------------------------------------------------------
  本月总用量: 2.50GB    总限额: 3.00GB    超限/耗尽用户: 1 个
==================================================
  本月最近流量流水 (按用户维度, 时间在行尾):
alice | 用尽流量: 已用 2.00GB / 限额 2.00GB | 2026-08-03 10:00:12
alice | 已用 2.00GB / 限额 2.00GB | 2026-08-03 10:00:12
```

- **耗尽时间**：用户本月首次流量用尽时记录一次（`/var/log/telemt_traffic.log` 中形如 `用尽流量: ...`），不会重复覆盖；跨月后重新计算。
- **月周期**：报表与「本月最近流量流水」均只统计**当月**记录（按时间戳末尾的 `YYYY-MM` 过滤），上月及更早的流水不显示；日志文件本身为追加式、跨月累积，不会被自动清除。

**总流量使用统计（历史累计）**

运行 `mtp usage_total` 或主菜单 [8]「流量统计」→「查看总流量统计 (历史累计)」可查看跨月累计用量排名：

```
==================================================
       总流量使用统计 (历史累计, 按已用排序)
==================================================
  排名 用户名        历史累计 统计月数
  ----------------------------------------------------------------
  1      alice            2.00GB       2
  2      bob              2.00GB       1
  3      carol            500.0MB      1
  ----------------------------------------------------------------
  历史累计总用量: 4.49GB    有流量记录用户: 3 个
==================================================
```

- **口径**：历史累计 = 各用户**每月流量快照的最大值跨月求和**（从 `/var/log/telemt_traffic.log` 反推），按月自动重置、手动重置、卸载均**不**影响已累计的历史流量。
- **增量缓存**：结果缓存于 `/opt/mtproxy/exhausteddata/telemt_total.json`（目录自动创建），仅解析自上次偏移以来的**新增**流水行，无需每次从头扫描；缓存被删除或日志被截断时，下次运行自动从完整日志重建。
- **排序**：按历史累计已用从高到低。
- **依赖**：需开启流量快照（安装即自动开启）并持续运行，仅当流水日志完整时统计才准确。
- **自动清除**：手动重置配额、`moduser` 改配额、删除用户、月度自动重置时，该用户的耗尽记录会同步清除。
- 卸载（`del`）会一并移除快照 Cron、流水日志、历史累计缓存与耗尽记录。

**Telegram 日报推送**

- 配置：主菜单 [7]「TG 推送配置」（交互式）或环境变量 `TELEMT_TG_TOKEN` / `TELEMT_TG_CHAT`（`tg_config` 非交互 / 安装时自动启用）。
- **可随时更换**：交互菜单可修改 Token / Chat ID / 推送时间，直接回车保留当前值；非交互 `tg_config` 支持只传 `TELEMT_TG_TOKEN=` 或 `TELEMT_TG_CHAT=` 之一（未提供项沿用已有配置）。
- 推送时间：默认**每天北京时间 09:00**（由全局变量 `TG_PUSH_TIME` 控制，`TELEMT_TG_TIME` 可覆盖），通过 UTC+8 换算判断，不依赖服务器时区。
- 手动发送：`mtp tg_report` 随时推送一次当前统计。
- **未配置 `TELEMT_TG_TOKEN` / `TELEMT_TG_CHAT` 时，不会发送任何统计**（定时任务静默跳过）。

### 5、环境变量说明

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
| `TELEMT_SECRET` | 指定用户通信密钥（必须为 32 位 hex，`adduser`/`moduser` 使用） | 自动生成 | `aabbccdd00112233aabbccdd00112233` |
| `TELEMT_DEDICATED_PORT` | 为用户分配专属独立端口（`adduser`/`moduser` 使用） | 共享端口 | `20443` |
| `TELEMT_TG_TOKEN` | Telegram Bot Token（安装或 `tg_config` 时启用推送） | 不推送 | `123456:ABC...` |
| `TELEMT_TG_CHAT` | 接收统计消息的 Telegram Chat ID | 不推送 | `123456789` |
| `TELEMT_TG_TIME` | 日报推送时间（北京时间 HH:MM，覆盖全局变量 `TG_PUSH_TIME`） | `09:00` | `08:30` |
| `DEBUG_FLAG` | 调试日志开关，设为 `1` 时向 stderr 输出排障信息（入口参数、解析结果、各命令目标等） | 0 | `1` |

> **全局变量 `TG_PUSH_TIME`**：位于脚本头部，控制 Telegram 日报的默认推送时间（北京时间 HH:MM，默认 `09:00`），可被环境变量 `TELEMT_TG_TIME` 覆盖。若未配置 `TELEMT_TG_TOKEN` / `TELEMT_TG_CHAT`，脚本不会发送任何统计到 Telegram。

> **密钥一致性**：只要自定义了 `SECRET`（并通过环境变量传入），无论重复安装多少次，生成的连接密钥与分享链接都完全一致（配合相同的 `DOMAIN`/`PORT` 效果更佳）。不填 `SECRET` 时每次安装都会自动生成全新密钥。若 `SECRET` 非法（非 32 位 hex），脚本会报错中止。

### 6、注意事项

- 需要 **root** 权限运行
- 安装流程：优先使用本地同目录下的预编译二进制（`mtg-go-<arch>` / `telemt-linux-<arch>` / `telemt`），未找到则从本项目 [singbox-tools](https://github.com/jyucoeng/singbox-tools) 的 `Go-Rust` Release 下载
- 支持系统：Debian/Ubuntu（systemd）、CentOS/RHEL（systemd）、Alpine（OpenRC）
- Telemt 多用户功能：专属端口、流量配额、到期日、独立限速、月度自动重置（Cron）
- 流量统计：每小时自动快照 + 本月用量报表 + 各用户流量耗尽时间记录

## 感谢

本项目魔改自 [0xdabiaoge/MTProxy](https://github.com/0xdabiaoge/MTProxy)，感谢原作者的优秀工作。本脚本在其基础上重写了安装/卸载、服务管理、多用户管理、流量统计、配额重置与 Telegram 推送等逻辑，二进制依赖仍沿用原仓库的编译产物。

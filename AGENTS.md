# AGENTS.md

## 版本号约定
- `mtp-new.sh` 每次代码改动后都必须递增 `SCRIPT_VERSION`（第 3 行），格式 `主.次.修订(YYYY-MM-DD)`（如 `2.2.1(2026-08-02)`），日期用改动当天。
- 用户通过版本号在服务器上确认是否已获取最新版（raw.githubusercontent.com 的 `refs/heads/main` URL 有 CDN 缓存，需用 commit SHA URL 绕过）。
- 改动推送前先 `git diff` 确认版本号已更新。

## 测试命令
- `bash -n mtp-new.sh`
- Python 内嵌引擎改动后需用 `/var/folders/55/mr9v7f5n77g09b4ln5b3rgcw0000gn/T/opencode/resplice.py` splice 回内嵌，并验证 embedded==source 与 `py_compile`。

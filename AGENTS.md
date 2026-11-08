# AGENTS.md

## 版本号约定
- `mtp-new.sh` 每次代码改动后都必须递增 `SCRIPT_VERSION`（第 3 行），格式 `主.次.修订(YYYY-MM-DD)`（如 `2.2.1(2026-08-02)`），日期用改动当天。
- 用户通过版本号在服务器上确认是否已获取最新版（raw.githubusercontent.com 的 `refs/heads/main` URL 有 CDN 缓存，需用 commit SHA URL 绕过）。
- 改动推送前先 `git diff` 确认版本号已更新。

## 推送超时（github.com DNS 被污染）
若 `git push` 报 `Failed to connect to github.com port 443 after 75000 ms`，是 github.com 被解析到了不通的 IP（如 `20.205.243.166`）。不要反复重试，直连时用 `http.curloptResolve` 钉一个可用 IP：

```bash
for ip in 20.27.177.113 140.82.116.3 140.82.112.3; do
  curl -s -o /dev/null -w "$ip %{http_code}\n" --max-time 6 --resolve github.com:443:$ip https://github.com
done
git -c http.curloptResolve=github.com:443:<可用IP> push origin main
```

`api.github.com`、`raw.githubusercontent.com` 通常不受影响。注意 `/etc/hosts` 需要 sudo 密码，不要指望改它。

## 测试命令
- `bash -n mtp-new.sh`
- Python 内嵌引擎改动后需用 `/var/folders/55/mr9v7f5n77g09b4ln5b3rgcw0000gn/T/opencode/resplice.py` splice 回内嵌，并验证 embedded==source 与 `py_compile`。

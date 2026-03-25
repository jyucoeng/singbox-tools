# 添加新协议的修改清单

以添加 `anytls` 协议为例，说明如何在 `sb00.sh` 中添加新协议。

## 修改点总结

添加新协议需要在以下 **11 个位置** 进行修改：

---

## 1. 环境变量定义（第 ~30 行）

**位置**：协议端口环境变量定义区域

**修改内容**：添加新协议的端口环境变量

```bash
# 原有代码
export port_tu=${tupt:-''};

# 新增代码
export port_any=${anypt:-''};
```

---

## 2. SNI 环境变量定义（第 ~15 行）

**位置**：SNI 相关环境变量定义区域（仅限需要 SNI 的协议）

**修改内容**：添加新协议的 SNI 环境变量

```bash
# 原有代码
export tu_sni=${tu_sni:-"www.microsoft.com"}

# 新增代码
export any_sni=${any_sni:-"www.microsoft.com"}
```

---

## 3. 协议启用判断（第 ~145 行）

**位置**：协议启用标志判断区域

**修改内容**：添加新协议的启用判断

```bash
# 原有代码
if [ -n "${tupt+x}" ]; then
    tup=yes
fi

# 新增代码
if [ -n "${anypt+x}" ]; then
    anyp=yes
fi
```

---

## 4. 协议启用检查函数（第 ~155 行）

**位置**：`any_proto_enabled()` 函数

**修改内容**：在条件判断中添加新协议标志

```bash
# 原有代码
any_proto_enabled() {
    is_yes "$vlr" || is_yes "$vmp" || is_yes "$trp" || is_yes "$hyp" || is_yes "$tup"
}

# 修改后
any_proto_enabled() {
    is_yes "$vlr" || is_yes "$vmp" || is_yes "$trp" || is_yes "$hyp" || is_yes "$tup" || is_yes "$anyp"
}
```

---

## 5. 端口冲突检测函数（第 ~3280 行）

**位置**：`check_port_conflicts_or_exit()` 函数中的 `vars` 变量

**修改内容**：添加新协议端口到检查列表

```bash
# 原有代码
local vars="trpt vlrt hypt tupt"

# 修改后
local vars="trpt vlrt hypt tupt anypt"
```

---

## 6. 菜单显示（第 ~722 行）

**位置**：`showmode()` 函数中的 `gradient` 输出

**修改内容**：更新菜单说明文字

```bash
# 原有代码
gradient "       singbox 一键脚本（vmess/trojan Argo选1,vless+hy2+tuic 3个直连）"

# 修改后
gradient "       singbox 一键脚本（vmess/trojan Argo选1,vless+hy2+tuic+anytls 4个直连）"
```

---

## 7. 版本号更新（第 ~14 行）

**位置**：`VERSION` 变量

**修改内容**：递增版本号并更新日期

```bash
# 原有代码
VERSION="1.0.6(2026-03-15)"

# 修改后
VERSION="1.0.7(2026-03-25)"
```

---

## 8. 协议配置生成（第 ~1520 行）

**位置**：`sbbout()` 函数中，其他协议配置之后

**修改内容**：添加新协议的配置生成逻辑

```bash
# 新增代码块
if [ -n "$anyp" ]; then
    if [ -n "$port_any" ]; then
        echo "$port_any" > "$SINGBOX_FOLDER_PATH/port_any"
    elif [ -s "$SINGBOX_FOLDER_PATH/port_any" ]; then
        port_any=$(cat "$SINGBOX_FOLDER_PATH/port_any")
    else
        port_any=$(rand_port)
        echo "$port_any" > "$SINGBOX_FOLDER_PATH/port_any"
    fi
    
    port_any=$(cat "$SINGBOX_FOLDER_PATH/port_any"); 
    yellow "AnyTLS端口：$port_any"

    cat >> "$SINGBOX_FOLDER_PATH/sb.json" <<EOF
{"type": "tls", "tag": "anytls-sb", "listen": "::", "listen_port": ${port_any},"sniff": true,"users": [{"username": "${uuid}","password": "${uuid}"}],"tls": {"enabled": true,"server_name": "${any_sni}"}},
EOF
fi
```

**关键点**：
- 端口处理采用三分支模式（有值 → 从文件读 → 生成随机）
- 端口必须写入文件以便持久化
- 配置必须追加到 `sb.json` 文件

---

## 9. 配置持久化（第 ~2510 行）

**位置**：`write2SingboxFolders()` 函数

**修改内容**：添加新协议 SNI 的保存

```bash
# 原有代码
echo "${tu_sni}"    > "$SINGBOX_FOLDER_PATH/tu_sni"
echo "${cdn_host}"  > "$SINGBOX_FOLDER_PATH/cdn_host"

# 修改后
echo "${tu_sni}"    > "$SINGBOX_FOLDER_PATH/tu_sni"
echo "${any_sni}"   > "$SINGBOX_FOLDER_PATH/any_sni"
echo "${cdn_host}"  > "$SINGBOX_FOLDER_PATH/cdn_host"
```

---

## 10. 节点输出（第 ~2940 行）

**位置**：`cip()` 函数中，其他协议输出之后

**修改内容**：添加新协议的节点链接输出

```bash
# 新增代码块
if grep -q "anytls-sb" "$SINGBOX_FOLDER_PATH/sb.json"; then
    port_any=$(cat "$SINGBOX_FOLDER_PATH/port_any")
    any_sni=$(cat "$SINGBOX_FOLDER_PATH/any_sni")

    anytls_link="tls://${uuid}@${server_ip}:${port_any}?sni=${any_sni}#${sxname}anytls-$hostname"
    yellow "🔐【 AnyTLS 】(直连协议)"; 
    green "$anytls_link"
    append_jh "$anytls_link"
    echo;
fi
```

**关键点**：
- 从文件读取端口和 SNI
- 生成正确格式的节点链接
- 使用 `append_jh` 添加到聚合节点文件

---

## 11. 卸载清理（第 ~3429 行）

**位置**：`rep` 覆盖安装时的清理列表

**修改内容**：添加新协议相关文件到清理列表

```bash
# 原有代码
rm -rf "$SINGBOX_FOLDER_PATH"/{sb.json,sbargoym.log,sbargotoken.log,argo.log,argoport.log,name,short_id,cdn_host,hy_sni,vl_sni,tu_sni,vl_sni_pt,cdn_pt};

# 修改后
rm -rf "$SINGBOX_FOLDER_PATH"/{sb.json,sbargoym.log,sbargotoken.log,argo.log,argoport.log,name,short_id,cdn_host,hy_sni,vl_sni,tu_sni,any_sni,vl_sni_pt,cdn_pt};
```

---

## 修改顺序建议

为了避免遗漏，建议按以下顺序进行修改：

1. ✅ 环境变量定义（第 1、2 点）
2. ✅ 协议启用判断（第 3、4 点）
3. ✅ 端口冲突检测（第 5 点）
4. ✅ 版本号和菜单（第 6、7 点）
5. ✅ 协议配置生成（第 8 点）
6. ✅ 配置持久化（第 9 点）
7. ✅ 节点输出（第 10 点）
8. ✅ 卸载清理（第 11 点）

---

## 快速检查清单

添加完新协议后，使用以下命令验证：

```bash
# 1. 检查环境变量是否定义
grep "export.*anypt" sb00.sh

# 2. 检查协议启用判断
grep "anyp=yes" sb00.sh

# 3. 检查端口冲突检测
grep "anypt" sb00.sh | grep "vars="

# 4. 检查配置生成
grep "anytls-sb" sb00.sh

# 5. 检查节点输出
grep "anytls_link" sb00.sh

# 6. 检查卸载清理
grep "any_sni" sb00.sh | grep "rm -rf"
```

---

## 使用示例

添加完成后，用户可以这样使用新协议：

```bash
anypt=41007 \
any_sni="www.yahoo.com" \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb00.sh) rep
```


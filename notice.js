async function sendMessage(message, title, instanceId = null) {
  const token = "7126463574:AAHSLx2WwHJSa3gpujRj64JhpEpCqsJcUZs";
  const chatId = "453472010";
  const panelUrl = "https://komari.xx66.nyc.mn";

  if (!token || !chatId) return false;

  const url = `https://api.telegram.org/bot${token}/sendMessage`;

  // 构建交互按钮
  let inline_keyboard = [];
  let row1 = [{ text: "📊 进入面板", url: panelUrl }];

  // 仅单实例事件才显示
  if (instanceId) {
    row1.push({
      text: "🌐 实例详情",
      url: `${panelUrl}/instance/${instanceId}`
    });
  }

  inline_keyboard.push(row1);

  // Telegram 单条消息上限 4096 字符，预留余量避免贴边失败
  const MAX_LEN = 4000;
  const header = `<b>${title}</b>\n\n`;
  const fullText = `${header}${message}`;

  // 超长时按换行处拆分，尽量不切断行内 HTML 标签
  const splitChunks = (text, limit) => {
    const chunks = [];
    let rest = text;
    while (rest.length > limit) {
      let cut = rest.lastIndexOf('\n', limit);
      if (cut <= 0) cut = limit;
      chunks.push(rest.slice(0, cut));
      // 换行处拆分时丢弃该换行，避免下一条以空行开头
      rest = rest.slice(cut + (rest[cut] === '\n' ? 1 : 0));
    }
    if (rest) chunks.push(rest);
    return chunks;
  };

  let parts;
  if (fullText.length <= MAX_LEN) {
    parts = [fullText];
  } else {
    // 每条预留出标题 + 分条标记的长度
    parts = splitChunks(message, MAX_LEN - 128);
  }

  let ok = true;
  for (let i = 0; i < parts.length; i++) {
    const total = parts.length;
    let text;
    if (total === 1) {
      text = parts[0];
    } else if (i === 0) {
      text = `✂️ <b>第 1/${total} 条</b>\n\n${header}${parts[i]}`;
    } else {
      text = `✂️ <b>第 ${i + 1}/${total} 条</b>\n\n${parts[i]}`;
    }

    const body = {
      chat_id: chatId,
      text,
      parse_mode: 'HTML',
    };

    // 交互按钮只挂在最后一条上
    if (i === total - 1) {
      body.reply_markup = { inline_keyboard };
    }

    const resp = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (!resp.ok) ok = false;
  }

  return ok;
}

async function sendEvent(event) {
  try {

    // ⏰ 时间转换函数
    const getCSTTime = (timeStr) => {
      if (!timeStr || timeStr.startsWith('0001')) return "1-01-01 08:00:00";
      const date = new Date(timeStr.replace(/\.\d+Z$/, 'Z'));
      const cst = new Date(date.getTime() + 8 * 60 * 60 * 1000);
      const f = (n) => n.toString().padStart(2, '0');
      return `${cst.getUTCFullYear()}-${f(cst.getUTCMonth() + 1)}-${f(cst.getUTCDate())} ${f(cst.getUTCHours())}:${f(cst.getUTCMinutes())}:${f(cst.getUTCSeconds())}`;
    };

    // 📦 流量单位转换函数
    const formatTraffic = (bytes) => {
      if (!bytes || bytes === 0) return '无限制';
      const gb = bytes / (1024 ** 3);
      if (gb >= 1024) return `${(gb / 1024).toFixed(2)} TB`;
      return `${gb.toFixed(2)} GB`;
    };

    const eventMap = {
      Offline: { cn: '🔴 离线', icon: '🔴 🔴 🔴' },
      Online:  { cn: '🟢 上线', icon: '🟢 🟢 🟢' },
      Alert:   { cn: '⚠️ 告警', icon: '⚠️ ⚠️ ⚠️' },
      Renew:   { cn: '💰 续费', icon: '💰 💰 💰' },
      Expire:  { cn: '🚨 到期', icon: '🚨 🚨 🚨' },
      Test:    { cn: '🧪 测试', icon: '🧪 🧪 🧪' },

      // ✔️ 保留 Login / DReport（避免误判）
      Login:   { cn: '🔐 登录', icon: '🔐 🔐 🔐' },
      DReport: { cn: '📊 日报', icon: '📊 📊 📊' },
      WReport: { cn: '📊 周报', icon: '📊 📊 📊' },
      MReport: { cn: '📊 月报', icon: '📊 📊 📊' }
    };

    const ev = eventMap[event.event] || { cn: event.event, icon: 'ℹ️ ℹ️ ℹ️' };
    const title = `\u200B${ev.icon} 服务器${ev.cn} | Komari 通知`;

    let clientInfo = '';
    let targetInstanceId = null;

    const clients = Array.isArray(event.clients)
      ? event.clients
      : [];

    // ========================
    // ✔️ 单服务器情况
    // ========================
    if (clients.length === 1) {
      const c = clients[0];

      targetInstanceId = c.uuid || null;

      const region = c.region ? ` [${c.region}]` : '';
      const cpu = c.cpu_cores || 0;
      const disk = c.disk_total ? Math.round(c.disk_total / (1024 ** 3)) : 0;

      // 内存：< 1G 用 M 显示，>= 1G 用 G 显示
      const memBytes = c.mem_total || 0;
      const mem = memBytes >= (1024 ** 3)
        ? `${Math.round(memBytes / (1024 ** 3))}G`
        : `${Math.round(memBytes / (1024 ** 2))}M`;

      clientInfo += `🖥 <b>服务器</b>：${c.name}${region}\n`;
      clientInfo += `⚙️ <b>配置</b>：${cpu}C / ${mem} / ${disk}G\n`;

      if (event.event === 'Renew' || event.event === 'Expire') {
        clientInfo += `💳 <b>账单</b>：${c.currency || '$'}${c.price || '0'} (${c.billing_cycle || '0'}天/付)\n`;
      }
    }

    // ========================
    // ✔️ 多服务器情况（不绑定具体机器）
    // ========================
    else if (clients.length > 1) {
      const MAX_LIST = 10;
      clientInfo += `🖥 <b>涉及服务器</b>：${clients.length} 台\n`;
      clientInfo += `📌 <b>服务器列表</b>：\n`;
      clients.slice(0, MAX_LIST).forEach((c) => {
        clientInfo += `  • ${c.name}\n`;
      });
      if (clients.length > MAX_LIST) {
        clientInfo += `  … 还有 ${clients.length - MAX_LIST} 台未显示\n`;
      }
    }

    let message = clientInfo;

    message += `\n📡 <b>状态</b>：${ev.icon.split(' ')[0]} ${event.event} (${ev.cn})`;
    message += `\n⏰ <b>时间</b>：${getCSTTime(event.time)}`;

    if (event.message && event.message.trim()) {
      message += `\n\n💬 <b>详细信息</b>：\n${event.message}`;
    }

    // 发送通知，传入真正的 UUID 以生成正确的按钮链接
    return await sendMessage(message, title, targetInstanceId);

  } catch (error) {
    return await sendMessage(`脚本解析出错: ${error.message}`, '❌ Error');
  }
}

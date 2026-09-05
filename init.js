#!/usr/bin/env node

const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');
const http = require('http');
process.noDeprecation = true;
const { spawn, execSync } = require('child_process');

// 环境变量
const PORT = process.env.PORT || 3000;           // http 服务
const SUB_PATH = process.env.SUB_PATH || 'sub';  // 节点订阅token
const config = {
  UUID: process.env.UUID || '505bc7c0-8f2a-44f7-bdf4-8e37a8f2e896',  // 节点UUID，使用哪吒v1时在不不同的平台部署需要修改，否则agent会覆盖
  NEZHA_SERVER: process.env.NEZHA_SERVER || 'nz.xx66.nyc.mn',       // 哪吒面板地址，v1格式: nezha.xxx.com:8008  v0格式： nezha.xxx.com
  NEZHA_PORT: process.env.NEZHA_PORT || '443',           // 哪吒v1请留空，哪吒v0 agent端口
  NEZHA_KEY: process.env.NEZHA_KEY || 'AFAE06fB1ufDERA2q1',             // 哪吒v1的NZ_CLIENT_SECRET或哪吒v0-agent密钥
  ARGO_DOMAIN: process.env.ARGO_DOMAIN || 'fr-dishost.dora.cc.cd',         // argo固定隧道域名,留空即启用临时隧道
  ARGO_AUTH: process.env.ARGO_AUTH || 'eyJhIjoiODYxM2UxNGFjMzJjZmQ1ZGFjZDlkZWJlOTljNzlhOGQiLCJ0IjoiOTE1MTFiMDQtOWJhMi00MjFkLWJlNmYtYzg0ZTIyOTVjNzQzIiwicyI6IlpUQTBNelEzTTJFdE5UUm1OQzAwWVdJM0xUa3hZVFV0TmpJNFpHUTNZVFJpTnpJNCJ9',             // argo固定隧道token或json,留空即启用临时隧道,json获取:https://json.zone.id
  ARGO_PORT: process.env.ARGO_PORT || '8001',         // argo隧道端口 使用固定隧道token,cloudflare后台设置的端口需和这里对应
  CFIP: process.env.CFIP || 'saas.sin.fan',           // 优选域名或优选ip
  CFPORT: process.env.CFPORT || '443',                // 优选域名或优选ip对应端口
  NAME: process.env.NAME || 'FR-dishost',                       // 节点备注
  S5_PORT: process.env.S5_PORT || '26414',                 // socks5端口,支持多端口玩具可填写，否则不动
  HY2_PORT: process.env.HY2_PORT || '26414',               // Hy2 端口，支持多端口玩具可填写，否则不动
  TUIC_PORT: process.env.TUIC_PORT || '',             // Tuic 端口，支持多端口玩具可填写，否则不动 
  ANYTLS_PORT: process.env.ANYTLS_PORT || '',         // AnyTLS 端口,支持多端口玩具可填写，否则不动
  REALITY_PORT: process.env.REALITY_PORT || '',       // Reality 端口,支持多端口玩具可填写，否则不动  
  ANYREALITY_PORT: process.env.ANYREALITY_PORT || '', // Any Reality 端口,支持多端口玩具可填写，否则不动
  CHAT_ID: process.env.CHAT_ID || '453472010',                 // TG chat_id，可在https://t.me/laowang_serv00_bot 获取
  BOT_TOKEN: process.env.BOT_TOKEN || '7126463574:AAHSLx2WwHJSa3gpujRj64JhpEpCqsJcUZs',             // TG bot_token, 使用自己的bot需要填写,使用上方的bot不用填写,不会给别人发送
  UPLOAD_URL: process.env.UPLOAD_URL || '',           // 节点上传地址，需部署merge-sub订阅器项目，例如：https://merge.xxx.com
  FILE_PATH: process.env.FILE_PATH || '.npm',         // sub.txt节点存放目录
  DISABLE_ARGO: process.env.DISABLE_ARGO || 'false',  // 是否禁用argo, true为禁用,false为不禁用,默认开启
  CLEAR_SECONDS: process.env.CLEAR_SECONDS || '45',   // 控制台日志自动清除时间(秒), 0表示不清除
};

function log(message, type = 'INFO') {
  const timestamp = new Date().toLocaleTimeString();
  console.log(`[${timestamp}] [${type}] ${message}`);
}

function getArchitecture() {
  const arch = os.arch();
  const platform = os.platform();
  
  log(`Platform: ${platform}, Arch: ${arch}`);
  
  if (platform === 'linux' || platform === 'darwin') {
    if (arch === 'x64' || arch === 'amd64') {
      return 'amd64';
    } else if (arch === 'arm64' || arch === 'aarch64') {
      return 'arm64';
    }
  }
  
  log('Unknown architecture, defaulting to amd64', 'WARN');
  return 'amd64';
}

function downloadFile(url, destPath) {
  return new Promise((resolve, reject) => {
    log(`Downloading: ${url}`);
    
    const file = fs.createWriteStream(destPath);
    
    https.get(url, (response) => {
      if (response.statusCode !== 200) {
        reject(new Error(`Download failed, status: ${response.statusCode}`));
        return;
      }
      
      response.pipe(file);
      
      file.on('finish', () => {
        file.close();
        resolve();
      });
      
    }).on('error', (err) => {
      fs.unlink(destPath, () => {});
      reject(err);
    });
  });
}

// HTTP
const server = http.createServer(async (req, res) => {
  try {
    if (req.url === '/') {
      const filePath = path.join(__dirname, 'index.html');
      if (fs.existsSync(filePath)) {
        const data = fs.readFileSync(filePath, 'utf8');
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(data);
      } else {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(`
          <html>
            <body>
              <h3>Server is Running</h3>
            </body>
          </html>
        `);
      }
    } else if (req.url === `/${SUB_PATH}`) {
      const subPath = path.join(config.FILE_PATH, 'sub.txt');
      if (fs.existsSync(subPath)) {
        const data = fs.readFileSync(subPath, 'utf8');
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(data);
      } else {
        res.writeHead(404);
        res.end('sub.txt not found yet.');
      }
    } else if (req.url === '/ps') {
      try {
        const output = execSync('ps aux', { encoding: 'utf8', maxBuffer: 1024 * 1024 });
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(output);
      } catch (err) {
        res.writeHead(500);
        res.end(`Error: ${err.message}`);
      }
    } else {
      res.writeHead(404);
      res.end('404 Not Found');
    }
  } catch (err) {
    res.writeHead(500);
    res.end('Internal Server Error');
  }
});
  
// 主函数
async function main() {
  log('Starting application...');
  
  let binaryPath = '';
  let binaryProcess = null;
  
  try {
    fs.mkdirSync(config.FILE_PATH, { recursive: true });
    const arch = getArchitecture();
    const downloadUrl = arch === 'amd64' 
      ? 'https://amd64.eooce.com/sbsh'
      : 'https://arm64.eooce.com/sbsh';
    
    binaryPath = path.join(process.cwd(), 'disbot');
    await downloadFile(downloadUrl, binaryPath);
    fs.chmodSync(binaryPath, 0o755);
    
    const env = {
      ...process.env,
      UUID: config.UUID,
      NEZHA_SERVER: config.NEZHA_SERVER,
      NEZHA_PORT: config.NEZHA_PORT,
      NEZHA_KEY: config.NEZHA_KEY,
      ARGO_DOMAIN: config.ARGO_DOMAIN,
      ARGO_AUTH: config.ARGO_AUTH,
      CFIP: config.CFIP,
      CFPORT: config.CFPORT,
      NAME: config.NAME,
      FILE_PATH: config.FILE_PATH,
      ARGO_PORT: config.ARGO_PORT,
      S5_PORT: config.S5_PORT,
      HY2_PORT: config.HY2_PORT,
      TUIC_PORT: config.TUIC_PORT,
      ANYTLS_PORT: config.ANYTLS_PORT,
      REALITY_PORT: config.REALITY_PORT,
      ANYREALITY_PORT: config.ANYREALITY_PORT,
      CHAT_ID: config.CHAT_ID,
      BOT_TOKEN: config.BOT_TOKEN,
      UPLOAD_URL: config.UPLOAD_URL,
      DISABLE_ARGO: config.DISABLE_ARGO
    };
    
    const END_MARK = 'Running done';
    let logOutput = '';
    let clearTimer = null;
    const clearSeconds = parseInt(config.CLEAR_SECONDS, 10) || 0;

    function clearScreen() {
      if (process.stdout.isTTY) {
        console.clear();
      } else {
        process.stdout.write('\x1b[2J\x1b[3J\x1b[H');
      }
    }

    function clearConsoleSoon() {
      if (clearTimer || clearSeconds <= 0) return;
      clearTimer = setTimeout(() => {
        clearScreen();
        process.stdout.write('Running done\n');
      }, clearSeconds * 1000);
    }

    function onMarker() {
      if (clearTimer || clearSeconds <= 0) return;
      log(`Logs will be cleared in ${clearSeconds} seconds,you can copy the above nodes`);
      clearConsoleSoon();
    }

    binaryProcess = spawn(binaryPath, [], {
      env: env,
      stdio: ['inherit', 'pipe', 'pipe']
    });

    function pipeOutput(data, stream) {
      logOutput = (logOutput + data.toString()).slice(-8192);
      stream.write(data);
      if (logOutput.includes(END_MARK)) onMarker();
    }

    binaryProcess.stdout.on('data', (data) => pipeOutput(data, process.stdout));
    binaryProcess.stderr.on('data', (data) => pipeOutput(data, process.stderr));
    
    binaryProcess.on('error', (err) => {
      log(`Process error: ${err.message}`, 'ERROR');
    });
    
    binaryProcess.on('exit', (code) => {
      if (!clearTimer && clearSeconds > 0) {
        log(`Logs will be cleared in ${clearSeconds} seconds,you can copy the above nodes`);
      }
      setTimeout(() => {
        if (fs.existsSync(binaryPath)) {
          fs.unlinkSync(binaryPath);
        }
      }, 1000);
      clearConsoleSoon();
    });
    
    log(`🌐 HTTP: http://localhost:${PORT}`);
    log(`📁 Sub: http://localhost:${PORT}/${SUB_PATH}`);
    
    process.on('SIGINT', () => {
      log('Shutting down...');
      if (binaryProcess) binaryProcess.kill();
      if (fs.existsSync(binaryPath)) fs.unlinkSync(binaryPath);
      process.exit(0);
    });
    
  } catch (error) {
    log(`Error: ${error.message}`, 'ERROR');
    if (fs.existsSync(binaryPath)) {
      fs.unlinkSync(binaryPath);
    }
    process.exit(1);
  }
}

server.listen(PORT, '0.0.0.0', () => {});

main();
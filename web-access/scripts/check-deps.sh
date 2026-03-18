#!/usr/bin/env bash
# 环境探测 - CDP Proxy v2
# 检测 Node.js 22+ 和 Chrome remote-debugging 状态

echo "=== web-access v2 环境探测 ==="
echo ""
echo "OS:       $(uname -s) $(uname -m)"

# Node.js
if command -v node &>/dev/null; then
  NODE_VER=$(node --version 2>/dev/null)
  NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_MAJOR" -ge 22 ] 2>/dev/null; then
    echo "node:     $NODE_VER ✓ (原生 WebSocket)"
  else
    echo "node:     $NODE_VER ⚠ (建议升级到 22+，当前版本需要 ws 模块)"
  fi
else
  echo "node:     missing ✗  → 需要安装 Node.js 22+"
fi

# Chrome remote-debugging 端口检测
echo ""
echo "--- Chrome 远程调试检测 ---"
CHROME_FOUND=0

# 检查 DevToolsActivePort 文件
case "$(uname -s)" in
  Darwin)
    DTAP="$HOME/Library/Application Support/Google/Chrome/DevToolsActivePort"
    ;;
  Linux)
    DTAP="$HOME/.config/google-chrome/DevToolsActivePort"
    ;;
  *)
    DTAP=""
    ;;
esac

if [ -n "$DTAP" ] && [ -f "$DTAP" ]; then
  DTAP_PORT=$(head -1 "$DTAP" 2>/dev/null)
  echo "DevToolsActivePort: 端口 $DTAP_PORT"
fi

# 扫描常用端口
for port in 9222 9229 9333; do
  if curl -s --connect-timeout 1 "http://127.0.0.1:$port/json/version" 2>/dev/null | grep -q "Browser"; then
    echo "chrome:   端口 $port ✓ (远程调试已开启)"
    CHROME_FOUND=1
    break
  fi
done

if [ "$CHROME_FOUND" -eq 0 ]; then
  echo "chrome:   远程调试未检测到 ⚠"
  echo ""
  echo "请用以下方式启动 Chrome 以启用远程调试："
  case "$(uname -s)" in
    Darwin)
      echo '  /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222'
      ;;
    Linux)
      echo '  google-chrome --remote-debugging-port=9222'
      ;;
    *)
      echo '  chrome.exe --remote-debugging-port=9222'
      ;;
  esac
  echo ""
  echo "或者关闭所有 Chrome 窗口后重新用上述命令启动。"
fi

# CDP Proxy 状态
echo ""
echo "--- CDP Proxy 状态 ---"
if curl -s --connect-timeout 1 "http://127.0.0.1:3456/health" 2>/dev/null | grep -q '"ok"'; then
  echo "proxy:    运行中 ✓ (端口 3456)"
else
  echo "proxy:    未运行（需要时自动启动）"
fi

#!/usr/bin/env bash
# 环境检查：Node.js、Chrome 调试端口、CDP Proxy

# Node.js
if command -v node &>/dev/null; then
  NODE_VER=$(node --version 2>/dev/null)
  NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_MAJOR" -ge 22 ] 2>/dev/null; then
    echo "node: ok ($NODE_VER)"
  else
    echo "node: warn ($NODE_VER, 建议升级到 22+)"
  fi
else
  echo "node: missing"
fi

# Chrome 调试端口
if curl -s --connect-timeout 1 "http://127.0.0.1:9222/json/version" 2>/dev/null | grep -q "Browser"; then
  echo "chrome: ok (port 9222)"
else
  echo "chrome: not connected — 请打开 chrome://inspect/#remote-debugging 并勾选 Allow remote debugging"
fi

# CDP Proxy
if curl -s --connect-timeout 1 "http://127.0.0.1:3456/health" 2>/dev/null | grep -q '"ok"'; then
  echo "proxy: running"
else
  echo "proxy: not running"
fi

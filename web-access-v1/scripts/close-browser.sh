#!/usr/bin/env bash
# 优雅关闭 agent-browser Chrome 实例（跨平台）
# 用法：bash close-browser.sh [PORT]  # 默认 9222

UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_utils.sh
source "$UTILS_DIR/_utils.sh"

CDP_PORT=${1:-9222}
if [ "$CDP_PORT" = "9222" ]; then
  PROFILE_DIR="$HOME/.claude/browser-profile"
else
  PROFILE_DIR="$HOME/.claude/browser-profile-${CDP_PORT}"
fi
SNAPSHOT_DIR="$HOME/.claude/browser-profile-snapshot"

# 1. CDP Browser.close —— 协议层关闭，跨平台，Chrome 自己正常退出
# 用 Python 发 WebSocket 帧，不依赖外部包
python3 - "${CDP_PORT}" <<'PYEOF' 2>/dev/null
import json, socket, base64, urllib.request, struct, sys

try:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 9222
    data = json.loads(urllib.request.urlopen(f'http://localhost:{port}/json/version', timeout=3).read())
    ws_url = data['webSocketDebuggerUrl']
    path = ws_url[len(f'ws://localhost:{port}'):]

    s = socket.socket()
    s.settimeout(5)
    s.connect(('localhost', port))
    key = base64.b64encode(b'claude-web-access!!').decode()
    s.send(f'GET {path} HTTP/1.1\r\nHost: localhost:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n'.encode())
    s.recv(4096)

    msg = json.dumps({"id": 1, "method": "Browser.close"}).encode()
    mask = bytes([0, 0, 0, 0])
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(msg))
    frame = bytes([0x81, 0x80 | len(msg)]) + mask + masked
    s.send(frame)
    s.close()
    print("Browser closed")
except Exception as e:
    print(f"CDP close failed: {e}", flush=True)
    exit(1)
PYEOF

# 2. 兜底：CDP 失败时按 OS 强制退出
if [ $? -ne 0 ]; then
  case "$(get_os)" in
    macos)
      OUR_PID=$(ps aux | grep "Google Chrome" | grep -- "--user-data-dir=${PROFILE_DIR}" | grep -v grep | awk '{print $2}' | head -1)
      [ -n "$OUR_PID" ] && kill_pid "$OUR_PID" && echo "Browser closed (osascript)"
      ;;
    linux)
      OUR_PID=$(ps aux | grep "google-chrome\|chromium" | grep -- "--user-data-dir=${PROFILE_DIR}" | grep -v grep | awk '{print $2}' | head -1)
      [ -n "$OUR_PID" ] && kill_pid "$OUR_PID" && echo "Browser closed (SIGTERM)"
      ;;
    windows)
      # wmic 已在 Windows 11+ 移除，改用 Get-CimInstance
      OUR_PID=$(powershell.exe -NoProfile -Command \
        "Get-CimInstance Win32_Process -Filter 'Name=\"chrome.exe\"' | Where-Object { \$_.CommandLine -match 'browser-profile' } | Select-Object -First 1 -ExpandProperty ProcessId" \
        2>/dev/null | tr -d '\r\n ')
      [ -n "$OUR_PID" ] && kill_pid "$OUR_PID" && echo "Browser closed (taskkill)"
      ;;
    *)
      echo "Unknown OS — please close the browser manually"
      ;;
  esac
fi

# 3. 关闭 9222 后自动更新 snapshot，供非 9222 端口克隆登录态
if [ "$CDP_PORT" = "9222" ] && [ -d "$PROFILE_DIR" ]; then
  mkdir -p "$SNAPSHOT_DIR"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude="SingletonLock" --exclude="SingletonCookie" --exclude="SingletonSocket" \
      --exclude="Default/Cache/" --exclude="Default/Code Cache/" --exclude="Default/GPUCache/" \
      --exclude="Default/Service Worker/CacheStorage/" \
      --exclude="ShaderCache/" --exclude="GrShaderCache/" --exclude="*.lock" \
      "$PROFILE_DIR/" "$SNAPSHOT_DIR/" 2>/dev/null
    echo "Profile snapshot updated"
  elif [ "$(get_os)" = "windows" ]; then
    # Git Bash 默认无 rsync，改用 robocopy（Windows 内置）
    PROFILE_WIN=$(cygpath -w "$PROFILE_DIR" 2>/dev/null || echo "$PROFILE_DIR")
    SNAPSHOT_WIN=$(cygpath -w "$SNAPSHOT_DIR" 2>/dev/null || echo "$SNAPSHOT_DIR")
    powershell.exe -NoProfile -Command \
      "robocopy '$PROFILE_WIN' '$SNAPSHOT_WIN' /MIR /XD Cache 'Code Cache' GPUCache ShaderCache GrShaderCache /XF '*.lock' SingletonLock SingletonCookie SingletonSocket | Out-Null" 2>/dev/null
    echo "Profile snapshot updated (robocopy)"
  fi
fi

# 4. 清理 agent-browser session daemon（如果存在）
SESSION_PID=$(cat "$HOME/.agent-browser/port-${CDP_PORT}.pid" 2>/dev/null)
if [ -n "$SESSION_PID" ] && kill -0 "$SESSION_PID" 2>/dev/null; then
  kill "$SESSION_PID" 2>/dev/null
fi
rm -f "$HOME/.agent-browser/port-${CDP_PORT}.pid" \
      "$HOME/.agent-browser/port-${CDP_PORT}.sock"

#!/usr/bin/env bash
# Chrome CDP 生命周期管理（始终 headed 模式）
# 用法：bash ensure-browser.sh [PORT]
# PORT 由主 agent 分配（默认 9222；并行时传入 9223、9224 等）

UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_utils.sh
source "$UTILS_DIR/_utils.sh"

CHROME=$(find_chrome)
if [ -z "$CHROME" ]; then
  echo "ERROR: Chrome not found. Please install Google Chrome." >&2
  exit 1
fi

CDP_PORT=${1:-9222}
SNAPSHOT_DIR="$HOME/.claude/browser-profile-snapshot"
OS=$(get_os)

# Profile 路径（9222 保持历史路径兼容）
if [ "$CDP_PORT" = "9222" ]; then
  PROFILE_DIR="$HOME/.claude/browser-profile"
else
  PROFILE_DIR="$HOME/.claude/browser-profile-${CDP_PORT}"
fi

# Windows 下 Chrome 需要 Windows 风格路径
if [ "$OS" = "windows" ]; then
  PROFILE_DIR_CHROME=$(cygpath -w "$PROFILE_DIR")
else
  PROFILE_DIR_CHROME="$PROFILE_DIR"
fi

# 检测 CDP 端口是否已就绪
check_ready() {
  curl -s "http://localhost:${CDP_PORT}/json/version" >/dev/null 2>&1
}

# 检测当前运行的 Chrome 是否使用了正确的 profile
check_profile() {
  if [ "$OS" = "windows" ]; then
    local profile_pattern
    if [ "$CDP_PORT" = "9222" ]; then
      # 9222 的目录名是 browser-profile（无后缀），用 [^-] 避免误匹配 browser-profile-9223 等
      profile_pattern="browser-profile[^-]"
    else
      profile_pattern="browser-profile-${CDP_PORT}"
    fi
    wmic process where "name='chrome.exe'" get commandline 2>/dev/null \
      | grep -qE "$profile_pattern" 2>/dev/null
  else
    ps aux | grep -E "Google Chrome|google-chrome|chromium" \
      | grep -- "--user-data-dir=${PROFILE_DIR}" \
      | grep -v grep >/dev/null 2>&1
  fi
}

if check_ready; then
  if check_profile; then
    AGENT_BROWSER_SESSION="port-${CDP_PORT}" agent-browser connect "${CDP_PORT}" >/dev/null 2>&1 || true
    echo "Browser ready on port ${CDP_PORT}"
    exit 0
  else
    echo "ERROR: Port ${CDP_PORT} is in use by another process." >&2
    exit 1
  fi
fi

# 非主端口：每次从 snapshot 克隆最新登录态（覆盖已有 profile）
if [ "$CDP_PORT" != "9222" ]; then
  if [ -d "$SNAPSHOT_DIR" ]; then
    mkdir -p "$PROFILE_DIR"
    rsync -a --delete \
      --exclude="SingletonLock" --exclude="SingletonCookie" --exclude="SingletonSocket" \
      --exclude="Default/Cache/" --exclude="Default/Code Cache/" --exclude="Default/GPUCache/" \
      --exclude="Default/Service Worker/CacheStorage/" \
      --exclude="ShaderCache/" --exclude="GrShaderCache/" --exclude="*.lock" \
      "$SNAPSHOT_DIR/" "$PROFILE_DIR/" 2>/dev/null
    echo "Profile cloned from snapshot" >&2
  else
    # 全新环境，用空 profile 启动
    mkdir -p "$PROFILE_DIR"
    echo "INFO: No snapshot available, starting with fresh profile" >&2
  fi
fi

# 如果有我们自己的 Chrome 残留（有 profile 但没监听端口），清理掉
if [ "$OS" = "windows" ]; then
  OUR_PID=$(wmic process where "name='chrome.exe'" get commandline,processid 2>/dev/null \
    | grep "browser-profile" | grep -oE '[0-9]+$' | head -1 | tr -d ' \r\n')
else
  OUR_PID=$(ps aux | grep -E "Google Chrome|google-chrome|chromium" \
    | grep -- "--user-data-dir=${PROFILE_DIR}" \
    | grep -v grep | awk '{print $2}' | head -1)
fi

if [ -n "$OUR_PID" ]; then
  kill_pid "$OUR_PID"
  sleep 1
fi

# 启动 Chrome（后台，始终 headed）
"$CHROME" \
  "--remote-debugging-port=${CDP_PORT}" \
  "--user-data-dir=${PROFILE_DIR_CHROME}" \
  "--no-first-run" \
  "--no-default-browser-check" \
  "--exclude-switches=enable-automation" \
  "--disable-infobars" \
  >/dev/null 2>&1 &

# 等待 CDP 就绪（最多 15 秒）
for i in $(seq 1 30); do
  if check_ready; then
    AGENT_BROWSER_SESSION="port-${CDP_PORT}" agent-browser connect "${CDP_PORT}" >/dev/null 2>&1 || true
    echo "Browser ready on port ${CDP_PORT}"
    exit 0
  fi
  sleep 0.5
done

echo "ERROR: Browser failed to start within 15 seconds" >&2
exit 1

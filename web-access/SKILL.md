---
name: web-access
version: 1.0.0
author: 一泽Eze
license: MIT
github: https://github.com/eze-is-1/eze-skills
description: |
  所有联网操作必须通过此 skill 处理，包括：搜索、网页抓取、登录后操作、动态页面交互等。
  触发场景：用户要求搜索信息、查看网页内容、访问需要登录的网站、操作网页界面、抓取社交媒体内容（小红书、微博、推特等）、读取动态渲染页面、以及任何需要真实浏览器环境的网络任务。
---

# web-access Skill

## 首次安装

用户首次使用时，执行以下流程：

**Step 1：运行环境探测**
```bash
bash ~/.claude/skills/web-access/scripts/check-deps.sh
```

**Step 2：AI 根据输出处理缺失依赖**

探测脚本只报告事实，安装决策由 AI 完成。缺什么装什么，Chrome 缺失时提示用户手动下载（无法自动安装）。

**Step 3：安装完成后，向用户说明以下内容**

> web-access 已就绪。凡是联网的需求直接说就行，我会自动选最合适的方式：
> - 只需要搜索结果 → 直接搜，最快
> - 需要看完整页面 → 抓取页面内容，不启动浏览器
> - 需要登录或动态页面 → 自动启动浏览器，登录一次后持久保存
>
> Windows 用户需要 Git Bash 环境（安装 Git for Windows 即可）。

## 核心理念

网页信息通过多种通道存在：搜索摘要、静态文字、动态渲染内容、图片承载的内容。**每种通道的获取代价不同，信息覆盖范围不同。** 目标始终是：以最低代价获取完整的相关信息。

这意味着不要用重型工具做轻量任务，也不要用轻量工具面对它覆盖不到的内容——尤其是图片。

## 感知通道选择

**先评估任务，再选通道**——根据「目标信息的性质、什么工具能直接拿到」决定起点，选最轻且能直达的方案。

| 场景 | 通道 |
|------|------|
| 只需搜索摘要或关键词结果，或需要发现信息来源 | **WebSearch** |
| URL 已知，静态公开页面 | **WebFetch** |
| 需要动态内容、登录态、交互操作，或需要像人一样在浏览器内自由导航探索 | **浏览器 CDP** |

浏览器 CDP 不要求 URL 已知——可从任意入口出发，通过页面内搜索、点击、跳转等方式找到目标内容。

WebFetch 请求时加 header `Accept: text/markdown, text/html`，支持该协议的网站直接返回 Markdown，省约 80% token。失败（空内容 / 403 / JS 渲染）时升级到浏览器层。

**降级禁止**：进入更重的通道后，不得回头用轻量工具完成同一目标——等同于重走已知不通的路。浏览器层遇到阻碍应在层内解决（如处理登录），而不是绕回。唯一例外：浏览器操作中衍生的新子目标，可重新选择通道。

进入浏览器层后，区分任务性质：

- **操作型**（导航、填表、点击）：用 accessibility tree 感知界面，无法识别时才截图辅助
- **内容型**（读帖子、看资讯、分析页面）：accessibility tree 读文字结构，同时判断图片是否承载核心信息——是则提取图片 URL 定向读取

**图片判断**：社交媒体、图文博客、截图类内容，默认图片有价值，主动去取；工具类、导航类页面，默认 accessibility tree 够用。

## 浏览器 CDP 模式

### 启动

```bash
bash ~/.claude/skills/web-access/scripts/ensure-browser.sh
```

- `already running` → 直接用（任务结束后不关闭）
- `Browser ready on port 9222` → 就绪（任务结束后关闭）
- `ERROR` 或 agent-browser 无响应 → 执行 `bash ~/.claude/skills/web-access/scripts/close-browser.sh` 后重新运行

> **⚠️ 严禁降级**：只用 agent-browser CDP 模式，不切换到 playwright MCP 或其他浏览器工具。降级会丢失持久化登录态，且绕过 headed 反爬机制。

### 常用命令

```bash
agent-browser --cdp 9222 open <url>           # 打开页面
agent-browser --cdp 9222 snapshot -i          # 可交互元素（操作用）
agent-browser --cdp 9222 snapshot             # 完整无障碍树（读文字用）
agent-browser --cdp 9222 click @ref-123       # 点击元素
agent-browser --cdp 9222 fill @ref-123 "内容" # 填写输入框
agent-browser --cdp 9222 wait load networkidle
agent-browser --cdp 9222 scroll down 3000     # 触发懒加载
agent-browser --cdp 9222 screenshot /tmp/x.png
agent-browser --cdp 9222 eval "<js>"          # 执行 JS，用于提取 DOM 信息
```

### 图片提取

判断内容在图片里时，用 `eval` 从 DOM 直接拿图片 URL，再定向打开截图读取——比全页截图精准得多。

需要知道的两个技术细节：
- **懒加载**：未进入视口的图片 `naturalWidth` 为 0，eval 前先 scroll 到底才能拿到完整列表
- **过滤噪声**：`naturalWidth > 200` 排除图标和头像，留下内容图

```bash
agent-browser --cdp 9222 scroll down 3000
agent-browser --cdp 9222 eval "JSON.stringify(Array.from(document.querySelectorAll('img')).map((img,i)=>({i,src:img.src,w:img.naturalWidth,h:img.naturalHeight})).filter(x=>x.w>200))"
# 对每张目标图片：
agent-browser --cdp 9222 open <img_url>
agent-browser --cdp 9222 screenshot /tmp/img_n.png
# 用 Read tool 读取截图内容
```

### 登录判断

登录判断的核心问题只有一个：**目标内容拿到了吗？**

打开页面后，先尝试获取目标内容，持续执行。在此过程中，结合两方面信息做判断：

1. **领域知识**：对该网站的了解——X/Twitter 的最新时间线、小红书的私密内容、微博的完整评论等，这类内容通常需要登录才能获取完整数据
2. **页面实际反馈**：内容是否符合预期？是降级版（如热门帖代替最新帖）？是否有明显缺失？

即使页面显示了登录提示，只要目标内容已经拿到，就不需要打扰用户登录。

只有当确认**目标内容无法获取**时，才推断：登录是否能解决这个问题？若推断成立，告知用户：
> "当前页面在未登录状态下无法获取[具体内容]，请在已打开的 Chrome 窗口中登录 [网站名]，完成后告诉我继续。"

登录完成后无需重启浏览器，直接继续原任务。

### 任务结束

ensure-browser.sh 返回 `Browser ready`（本次启动）→ 关闭浏览器（**必须用此脚本，勿直接 kill，否则会留下崩溃窗口**）：
```bash
bash ~/.claude/skills/web-access/scripts/close-browser.sh
```

## References 索引

| 文件 | 何时加载 |
|------|---------|
| `references/commands.md` | 需要不常用命令时（drag、storage、pdf 等） |
| `references/login-flow.md` | 需要了解登录流程细节时 |

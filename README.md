# eze-skills

一泽Eze 的 Claude Code Skills 公开合集。

把日常高频用到的能力封装成 skill，让 Claude Code 开箱即用。

---

## Skills

| Skill | 简介 | 触发方式 |
|-------|------|---------|
| [daily-news](./daily-news) | 每日资讯日报生成器 | `/daily-news` |
| [web-access](./web-access) | 让 Claude Code 真正能上网 | 自动触发 |

---

## daily-news

三阶段工作流：获取元数据 → 生成摘要 → 输出日报。支持自定义信源，适合需要每日信息聚合的场景。

## web-access

Claude Code 原生有联网能力，但降级策略不完善，也不支持持久化登录。web-access 在原有基础上补全了整个联网操作链路，并以"**像人一样浏览**"为核心理念：带着目标进入，边看边判断，遇到阻碍在层内解决，不打扰用户。

遇到联网任务时自动按代价从低到高选择方式：

1. **WebSearch** — 只需搜索结果，最轻量
2. **Jina**（默认）— 通过 [Jina Reader](https://jina.ai/reader) 渲染页面并提取正文，支持 JS 渲染和 PDF，token 消耗低；需要原始结构化数据时改用 **WebFetch**
3. **agent-browser CDP 模式** — 非公开内容、已知反爬平台（小红书、微信公众号等）或需要交互时直接进入此层

引入 [agent-browser](https://www.npmjs.com/package/agent-browser) 的原因：accessibility tree 快照比截图节省约 10x token，独立 Chrome profile 实现登录态持久化，不影响用户自己的浏览器。

**v1.3.0 更新：**
- Windows 兼容性：`close-browser.sh` 兜底从 `wmic`（Windows 11+ 已移除）改为 `Get-CimInstance`；`rsync` 检测，Windows 降级为内置 `robocopy`
- 子 Agent 分治规范：新增 Prompt 写法指引——主 Agent 给目标，不预填未验证的 URL/账号名，让子 Agent 自主搜索验证官方来源
- `ensure-browser.sh` 支持自定义端口参数，多实例并发时 profile 完全隔离

---

## Installation

```bash
git clone https://github.com/eze-is/eze-skills.git

# 复制需要的 skill 到 Claude Code 目录
cp -R eze-skills/daily-news ~/.claude/skills/
cp -R eze-skills/web-access ~/.claude/skills/
```

web-access 首次使用需检查依赖：

```bash
bash ~/.claude/skills/web-access/scripts/check-deps.sh
```

---

This repository is synced from [eze-skills-private](https://github.com/eze-is/eze-skills-private).

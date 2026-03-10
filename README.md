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
2. **WebFetch** — 读取静态公开页面，不启动浏览器
3. **agent-browser CDP 模式** — 社交媒体/动态内容/登录态场景直接进入此层

引入 [agent-browser](https://www.npmjs.com/package/agent-browser) 的原因：accessibility tree 快照比截图节省约 10x token，独立 Chrome profile 实现登录态持久化，不影响用户自己的浏览器。

**v1.1.0 新增能力：**
- 社交媒体（小红书、微博、X/Twitter 等）直走 CDP，跳过 WebFetch
- 视频内容采帧分析：seek 到任意时间点截图，离散采样视频内容
- 完善 already-running 状态验证流程

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

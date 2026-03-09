# eze-skills

My Claude Code Skills collection.

## Skills

| Skill | Description | Trigger |
|-------|-------------|---------|
| [daily-news](./daily-news) | 每日资讯日报生成器。三阶段工作流：获取元数据、生成摘要、输出日报 | `/daily-news` |
| [web-access](./web-access) | 让 Claude 真正能上网。自动判断用搜索、抓页面还是启动浏览器，登录态持久化 | 自动触发 |

## Installation

```bash
git clone https://github.com/eze-is/eze-skills.git

# Copy a skill to Claude Code directory
cp -R eze-skills/daily-news ~/.claude/skills/
cp -R eze-skills/web-access ~/.claude/skills/

# web-access 首次使用需运行依赖检查
bash ~/.claude/skills/web-access/scripts/setup.sh
```

## Development

This repository is synced from [eze-skills-private](https://github.com/eze-is/eze-skills-private).

```bash
# Sync from private repo
./sync.sh
```

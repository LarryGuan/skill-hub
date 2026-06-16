# 建新 skill — 引导流程

## 第一步：收集信息

依次问用户（未提供的才问，已提供的直接用）：

1. **skill 名字**：用小写字母+连字符，如 `my-workflow`
2. **一句话描述**：这个 skill 是干什么的？（填入 SKILL.md `description` 字段）
3. **触发场景**：用户在什么情况下会用它？说什么话会触发？
4. **放在哪个 package**：默认 `~/WorkData/my-skill/packages/`，确认或让用户指定

## 第二步：生成目录结构

```
<package>/skills/<skill-name>/
├── SKILL.md
└── references/        ← 仅当内容复杂时创建
```

## 第三步：生成 SKILL.md

模板：

```markdown
---
name: <skill-name>
description: <一句话描述>。当用户说"<触发词1>""<触发词2>"时使用。
---

# <skill-name>

## 用途
<描述这个 skill 解决什么问题>

## 使用方式
<核心操作步骤或引导逻辑>
```

**写作原则**：
- description 必须包含触发词，Claude 靠它判断何时加载
- 主文件保持轻量，复杂内容放 `references/` 按需加载
- 不写注释，不写"本文件作用"之类的废话

## 第四步：告知激活方式

创建完成后提示：

```
skill 已创建：<package>/skills/<skill-name>/SKILL.md

如果这个 package 已经 use 过，编辑后重启 Claude 即生效。
如果还没 use，运行：
  skill-hub use <package-name>
```

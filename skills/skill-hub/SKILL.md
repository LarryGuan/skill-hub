---
name: skill-hub
description: skill-hub 管理助手。查状态、装/卸技能包、建新 skill、管理 source。当你说"装 pm 技能""卸载 feat-x""查技能状态""建一个新 skill""添加技能源"时使用。
---

# skill-hub 管理助手

## 能做什么

| 意图 | 触发说法 |
|---|---|
| 查技能状态 | "查一下技能状态" / "现在装了哪些技能" |
| 装技能包 | "装 pm 技能" / "安装 feat-x" |
| 卸技能包 | "卸载 pm" / "移除 feat-x" |
| 建新 skill | "帮我建一个新 skill" / "新建 skill" |
| 建新 package | "新建一个技能包" / "建 package" |
| 管理 source | "添加 source" / "查看已注册的 source" |

---

## 查技能状态

执行以下命令并解读结果：

```bash
skill-hub list    # 列出所有 source 中的技能包
skill-hub check   # 软链健康审计（已纳管/外部源/失效）
```

---

## 装 / 卸技能包

```bash
skill-hub use <包名>            # 装到全局（默认）
skill-hub use <包名> -t project # 装到当前项目
skill-hub unuse <包名>          # 从全局卸载
```

---

## 管理 source

```bash
skill-hub source list           # 查看已注册的 source
skill-hub source add <路径>     # 注册新 source（本地路径）
skill-hub source remove <路径>  # 移除 source
```

---

## 建新 skill → 读 references/new-skill.md

## 建新 package → 读 references/new-package.md

## 命令速查 → 读 references/commands.md

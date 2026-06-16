# 建新 package — 引导流程

一个 package 是一组相关 skill 的集合，对应一个独立的目录。

## 第一步：收集信息

1. **package 名字**：小写字母+连字符，如 `writing` / `ops-tools`
2. **放在哪个 source**：默认 `~/WorkData/my-skill`，确认或让用户指定
3. **简短描述**：一句话（写入 README.md 首段，`skill-hub list` 会展示）

## 第二步：创建目录结构

```bash
mkdir -p <source>/packages/<package-name>/skills
```

并创建 README.md：

```markdown
# <package-name>

<一句话描述>
```

## 第三步：告知后续

```
package 已建好：<source>/packages/<package-name>/

下一步：
1. 在 skills/ 下创建你的第一个 skill（说"建新 skill"我来帮你）
2. 建好后运行：skill-hub use <package-name>
```

## 注意

- 如果 source 还没注册，需要先：`skill-hub source add <source路径>`
- package 里可以有多个 skill，统一用 `skill-hub use <package>` 一次性装入

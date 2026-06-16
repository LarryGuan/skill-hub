# PRD: publish.sh — skill-hub 技能发布与软链体检脚本

> feat 目录：feature/feature-2606151813-初始项目/
> 关联定稿设计：v2.0（2026-06-15 对话收敛）

## 一、背景与目标

### 1.1 背景
skill-hub 仓库按「项目」组织技能源（如 `pm/skills/*`，当前 18 个 pm-* 技能），定位为**技能纳管中心**。技能需以软链形式发布到：
- A 全局：`~/.claude/skills/`
- B 工程级：`<当前工作目录>/.claude/skills/`

现状痛点：
1. 手动 `ln -s` 易写错绝对路径、易产生失效软链；
2. A/B 侧软链与实体目录混存（实测全局 66 个软链多指向 `~/.newmax/skills/`），无法一眼看出哪些已被 skill-hub 纳管、哪些是外部源游离；
3. 多项目技能批量发布、同名覆盖无统一安全确认。

### 1.2 目标
单一 bash 脚本 `publish.sh`，覆盖三件事：
- **check**：软链来源审计——甄别 A/B 侧软链纳管状态（已纳管/外部源/失效），实体目录视为原生不过问。
- **list**：总览 skill-hub 内项目（含 README 描述）及项目下技能清单。
- **publish**：把指定项目的全部技能以**绝对路径软链**发布到 A 或 B，整项目全发，同名逐个确认。

**非目标**：不管理实体目录型 skill；不做远程同步；不依赖 fzf/gum。

## 二、目录结构与文件约定（对应模板「数据模型」）

### 2.1 skill-hub 工程结构
```
skill-hub/
├── publish.sh                       ← 本脚本（本次交付）
├── feature/feature-<ts>-初始项目/PRD.md
├── pm/                              ← 项目 #1
│   ├── README.md                    ← 首段=项目描述（本次补建）
│   └── skills/<技能名>/SKILL.md
└── <未来其他项目>/skills/...
```

### 2.2 三方关系
```
源仓库 skill-hub/<项目>/skills/*  ──publish(软链)──►  A. 全局 ~/.claude/skills/
                                                      B. 工程级 $PWD/.claude/skills/
                                                      ↑ check 只扫这两处
```

### 2.3 约定
- **技能名** = 目录名（不依赖 SKILL.md 的 name 字段）。
- **项目描述** = `<项目>/README.md` 首段；缺失标注「未提供」并提示。
- **软链形态**：目标处 `→ 绝对路径 skill-hub/<项目>/skills/<技能名>`，避免仓库移动失效。
- **工程根** = 脚本调用时的 `$PWD`（纯动态，无参数；发别的项目先 `cd`）。

## 三、CLI 接口规格（对应模板「API 变更」）

| 命令 | 行为 | 退出码 |
|---|---|---|
| `./publish.sh` | 无参 → 进交互菜单 | — |
| `./publish.sh check` | 体检 A + B | 0 / 2(有失效软链) |
| `./publish.sh list` | 列 skill-hub 项目 | 0 |
| `./publish.sh publish <项目> --target global` | 整项目全发到 A | 0 / 1(部分失败) |
| `./publish.sh publish <项目> --target project` | 整项目全发到 B($PWD) | 0 / 1 |

**check 分类逻辑**：实体目录→原生计数；软链→`realpath` 解析，落 skill-hub 根内=✅已纳管，落外=⚠️外部源，指向不存在=❌失效。

**输出示例（check）**：
```
[A] ~/.claude/skills/
  ✅ pm-init           → .../skill-hub/pm/skills/pm-init
  ⚠️ algorithmic-art   → ~/.newmax/skills/algorithmic-art   (外部源)
  ❌ dead-skill        → (失效)
  —  baoyu-comic        (原生目录, 共 22 个)
统计: 软链 已纳管3 / 外部源1 / 失效1 / 原生22
```

## 四、交互菜单流程（对应模板「展示页UI」，删除编辑页章节）

```
publish.sh 主菜单
 1) 软链体检 (check)
 2) 项目总览 (list)
 3) 发布技能 (publish)
 0) 退出
```

选 3 → 列项目(带描述)选一 → 选目标[1]全局/[2]工程级 → 展示将发布的全量技能清单 → y/n 确认 → 逐个建链(同名逐个提示) → 汇总成功/跳过/失败。

全程裸 bash `select`/`read`，不依赖外部 TUI 工具。

## 五、脚本模块结构（对应模板「涉及文件」）

| 模块(函数) | 职责 |
|---|---|
| `main` / 参数路由 | 解析子命令，分发或进菜单 |
| `resolve_hub_root` | 由 `$BASH_SOURCE` 定位 skill-hub 根 |
| `cmd_check` | 扫描 A/B，分类输出 + 统计 |
| `classify_link` | 单条目分类(原生/已纳管/外部源/失效) |
| `cmd_list` | 扫项目，读 README，列技能清单 |
| `cmd_publish` | 选项目/目标，建绝对路径软链，同名确认 |
| `menu_*` | 交互菜单封装 |
| `log/confirm` | 统一日志与 y/n 确认 |

## 六、执行计划

### Phase 1: 脚手架与体检
1. 建 `publish.sh` 骨架：参数路由、`resolve_hub_root`、日志/确认工具函数
2. 实现 `cmd_check` + `classify_link`，覆盖 A/B
3. 验证：全局侧能正确区分已纳管/外部源/失效/原生

### Phase 2: 总览
1. 实现 `cmd_list`：扫项目、读 README 首段、列技能(SKILL.md description 首行)
2. 为 `pm/` 补建 `README.md`
3. 验证：项目与技能清单正确

### Phase 3: 发布
1. 实现 `cmd_publish`：整项目全发、绝对路径软链、工程级缺目录提示创建
2. 同名逐个确认(明示软链/实体+文件数)
3. 交互菜单串联
4. 验证：发布到 A 与 B 均成功；同名确认生效；失败汇总正确

## 七、测试检查要点

### 功能测试
- [ ] check 正确分类全局侧软链为已纳管/外部源/失效
- [ ] check 对实体目录仅计数、不进审计清单
- [ ] list 列出 pm 项目及其 18 个技能，描述取自 README 首段
- [ ] publish pm --target global 在 ~/.claude/skills/ 生成全部软链，指向绝对路径
- [ ] publish pm --target project 在 $PWD/.claude/skills/ 生成软链
- [ ] 无参运行进入交互菜单，各菜单项可达

### 边界测试
- [ ] 项目无 README.md 时，list 标注「未提供」并提示
- [ ] B 侧 $PWD/.claude/skills/ 不存在时，check 提示跳过、publish 提示是否创建
- [ ] 同名目标为软链 → 提示后替换；为实体目录 → 明示文件数再确认
- [ ] 源技能目录缺失 / 目标父目录不可写 → 单条跳过，末尾汇总，不中断
- [ ] 失效软链(指向已删目录)被正确识别为 ❌

### 数据一致性
- [ ] 发布后的软链 realpath 确实落在 skill-hub 根下（被 check 识别为 ✅已纳管）
- [ ] 同一技能发布到 A 与 B 两处互不干扰
- [ ] 仓库移动后软链仍有效（因使用绝对路径）

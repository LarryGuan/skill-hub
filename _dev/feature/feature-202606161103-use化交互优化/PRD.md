# PRD: skill-hub V1 — 命令 use 化 + 交互傻瓜化 + install

> feat 目录：feature/feature-202606161103-use化交互优化/
> 前置：初始版见 feature/feature-2606151813-初始项目/PRD.md

## 一、背景与目标

### 1.1 背景
初始版(publish.sh)已实现 check/list/publish 三功能。使用中暴露：
1. `publish` 单向语义，无法覆盖后续"收编"场景，且与反向操作不对称；
2. CLI 参数式交互认知重——需记项目名、`--target`、`global|project`；
3. 无全局命令，每次 `./publish.sh` 或先 `cd`；
4. 同名冲突在发布过程中逐个打断，无前置预检。

### 1.2 目标
- **命令按"意图"重构**：`publish → use`；`collect` 占位(V2)；新增 `install`。
- **交互傻瓜化**：上下键选择、完整目标路径展示、同名预检。
- **全局命令**：`skill-hub install` 自举。
- **脚本改名**（建议，编码时最终确认）：`publish.sh → skill-hub.sh`，与全局命令一致。

**非目标**：`collect` 的实现(V2，单独 PRD)；远程同步。

## 二、命令体系（对应模板「数据模型」）

| 命令 | 意图 | 操作 | 状态 |
|---|---|---|---|
| check | 查归属 | 扫全局软链纳管状态 | 已有 |
| list | 看家底 | 列项目 + 技能 | 已有 |
| use | 拿去用 | skill-hub → 全局/项目，建软链(轻) | 改名自 publish |
| install | 装全局 | 自举软链 `skill-hub` | 新增 |
| collect | 收进来 | 外部 → skill-hub，搬实体(重) | V2 占位 |

命名原则：**按意图命名，不按方向命名**——避免 push/pull 式"我在哪"导致的方向晕。

## 三、CLI 接口（对应模板「API 变更」）

| 命令 | 行为 |
|---|---|
| `skill-hub` | 上下键主菜单 |
| `skill-hub check` / `list` | 同初始版 |
| `skill-hub use [项目] [-t global\|project]` | 无参 → 向导；带参 → 非交互 |
| `skill-hub install` | 自举 `~/.local/bin/skill-hub` + PATH 检测，幂等 |
| `skill-hub collect ...` | 提示"V2 暂未实现"，退出 0 |

## 四、交互菜单流程（对应模板「展示页 UI」）

`select_arrow`（上下键 + 回车 + ESC）复用于：主菜单 / use 选项目 / use 选目标。

**use 向导**：选项目 → 选目标(全局/当前项目) → 展示完整目标绝对路径 → 同名预检报告 → 确认 → 发布(同名逐个 y/N) → 汇总。

**非 TTY 环境**（管道/重定向）：`select_arrow` 降级为编号输入，保证可脚本化。

## 五、脚本模块结构（对应模板「涉及文件」）

| 模块 | 职责 |
|---|---|
| `select_arrow` | 上下键菜单内核（read -rsn + ANSI 重绘 + 非 TTY 降级） |
| `main_menu` | 改用 `select_arrow`；加 install、collect(占位) 项 |
| `cmd_use` | 原 `cmd_publish` 改名 + 向导化 + 预检 |
| `scan_conflicts` | 选定项目+目标后扫目标，出 新增/冲突 报告 |
| `cmd_install` | 自举全局软链 + PATH 检测 + 幂等 |
| `cmd_check` / `cmd_list` | 措辞对齐（小） |

## 六、执行计划

### Phase 1: select_arrow + 主菜单
1. 实现 `select_arrow`（上下键移动 / 回车确认 / ESC 返回 / 非 TTY 降级为编号）
2. `main_menu` 改用之；新增 install、collect(占位) 菜单项

### Phase 2: use 改名 + 向导
1. `publish.sh → skill-hub.sh`；`cmd_publish → cmd_use`；CLI/菜单/帮助文案同步
2. use 向导：`select_arrow` 选项目/目标 + 完整目标路径展示
3. `scan_conflicts` 同名预检 + 报告

### Phase 3: install
1. `cmd_install`：自举 `~/.local/bin/skill-hub` + PATH 检测 + 幂等

### Phase 4: 验证
1. `bash -n` 语法；隔离目录真跑 use 向导；install 自举（隔离 PATH 验证）；同名预检验证

## 七、测试检查要点

### 功能测试
- [ ] 上下键可在主菜单 / use 向导移动选择，回车确认、ESC 返回
- [ ] `skill-hub use` 无参进向导；`skill-hub use pm -t global` 非交互可用
- [ ] use 向导选定后展示完整目标绝对路径
- [ ] 同名预检输出 新增 N / 冲突 M（列出，含类型与条目数）
- [ ] install 建 `~/.local/bin/skill-hub`，之后任意 cwd 可敲 `skill-hub`
- [ ] install 幂等（重复运行不报错）

### 边界测试
- [ ] install 时 `~/.local/bin` 不存在 → 创建；不在 PATH → 提示 export 语句
- [ ] use 向导目标目录不存在(project) → 提示创建
- [ ] `collect` 命令提示"V2 暂未实现"而非报错
- [ ] 非 TTY 环境 `select_arrow` 降级为编号输入

### 数据一致性
- [ ] use 建的软链仍被 check 识别为 ✅已纳管
- [ ] install 的全局软链在任何 cwd 调用都正确定位 HUB_ROOT
- [ ] 改名后无 publish 残留（代码 / 帮助 / PRD 一致）

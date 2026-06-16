# skill-hub 命令速查

## 常用

```bash
skill-hub list                          # 列出所有技能包
skill-hub check                         # 软链健康审计
skill-hub use <包>                      # 装到全局（默认）
skill-hub use <包> -t project           # 装到当前项目
skill-hub unuse <包>                    # 从全局卸载
```

## Source 管理

```bash
skill-hub source list                   # 查看已注册的 source
skill-hub source add ~/WorkData/my-skill   # 注册个人 source
skill-hub source add ~/team/team-skills    # 注册团队 source
skill-hub source remove <路径>          # 移除 source
```

## 工具自身

```bash
skill-hub install                       # 安装全局命令 + 伴随 skill
skill-hub help                          # 显示帮助
```

## Source 路径约定

| 类型 | 本地路径约定 |
|------|------------|
| 个人技能 | `~/WorkData/my-skill/` |
| 团队技能 | `~/WorkData/<team>-skill/`（clone 后注册）|
| 公共工具 | `~/WorkData/skill-hub/`（工具 repo 自身）|

## 典型工作流

```bash
# 新机器初始化
git clone git@github.com:LarryGuan/skill-hub ~/WorkData/skill-hub
~/WorkData/skill-hub/skill-hub.sh install
git clone git@github.com:LarryGuan/my-skill ~/WorkData/my-skill
skill-hub source add ~/WorkData/my-skill
skill-hub use pm
skill-hub use feat-x
```

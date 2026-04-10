# 跨机器开发工作流指南

> 背景：本项目在 Windows（日常编码 + Claude Code CLI）和 Mac（Xcode 编译调试）两台机器上协作开发。
> 本文记录实践过程中总结的最佳实践，供自己复盘或团队参考。

---

## 一、问题来源

本项目的开发分工如下：

- **Windows**：使用 Claude Code CLI 编写 Swift 代码、管理 git、与 AI 对话协作
- **Mac**：使用 Xcode 完成编译、Target 配置、Capability 添加、真机调试

两台机器频繁切换，产生三个核心问题：

1. **代码同步**：如何保证两台机器的代码始终是最新的？
2. **Xcode 配置**：Mac 上做的 Target / Capability 配置，下次 pull 后会不会丢失？
3. **AI 上下文**：与 Claude 的对话记录存在本地，换机器换会话后项目背景会丢失？

---

## 二、解决方案

### 2.1 代码同步 → 用 git，切换前务必 push

git 是唯一的同步媒介。**切换机器前必须将当前工作 push 到远端**，哪怕代码没写完。

```bash
# 离开当前机器前执行
git add -A
git commit -m "wip: 描述当前进度"
git push
```

到新机器后：

```bash
git pull
```

> ⚠️ 常见错误：没有 push 就切换机器，导致另一台机器拿不到最新代码，或两端同时有修改产生冲突。

---

### 2.2 Xcode 配置 → 配置完 commit project.pbxproj

Xcode 的所有项目配置（Target 定义、Build Phase、文件归属、Capability）都保存在：

```
swiftUI Practice.xcodeproj/project.pbxproj
```

以及对应的权限文件：

```
swiftUI Practice/swiftUI_Practice.entitlements
VocabWidget/VocabWidget.entitlements
```

**只要在 Mac 上配置完后 commit 这些文件，下次任意机器 pull 后配置即自动生效，无需重复操作。**

```bash
git add "swiftUI Practice.xcodeproj/project.pbxproj"
git add "swiftUI Practice/swiftUI_Practice.entitlements"
git add "VocabWidget/VocabWidget.entitlements"
git commit -m "chore: add Widget target and App Groups capability"
git push
```

#### 唯一需要每台 Mac 手动做一次的事

只有**签名**（Signing）：在 Xcode → Signing & Capabilities 中选择你的 Apple ID Team。这是开发者账号绑定，属于本机凭证，不应放入 git。开启 **Automatically manage signing** 后，Xcode 自动处理证书，只需登录一次 Apple ID。

---

### 2.3 AI 上下文 → 用 CLAUDE.md 作为"项目大脑"

Claude Code 的对话记忆（`~/.claude/`）存储在**本地机器**，不随 git 同步。换机器后新开会话，AI 不记得之前的对话内容。

解决方案：**把关键项目上下文写入 `CLAUDE.md`**，这个文件在 git 里，任何机器 pull 后 Claude 启动时都会自动读取。

`CLAUDE.md` 应包含：

- 项目整体架构说明
- 各模块的关键设计决策
- 重要文件及其职责
- 当前待完成的 Xcode 配置项
- 切换机器前的注意事项

每隔一段时间（或每个功能开发完成后），让 Claude 把最新进度更新进 `CLAUDE.md` 并 commit：

```
# 对话中告诉 Claude：
"帮我把当前的开发进度和待办事项更新到 CLAUDE.md"
```

---

## 三、完整的切换机器流程

### 离开当前机器（Windows 或 Mac）

```bash
# 1. 提交当前所有改动（包括未完成的代码）
git add -A
git commit -m "wip: 做到哪里了的简短描述"

# 2. 推送到远端
git push
```

### 到达新机器

```bash
# 1. 拉取最新代码
git pull

# 2. 启动 Claude Code（会自动读取 CLAUDE.md）
claude
```

然后直接告诉 Claude 继续做什么，无需重新解释项目背景。

---

## 四、CLAUDE.md 的分支策略

`CLAUDE.md` 和代码一样跟随 git 分支，不同分支内容可能不同。

**推荐做法：以 `main` 分支为准**，功能分支开发完合并进 `main` 时，`CLAUDE.md` 的更新内容也一并合并。避免在各功能分支单独维护，防止内容分叉和合并冲突。

---

## 五、各角色分工总结

| 工具 | 职责 |
|------|------|
| **git / GitHub** | 代码和配置文件的唯一同步媒介 |
| **project.pbxproj** | 持久化所有 Xcode 配置，随 git 同步 |
| **CLAUDE.md** | AI 的跨会话"记忆"，随 git 同步 |
| **~/.claude/ 本地记忆** | 补充性的 AI 记忆，仅限本机，不可跨机器依赖 |
| **Apple ID / 签名** | 本机一次性配置，不入 git |

---

## 六、快速检查清单

切换机器前：
- [ ] 当前改动已 `git add` + `git commit`
- [ ] 已 `git push` 到远端
- [ ] 如果做了 Xcode 配置，`project.pbxproj` 也已 commit

到达新机器后：
- [ ] `git pull` 拉取最新
- [ ] 启动 Claude Code，读取 CLAUDE.md 恢复上下文
- [ ] 如果是 Mac，检查 Xcode 签名是否正常

---

*文档创建于 2026-04-10，基于 iOS Quiz App 项目实际开发经验整理。*

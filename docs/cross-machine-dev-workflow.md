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

## 三、本项目当前需要在 Xcode 完成的配置（一次性）

> 以下配置在 Windows 端已完成代码编写，需要在 Mac 上用 Xcode 操作一次。
> **配置完成后务必 commit `project.pbxproj` 和 `.entitlements` 文件，之后所有机器 pull 即可，无需重复配置。**

### 3.1 注册 URL Scheme（Widget 点击跳转 App）

1. Xcode 左侧选择项目根节点 → 选中 **Lexora** target
2. 切换到 **Info** 标签页
3. 找到 **URL Types** 一栏，点击 `+`
4. 填写：
   - **Identifier**：`com.acspace.swiftUI-Practice`
   - **URL Schemes**：`quizapp`

作用：Widget 点击后通过 `quizapp://vocabulary` 唤起 App 并跳转到词汇 Tab。

---

### 3.2 为主 App 开启 App Groups

1. 选中 **Lexora** target → **Signing & Capabilities**
2. 点击左上角 `+ Capability`，选择 **App Groups**
3. 点击 `+` 添加：`group.com.acspace.swiftUI-Practice`

作用：让主 App 和 Widget Extension 共享同一个 `UserDefaults`，Widget 才能读取词汇学习数据。

---

### 3.3 创建 Widget Extension Target

1. 菜单栏 **File → New → Target**
2. 选择 **Widget Extension**，点击 Next
3. 填写：
   - **Product Name**：`VocabWidget`
   - **Include Configuration App Intent**：**不要勾选**
4. 点击 Finish，弹出提示选 **Activate**
5. Xcode 会自动生成一些模板文件（`VocabWidget.swift` 等），**全部删除**，因为我们已经写好了 `VocabWidget/VocabWidget.swift`

---

### 3.4 配置 VocabWidget Target

#### 开启 App Groups
1. 选中 **VocabWidget** target → **Signing & Capabilities**
2. 点击 `+ Capability` → **App Groups**
3. 添加：`group.com.acspace.swiftUI-Practice`（与主 App 相同）

#### 添加共享文件到 Target Membership
Widget Extension 需要用到主 App 里的两个文件，要在 File Inspector 里勾选它们属于 VocabWidget target：

| 文件 | 路径 |
|------|------|
| `Word.swift` | `swiftUI Practice/Models/Word.swift` |
| `VocabSharedHelper.swift` | `swiftUI Practice/Store/VocabSharedHelper.swift` |

操作方式：在 Xcode 左侧点击对应文件 → 右侧面板 **File Inspector** → **Target Membership** → 勾选 `VocabWidget`

> ⚠️ `VocabWidget.swift` 本身已在 `VocabWidget/` 文件夹内，Xcode 创建 target 时会自动归属，无需手动勾选。

---

### 3.5 把 WordBooks 文件夹加入 App Bundle

内置词库的 JSON 文件需要打包进 App，否则运行时无法读取：

1. 在 Xcode 左侧 Project Navigator 中，将 `WordBooks/` 文件夹拖入项目
2. 弹窗选项中选择 **"Create folder references"**（图标为蓝色文件夹，不是黄色 Group）
3. **Destination**：勾选 **Copy items if needed**
4. **Add to targets**：勾选 **Lexora**（主 App），VocabWidget 不需要
5. 拖入后，在 **Build Phases → Copy Bundle Resources** 里确认 11 个 JSON 文件都在列表中

---

### 3.6 配置完成后 commit（关键步骤）

```bash
git add "swiftUI Practice.xcodeproj/project.pbxproj"
git add "swiftUI Practice/swiftUI_Practice.entitlements"
git add "VocabWidget/VocabWidget.entitlements"
git commit -m "chore: configure VocabWidget target, App Groups, URL scheme, and bundle resources"
git push
```

**commit 之后，下次任意机器 pull，以上所有配置自动生效，无需重做。**

---

### 3.7 验证配置是否成功

| 验证项 | 方法 |
|--------|------|
| App Groups | 真机运行，词汇数据能正常保存和读取 |
| Widget 显示 | 在主屏幕长按 → 添加小组件 → 找到"词汇学习" |
| Widget 点击跳转 | 点击 Widget 能打开 App 并跳转到词汇 Tab |
| Siri 快捷指令 | Siri 说"添加生词 hello"能响应 |

---

## 四、完整的日常切换机器流程

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

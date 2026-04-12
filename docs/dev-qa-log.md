# Lexora 项目开发 Q&A 记录

> 记录开发过程中遇到的真实问题与解决方案，按主题分类，供日后复盘参考。

---

## 目录

1. [Xcode 配置](#一xcode-配置)
2. [编译错误](#二编译错误)
3. [真机调试](#三真机调试)
4. [Siri 与 App Intent](#四siri-与-app-intent)
5. [项目重命名](#五项目重命名)
6. [签名与 Provisioning](#六签名与-provisioning)
7. [App 图标](#七app-图标)
8. [工具使用技巧](#八工具使用技巧)
9. [多语言支持](#九多语言支持)

---

## 一、Xcode 配置

### Q1：把 WordBooks 文件夹加入 App Bundle 时，弹窗里的选项和文档说的不一样

**背景：** 文档说选"Create folder references"，但 Xcode 16 弹窗显示的是"Create folders"和"Reference files in place"，没有文档里说的那些选项。

**原因：** Xcode 16 重新设计了添加文件的弹窗，选项名称改变了，但含义相同：

| 旧版 Xcode（文档描述） | Xcode 16（实际显示） |
|---|---|
| Create folder references | **Create folders** |
| Copy items if needed | Reference files in place（已在项目目录内时用此项）|

**正确设置：**
- `Action`：Reference files in place（文件已在项目目录内）
- `Groups`：**Create folders**（等同于旧版 Create folder references，保留文件夹结构）
- `Targets`：勾选主 App，Widget 不需要

**经验：** Xcode 每个大版本都会调整 UI，遇到和文档不一样的地方，优先理解选项的实际含义，而不是死找一模一样的文字。

---

### Q2：改了项目名称后，Scheme 下拉里没有主 App 了，只剩 Widget

**背景：** 把项目从"swiftUI Practice"改名为"Lexora"后，顶部 Scheme 选择器里找不到 Lexora，只剩 VocabWidgetExtension。但 App 还是被成功安装到了 iPad 上。

**原因：** Xcode 重命名 Target 后，旧的 Scheme 会丢失，需要手动新建。App 能装上设备是因为 VocabWidgetExtension scheme 构建时会把主 App 一起打包（Widget 嵌入在主 App 内）。

**解决：**
1. Scheme 下拉 → **Manage Schemes...**
2. 点 `+` → Target 选 **Lexora** → 确认
3. 勾选 **Shared** 列
4. 关闭，选择 Lexora scheme 再 Build

**经验：** Scheme 和 Target 是两个独立概念。Target 定义"构建什么"，Scheme 定义"怎么构建/运行"。改名后 Target 还在，但 Scheme 可能丢失，需手动补建。

---

## 二、编译错误

### Q3：`Cannot convert return expression of type 'Binding<Subject>' to return type '[Word]'`

**报错文件：** `WordNotebookView.swift`

**表面现象：** 错误信息提示类型是 `Binding<Subject>`，看起来和 `Binding` 有关，但代码里没有任何 `$` 前缀或 Binding 用法。

**真实原因：** `WordNotebookView` 里的 `displayedWords` 计算属性引用了 `vocabStore.studiedWords`，但 `VocabularyStore` 里根本没有定义这个属性。Swift 编译器找不到成员时，有时会产生与实际问题无关的误导性错误信息。

**解决：** 在 `VocabularyStore.swift` 里补充缺失的计算属性：

```swift
var studiedWords: [Word] {
    let studiedIds = Set(wordRecords.map { $0.wordId })
    return allWords.filter { studiedIds.contains($0.id) }
}
```

**经验：** Swift 的编译错误有时是"级联错误"——真正的根因在别处，编译器报出的错误是次生的。遇到看起来莫名其妙的类型错误，先检查是否有引用了不存在的属性或方法。

---

## 三、真机调试

### Q4：词汇功能如何在真机上测试？

**完整流程：**

**第一步：选真机并 Build**
1. iPhone 用 USB 连接 Mac，或同一 Wi-Fi 下无线连接
2. Xcode 顶部 Scheme 旁的设备选择器切换到你的 iPhone/iPad
3. 首次连接需在手机点击"信任此电脑"
4. 确认 Scheme 是主 App（不是 Widget Extension）
5. `Cmd+R` 构建安装

> 首次真机运行会提示"未受信任的开发者"：**设置 → 通用 → VPN 与设备管理 → 找到 Apple ID → 信任**

**第二步：测试 Widget**
1. 主屏幕长按空白区域 → 点左上角 `+`
2. 搜索 App 名称，选择尺寸，添加小组件
3. 点击 Widget 验证能否跳转到 App

**第三步：测试 Siri**
1. 先把 App 在真机上跑一次（注册 App Intent）
2. 呼出 Siri，说指令即可

**常见坑：**
| 问题 | 解决 |
|------|------|
| Widget 装不上 | 确认 Scheme 是主 App，Widget 会一起打包 |
| Siri 不响应 | 先运行一次主 App 再测 |
| Widget 不更新 | 有 30 分钟缓存，正常现象 |

---

## 四、Siri 与 App Intent

### Q5：Siri 语言设置成英文，说中文指令没反应怎么办？

**原因：** `VocabAppShortcuts` 里的 `phrases` 数组全是中文字符串，Siri 只匹配当前语言对应的短语。

**解决：** 在 `phrases` 数组里同时加入英文短语，Siri 会自动匹配当前语言：

```swift
AppShortcut(
    intent: AddWordIntent(),
    phrases: [
        "添加生词 \(\.$word)",           // 中文 Siri
        "Add word \(\.$word) in \(.applicationName)",   // 英文 Siri
        "Save word \(\.$word) to my vocabulary",
        "Remember \(\.$word) in \(.applicationName)"
    ],
    shortTitle: "Add Word",
    systemImageName: "plus.circle"
)
```

**经验：** `AppShortcut` 的 `phrases` 支持多语言混合，Siri 会根据系统语言选择匹配的短语。带有 `\(.applicationName)` 的句子是必须的，Siri 靠它区分调用哪个 App。

---

## 五、项目重命名

### Q6：把 App 名从"swiftUI Practice"改为"Lexora"，需要改哪些地方？

改动分两类：

**代码文件（可直接编辑）：**

| 文件 | 改动内容 |
|------|----------|
| `swiftUI_PracticeApp.swift` | struct 名 → `LexoraApp` |
| `Quizapp.swift` | PDF 页脚 `"由 QuizApp 生成"` → `"由 Lexora 生成"` |
| `ExamContainerView.swift` | 同上，共 2 处 |
| `VocabSharedHelper.swift` | App Group ID → `group.com.acspace.Lexora` |
| 两个 `.entitlements` | App Group ID 同上 |
| `Info.plist` | URL Scheme identifier → `com.acspace.Lexora` |
| 测试文件 | `@testable import swiftUI_Practice` → `@testable import Lexora` |

**必须在 Xcode GUI 操作：**

| 操作 | 位置 |
|------|------|
| 项目 & Target 名 | Project Navigator → 点击名称重命名 |
| Bundle ID | Target → General → Bundle Identifier |
| Product Module Name | Target → Build Settings → 搜索 `Product Module Name` |
| App Group（两个 target）| Signing & Capabilities → App Groups |

**不需要改的：**
- `UserDefaults` 存储键（`quiz_banks_v2` 等）：这些是内部 key，与 App 名无关，改了会丢失用户数据

---

### Q7：项目文件夹名称还叫"swiftUI Practice"，要不要改成"Lexora"？

**结论：不建议改，收益极低，风险不小。**

- 文件夹名是开发内部路径，用户完全看不到，不影响 Bundle ID、App 名称、任何运行时行为
- 直接在 Finder 改名会导致 Xcode 找不到所有源文件（`project.pbxproj` 里的路径失效）
- 如果一定要改，必须在 Xcode Project Navigator 里操作（右键 → Rename），让 Xcode 同步更新磁盘路径和 pbxproj

**经验：** 区分"用户可见的名称"（App Name、Bundle ID）和"开发内部的标识"（文件夹名、模块名）。前者值得统一，后者改动成本高于收益时应保持现状。

---

## 六、签名与 Provisioning

### Q8：`Provisioning profile doesn't match the entitlements file's value for com.apple.security.application-groups`

**原因：** entitlements 文件里的 App Group ID 已改为新值（`group.com.acspace.Lexora`），但 Xcode 的 Provisioning Profile 还是用旧 App Group ID 生成的，两边不一致。

**解决：** 在 Xcode Signing & Capabilities 里重新设置 App Group：
1. 选对应 target → Signing & Capabilities → App Groups
2. 取消勾选/删除旧的 `group.com.acspace.swiftUI-Practice`
3. 点 `+` 添加 `group.com.acspace.Lexora`
4. Xcode 自动向 Apple 服务器注册并重新生成 Provisioning Profile
5. **两个 target（主 App + Widget）都要操作**

**经验：** entitlements 文件和 Provisioning Profile 必须严格对齐。只改文件不改 Profile，或只改 Profile 不改文件，都会报这个错。

---

### Q9：`Xcode failed to provision this target. Please file a bug report...`

**原因：** 通常是 Xcode 自动签名卡住，向 Apple 服务器注册新 App Group 时请求失败。

**解决方案（按优先级）：**

1. **刷新证书：** Xcode → Settings → Accounts → 选 Apple ID → 点 **"Download Manual Profiles"**
2. **清理缓存：** `Cmd+Shift+K` 清理构建，再删除 DerivedData：
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. **临时移除 App Groups：** 从 Widget target 的 Signing & Capabilities 中删掉 App Groups capability，让主 App 先能 Build，之后再重新添加

**经验：** 这类错误多数是 Xcode 本地缓存/状态问题，不是代码问题。优先用"刷新 + 清缓存"解决，而不是修改代码。

---

### Q10：`Embedded binary's bundle identifier is not prefixed with the parent app's bundle identifier`

**原因：** Widget Extension 的 Bundle ID 必须以主 App Bundle ID 为前缀，否则 iOS 拒绝嵌入。

**修复：** Widget target → General → Bundle Identifier 改为：
```
com.acspace.Lexora.VocabWidget
```

主 App 是 `com.acspace.Lexora`，Widget 加 `.VocabWidget` 后缀，体现父子关系。

**经验：** iOS 的 Extension（Widget、Share Extension、Notification Service 等）Bundle ID 必须是宿主 App Bundle ID 的子集，这是系统强制要求，不是可选项。

---

## 七、App 图标

### Q11：如何为 App 设计一个符合品牌的图标？

**Lexora 图标设计思路：**
- **含义：** Lex（词汇/lexicon）+ ora（光晕/aura，拉丁语"说"）
- **视觉：** 深紫渐变背景（与 App 内配色一致）+ 白色 L 字形（书脊+展开书页）+ 光线从 L 顶端向右上方放射

**快速实现方式：**

1. **AI 生成：** 使用 Midjourney / DALL-E，提示词：
   ```
   App icon for "Lexora", dark purple gradient background,
   stylized capital L shaped like an open book,
   light rays radiating from top-right, flat design, iOS style
   ```

2. **纯代码生成（SwiftUI）：** 创建 `LexoraIconView.swift`，用 `ImageRenderer` 导出 1024×1024 PNG，保存到相册后拖入 `Assets.xcassets`

**经验：** 开发阶段先用代码生成的占位图标，能让 App 跑起来、Widget 显示正常；正式图标等产品方向稳定后再找设计师或用专业工具打磨。

---

## 八、工具使用技巧

### Q12：如何在 Claude Code CLI 中分享截图？

三种方式：

| 方式 | 操作 |
|------|------|
| **粘贴截图（推荐）** | `Cmd+Shift+4` 截图时按住 `Ctrl`，截图进剪贴板，在输入框 `Cmd+V` 粘贴 |
| **文件路径** | 把图片拖到终端窗口获取路径，告诉 Claude 路径，用 Read 工具读取 |
| **终端命令** | 输入 `! ls ~/Desktop/*.png` 找到文件名再提供路径 |

**经验：** `Cmd+Shift+4` + 按住 `Ctrl` 是最快的截图→粘贴工作流，不需要保存文件再找路径。

---

### Q13：跨 Mac/Windows 开发时，Xcode 配置如何保持同步？

**核心原则：** Xcode 所有配置都保存在 `project.pbxproj` 和 `.entitlements` 文件中，只要把这些文件 commit 进 git，换机器 pull 后配置自动生效。

**唯一需要每台 Mac 手动做一次的事：** 在 Xcode → Signing & Capabilities 选择你的 Apple ID Team（签名是本机凭证，不入 git）。

**切换机器前必做：**
```bash
git add -A
git commit -m "wip: 当前进度描述"
git push
```

**经验：** 把"需要手动配置的事"降到最低是跨机器协作的关键。每次在 Xcode 完成配置后，立即 commit `project.pbxproj`，让 git 成为配置的唯一真相来源。

---

---

### Q14：feature 分支开发完成后，如何合并到 main？

有两种方式，各有适用场景：

**方式 A：本地合并再推送**

```bash
git checkout main
git pull origin1 main                      # 拉取最新 main
git merge feature/vocabulary-learning      # 本地合并
git push origin1 main                      # 推送到远端
```

适合：个人项目、小团队、对合并结果有把握时。

---

**方式 B：push 分支到 GitHub，创建 PR 在网页合并（推荐）**

```bash
# 分支已推过则跳过第一步
git push origin1 feature/vocabulary-learning
# 去 GitHub 网页 → Compare & pull request → 创建并合并 PR
git checkout main
git pull origin1 main                      # 合并后同步到本地
```

适合：想保留完整 PR 记录、需要 Code Review、多人协作。

**推荐使用方式 B 的原因：**
- 一直用 feature 分支开发，PR 是配套的最佳实践
- GitHub 保留合并记录，方便日后追溯功能是何时合入的
- 合并冲突在网页上处理比命令行更直观

**经验：** 个人项目也值得养成 PR 习惯。PR 记录本质上是一份"这个功能做了什么、为什么这样做"的文档，比 commit message 更完整。

---

---

## 九、多语言支持

### Q15：多语言支持的原理是什么？如何手动补充漏翻译的字符串？

#### 核心机制

SwiftUI 的 `Text("字符串")` 会自动把引号里的内容当作 **key**，去对应语言的 `Localizable.strings` 文件里查找翻译。找到就显示翻译，找不到就直接显示原始字符串（简体中文）。

```
Text("设置")
  └─ 当前语言是英文 → 去 en.lproj/Localizable.strings 找 "设置" 的值
  └─ 找到 "Settings" → 显示 "Settings"
  └─ 找不到        → 显示 "设置"（原文兜底）
```

#### 文件位置

```
swiftUI Practice/
  zh-Hant.lproj/
    Localizable.strings   ← 繁体中文翻译
  en.lproj/
    Localizable.strings   ← 英文翻译
```

#### 文件格式

```
"简体中文原文" = "翻译";
```

注意：**必须以分号结尾**，等号两边有空格，字符串用双引号。

---

#### 三种常见情况

**情况 1：普通字符串** — 直接加一行

```swift
// 代码
Text("导出备份")
```

```
// en.lproj/Localizable.strings
"导出备份" = "Export Backup";

// zh-Hant.lproj/Localizable.strings
"导出备份" = "匯出備份";
```

---

**情况 2：插值字符串**（含变量）— key 是带格式符的模板

```swift
// 代码
Text("共 \(count) 道题")
```

```
// en.lproj
"共 %lld 道题" = "%lld questions";

// zh-Hant.lproj
"共 %lld 道题" = "共 %lld 道題";
```

规则：`Int` → `%lld`，`String` → `%@`

---

**情况 3：条件/三目运算符返回的 String** — 不会自动本地化，需要显式包装

```swift
// ❌ 这种写法不会被翻译
Text(isEnabled ? "已开启" : "已关闭")

// ✅ 显式包装为 LocalizedStringKey
Text(LocalizedStringKey(isEnabled ? "已开启" : "已关闭"))
```

---

#### 操作流程

**第一步：找到漏翻译的字符串**

切换到英文模式运行 App，哪里还显示中文就是遗漏的。

**第二步：在两个文件末尾各加一行**

打开 `en.lproj/Localizable.strings`：
```
"原文" = "English translation";
```

打开 `zh-Hant.lproj/Localizable.strings`：
```
"原文" = "繁體翻譯";
```

**第三步：重新 Build**

不需要重启模拟器，`Cmd+R` 后直接生效。整个过程不需要改任何 Swift 代码。

---

#### 常见错误

| 错误写法 | 正确写法 |
|----------|----------|
| `"key" = "value"` （缺分号）| `"key" = "value";` |
| `key = "value";` （key 没引号）| `"key" = "value";` |
| 插值写 `"有 \(n) 道题"` 当 key | key 必须写 `"有 %lld 道题"` |

---

*文档创建于 2026-04-11，基于 Lexora（原 swiftUI Practice）项目开发过程整理。*
*持续更新：每遇到新问题解决后追加记录。*

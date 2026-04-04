# Flashcards - 卡片式语言学习APP

基于艾宾浩斯遗忘曲线的卡片式语言学习应用

## 快速开始

### 1. 环境准备

```bash
export PATH="$PATH:$HOME/software/flutter/bin"
flutter doctor
```

### 2. 安装依赖

```bash
cd /home/zhuojun/workspace/apps/flashcards
flutter pub get
```

### 3. 运行应用

**Android模拟器**
```bash
flutter run -d emulator-5554 -v # flutter devices先看看有什么设备
```

**Web浏览器**
```bash
flutter run -d chrome -v
```

> **注意：Web 开发时的 CORS 限制**
>
> 自动翻译和例句功能依赖第三方 API（MyMemory、Tatoeba）。移动端/桌面端没有问题，但浏览器会因同源策略（CORS）拦截对这些 API 的请求，导致例句获取失败。
>
> 开发调试时，使用以下命令禁用浏览器 CORS 检查：
> ```bash
> flutter run -d chrome --web-browser-flag "--disable-web-security"
> ```
>
> 生产环境 Web 部署需自建 CORS 代理（如 Cloudflare Worker）转发 Tatoeba 请求。移动端打包无需任何额外处理。

**VSCode**: 按F5选择设备

## 功能测试

### 1. 创建单词本
- 点击右下角"+"
- 输入名称"英语单词"
- 点击"创建"

### 2. 添加单词
- 点击单词本进入
- 点击右下角"+"
- 填写：单词(apple)、译文(苹果)、注释、标签(水果,食物)
- 点击"保存"

### 3. 记忆训练
- 点击单词本右侧大脑图标
- 点击卡片翻转查看背面
- 点击"记住了"或"再来一次"

### 4. 设置
- 主页右上角设置图标
- 修改主语言和默认复习数量

## 项目结构

```
lib/
├── main.dart
├── models/
│   ├── wordbook.dart
│   └── word.dart
├── services/
│   ├── database_service.dart
│   └── spaced_repetition.dart
└── screens/
    ├── home_screen.dart
    ├── wordbook_screen.dart
    ├── add_word_screen.dart
    ├── training_screen.dart
    └── settings_screen.dart
```

## 技术栈

- Flutter 3.x + Dart
- SQLite (sqflite)
- Material Design

## 开发调试

- 热重载: 按 `r`
- 完全重启: 按 `R`
- 查看日志: `flutter logs`


## prerequirment

1. 安装Android studio
   1. 设备管理安装模拟器
2. `flutter create .` # AndroidManifest.xml could not be found.
3. 安装Java `sudo apt install openjdk-17-jdk`
### AndroidManifest.xml could not be found.

```
flutter create .
```
```
sudo apt install openjdk-17-jdk
```

### run in linux

```
sudo apt install ninja-build clang cmake pkg-config libgtk-3-dev 
```

## iOS 真机测试（Linux 环境）

Linux 无法直接连接 iPhone，推荐以下方案：

### 整体流程

```
本地开发 (flutter run -d linux) → push 到 GitHub → Codemagic 云端构建 iOS → 下载 IPA → AltStore 安装到 iPhone
```

- **IPA**：iPhone Package Archive，苹果手机应用安装包，相当于安卓的 APK
- **Codemagic**：专为 Flutter 设计的云端 CI/CD 构建服务，拥有 Mac 服务器，可帮你在云端编译出 iOS 应用，免费额度 500 分钟/月

### 步骤

**1. 注册 Codemagic**
- 访问 [codemagic.io](https://codemagic.io)，用 GitHub 账号登录
- 连接你的 GitHub 仓库

**2. 配置 iOS 签名**
- 用 Apple ID 注册免费开发者账号（无需付费 $99/年）
- 在 Codemagic 填入 Apple ID 进行签名
- 注意：免费账号构建的 IPA 有效期 **7天**，到期需重装

**配置 APPLE_TEAM_ID（必须）**

iOS 应用必须经过苹果签名才能安装到真机，签名时需要 Team ID 来标识你的开发者账号身份。Codemagic 在云端构建时无法自动获取，需要你手动配置。

获取 Team ID：
1. 用 Apple ID 登录 [developer.apple.com](https://developer.apple.com)
2. 右上角点击名字 → Account
3. 页面中找到 **Team ID**，是一串 10 位字母数字（如 `ABC1234DEF`）

在 Codemagic 配置：
- 登录 Codemagic → 项目设置 → **Environment variables**
- 添加变量名 `APPLE_TEAM_ID`，值填入你的 Team ID

**3. 构建**
- push 代码后在 Codemagic 触发构建（约 10-15 分钟）
- 构建完成后下载 `.ipa` 文件

**4. 安装到 iPhone（AltStore）**
- 在 iPhone 上安装 [SideStore](https://sidestore.io)（无需连接电脑，更方便）
- 用 SideStore 打开 `.ipa` 文件完成安装
- 每隔 7 天需要通过 SideStore 刷新签名

IPA = iPhone Package Archive，苹果手机应用的安装包文件格式，相当于安卓的 APK。

Codemagic = 专门为 Flutter/移动端设计的云端 CI/CD构建服务，它有 Mac 服务器，可以帮你在云端编译出 iOS 应用。


### 注意事项

| 问题 | 说明 |
|------|------|
| 7天重签 | 免费账号每隔 7 天需重新安装 |
| 构建等待 | 每次改动需等 10-15 分钟才能看到效果 |
| 不适合调试 | 无法热重载，仅适合阶段性验收测试 |

**建议**：日常开发用 `flutter run -d linux`，功能完成后再用此方案做 iOS 真机验收。



## 安装到苹果手机

TestFlight 版本过期后，你不能直接“续期”同一个版本，而是需要**上传一个新的版本**。

这是由苹果的测试机制决定的：每个通过 TestFlight 分发的构建版本，其生命周期固定为 **90 天**。超过这个期限，应用就无法再被打开。

要让你自己（和其他测试者）在 90 天后继续使用，可以按照以下步骤操作：

---

### 🔄 解决方案：上传新版本并更新

核心流程就是**构建一个新的 `.ipa` 文件，上传到 App Store Connect，然后通过 TestFlight 更新**。

#### 第一步：在 Ubuntu 上准备新版本

1.  **修改版本号**：在 `pubspec.yaml` 中，更新 `version` 字段。苹果要求每个上传的构建版本必须有唯一的版本号。例如，从 `1.0.0+1` 改为 `1.0.1+2`。
2.  **提交代码**：将修改后的代码推送到你的 Git 仓库。

#### 第二步：构建并上传新版本

重复之前你完成过的流程，生成新的 `.ipa` 文件并上传。

1.  **云端构建**：使用 **Codemagic** 或 **GitHub Actions**，基于你最新的代码进行构建。
2.  **上传与签名**：使用 **Appuploader**，将新生成的 `.ipa` 文件上传到 App Store Connect。

#### 第三步：在 App Store Connect 中管理

1.  登录 [App Store Connect](https://appstoreconnect.apple.com)。
2.  进入你的应用页面，找到“TestFlight”标签页。
3.  在“构建版本”部分，你会看到新上传的版本。
4.  **将它添加到测试群组**（就是你之前添加自己的那个测试群组）。

#### 第四步：在 iPhone 上更新应用

1.  当新版本处理完成后，你的 iPhone 上会收到 TestFlight 的推送通知。
2.  打开 **TestFlight** 应用。
3.  找到你的应用，点击右侧的 **“Update”**（更新）按钮。
4.  更新完成后，新的 90 天计时器就开始了，你可以继续正常使用。

> **重要提醒**：在执行此操作前，请确保你已备份应用内的重要数据。根据一些应用的说明，应用在过期失效后，未同步的数据可能会丢失。

---

### 💎 总结：开发者的日常工作流

对于你这种没有 Mac、用云端构建的情况，这个“每 90 天更新一次”的过程，应该成为你应用的**常规维护工作流**。

你可以把它看作是应用的一种“心跳”：
*   **持续迭代**：每 90 天内至少修复一个 Bug 或增加一个小功能，发布新版本。
*   **保持活跃**：通过持续更新，确保自己和测试者能一直使用最新版本的应用。

这样不仅能解决过期问题，还能让你的应用不断完善。
90天到期后，这个App将无法再打开。数据不会自动删除：App的沙盒数据（数据库、文件、用户设置等）仍然保留在手机上，只是无法访问。
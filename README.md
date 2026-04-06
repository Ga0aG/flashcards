# Flashcards - 卡片式语言学习APP

基于艾宾浩斯遗忘曲线的卡片式语言学习应用

**生产地址：** https://flashcards-two-alpha.vercel.app

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

### 3. 本地开发

```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

> **注意：Web 开发时的 CORS 限制**
>
> 自动翻译和例句功能依赖第三方 API（MyMemory、Tatoeba）。开发调试时需要 `--disable-web-security` 跳过浏览器 CORS 检查。生产环境已通过 Vercel 部署，翻译 API 可正常使用。

## 部署到 Vercel

### 首次部署

```bash
# 1. 构建 Web 产物
flutter build web --release

# 2. 安装 Vercel CLI（如未安装）
npm i -g vercel

# 3. 部署
vercel
```

按提示操作：新建项目，输出目录保持默认（`vercel.json` 已配置为 `build/web`）。

### 后续更新

每次代码改动后：

```bash
flutter build web --release && vercel --prod
```

### 部署后配置（首次需要）

1. **Google Cloud Console** → OAuth 客户端 ID → 已获授权的 JavaScript 来源，加上 Vercel 域名：
   ```
   https://flashcards-two-alpha.vercel.app
   ```

2. **Firebase Console** → Authentication → 设置 → 已获授权的网域，加上：
   ```
   flashcards-two-alpha.vercel.app
   ```


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

- Flutter 3.x + Dart（Web）
- Firebase Firestore（云端数据同步）
- Firebase Authentication（Google 登录）
- Vercel（静态托管）
- Material Design 3

## 开发调试

- 热重载: 按 `r`
- 完全重启: 按 `R`
- 查看日志: `flutter logs`

## Firebase 云同步配置

### 1. 创建 Firebase 项目

1. 访问 [console.firebase.google.com](https://console.firebase.google.com)，用 Google 账号登录
2. 点击「新增专案」（或「Add project」），填写项目名称，完成创建
3. 进入项目控制台后，**左侧导航栏**（不是 Cloud Shell）找到以下入口：

### 2. 开启 Firestore 数据库

1. 左侧导航栏 → **构建（Build）** → **Firestore Database**（或者搜索产品）
2. 点击「建立资料库」（Create database）
3. 选择「以生产模式启动」（Start in production mode）
4. 选择数据库位置（亚洲用 `asia-east1` 或 `asia-northeast1`）
5. 创建完成后，点击左侧「规则（Rules）」标签页，将规则替换为：
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{uid}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == uid;
       }
     }
   }
   ```
   点击「发布（Publish）」保存规则

### 3. 开启 Google 登录

1. 左侧导航栏 → **构建（Build）** → **Authentication**
2. 点击「开始使用」（Get started）
3. 点击「Sign-in method」标签页 → 找到「Google」→ 点击启用（Enable）
4. 填写项目的公开名称（显示在 Google 登录弹窗上，如「Flashcards」）
5. 选择支持邮箱，点击「储存（Save）」

### 4. 安装 Firebase CLI 和 FlutterFire CLI

```bash
# 安装 Firebase CLI（需要 Node.js）
npm install -g firebase-tools

# 安装 FlutterFire CLI
dart pub global activate flutterfire_cli

# 确保 PATH 包含 pub global bin
export PATH="$PATH:$HOME/.pub-cache/bin"
```

### 5. 登录并配置项目

```bash
# 登录 Firebase（会打开浏览器）
firebase login

# 在项目根目录运行，自动生成各平台配置
cd /home/zhuojun/workspace/apps/flashcards
flutterfire configure --project=flashcards-b6e18
```

运行后会：
- 自动生成 `lib/firebase_options.dart`（各平台配置汇总）
- 自动生成 `android/app/google-services.json`
- 自动生成 `ios/Runner/GoogleService-Info.plist`

### 6. 安装依赖并运行

```bash
flutter pub get
flutter run -d chrome --web-browser-flag “--disable-web-security”
```

---

## prerequirment

1. 安装 Node.js（用于 Firebase CLI 和 Vercel CLI）
2. `dart pub global activate flutterfire_cli`
3. 安装Java `sudo apt install openjdk-17-jdk`（Flutter Web 构建需要）
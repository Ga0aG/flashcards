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
flutter run
```

**Web浏览器**
```bash
flutter run -d chrome
```

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

# Flashcards语言学习App技术方案

## 1. 项目概述

基于艾宾浩斯遗忘曲线的卡片式语言学习应用，支持iPhone平台。

**开发环境**: Linux系统
**技术栈**: Flutter (Dart)
**目标平台**: iOS (最终) / Android + Web (开发测试)

## 2. 技术选型

### 核心框架: Flutter

**选择理由**:
- 一次开发，多平台运行 (Android/iOS/Web)
- Linux环境完美支持Android和Web开发
- 代码无需修改即可在iOS上运行
- 热重载开发体验优秀

**技术组件**:
- 语言: Dart
- 数据库: sqflite (SQLite)
- 音频: audioplayers
- 手势: Dismissible (内置)
- 网络: http
- 状态管理: Provider

## 3. 项目结构

```
flashcards/
├── lib/
│   ├── main.dart                      # 应用入口
│   ├── models/                        # 数据模型
│   │   ├── wordbook.dart
│   │   ├── word.dart
│   │   └── settings.dart
│   ├── services/                      # 业务逻辑
│   │   ├── database_service.dart      # SQLite数据库
│   │   ├── translation_service.dart   # 翻译API
│   │   ├── pronunciation_service.dart # 发音
│   │   └── spaced_repetition.dart     # 间隔重复算法
│   ├── providers/                     # 状态管理
│   │   ├── wordbook_provider.dart
│   │   ├── settings_provider.dart
│   │   └── training_provider.dart
│   ├── screens/                       # 页面
│   │   ├── home_screen.dart           # 主页
│   │   ├── settings_screen.dart       # 设置
│   │   ├── wordbook_screen.dart       # 单词本详情
│   │   ├── add_word_screen.dart       # 添加单词
│   │   └── training_screen.dart       # 记忆训练
│   └── widgets/                       # UI组件
│       ├── word_card.dart
│       ├── swipeable_card.dart
│       └── tag_selector.dart
└── pubspec.yaml                       # 依赖配置
```

## 4. 数据模型

### WordBook (单词本)
```dart
class WordBook {
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;
}
```

### Word (单词)
```dart
class Word {
  final String id;
  final String wordBookId;
  final String front;              // 单词
  final String back;               // 译文
  final String notes;              // 例句
  final List<String> tags;         // 标签
  final String pronunciation;      // 发音
  final int memoryLevel;           // 记忆程度 0-5
  final int lastCorrectAt;         // 上次答对时间
  final int createdAt;
}
```

### Settings (设置)
```dart
class Settings {
  final String mainLanguage;       // 主语言
  final int defaultReviewCount;    // 默认复习数量
}
```

## 5. 数据库设计 (SQLite)

### 表结构

**wordbooks 表**
```sql
CREATE TABLE wordbooks (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
```

**words 表**
```sql
CREATE TABLE words (
  id TEXT PRIMARY KEY,
  wordbook_id TEXT NOT NULL,
  front TEXT NOT NULL,
  back TEXT NOT NULL,
  notes TEXT,
  tags TEXT,
  pronunciation TEXT,
  memory_level INTEGER DEFAULT 0,
  last_correct_at INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (wordbook_id) REFERENCES wordbooks (id) ON DELETE CASCADE
)
```

**settings 表**
```sql
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
```

### 数据存储位置
- Android: `/data/data/com.flashcards/databases/flashcards.db`
- iOS: `/var/mobile/Containers/Data/Application/<UUID>/Documents/flashcards.db`

### 数据持久化
- 应用关闭后数据保留
- 手机重启后数据保留
- 应用卸载后数据删除

## 6. 间隔重复算法

### 记忆等级
- Level 0: 1天 (新单词)
- Level 1: 2天
- Level 2: 4天
- Level 3: 7天
- Level 4: 15天
- Level 5: 30天

### 选词权重
- Level 0: 必定出现
- Level 1: 权重 100
- Level 2: 权重 70
- Level 3: 权重 40
- Level 4: 权重 20
- Level 5: 权重 5

### 答题反馈
- **左划 (记住了)**: memoryLevel+1, 更新lastCorrectAt
- **右划 (再来一次)**: memoryLevel重置为0, 移到队列尾部
- 本次训练中右划过的单词不会升级

## 7. 核心功能

### 7.1 单词本管理
- 创建/删除单词本
- 单词列表展示 (按创建时间倒序)
- 单词编辑/删除 (二次确认)

### 7.2 添加单词
- 手动输入: 单词、译文、例句、标签
- 自动翻译: 2秒超时，失败可手动输入
- 发音获取: 在线TTS或本地生成

### 7.3 记忆训练
- 标签筛选
- 根据记忆程度选词
- 卡片滑动交互 (Dismissible)
- 卡片翻转动画
- 发音播放

### 7.4 设置
- 主语言设置
- 默认复习单词数量

## 8. 开发环境 (Linux)

### 8.1 Flutter安装
```bash
# 下载Flutter SDK
cd ~
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/flutter/bin"
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
flutter doctor
```

### 8.2 开发选项
1. **Android模拟器** (推荐): 功能完整
2. **Web版本**: 快速预览
3. **Chrome调试**: 浏览器运行

### 8.3 项目初始化
```bash
cd /home/zhuojun/workspace/apps/flashcards
flutter create . --org com.flashcards --platforms android,ios,web
flutter pub get
flutter run  # 选择设备
```

### 8.4 依赖配置 (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  path_provider: ^2.1.0
  path: ^1.8.3
  audioplayers: ^5.2.0
  http: ^1.1.0
  provider: ^6.1.0
  uuid: ^4.0.0
  shared_preferences: ^2.2.0
```

## 9. 开发流程

### Phase 1: 项目初始化 (0.5天)
- 创建Flutter项目
- 配置依赖
- 验证环境

### Phase 2: 数据层 (2天)
- 创建数据模型
- 实现DatabaseService
- 实现间隔重复算法

### Phase 3: API集成 (1.5天)
- 翻译服务
- 发音服务
- 错误处理

### Phase 4: UI组件 (3天)
- WordCard组件
- SwipeableCard组件
- TagSelector组件

### Phase 5: 页面开发 (4天)
- 主页
- 设置页
- 单词本详情
- 添加单词
- 记忆训练

### Phase 6: 状态管理 (1天)
- Provider配置
- 状态持久化

### Phase 7: 测试优化 (2天)
- 功能测试
- 性能优化

**总计: 约14天**

## 10. iOS编译方案

### 方案1: GitHub Actions (推荐)
- 免费macOS runner
- 自动编译iOS版本
- 无需本地Mac

### 方案2: 云端macOS服务
- MacStadium
- MacinCloud
- 远程连接编译

### 方案3: 借用Mac设备
- 朋友的Mac
- 编译后发布到TestFlight

## 11. 技术风险

### 风险1: Linux无法编译iOS
**解决**: 先开发Android版本，后期用GitHub Actions编译iOS

### 风险2: Android模拟器性能
**解决**: 使用硬件加速(KVM)，或用真机调试

### 风险3: 翻译API费用
**解决**: 使用免费额度，本地缓存，提供手动输入

### 风险4: 数据库跨平台
**解决**: Android/iOS用sqflite，Web用sqflite_common_ffi_web

## 12. 快速开始

```bash
# 1. 检查环境
flutter doctor

# 2. 创建项目
cd /home/zhuojun/workspace/apps/flashcards
flutter create . --org com.flashcards --platforms android,ios,web

# 3. 安装依赖
flutter pub get

# 4. 运行
flutter run  # 选择Android模拟器或Chrome
```

## 13. 总结

**当前方案**:
- 使用Flutter在Linux上开发
- 先用Android模拟器或Web验证功能
- 代码完全兼容iOS，无需修改

**优势**:
- 一次开发，多平台运行
- 立即可以开始开发测试
- 后期iOS编译零成本(GitHub Actions)
- 数据库、动画、手势功能完全一致

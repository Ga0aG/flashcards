// Supported languages: code -> (flag emoji, display name)
const supportedLanguages = {
  'ja': ('🇯🇵', '日语'),
  'en': ('🇺🇸', '英语'),
  'zh': ('🇨🇳', '汉语'),
  'it': ('🇮🇹', '意大利语'),
  'es': ('🇪🇸', '西班牙语'),
};

String langFlag(String code) => supportedLanguages[code]?.$1 ?? '🌐';
String langName(String code) => supportedLanguages[code]?.$2 ?? code;

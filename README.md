# 🎵 Curvora Flutter

**HiFi Audio Waveform Analyzer & Manipulator — Cross-Platform Edition**

Curvora Flutter 是 [Curvora Web](https://github.com/Eronwu/curvora_web) 的跨平台版本，使用 Flutter 构建，支持 Android / iOS / Web / macOS / Windows / Linux。

![Flutter](https://img.shields.io/badge/Flutter-3.41+-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)
![Platforms](https://img.shields.io/badge/Platforms-Android%20|%20iOS%20|%20Web%20|%20macOS%20|%20Windows%20|%20Linux-brightgreen)

---

## ✨ Features

### 🔍 Interactive Waveform
- **Canvas 原生绘制** — 基于 CustomPainter 的高性能波形渲染
- **手势缩放/平移** — 双指缩放 + 拖拽浏览时间轴
- **采样点显示** — 放大后可看到每个采样点（红色圆点）

### 📊 Spectrogram
- **FFT 频谱分析** — 实时计算 STFT，Hann 窗函数
- **热力图渲染** — 基于 Canvas 的频率-时间热力图
- **自适应分辨率** — 根据采样数自动调整 hop size

### 🎵 HiFi Resampling (采样率倍增)

| 采样率 | 用途 |
|--------|------|
| 8 kHz | 电话语音 |
| 16 kHz | 语音识别 |
| 22.05 kHz | AM 广播 |
| 44.1 kHz | CD 标准 |
| 48 kHz | 专业音频/视频 |
| 88.2 kHz | HiFi 2x |
| 96 kHz | HiFi / Studio |
| 176.4 kHz | HiFi 4x |
| 192 kHz | Ultra HiFi / Mastering |

### 🧮 Resampling Algorithms

| 算法 | 说明 |
|------|------|
| `linear` | 线性插值，速度快 |
| `sinc` | Sinc 插值，高质量 HiFi 重采样 |

### 🔊 Audio Processing
- **Gain** — 0.0x ~ 3.0x 音量调节
- **Clipping** — 硬裁剪，限制最大振幅
- **Export** — 处理后音频导出为 WAV

### 📱 Responsive Layout
- **宽屏** (≥1080px) — 左侧控制面板 + 右侧可视化
- **窄屏** — 上方控制面板 + 下方可视化
- 适配手机、平板、桌面

---

## 🚀 Quick Start

### 环境要求
- Flutter 3.41+
- Dart 3.11+

### 安装 & 运行

```bash
# 克隆项目
git clone git@github.com:Eronwu/curvora_flutter.git
cd curvora_flutter

# 安装依赖
flutter pub get

# 运行 Web 版（最快体验）
flutter run -d chrome

# 运行 macOS 桌面版
flutter run -d macos

# 运行 Android（需要连接设备或模拟器）
flutter run -d android
```

### 支持的音频格式
- WAV（原生解析，完整采样数据）
- MP3 / OGG / FLAC（元数据估算模式）

---

## 🏗️ Architecture

```
lib/
├── main.dart                         # 入口
├── app.dart                          # Material3 暗色主题配置
├── screens/
│   └── curvora_screen.dart           # 主界面（状态管理 + 布局）
├── models/
│   ├── audio_data.dart               # 音频源数据模型
│   ├── processed_audio.dart          # 处理后数据模型
│   └── processing_settings.dart      # 处理参数（增益/采样率/算法）
├── services/
│   ├── audio_file_service.dart       # 文件选取 + WAV 解析
│   ├── audio_processing_service.dart # 增益/裁剪/重采样引擎
│   ├── spectrogram_service.dart      # FFT + Hann 窗 + 频谱计算
│   └── wav_codec.dart                # WAV 格式编解码器
└── widgets/
    ├── control_panel.dart            # 控制面板（滑块/选择器/按钮）
    ├── waveform_view.dart            # 波形可视化（缩放/平移/采样点）
    └── spectrogram_view.dart         # 频谱热力图
```

### 技术栈

| 组件 | 用途 |
|------|------|
| [Flutter](https://flutter.dev/) | 跨平台 UI 框架 |
| [CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html) | Canvas 波形/频谱绘制 |
| [fft](https://pub.dev/packages/fft) | 快速傅里叶变换 |
| [file_picker](https://pub.dev/packages/file_picker) | 跨平台文件选取 |
| [Material 3](https://m3.material.io/) | 现代化 UI 设计语言 |

---

## 🗺️ Roadmap

- [ ] 真实音频播放（集成 just_audio）
- [ ] MP3/OGG/FLAC 完整解码（FFI + native codec）
- [ ] 更多重采样算法（soxr_hq, soxr_vhq, polyphase）
- [ ] A/B 对比模式
- [ ] 频率滤波器（高通/低通/带通）
- [ ] 批量处理模式
- [ ] 多通道波形独立显示

---

## 🔗 Related Projects

- **[Curvora Web](https://github.com/Eronwu/curvora_web)** — Python + Streamlit 版本（快速原型）

---

## 📄 License

MIT License — 自由使用、修改和分发。

---

## 🙏 Acknowledgments

Built with ❤️ by [Eron Wu](https://github.com/Eronwu)

Powered by Flutter, Dart FFT, and the open-source audio community.

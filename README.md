# 视频转码脚本

基于 FFmpeg + NVIDIA GPU 硬件加速的视频转码 PowerShell 脚本集，用于将视频转为 HEVC (H.265) 编码，适用于本地归档或社交平台上传。

## 平台

Windows（PowerShell）

## 环境搭建

### 安装依赖

使用 [winget](https://learn.microsoft.com/zh-cn/windows/package-manager/winget/) 安装：

```powershell
winget install Gyan.FFmpeg
winget install OliverBetz.ExifTool
```

- **FFmpeg**：视频编解码核心，需为支持 CUDA 和 NVENC 的完整构建（Gyan 版本自带）。
- **ExifTool**：仅 `GPU_dcuda.ps1` 使用，用于写入视频旋转元数据。

### 硬件要求

- NVIDIA GPU（需支持 NVENC 硬件编码）。
- 已安装 NVIDIA 显卡驱动。

### 验证安装

```powershell
ffmpeg -version
exiftool -ver
nvidia-smi
```

三条命令均应正常输出版本信息。

## 脚本说明

所有脚本均接受一个必填参数 `-InputFile`，输出文件名为 `{原文件名}_hevc.mp4`。

### GPU_dcuda.ps1

纯 GPU 管线，转码后通过 ExifTool 写入旋转元数据。

| 项目 | 参数 |
|------|------|
| 管线 | GPU 解码 (CUDA) → GPU 缩放 → NVENC 编码 |
| 分辨率 | 自动宽度 × 720p |
| 帧率 | 30fps |
| 编码预设 | p5 / VBR HQ / CQ 29 |
| 码率上限 | 2.4 Mbps |
| 音频 | 直接复制 |
| 后处理 | ExifTool 写入 rotation=90 元数据 |

```powershell
.\GPU_dcuda.ps1 -InputFile ".\video.mp4"
```

适用于竖屏拍摄的视频——不物理旋转像素，而是通过元数据标记方向，播放器自动旋转显示。

### GPU_dcuda_upload.ps1

通过 CPU 端 transpose 物理旋转像素，输出竖屏视频。

| 项目 | 参数 |
|------|------|
| 管线 | GPU 解码 (CUDA) → CPU 转置 → GPU 缩放 → NVENC 编码 |
| 分辨率 | 720 × 1280（竖屏） |
| 帧率 | 30fps |
| 编码预设 | p5 / VBR HQ / CQ 29 |
| 码率上限 | 2.4 Mbps |
| 音频 | 直接复制 |

```powershell
.\GPU_dcuda_upload.ps1 -InputFile ".\video.mp4"
```

滤镜链：`hwdownload → format=nv12 → transpose=clock → hwupload_cuda → scale_cuda=720:1280`

像素被物理旋转为竖屏，兼容性最好，适合上传到不读取旋转元数据的平台。

### GPU_dnv12_upload.ps1

与 `GPU_dcuda_upload.ps1` 目的一致（生成竖屏视频），但采用 nv12 输出格式，省去 CPU 中转。

| 项目 | 参数 |
|------|------|
| 管线 | GPU 解码 (nv12) → GPU 缩放 → NVENC 编码 |
| 分辨率 | 720 × 1280（竖屏） |
| 帧率 | 30fps |
| 编码预设 | p5 / VBR HQ / CQ 29 |
| 码率上限 | 2.4 Mbps |
| 音频 | 直接复制 |

```powershell
.\GPU_dnv12_upload.ps1 -InputFile ".\video.mp4"
```

滤镜链：`hwupload_cuda → scale_cuda=720:1280`

全程 GPU 处理，速度更快，但不会物理旋转像素——如果原始视频是横屏拍摄，输出仍然是横屏画面。适用于素材本身已经是竖屏的情况。

### script_CPU_GPU.ps1

CPU 解码 + GPU 编码的混合管线，同时转码音频。

| 项目 | 参数 |
|------|------|
| 管线 | CPU 解码 → CPU 缩放 → NVENC 编码 |
| 分辨率 | 自动宽度 × 1080p |
| 帧率 | 60fps |
| 编码预设 | p7 / VBR / CQ 27 |
| 码率上限 | 2.6 Mbps |
| 音频 | AAC 96kbps 单声道 |

```powershell
.\script_CPU_GPU.ps1 -InputFile ".\video.mp4"
```

适用于需要高质量 60fps 输出、或 GPU 解码不可用的场景。p7 预设编码质量最高但速度较慢。

## GPU_dcuda_upload 与 GPU_dnv12_upload 对比

两个脚本目标相同——生成 720×1280 竖屏 HEVC 视频用于上传，区别在于旋转处理方式：

| | GPU_dcuda_upload | GPU_dnv12_upload |
|---|---|---|
| 解码输出格式 | `cuda` | `nv12` |
| 像素物理旋转 | 有（CPU transpose） | 无 |
| 性能 | 较慢（需 CPU↔GPU 数据搬运） | 较快（全程 GPU） |
| 适用场景 | 横屏素材需旋转为竖屏 | 素材本身已为竖屏 |

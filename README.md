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

所有脚本均接受一个必填参数 `-InputFile`，输出文件名为 `{原文件名}_hevc.mp4`。编码参数统一为 p6 / VBR HQ / CQ 29 / 码率上限 2.4 Mbps / 音频直接复制。

### GPU_dcuda.ps1 — 推荐（全 GPU 管线，性能最佳）

**全程在 GPU 显存内完成，不解码到系统内存，没有 CPU 处理旋转的部分。** 解码（CUDA 格式）→ 缩放（scale_cuda）→ 编码（NVENC）三个阶段数据始终留在 GPU 上，是三个脚本中性能最佳、CPU 和内存占用最低的方案。

| 项目 | 参数 |
|------|------|
| 管线 | GPU 解码 (CUDA) → GPU 缩放 → NVENC 编码 |
| 分辨率 | 720p（自动对边） |
| 帧率 | 30fps |
| 编码预设 | p6 / VBR HQ / CQ 29 |
| 码率上限 | 2.4 Mbps |
| 音频 | 直接复制 |
| 后处理 | ExifTool 写入 rotation=90 元数据 |

```powershell
.\GPU_dcuda.ps1 -InputFile ".\video.mp4"
```

使用 `-noautorotate` 禁止 FFmpeg 自动旋转，scale_cuda 直接按存储分辨率缩放（`-2:720`，720 对应存储时短边宽度），转码完成后通过 ExifTool 写入旋转元数据，播放器自动旋转显示。不物理旋转像素，而是通过元数据标记方向。

相比之下，另外两个上传脚本都需要将视频帧输出到系统内存，在 CPU 上完成旋转后再上传回 GPU，额外的数据搬运带来显著的性能开销。

### GPU_dcuda_upload.ps1

通过 CPU 端 transpose 物理旋转像素，输出竖屏视频。

| 项目 | 参数 |
|------|------|
| 管线 | GPU 解码 (CUDA) → **CPU 转置** → GPU 缩放 → NVENC 编码 |
| 分辨率 | 720p（自动对边） |
| 帧率 | 30fps |
| 编码预设 | p6 / VBR HQ / CQ 29 |
| 码率上限 | 2.4 Mbps |
| 音频 | 直接复制 |

```powershell
.\GPU_dcuda_upload.ps1 -InputFile ".\video.mp4"
```

滤镜链：`hwdownload → format=nv12 → transpose=clock → hwupload_cuda → scale_cuda=720:-2`

需要将帧从 GPU 下载到系统内存（hwdownload），由 CPU 执行 transpose 物理旋转像素，再上传回 GPU（hwupload_cuda）进行缩放和编码。这一来一回的数据搬运增加了 CPU 和内存开销。像素被物理旋转为竖屏，兼容性最好，适合上传到不读取旋转元数据的平台。

### GPU_dnv12_upload.ps1

与 `GPU_dcuda_upload.ps1` 目的一致（物理旋转像素，输出竖屏视频用于上传），但旋转由 FFmpeg 在 nv12 解码时隐式完成。

| 项目 | 参数 |
|------|------|
| 管线 | GPU 解码 (nv12, 隐式旋转) → GPU 缩放 → NVENC 编码 |
| 分辨率 | 720p（自动对边） |
| 帧率 | 30fps |
| 编码预设 | p6 / VBR HQ / CQ 29 |
| 码率上限 | 2.4 Mbps |
| 音频 | 直接复制 |

```powershell
.\GPU_dnv12_upload.ps1 -InputFile ".\video.mp4"
```

滤镜链：`hwupload_cuda → scale_cuda=720:-2`

使用 `hwaccel_output_format nv12` 时，FFmpeg 读取到原视频的旋转矩阵后会在解码阶段隐式执行 transpose，输出的 nv12 帧（存放在系统内存）已经是旋转后的画面。再通过 hwupload_cuda 上传回 GPU 显存进行缩放和编码。隐式旋转同样发生在 CPU 上，因此与 GPU_dcuda_upload.ps1 性能相当，区别仅在于旋转由 FFmpeg 内部完成而非通过显式的 transpose 滤镜。

## 三个脚本对比

| | GPU_dcuda.ps1 | GPU_dcuda_upload.ps1 | GPU_dnv12_upload.ps1 |
|---|---|---|---|
| 解码输出格式 | `cuda`（GPU 显存） | `cuda` → hwdownload 到系统内存 | `nv12`（系统内存，隐式旋转） |
| 旋转方式 | 元数据（ExifTool） | CPU 显式 transpose | FFmpeg 隐式旋转（nv12 解码时） |
| CPU↔GPU 数据搬运 | **无** | 有 | 有 |
| CPU 占用 | **最低** | 高 | 高 |
| 内存占用 | **最低** | 高 | 高 |
| 编码速度 | **最快** | 较慢 | 较慢 |
| 适用场景 | 本地归档、支持元数据的平台 | 上传到不读取旋转元数据的平台 | 同左 |

**如果目标平台支持旋转元数据，优先使用 `GPU_dcuda.ps1`——全 GPU 管线，不折腾 CPU 和内存。**

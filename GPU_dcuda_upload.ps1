param (
    [Parameter(Mandatory=$true)]
    [string]$InputFile
)

$OutputFile = [System.IO.Path]::GetFileNameWithoutExtension($InputFile) + "_hevc.mp4"

if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

Write-Host "Input  : $InputFile"
Write-Host "Output : $OutputFile"
Write-Host "Pipeline: GPU Decode → CPU transpose → GPU scale → NVENC Encode"

$ffmpegArgs = @(
    "-hwaccel", "cuda",
    "-hwaccel_output_format", "cuda",
    "-i", $InputFile,
    #手机拍摄的竖屏视频存储的时候是横着存的，实际为1920x1080，配合旋转矩阵竖屏播放
    #这里scale为720:-2,原因是解码时读取了旋转元数据，导致宽高被交换了，所以720是为竖屏的短边宽度
    "-vf", "hwdownload,format=nv12,transpose=clock,hwupload_cuda,scale_cuda=720:-2,fps=30",
    "-c:v", "hevc_nvenc",
    "-profile:v", "main",
    "-preset", "p6",
    "-rc", "vbr_hq",
    "-cq", "29",
    "-maxrate", "2.4M",
    "-bufsize", "4.8M",
    "-spatial-aq", "1",
    "-temporal-aq", "1",                     
    "-c:a", "copy",
    "-movflags", "+faststart",
    $OutputFile
)

& ffmpeg $ffmpegArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "Done." -ForegroundColor Green
} else {
    Write-Error "FFmpeg failed."
}
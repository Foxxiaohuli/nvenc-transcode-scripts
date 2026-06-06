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
    "-vf", "hwdownload,format=nv12,transpose=clock,hwupload_cuda,scale_cuda=720:1280,fps=30",
    "-c:v", "hevc_nvenc",
    "-profile:v", "main",
    "-preset", "p5",
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
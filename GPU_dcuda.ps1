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
Write-Host "Pipeline: GPU Decode → GPU scale → NVENC Encode"

$ffmpegArgs = @(
    "-hwaccel", "cuda",
    "-hwaccel_output_format", "cuda",
    "-noautorotate",
    "-i", $InputFile,
    "-vf", "scale_cuda=-2:720,fps=30",
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
    Write-Host "FFmpeg done, applying rotation metadata..." -ForegroundColor Yellow

    exiftool -overwrite_original -rotation=90 $OutputFile

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Done." -ForegroundColor Green
    } else {
        Write-Warning "exiftool failed, the video may display rotated incorrectly."
    }
} else {
    Write-Error "FFmpeg failed."
}

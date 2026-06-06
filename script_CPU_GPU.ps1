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

$ffmpegArgs = @(
    "-i", $InputFile,
    "-vf", "scale=-2:1080,fps=60",
    "-c:v", "hevc_nvenc",
    "-preset", "p7",
    "-rc", "vbr",
    "-cq", "27",                 
    "-maxrate", "2.6M",          
    "-bufsize", "5.2M",
    "-spatial-aq", "1",
    "-temporal-aq", "1",
    "-c:a", "aac",
    "-b:a", "96k",
    "-ac", "1",
    "-movflags", "+faststart",
    $OutputFile
)

& ffmpeg $ffmpegArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "Done." -ForegroundColor Green
} else {
    Write-Error "FFmpeg failed."
}
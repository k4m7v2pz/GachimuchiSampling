<#
.SYNOPSIS
    检查仓库中所有 WAV 文件的采样率，报告不符合 48kHz 的文件。

.DESCRIPTION
    遍历指定目录（默认当前目录）下所有 .wav 文件，读取 WAV 文件头中的采样率，
    与目标采样率（默认 48000 Hz）对比，输出统计报告。

.PARAMETER Path
    要检查的根目录，默认为脚本所在目录。

.PARAMETER TargetRate
    目标采样率，默认为 48000。

.PARAMETER Csv
    可选：将不符合的文件列表导出为 CSV 文件路径。

.EXAMPLE
    ./scripts/check_samplerate.ps1

.EXAMPLE
    ./scripts/check_samplerate.ps1 -Path "D:\Samples" -TargetRate 44100 -Csv "report.csv"
#>

param(
    [string]$Path = (Get-Location),
    [int]$TargetRate = 48000,
    [string]$Csv = ""
)

$ErrorActionPreference = "Stop"

# ---------- 收集 WAV 文件 ----------
$wavs = Get-ChildItem -Path $Path -Recurse -Filter *.wav
if ($wavs.Count -eq 0) {
    Write-Host "未找到 .wav 文件。" -ForegroundColor Yellow
    exit 0
}

# ---------- 逐文件检查 ----------
$ok = 0
$bad = @()

foreach ($f in $wavs) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        if ($bytes.Length -lt 44) {
            # 文件太短，不是有效 WAV
            $bad += [PSCustomObject]@{
                File       = $f.FullName
                Rate       = "N/A"
                Note       = "文件过短 (< 44 bytes)"
            }
            continue
        }

        # WAV 格式：RIFF header (12) + fmt chunk
        # sample rate 位于偏移 24，4 字节小端序
        $rate = [BitConverter]::ToUInt32($bytes, 24)

        if ($rate -eq $TargetRate) {
            $ok++
        }
        else {
            $note = if ($rate -eq 0) { "无法读取采样率，可能是 WAV 变体格式" } else { "" }
            $bad += [PSCustomObject]@{
                File = $f.FullName
                Rate = "$rate Hz"
                Note = $note
            }
        }
    }
    catch {
        $bad += [PSCustomObject]@{
            File = $f.FullName
            Rate = "ERROR"
            Note = $_.Exception.Message
        }
    }
}

# ---------- 输出报告 ----------
Write-Host "=== 采样率检查报告 ===" -ForegroundColor Cyan
Write-Host "检查路径 : $Path"
Write-Host "目标采样率: $TargetRate Hz"
Write-Host "总检查文件: $($wavs.Count)"
Write-Host "符合要求  : $ok"
Write-Host "不符合    : $($bad.Count)"

if ($bad.Count -gt 0) {
    Write-Host "`n--- 不符合的文件 ---" -ForegroundColor Yellow
    $bad | ForEach-Object {
        Write-Host ("  {0,-8} | {1}" -f $_.Rate, $_.File)
        if ($_.Note) { Write-Host ("          {0}" -f $_.Note) }
    }
}

# ---------- 导出 CSV ----------
if ($Csv -and $bad.Count -gt 0) {
    $bad | Export-Csv -Path $Csv -NoTypeInformation -Encoding UTF8
    Write-Host "已导出 CSV: $Csv" -ForegroundColor Green
}

# 返回退出码（方便 CI 使用）
exit ($bad.Count -gt 0 ? 1 : 0)

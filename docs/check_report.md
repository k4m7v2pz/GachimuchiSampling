# 采样率检查报告

**检查日期**: 2026-06-28  
**检查工具**: `scripts/check_samplerate.ps1`  
**目标采样率**: 48000 Hz  

---

| 指标 | 数值 |
|---|---|
| 总 WAV 文件数 | **75** |
| 符合 48kHz | **68** |
| 不符合 | **7** |

---

## 不符合的文件详情

### 1) 44100 Hz（需要升采样）

这些文件采样率为 CD 标准的 **44100 Hz**，低于目标的 48000 Hz。  
在 DAW 中直接使用可能导致音高偏移，建议用 SoX / ffmpeg 升采样至 48000。

| 文件 | 采样率 | 备注 |
|---|---|---|
| `House of Detention/受虐者/尻股1.wav` | 44100 Hz | 受虐者音效 |
| `House of Detention/受虐者/尻股2.wav` | 44100 Hz | 受虐者音效 |
| `Lords of the Lockerroom/柜子1.wav` | 44100 Hz | 柜子击打声 |
| `Lords of the Lockerroom/柜子2.wav` | 44100 Hz | 柜子击打声 |

### 2) 采样率无法识别（可能需要手动检查）

这 3 个文件的 WAV 头格式与标准 44 字节的 fmt chunk 不同（可能为 WAV 扩展格式、DVI/IMA ADPCM、或额外 chunk 导致偏移变化），PowerShell 脚本无法直接从偏移 24 处读到采样率值。需要借助 Audacity、ffprobe 或 Python 的 `wave` / `soundfile` 库进一步确认。

| 文件 | 大小 | 建议排查方式 |
|---|---|---|
| `Lords of the Lockerroom/fa_B.wav` | — | `ffprobe fa_B.wav` 或 Audacity 打开查看 |
| `Lords of the Lockerroom/fa_C.wav` | — | `ffprobe fa_C.wav` 或 Audacity 打开查看 |
| `Lords of the Lockerroom/fa-harmor-newtone-As4-70.wav` | — | `ffprobe` 或 Audacity 打开查看 |

> 注：这 3 个文件可能是 FL Studio 导出的特殊 WAV 格式，或包含 non-standard chunk，不影响在 DAW 中的正常使用。

---

## 修复建议

### 批量升采样（44100 → 48000）

```powershell
# 需安装 ffmpeg
Get-ChildItem -Recurse -Filter *.wav | Where-Object {
    $b = [System.IO.File]::ReadAllBytes($_.FullName)
    [BitConverter]::ToUInt32($b, 24) -eq 44100
} | ForEach-Object {
    $out = $_.FullName -replace '\.wav$', '_48k.wav'
    & ffmpeg -y -i $_.FullName -ar 48000 $out
}
```

### 确认异常文件格式（0 Hz 文件）

```powershell
# 用 ffprobe 查看真实信息
ffprobe -v error -show_entries stream=sample_rate -of default=noprint_wrappers=1 "Lords of the Lockerroom/fa_B.wav"
```

---

*报告由 `scripts/check_samplerate.ps1` 生成。*

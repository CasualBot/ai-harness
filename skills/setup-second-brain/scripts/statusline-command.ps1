#!/usr/bin/env pwsh
# Claude Code statusline (PowerShell 7+) — mirrors statusline-command.sh.
# Wire up in settings.json:
#   "statusLine": {
#     "type": "command",
#     "command": "pwsh -NoProfile -File \"C:\\path\\to\\statusline-command.ps1\""
#   }

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ESC = [char]27

# ---- Read CC input from stdin ----
$rawInput = [Console]::In.ReadToEnd()
try { $d = $rawInput | ConvertFrom-Json } catch { $d = [pscustomobject]@{} }

# ---- Terminal width ----
$termWidth = 0
try { $termWidth = [int]$Host.UI.RawUI.WindowSize.Width } catch {}
if ($termWidth -le 0 -and $env:COLUMNS) { $termWidth = [int]$env:COLUMNS }
if ($termWidth -le 0) { $termWidth = 120 }

# ---- Cache paths (cross-platform) ----
$tmp = if ($IsWindows -or $env:OS -match 'Windows') { $env:TEMP } else { '/tmp' }
$ccusageCache = Join-Path $tmp 'ccusage-statusline.json'
$ccusageStamp = Join-Path $tmp 'ccusage-statusline.ts'
$rateCache    = Join-Path $tmp 'claude-rate-limits.json'

# ---- ccusage: 3s TTL, background refresh, in-flight de-dup ----
$now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
$stale = $true
if (Test-Path $ccusageStamp) {
    try {
        $ts = [int64]((Get-Content $ccusageStamp -Raw -ErrorAction Stop).Trim())
        if (($now - $ts) -lt 3) { $stale = $false }
    } catch {}
}
if ($stale) {
    # Bump stamp BEFORE forking so concurrent renders don't pile up duplicate fetches.
    Set-Content -Path $ccusageStamp -Value $now -NoNewline -ErrorAction SilentlyContinue
    $bgCmd = @"
`$result = & npx --yes ccusage@latest blocks --active --json 2>`$null
if (`$result) {
    Set-Content -Path '$ccusageCache' -Value `$result -NoNewline
    Set-Content -Path '$ccusageStamp' -Value ([DateTimeOffset]::Now.ToUnixTimeSeconds()) -NoNewline
}
"@
    Start-Process pwsh -ArgumentList '-NoProfile','-WindowStyle','Hidden','-Command',$bgCmd -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
}
$ccusageJson = if (Test-Path $ccusageCache) { Get-Content $ccusageCache -Raw } else { '' }

# ---- Helpers ----
function To-Pct($v) {
    if ($null -eq $v) { return 0 }
    try { return [int][Math]::Round([double]$v) } catch { return 0 }
}

function Parse-Iso($s) {
    if (-not $s) { return $null }
    try { return [DateTimeOffset]::Parse($s, $null, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal) }
    catch { return $null }
}

function Format-ResetAt($iso) {
    $dt = Parse-Iso $iso
    if (-not $dt) { return '' }
    $local = $dt.ToLocalTime()
    $hour12 = $local.Hour % 12
    if ($hour12 -eq 0) { $hour12 = 12 }
    $suffix = if ($local.Hour -lt 12) { 'AM' } else { 'PM' }
    if ($local.Minute -eq 0) { return "$hour12$suffix" }
    return ('{0}:{1:D2}{2}' -f $hour12, $local.Minute, $suffix)
}

function Format-ResetIn($iso) {
    $dt = Parse-Iso $iso
    if (-not $dt) { return '' }
    $total = [int]($dt.UtcDateTime - [DateTime]::UtcNow).TotalSeconds
    if ($total -le 0) { return 'now' }
    $days  = [int]($total / 86400)
    $hours = [int](($total % 86400) / 3600)
    $mins  = [int](($total % 3600) / 60)
    if ($days  -gt 0) { return $(if ($hours) { "${days}d${hours}h" } else { "${days}d" }) }
    if ($hours -gt 0) { return $(if ($mins)  { "${hours}h${mins}m" } else { "${hours}h" }) }
    return "${mins}m"
}

function Format-Tokens($n) {
    if (-not $n) { return '0' }
    $n = [int64]$n
    if ($n -ge 1000000) { return ('{0:N1}M' -f ($n / 1000000.0)) }
    if ($n -ge 1000)    { return ('{0}k' -f [int]($n / 1000)) }
    return "$n"
}

function Get-Bar($pct, $color) {
    $filled = [Math]::Max(0, [Math]::Min(10, [int][Math]::Floor(($pct + 5) / 10)))
    $blocks = ('█' * $filled) + ('░' * (10 - $filled))
    return "$ESC[${color}m$blocks$ESC[0m"
}

# ---- Pull values from CC input ----
$cw = $d.context_window
$rl = $d.rate_limits
$fiveObj  = $rl.five_hour
$sevenObj = $rl.seven_day

$ctxPct      = To-Pct $cw.used_percentage
$fiveHour    = To-Pct $fiveObj.used_percentage
$sevenDay    = To-Pct $sevenObj.used_percentage
$fiveResets  = $fiveObj.resets_at
$sevenResets = $sevenObj.resets_at

# ---- Rate-limits cache: fall back when CC input is empty (fresh session) ----
$cache = $null
if (Test-Path $rateCache) {
    try { $cache = Get-Content $rateCache -Raw | ConvertFrom-Json } catch { $cache = $null }
}
function Cache-Alive($iso) {
    $dt = Parse-Iso $iso
    return ($dt -and $dt.UtcDateTime -gt [DateTime]::UtcNow)
}
if (-not $fiveResets -and $cache.five_hour -and (Cache-Alive $cache.five_hour.resets_at)) {
    $fiveHour   = To-Pct $cache.five_hour.used_percentage
    $fiveResets = $cache.five_hour.resets_at
}
if (-not $sevenResets -and $cache.seven_day -and (Cache-Alive $cache.seven_day.resets_at)) {
    $sevenDay    = To-Pct $cache.seven_day.used_percentage
    $sevenResets = $cache.seven_day.resets_at
}

# Persist live values for future fresh sessions
$newCache = @{}
if ($cache) { foreach ($p in $cache.PSObject.Properties) { $newCache[$p.Name] = $p.Value } }
if ($fiveObj.resets_at)  { $newCache['five_hour'] = @{ used_percentage = $fiveObj.used_percentage;  resets_at = $fiveObj.resets_at } }
if ($sevenObj.resets_at) { $newCache['seven_day'] = @{ used_percentage = $sevenObj.used_percentage; resets_at = $sevenObj.resets_at } }
try { ($newCache | ConvertTo-Json -Compress) | Set-Content -Path $rateCache -NoNewline -ErrorAction Stop } catch {}

# ---- Width tiers ----
$includeResets = $termWidth -ge 100
$includeBars   = $termWidth -ge 70

# ---- Build segments ----
$parts = @()

# Context (cyan / yellow / red)
$ctxColor = if ($ctxPct -ge 90) { '0;31' } elseif ($ctxPct -ge 75) { '0;33' } else { '0;36' }
$parts += "🧠 $ESC[${ctxColor}m$ctxPct%$ESC[0m"

# 5h bar
$fiveColor = if ($fiveHour -ge 90) { '0;31' } elseif ($fiveHour -ge 75) { '0;33' } else { '0;32' }
$fiveLabel = if ($includeBars) {
    "⏱️ $(Get-Bar $fiveHour $fiveColor) $ESC[${fiveColor}m$fiveHour%$ESC[0m"
} else {
    "⏱️ $ESC[${fiveColor}m$fiveHour%$ESC[0m"
}
if ($includeResets) {
    $r = Format-ResetAt $fiveResets
    if ($r) { $fiveLabel += " $ESC[2m→$r$ESC[0m" }
}
$parts += $fiveLabel

# 7d bar
$sevenColor = if ($sevenDay -ge 90) { '0;31' } elseif ($sevenDay -ge 75) { '0;33' } else { '0;34' }
$sevenLabel = if ($includeBars) {
    "📅 $(Get-Bar $sevenDay $sevenColor) $ESC[${sevenColor}m$sevenDay%$ESC[0m"
} else {
    "📅 $ESC[${sevenColor}m$sevenDay%$ESC[0m"
}
if ($includeResets) {
    $r = Format-ResetIn $sevenResets
    if ($r) { $sevenLabel += " $ESC[2m→$r$ESC[0m" }
}
$parts += $sevenLabel

# ccusage burn rates
if ($ccusageJson) {
    try {
        $cu = $ccusageJson | ConvertFrom-Json
        $blocks = if ($cu -is [array]) { $cu } elseif ($cu.blocks) { $cu.blocks } else { @() }
        $active = $blocks | Where-Object { $_.isActive -or $_.active } | Select-Object -First 1
        if (-not $active -and $blocks) { $active = $blocks[0] }
        if ($active) {
            $burn = $active.burnRate
            if ($burn.costPerHour -ne $null) {
                $parts += ("🔥 $ESC[1;31m`${0:N2}/hr$ESC[0m" -f [double]$burn.costPerHour)
            }
            if ($burn.tokensPerMinute -ne $null) {
                $parts += "🪙 $ESC[1;33m$(Format-Tokens ([double]$burn.tokensPerMinute * 60))/hr$ESC[0m"
            }
        }
    } catch {}
}

[Console]::Out.WriteLine(($parts -join '  '))

# =====================================================================
# SIT722 Task 10.3HD - watch production during a release (PowerShell)
#
# Usage: .\scripts\watch_prod.ps1 https://koalatech-course-xx.azurewebsites.net
# Sends a request every 0.5s and counts non-200 responses. Ctrl+C to stop.
# =====================================================================
param([Parameter(Mandatory = $true)][string]$Url)

$healthUrl = $Url.TrimEnd('/') + '/health'
$ok = 0; $fail = 0; $lastVersion = ''

try {
    while ($true) {
        $version = '?'
        try {
            $r = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 5 -UseBasicParsing
            $code = [int]$r.StatusCode
            $version = (($r.Content | ConvertFrom-Json).version)
            if ($version.Length -gt 7) { $version = $version.Substring(0, 7) }
        } catch {
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode } else { $code = 0 }
        }
        if ($code -eq 200) { $ok++ } else { $fail++ }
        $marker = ''
        if ($lastVersion -and $version -ne '?' -and $version -ne $lastVersion) {
            $marker = "   <== VERSION CHANGED $lastVersion -> $version"
        }
        if ($version -ne '?') { $lastVersion = $version }
        $color = if ($code -eq 200) { 'Green' } else { 'Red' }
        Write-Host ("{0}  HTTP {1}  version={2}  ok={3} fail={4}{5}" -f (Get-Date -Format 'HH:mm:ss'), $code, $version, $ok, $fail, $marker) -ForegroundColor $color
        Start-Sleep -Milliseconds 500
    }
} finally {
    Write-Host ""
    Write-Host ("== Summary: {0} OK, {1} failed out of {2} requests" -f $ok, $fail, ($ok + $fail))
}

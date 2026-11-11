<#
.SYNOPSIS
  Runs the performance and memory measurement (plan, phase 1 step 11) and
  reports times, the heap of the model and the peak working set.

.DESCRIPTION
  Builds tests/LandrixGaebPerf.dpr with the given toolchains (via build.ps1)
  and runs it once per toolchain with the given size. Windows toolchains
  get the peak working set of the process (read before it exits), which
  includes the generated document, the written outputs and the XSD
  validation besides the model.
  Linux toolchains (WSL) report the maximum resident set size via
  /usr/bin/time.

.EXAMPLE
  ./tools/perf.ps1                              # d6, d13-win64, fpc322-win64, 50 MB
  ./tools/perf.ps1 -Toolchains d6,fpc322-linux -SizeMB 10
#>
param(
  [string[]]$Toolchains = @('d6', 'd13-win64', 'fpc322-win64'),
  [int]$SizeMB = 50
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$Toolchains = ($Toolchains -join ',').Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

& "$PSScriptRoot/build.ps1" ($Toolchains -join ',') -Program tests/LandrixGaebPerf.dpr -NoRun | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'build failed' }

$WslRoot = '/mnt/' + $Root.Substring(0, 1).ToLower() + ($Root.Substring(2) -replace '\\', '/')

foreach ($t in $Toolchains) {
  Write-Host "=== $t, $SizeMB MB ===" -ForegroundColor Cyan
  if ($t -like '*-linux*') {
    $out = & wsl.exe -e bash -lc "cd '$WslRoot' && /usr/bin/time -f 'peak resident set: %M KB' './build/$t/LandrixGaebPerf' $SizeMB '$WslRoot' 2>&1"
    $code = $LASTEXITCODE
    $out | ForEach-Object { Write-Host "  $_" }
    if ($code -ne 0) { throw "$t exited with $code" }
    continue
  }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = Join-Path $Root "build/$t/LandrixGaebPerf.exe"
  $psi.Arguments = "$SizeMB `"$Root`" -wait"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardInput = $true
  $psi.UseShellExecute = $false
  $p = [System.Diagnostics.Process]::Start($psi)
  # the program waits after "done": the peak of the whole run is read while
  # the process still exists (PeakWorkingSet64 is cached until Refresh)
  $peak = 0
  while ($null -ne ($line = $p.StandardOutput.ReadLine())) {
    if ($line.Trim() -eq 'done') {
      $p.Refresh()
      $peak = $p.PeakWorkingSet64
      $p.StandardInput.WriteLine()
      continue
    }
    Write-Host "  $($line.Trim())"
  }
  $p.WaitForExit()
  if ($p.ExitCode -ne 0) { throw "$t exited with $($p.ExitCode)" }
  Write-Host ("  peak working set: {0:N0} MB" -f ($peak / 1MB))
}

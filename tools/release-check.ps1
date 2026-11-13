<#
.SYNOPSIS
  Reproducible release acceptance: runs every check a release needs and
  writes a protocol to build/release/<version>.txt.

.DESCRIPTION
  Steps (all run, the result is the conjunction):
    1. Repository state: clean working tree, HEAD on a remote branch,
       submodule checked out at the recorded commit, on a tag and on a
       remote branch; Specification/ and tests/data/local-full/ present.
    2. Static checks: tools/check-forbidden.py, tools/check-api.py and every
       generator with --check (schema extraction, merge, model, schema
       checksums, coverage, legacy and rule cases).
    3. Schemas: SHA-256 of every schema file listed in
       tools/schema/manifest.json, compared with the manifest.
    4. Full matrix: tools/build.ps1 all -Full (every toolchain, the complete
       local corpus, the examples). A skipped test fails the release, except
       on the Mac: its runner copies no git-ignored folders (schemas, local
       corpus), so the tests that need them skip there; their number is
       recorded.
    5. External XSD validation (stage 5): the XSD tests of the Delphi 13
       Win32 test runner export every document they validate; each one is
       validated again with .NET (tools/schema/validate-external.ps1) and
       the verdicts must agree. The export must contain documents of the
       local corpus. The exported copies are deleted afterwards.
    6. Versions of every compiler and external tool.

  The version is LandrixGaebLibraryVersion from source/LandrixGaebTypes.pas.
  The protocol names no test data (counts only; details of a failure are in
  the console log) and is archived with the release, not committed. The
  complete console output goes to build/release/<version>-console.log
  (local, may name test files). A protocol is written even when the check
  aborts.

  -DryRun: for trying the check before a release. Repository state findings
  are reported as warnings, any toolchain set is allowed, and the protocol
  is written to build/release/<version>-dryrun.txt.

.EXAMPLE
  ./tools/release-check.ps1
  ./tools/release-check.ps1 -DryRun -Toolchains d13-win32
#>
param(
  [string[]]$Toolchains = @('all'),
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
# one comma-separated list, as build.ps1 takes it
$Toolchains = ($Toolchains -join ',') -replace '\s', ''
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Delphi6  = 'D:\Projekte\Borland\Delphi6'
$Delphi7  = 'D:\Projekte\Borland\Delphi7'
$Delphi13 = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
$LocalBin = Join-Path $env:USERPROFILE '.local\bin'
$TestExe = 'build/d13-win32/LandrixGaebTests.exe'
$ReleaseDir = 'build/release'
$ExportDir = "$ReleaseDir/xsd"

$typesUnit = Get-Content -Raw 'source/LandrixGaebTypes.pas'
if ($typesUnit -notmatch "LandrixGaebLibraryVersion\s*=\s*'([^']+)'") {
  throw 'LandrixGaebLibraryVersion not found'
}
$Version = $Matches[1]
$Suffix = if ($DryRun) { '-dryrun' } else { '' }
New-Item -ItemType Directory -Force $ReleaseDir | Out-Null
$Protocol = "$ReleaseDir/$Version$Suffix.txt"
$ConsoleLog = "$ReleaseDir/$Version$Suffix-console.log"
# an earlier result must not survive an aborted run
Remove-Item -Force -ErrorAction SilentlyContinue $Protocol
if (Test-Path $Protocol) { throw "cannot remove the old protocol $Protocol" }
Set-Content -Encoding utf8 $ConsoleLog ''

$Report = New-Object System.Collections.Generic.List[string]
$Failures = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]
$Started = Get-Date
# set at the end of the last stage: an interrupted run (Ctrl+C skips the
# catch block, not the finally block) is never reported as passed
$Completed = $false

function Add-Line([string]$Text) { $Report.Add($Text) }

function Add-Section([string]$Title) {
  Add-Line ''
  Add-Line "== $Title =="
  Write-Host "=== $Title ===" -ForegroundColor Cyan
}

# A finding of the repository state: a failure, or a warning with -DryRun.
function Add-StateFinding([string]$Text) {
  if ($DryRun) { $Warnings.Add($Text); Add-Line "WARN  $Text" }
  else { $Failures.Add($Text); Add-Line "FAIL  $Text" }
  Write-Host "  $Text" -ForegroundColor Yellow
}

function Add-Result([string]$Name, [bool]$Ok, [string]$Detail) {
  $state = if ($Ok) { 'OK  ' } else { 'FAIL' }
  Add-Line ('{0} {1,-34} {2}' -f $state, $Name, $Detail)
  if (-not $Ok) { $Failures.Add($Name) }
  $color = if ($Ok) { 'Green' } else { 'Red' }
  Write-Host ('{0} {1} {2}' -f $state, $Name, $Detail) -ForegroundColor $color
}

# Runs a native command; returns exit code and output lines, logs the output.
function Invoke-Logged([string]$Title, [scriptblock]$Command) {
  Add-Content -Encoding utf8 $ConsoleLog "---- $Title"
  $out = @(& $Command 2>&1 | ForEach-Object { "$_" })
  $code = $LASTEXITCODE
  Add-Content -Encoding utf8 $ConsoleLog $out
  return @{ Code = $code; Out = $out }
}

# Deletes the export (copies of local files); a failure is a release failure.
function Remove-Export {
  if (Test-Path $ExportDir) {
    try { Remove-Item -Recurse -Force $ExportDir } catch { Write-Host "  $_" -ForegroundColor Red }
  }
  return -not (Test-Path $ExportDir)
}

# The first line of a version query that matches APattern, or $null; the
# query must end with exit code 0 unless AAnyExit (the Delphi compilers
# print their banner and end with an error when called without a file).
function Get-Version([scriptblock]$Command, [string]$Pattern, [bool]$AAnyExit) {
  try {
    $global:LASTEXITCODE = 0
    $out = @(& $Command 2>&1 | ForEach-Object { "$_".Trim() } | Where-Object { $_ -match $Pattern })
    if (-not $AAnyExit -and $LASTEXITCODE -ne 0) { return $null }
    if ($out.Count -gt 0) { return $out[0] }
  } catch { }
  return $null
}

Add-Line "GAEB-for-Pascal release check $Version$(if ($DryRun) { ' (DRY RUN, not a release)' })"
Add-Line "Started: $($Started.ToString('yyyy-MM-dd HH:mm:ss'))"
Add-Line "Toolchains: $Toolchains"

try {
  # ---- 1. repository state ----
  Add-Section 'Repository'
  $head = (git rev-parse HEAD).Trim()
  Add-Line "HEAD: $head $((git log -1 --format=%s).Trim())"
  $dirty = @(git status --porcelain)
  if ($dirty.Count -gt 0) { Add-StateFinding "working tree not clean ($($dirty.Count) path(s))" }
  else { Add-Line 'OK    working tree clean' }
  if (@(git branch -r --contains HEAD).Count -eq 0) { Add-StateFinding 'HEAD is on no remote branch (not pushed)' }
  else { Add-Line 'OK    HEAD on a remote branch' }

  $subStatus = (git submodule status external/landrix-xml).Trim()
  $subHead = (git -C external/landrix-xml rev-parse HEAD).Trim()
  Add-Line "Submodule external/landrix-xml: $subHead"
  if ($subStatus -match '^[+\-U]') { Add-StateFinding "submodule not at the recorded commit ($($subStatus.Substring(0, 1)))" }
  if (@(git -C external/landrix-xml status --porcelain).Count -gt 0) { Add-StateFinding 'submodule working tree not clean' }
  $subTag = (git -C external/landrix-xml tag --points-at HEAD) -join ', '
  if ($subTag) { Add-Line "OK    submodule on tag $subTag" } else { Add-StateFinding 'submodule commit has no tag' }
  if (@(git -C external/landrix-xml branch -r --contains HEAD).Count -eq 0) {
    Add-StateFinding 'submodule commit is on no remote branch'
  }
  if ($Version -notmatch '^\d+\.\d+\.\d+$') { Add-StateFinding "version '$Version' is not MAJOR.MINOR.PATCH" }
  if (-not $DryRun -and $Toolchains -ne 'all') { Add-StateFinding "toolchains '$Toolchains' instead of 'all'" }
  # without them the schema and corpus tests skip
  Add-Result 'Specification/ present' (Test-Path 'Specification/XML-3.3/Schema') ''
  Add-Result 'tests/data/local-full/ present' (Test-Path 'tests/data/local-full') ''

  # ---- 2. static checks ----
  Add-Section 'Static checks'
  $static = @(
    @{ Name = 'check-forbidden';     Args = @('tools/check-forbidden.py') },
    @{ Name = 'check-api';           Args = @('tools/check-api.py') },
    @{ Name = 'extract-gaeb-xsd';    Args = @('tools/schema/extract-gaeb-xsd.py', '--check') },
    @{ Name = 'merge-gaeb';          Args = @('tools/schema/merge-gaeb.py', '--check') },
    @{ Name = 'gen-gaeb-model';      Args = @('tools/schema/gen-gaeb-model.py', '--check') },
    @{ Name = 'gen-xsd-sums';        Args = @('tools/schema/gen-xsd-sums.py', '--check') },
    @{ Name = 'make-coverage-cases'; Args = @('tools/coverage/make-coverage-cases.py', '--check') },
    @{ Name = 'make-legacy-cases';   Args = @('tools/legacy/make-legacy-cases.py', '--check') },
    @{ Name = 'make-rule-cases';     Args = @('tools/rules/make-rule-cases.py', '--check') }
  )
  foreach ($s in $static) {
    $a = $s.Args
    $r = Invoke-Logged $s.Name { python @a }
    # a failure message can name a test file: only the exit code goes to the protocol
    $detail = if ($r.Code -eq 0 -and $r.Out.Count -gt 0) { $r.Out[-1] } else { "exit code $($r.Code) (details in the console log)" }
    Add-Result $s.Name ($r.Code -eq 0) $detail
  }

  # ---- 3. schemas ----
  Add-Section 'Schemas (SHA-256, tools/schema/manifest.json)'
  $manifest = Get-Content -Raw -Encoding utf8 'tools/schema/manifest.json' | ConvertFrom-Json
  $seen = @{}
  $bad = 0
  foreach ($ctx in $manifest.contexts) {
    foreach ($p in $ctx.files.PSObject.Properties) {
      $rel = "$($ctx.folder)/$($p.Name)"
      if ($seen.ContainsKey($rel)) { continue }
      $seen[$rel] = $true
      $path = Join-Path (Join-Path $Root $manifest.root) $rel
      $actual = if (Test-Path $path) { (Get-FileHash -Algorithm SHA256 $path).Hash.ToLower() } else { 'missing' }
      $ok = $actual -eq $p.Value
      if (-not $ok) { $bad++ }
      Add-Line ('{0} {1} {2}' -f $(if ($ok) { 'OK  ' } else { 'FAIL' }), $p.Value, $rel)
    }
  }
  Add-Result 'schema checksums' ($bad -eq 0) "$($seen.Count) file(s), $bad mismatch(es)"

  # ---- 4. full matrix ----
  Add-Section 'Matrix (tools/build.ps1 -Full)'
  $matrixStart = Get-Date
  $r = Invoke-Logged 'build.ps1' { pwsh -NoProfile -File tools/build.ps1 -Toolchains $Toolchains -Full }
  $current = ''
  $inSummary = $false
  $skipFailures = 0
  foreach ($line in $r.Out) {
    if ($line -match '^=== (.+) ===$') { $current = $Matches[1]; continue }
    if ($line -eq 'Summary') { $inSummary = $true; continue }
    if ($inSummary) {
      if ($line.Trim() -ne '') { Add-Line "  $line" }
    } elseif ($line -match '^\d+ test\(s\), .*, (\d+) skip\(s\)$') {
      $skips = [int]$Matches[1]
      $note = ''
      if ($skips -gt 0) {
        if ($current -eq 'mac') { $note = ' (accepted: no schemas and no local corpus on the Mac)' }
        else { $note = ' (SKIPS NOT ALLOWED)'; $skipFailures++ }
      }
      Add-Line "  tests $current`: $line$note"
    }
  }
  Add-Result 'matrix' ($r.Code -eq 0) ("exit code {0}, {1:N1} min" -f $r.Code, ((Get-Date) - $matrixStart).TotalMinutes)
  Add-Result 'no skipped tests' ($skipFailures -eq 0) "$skipFailures toolchain(s) with skips"

  # ---- 5. external XSD validation ----
  Add-Section 'External XSD validation (stage 5, .NET System.Xml.Schema)'
  if (-not (Test-Path $TestExe)) {
    Add-Result 'stage 5' $false "$TestExe missing (d13-win32 not built)"
  } elseif (-not (Remove-Export)) {
    Add-Result 'stage 5' $false "old export $ExportDir cannot be deleted"
  } else {
    try {
      $ok = $true
      # quoted: PowerShell would split an unquoted -filter=Local.Xsd at the dot
      foreach ($filter in @('Xsd', 'Local.Xsd')) {
        $r = Invoke-Logged "export $filter" { & $TestExe $Root "-filter=$filter" '-full' "-export=$ExportDir" }
        $last = @($r.Out | Where-Object { $_ -match '^\d+ test\(s\), ' })
        Add-Line "  export $filter`: $($last -join ' ')"
        if ($r.Code -ne 0 -or ($last -join ' ') -notmatch ', 0 skip\(s\)$') { $ok = $false }
      }
      $r = Invoke-Logged 'validate-external' { pwsh -NoProfile -File tools/schema/validate-external.ps1 -ExportDir $ExportDir }
      $summary = @($r.Out | Where-Object { $_ -match '^validate-external: ' }) -join ' '
      $disagree = @($r.Out | Where-Object { $_ -match '^DISAGREE ' }).Count
      Add-Line "  $summary"
      $local = if ($summary -match '\((\d+) local\)') { [int]$Matches[1] } else { 0 }
      Add-Result 'stage 5' ($ok -and $r.Code -eq 0 -and $local -gt 0) "$disagree disagreement(s), $local local document(s)"
    } finally {
      Add-Result 'export deleted' (Remove-Export) $ExportDir
    }
  }

  # ---- 6. versions ----
  Add-Section 'Compilers and tools'
  $fpcVersion = '^\d+\.\d+\.\d+'
  $versions = @(
    @{ Name = 'Delphi 6 dcc32';        Pattern = 'Delphi Version';  Command = { & "$Delphi6\Bin\dcc32.exe" } },
    @{ Name = 'Delphi 7 dcc32';        Pattern = 'Delphi Version';  Command = { & "$Delphi7\Bin\dcc32.exe" } },
    @{ Name = 'Delphi 13 dcc32';       Pattern = 'compiler version'; Command = { & "$Delphi13\bin\dcc32.exe" } },
    @{ Name = 'Delphi 13 dcc64';       Pattern = 'compiler version'; Command = { & "$Delphi13\bin\dcc64.exe" } },
    @{ Name = 'Delphi 13 dccosxarm64'; Pattern = 'compiler version'; Command = { & "$Delphi13\bin\dccosxarm64.exe" } },
    @{ Name = 'FPC 3.2.2 Linux (WSL)'; Pattern = $fpcVersion; Command = { wsl.exe -e bash -lc '~/.local/bin/fpc322 -iW' } },
    @{ Name = 'FPC 3.2.4 Linux (WSL)'; Pattern = $fpcVersion; Command = { wsl.exe -e bash -lc '~/.local/bin/fpc324 -iW' } },
    @{ Name = 'FPC 3.3.1 Linux (WSL)'; Pattern = $fpcVersion; Command = { wsl.exe -e bash -lc '~/.local/bin/fpc331 -iW' } },
    @{ Name = 'FPC 3.2.2 Win32';       Pattern = $fpcVersion; Command = { & (Join-Path $LocalBin 'fpc322-win32.cmd') -iW } },
    @{ Name = 'FPC 3.2.2 Win64';       Pattern = $fpcVersion; Command = { & (Join-Path $LocalBin 'fpc322-win64.cmd') -iW } },
    @{ Name = 'FPC 3.3.1 WinARM';      Pattern = $fpcVersion; Command = { & (Join-Path $LocalBin 'fpc331-winarm.cmd') -iW } },
    @{ Name = 'FPC 3.2.4 macOS (Mac)'; Pattern = $fpcVersion; Command = { ssh macos-tests '~/remote-toolchains/macos-fpc/bin/fpc.sh -iW' } },
    @{ Name = 'Python';                Pattern = '^Python \d';  Command = { python --version } },
    @{ Name = 'Git';                   Pattern = '^git version'; Command = { git --version } },
    @{ Name = 'PowerShell';            Pattern = '^\d+\.\d+';   Command = { "$($PSVersionTable.PSVersion)" } },
    @{ Name = '.NET (stage 5)';        Pattern = '^\.NET \d';   Command = { [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription } },
    @{ Name = 'Windows';               Pattern = 'Windows';     Command = { [System.Environment]::OSVersion.VersionString } }
  )
  $missing = @()
  foreach ($v in $versions) {
    $text = Get-Version $v.Command $v.Pattern ($v.Name -like 'Delphi*')
    if ($null -eq $text) { $missing += $v.Name; $text = 'NOT AVAILABLE' }
    Add-Line ('{0,-24} {1}' -f $v.Name, $text)
  }
  Add-Result 'versions recorded' ($missing.Count -eq 0) $(if ($missing.Count -gt 0) { 'missing: ' + ($missing -join ', ') } else { "$($versions.Count) tool(s)" })
  $Completed = $true
} catch {
  Add-Line ''
  Add-Line "ABORTED: $($_.Exception.Message)"
  $Failures.Add('aborted')
  Write-Host "ABORTED: $($_.Exception.Message)" -ForegroundColor Red
} finally {
  if (Test-Path $ExportDir) {
    if (-not (Remove-Export)) { $Failures.Add('export deleted') }
  }
  if (-not $Completed -and -not $Failures.Contains('aborted')) { $Failures.Add('incomplete (interrupted)') }
  $Finished = Get-Date
  Add-Line ''
  Add-Line '== Result =='
  Add-Line ("Finished: {0} ({1:N1} min)" -f $Finished.ToString('yyyy-MM-dd HH:mm:ss'), ($Finished - $Started).TotalMinutes)
  foreach ($w in $Warnings) { Add-Line "WARN $w" }
  foreach ($f in $Failures) { Add-Line "FAIL $f" }
  $passed = $Failures.Count -eq 0
  $resultLine = if ($passed) { 'RESULT: PASSED' } else { "RESULT: FAILED ($($Failures.Count))" }
  Add-Line $resultLine
  $Report | Set-Content -Encoding utf8 $Protocol
  Write-Host ''
  Write-Host "Protocol: $Protocol" -ForegroundColor Cyan
  Write-Host $resultLine -ForegroundColor $(if ($passed) { 'Green' } else { 'Red' })
}
if ($passed) { exit 0 } else { exit 1 }

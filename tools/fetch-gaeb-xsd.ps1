<#
.SYNOPSIS
  Downloads the official GAEB DA XML schemas for the bill of quantities
  phases (DA 80 to 87) from gaeb.de into a folder of your choice, for
  LandrixGaebXmlXsd (TLandrixGaebXmlXsdSchemas.Create(Folder)).

.DESCRIPTION
  The schemas are not part of GAEB-for-Pascal. This script downloads the
  packages GAEB publishes on https://www.gaeb.de (download section "GAEB
  Datenaustausch"), unpacks them into <Folder>/XML-<version>-<edition>/ and
  checks every schema file against the SHA-256 in tools/schema/manifest.json.
  A file that differs is reported and the script fails; nothing outside
  <Folder> is written. Use the schemas under the terms of GAEB.

  Packages:
    3.2 (2013-10)  Leistungsverzeichnis.zip
    3.3 (2021-05)  2021-05_Leistungsverzeichnis.zip
  GAEB no longer offers 3.3 edition 2019-11; copy those schemas into the
  folder yourself if you need them.

.EXAMPLE
  ./tools/fetch-gaeb-xsd.ps1 -Folder C:\GAEB\Schemas
#>
param(
  [Parameter(Mandatory = $true)][string]$Folder
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Packages = @(
  @{ Name = 'XML-3.2-2013-10'; Edition = '3.2_2013-10'
     Url = 'https://www.gaeb.de/wp-content/uploads/2019/04/Leistungsverzeichnis.zip' },
  @{ Name = 'XML-3.3-2021-05'; Edition = '3.3_2021-05'
     Url = 'https://www.gaeb.de/wp-content/uploads/2021/06/2021-05_Leistungsverzeichnis.zip' }
)

# the official checksums of the published targets
$manifest = Get-Content -Raw -Encoding utf8 (Join-Path $Root 'tools/schema/manifest.json') | ConvertFrom-Json
$official = @{}
foreach ($ctx in $manifest.contexts) {
  if (-not $ctx.publish) { continue }
  foreach ($p in $ctx.files.PSObject.Properties) { $official[$p.Name] = $p.Value }
}

New-Item -ItemType Directory -Force $Folder | Out-Null
$Folder = (Resolve-Path $Folder).Path
$temp = Join-Path ([IO.Path]::GetTempPath()) ('gaeb-xsd-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $temp | Out-Null
$bad = 0
$count = 0
try {
  foreach ($pkg in $Packages) {
    $zip = Join-Path $temp "$($pkg.Name).zip"
    $unpacked = Join-Path $temp $pkg.Name
    Write-Host "Downloading $($pkg.Url)"
    Invoke-WebRequest -Uri $pkg.Url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $unpacked
    $target = Join-Path $Folder $pkg.Name
    New-Item -ItemType Directory -Force $target | Out-Null
    # only the schema files of the published targets, flat into the target folder
    $files = @(Get-ChildItem -Recurse -File $unpacked | Where-Object {
      $_.Name -like "GAEB_DA_XML_*_$($pkg.Edition).xsd" -and $official.ContainsKey($_.Name) })
    # every file the library knows for this edition must be in the package
    $expected = @($official.Keys | Where-Object { $_ -like "GAEB_DA_XML_*_$($pkg.Edition).xsd" } | Sort-Object)
    $names = @($files | ForEach-Object { $_.Name } | Sort-Object -Unique)
    $missing = @($expected | Where-Object { $names -notcontains $_ })
    if ($missing.Count -gt 0) { throw "$($pkg.Url) lacks $($missing -join ', ')" }
    if ($files.Count -ne $names.Count) { throw "$($pkg.Url) holds a schema file more than once" }
    foreach ($f in $files) {
      $hash = (Get-FileHash -Algorithm SHA256 $f.FullName).Hash.ToLower()
      if ($hash -ne $official[$f.Name]) {
        Write-Host "DIFFERS  $($f.Name)" -ForegroundColor Red
        $bad++
        continue
      }
      Copy-Item $f.FullName (Join-Path $target $f.Name) -Force
      $count++
    }
  }
} finally {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $temp
}
Write-Host "fetch-gaeb-xsd: $count schema file(s) in $Folder, $bad differing"
if ($bad -gt 0) { exit 1 }
exit 0

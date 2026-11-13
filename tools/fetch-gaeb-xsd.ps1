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
    3.1 (2007-11)  the packages X81-X83/X85-X88 and X84, both into
                   XML-3.1-2007-11/ (the X84 package has no xml.xsd and
                   xmldsig-core-schema.xsd of its own)
    3.1 (2009-12)  the packages X81-X83/X85-X87 and X84, both into
                   XML-3.1-2009-12/
  GAEB no longer offers 3.3 edition 2019-11 and 3.0 (2004-07); copy those
  schemas into the folder yourself if you need them (3.0: GAEB_DA_XML.xsd
  with its xml.xsd and xmldsig-core-schema.xsd in a folder of its own).

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
     Url = 'https://www.gaeb.de/wp-content/uploads/2021/06/2021-05_Leistungsverzeichnis.zip' },
  # 3.1: schema sets of tools/schema/manifest.json (validationSets); Next =
  # the package also holds xml.xsd and xmldsig-core-schema.xsd
  @{ Name = 'XML-3.1-2007-11'; Set = '3.1-2007-11'; Next = $true
     Url = 'https://www.gaeb.de/wp-content/uploads/2022/11/schema_gaeb-da-xml-3.1_20-11-2007_X81-X83_u_X85-X88.zip' },
  @{ Name = 'XML-3.1-2007-11'; Set = '3.1-2007-11-84'; Next = $false
     Url = 'https://www.gaeb.de/wp-content/uploads/2022/11/schema_gaeb-da-xml-3.1_20-11-2007_X84.zip' },
  @{ Name = 'XML-3.1-2009-12'; Set = '3.1-2009-12'; Next = $true
     Url = 'https://www.gaeb.de/wp-content/uploads/2022/11/Schema_GAEB_DA_XML_3.1_2009-12_X81-X83_u_X85-X87.zip' },
  @{ Name = 'XML-3.1-2009-12'; Set = '3.1-2009-12-84'; Next = $true
     Url = 'https://www.gaeb.de/wp-content/uploads/2022/11/Schema_GAEB_DA_XML_3.1_2009-12_X84.zip' }
)

# the official checksums of the published targets
$manifest = Get-Content -Raw -Encoding utf8 (Join-Path $Root 'tools/schema/manifest.json') | ConvertFrom-Json
$official = @{}
foreach ($ctx in $manifest.contexts) {
  if (-not $ctx.publish) { continue }
  foreach ($p in $ctx.files.PSObject.Properties) { $official[$p.Name] = $p.Value }
}
$sets = @{}
foreach ($v in $manifest.validationSets) { $sets[$v.id] = $v }

# The files written in this run (destination path -> $true).
$written = @{}

# Copies a file into the target folder; a file this run already wrote there
# (from the other package of the same edition) must be the same.
function Copy-Checked([string]$Source, [string]$Dest) {
  if ($written.ContainsKey($Dest)) {
    $old = (Get-FileHash -Algorithm SHA256 $Dest).Hash
    $new = (Get-FileHash -Algorithm SHA256 $Source).Hash
    if ($old -ne $new) { throw "$(Split-Path -Leaf $Dest) differs between the packages of $(Split-Path -Leaf (Split-Path $Dest))" }
    return
  }
  Copy-Item $Source $Dest -Force
  $written[$Dest] = $true
}

New-Item -ItemType Directory -Force $Folder | Out-Null
$Folder = (Resolve-Path $Folder).Path
$temp = Join-Path ([IO.Path]::GetTempPath()) ('gaeb-xsd-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $temp | Out-Null
$bad = 0
try {
  $index = 0
  foreach ($pkg in $Packages) {
    # two packages of one edition share the target folder, not the download
    $index++
    $zip = Join-Path $temp "$index.zip"
    $unpacked = Join-Path $temp "$index"
    Write-Host "Downloading $($pkg.Url)"
    Invoke-WebRequest -Uri $pkg.Url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $unpacked
    $target = Join-Path $Folder $pkg.Name
    New-Item -ItemType Directory -Force $target | Out-Null
    if ($pkg.Set) {
      # a schema set of 3.0/3.1: the main schema and, if the package has
      # them, xml.xsd and xmldsig-core-schema.xsd, each checked against the set
      $set = $sets[$pkg.Set]
      if (-not $set) { throw "schema set $($pkg.Set) not in tools/schema/manifest.json" }
      $names = @($set.main)
      if ($pkg.Next) { $names += @('xml.xsd', 'xmldsig-core-schema.xsd') }
      foreach ($n in $names) {
        $found = @(Get-ChildItem -Recurse -File $unpacked | Where-Object { $_.Name -eq $n })
        if ($found.Count -ne 1) { throw "$($pkg.Url) holds $n $($found.Count) time(s)" }
        $hash = (Get-FileHash -Algorithm SHA256 $found[0].FullName).Hash.ToLower()
        if ($hash -ne $set.files.$n) {
          Write-Host "DIFFERS  $n ($($pkg.Set))" -ForegroundColor Red
          $bad++
          continue
        }
        Copy-Checked $found[0].FullName (Join-Path $target $n)
      }
      continue
    }
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
      Copy-Checked $f.FullName (Join-Path $target $f.Name)
    }
  }
} finally {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $temp
}
Write-Host "fetch-gaeb-xsd: $($written.Count) schema file(s) in $Folder, $bad differing"
if ($bad -gt 0) { exit 1 }
exit 0

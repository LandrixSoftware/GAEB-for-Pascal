<#
.SYNOPSIS
  External XSD validation (stage 5): validates the documents exported by the
  test runner with the schema processor of .NET and compares the verdicts
  with those of the LandrixXml validator.

.DESCRIPTION
  The test runner, started with -export=<Folder>, writes every document its
  XSD tests validate to <Folder> (00001.xml, ...) and a line per document to
  <Folder>/index.txt:

    file <TAB> schema below Specification/ <TAB> valid|invalid <TAB> repo|local

  Every document is validated again with System.Xml.Schema (an independent
  processor that supports xs:redefine) against the original schema from the
  local Specification/ folder. A document passes when both verdicts agree;
  the exported set contains valid documents and targeted invalid ones
  (committed -invalid cases and the mutations of Xsd.Agreement), so both
  directions are compared.

  Messages of the schema processor can quote values of the document: for
  documents from the local corpus only the file number and the position are
  printed. Exit code 0 = every verdict agrees.

.EXAMPLE
  ./tools/schema/validate-external.ps1 -ExportDir build/release/xsd
#>
param(
  [Parameter(Mandatory = $true)][string]$ExportDir,
  [string]$SpecificationDir
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $SpecificationDir) { $SpecificationDir = Join-Path $Root 'Specification' }
$ExportDir = (Resolve-Path $ExportDir).Path
$IndexFile = Join-Path $ExportDir 'index.txt'
if (-not (Test-Path $IndexFile)) { throw "index.txt missing in $ExportDir" }

$Schemas = @{}

# The compiled schema set of a main schema, loaded once.
function Get-SchemaSet([string]$RelPath) {
  if ($Schemas.ContainsKey($RelPath)) { return $Schemas[$RelPath] }
  $path = Join-Path $SpecificationDir ($RelPath -replace '/', '\')
  $errors = New-Object System.Collections.Generic.List[string]
  $set = New-Object System.Xml.Schema.XmlSchemaSet
  $set.XmlResolver = New-Object System.Xml.XmlUrlResolver
  $set.add_ValidationEventHandler({ param($s, $e) $errors.Add("$($e.Severity): $($e.Message)") }.GetNewClosure())
  $settings = New-Object System.Xml.XmlReaderSettings
  $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
  $reader = [System.Xml.XmlReader]::Create($path, $settings)
  try { [void]$set.Add([NullString]::Value, $reader) } finally { $reader.Close() }
  $set.Compile()
  if ($errors.Count -gt 0 -or -not $set.IsCompiled) {
    throw "schema $RelPath does not compile: $($errors -join '; ')"
  }
  $Schemas[$RelPath] = $set
  return $set
}

# Validates a file; returns the list of findings (errors and warnings).
# A warning counts as a finding too: "no schema information" for an element
# means it was not validated at all.
function Test-Document([string]$Path, $Set) {
  $findings = New-Object System.Collections.Generic.List[object]
  $settings = New-Object System.Xml.XmlReaderSettings
  $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
  $settings.XmlResolver = $null
  $settings.ValidationType = [System.Xml.ValidationType]::Schema
  $settings.Schemas = $Set
  $settings.ValidationFlags = $settings.ValidationFlags -bor
    [System.Xml.Schema.XmlSchemaValidationFlags]::ReportValidationWarnings
  $settings.add_ValidationEventHandler({
    param($s, $e)
    $findings.Add([pscustomobject]@{
      Line = $e.Exception.LineNumber; Column = $e.Exception.LinePosition
      Severity = "$($e.Severity)"; Message = $e.Message })
  }.GetNewClosure())
  $reader = [System.Xml.XmlReader]::Create($Path, $settings)
  try {
    while ($reader.Read()) { }
  } catch [System.Xml.XmlException] {
    $findings.Add([pscustomobject]@{
      Line = $_.Exception.InnerException.LineNumber; Column = $_.Exception.InnerException.LinePosition
      Severity = 'NotWellFormed'; Message = $_.Exception.InnerException.Message })
  } finally {
    $reader.Close()
  }
  return , $findings
}

$lines = @(Get-Content -Encoding utf8 $IndexFile | Where-Object { $_ -ne '' })
$total = 0; $valid = 0; $invalid = 0; $agree = 0; $local = 0
$disagree = @()
foreach ($line in $lines) {
  $f = $line.Split("`t")
  if ($f.Count -ne 4) { throw "malformed index line: $line" }
  $name, $schema, $verdict, $origin = $f
  $set = Get-SchemaSet $schema
  $findings = Test-Document (Join-Path $ExportDir $name) $set
  $total++
  if ($origin -eq 'local') { $local++ }
  $netValid = $findings.Count -eq 0
  if ($netValid) { $valid++ } else { $invalid++ }
  if ($netValid -eq ($verdict -eq 'valid')) {
    $agree++
  } else {
    $first = if ($findings.Count -gt 0) { $findings[0] } else { $null }
    $where = if ($first) { " line $($first.Line), column $($first.Column), $($first.Severity)" } else { '' }
    # values of local files are never printed
    $text = if ($first -and $origin -ne 'local') { ": $($first.Message)" } else { '' }
    $disagree += "$name ($origin, $schema): LandrixXml $verdict, .NET $(if ($netValid) { 'valid' } else { 'invalid' })$where$text"
  }
}

$disagree | ForEach-Object { Write-Host "DISAGREE $_" -ForegroundColor Red }
$runtime = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
$summary = ("validate-external: {0} document(s) ({1} local), {2} schema(s), .NET {3} valid / {4} invalid, " +
  "verdicts agree on {5}, disagree on {6} ({7})") -f $total, $local, $Schemas.Count, $valid, $invalid,
  $agree, $disagree.Count, $runtime
Write-Host $summary
if ($total -eq 0) { Write-Host 'validate-external: no documents' -ForegroundColor Red; exit 1 }
if ($disagree.Count -gt 0) { exit 1 }
exit 0

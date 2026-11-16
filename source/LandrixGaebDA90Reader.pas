{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Reading GAEB 90 files (exchange phases 81 to 86) into the GAEB DA XML
  3.3 (2021-05) syntax model. The result is the mapping of the file as it
  is: totals the file leaves out stay missing (the bill of quantities
  fills them when loading, see TLandrixGaebBillOfQuantities.LoadFromDA90File
  and LandrixGaebFillMissingTotals). The character set, which GAEB 90 does
  not declare, is decided from the bytes of the whole file unless the
  caller gives it. File physics, what the target has no counterpart for or
  is not mapped yet and unusable values are reported in ADiagnostics; the
  messages name record types, fields and lines, never values. Files split
  into parts (.001, .002, ...) are not joined: a later part has no record
  00 and is rejected. Since 1.4.0.

  DE: Lesen von GAEB-90-Dateien (Austauschphasen 81 bis 86) in das
  Syntaxmodell GAEB DA XML 3.3 (2021-05). Das Ergebnis ist die Abbildung
  der Datei, wie sie ist: Summen, die die Datei auslaesst, bleiben fehlend
  (das LV fuellt sie beim Laden, siehe
  TLandrixGaebBillOfQuantities.LoadFromDA90File und
  LandrixGaebFillMissingTotals). Der Zeichensatz, den GAEB 90 nicht
  angibt, wird aus den Bytes der ganzen Datei bestimmt, wenn der Aufrufer
  ihn nicht vorgibt. Dateiphysik, was im Ziel kein Gegenstueck hat oder
  noch nicht abgebildet ist, und unbrauchbare Werte werden in ADiagnostics
  gemeldet; die Meldungen nennen Satzarten, Felder und Zeilen, nie Werte.
  In Teile zerlegte Dateien (.001, .002, ...) werden nicht zusammengefuegt:
  ein spaeterer Teil hat keinen Satz 00 und wird abgewiesen. Seit 1.4.0. }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixGaebDA90Reader;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel;

type
  { OEM code page of a GAEB 90 file read as OEM. Later versions may add
    values.
    DE: OEM-Codepage einer GAEB-90-Datei, die als OEM gelesen wird.
    Spaetere Versionen koennen Werte ergaenzen. }
  TLandrixGaebOemCodePage = (gocCp850, gocCp437);

  { Options for reading GAEB 90. Always start from
    LandrixGaebDA90DefaultReadOptions and change single fields: later
    versions add fields.
    DE: Optionen fuer das Lesen von GAEB 90. Immer mit
    LandrixGaebDA90DefaultReadOptions beginnen und einzelne Felder
    aendern: spaetere Versionen ergaenzen Felder. }
  TLandrixGaebDA90ReadOptions = record
    { Size limit in bytes; <= 0 means LandrixGaebDefaultMaxSize (default 0).
      DE: Groessengrenze in Byte; <= 0 bedeutet LandrixGaebDefaultMaxSize
      (Standard 0). }
    MaxSize: Int64;
    { Character set of the file. gcsUnknown (default): a UTF-8 byte order
      mark or valid UTF-8 with multi-byte sequences means UTF-8, else the
      umlauts of the whole file decide between ANSI (Windows-1252) and OEM
      (OemCodePage); a file without umlauts is read as ANSI. gcsAnsi,
      gcsOem and gcsUnicode (UTF-8) are taken as given, also against a
      byte order mark. The choice is reported as GAEB-D90-FILE-001;
      Detection.SourceCharset stays gcsUnknown (GAEB 90 declares none).
      The input must still be recognisable as GAEB 90 from its bytes
      (records of 80 columns; UTF-8 counted in characters where it is
      valid or follows a byte order mark): Charset does not change the
      recognition.
      DE: Zeichensatz der Datei. gcsUnknown (Standard): eine
      UTF-8-Bytereihenfolgemarke oder gueltiges UTF-8 mit
      Mehrbytefolgen bedeutet UTF-8, sonst entscheiden die Umlaute der
      ganzen Datei zwischen ANSI (Windows-1252) und OEM (OemCodePage);
      eine Datei ohne Umlaute wird als ANSI gelesen. gcsAnsi, gcsOem und
      gcsUnicode (UTF-8) gelten wie angegeben, auch gegen eine
      Bytereihenfolgemarke. Die Wahl wird als GAEB-D90-FILE-001 gemeldet;
      Detection.SourceCharset bleibt gcsUnknown (GAEB 90 gibt keinen an).
      Die Eingabe muss dennoch an ihren Bytes als GAEB 90 erkennbar sein
      (Saetze zu 80 Spalten; UTF-8 in Zeichen gezaehlt, wo es gueltig ist
      oder einer Bytereihenfolgemarke folgt): Charset aendert die
      Erkennung nicht. }
    Charset: TLandrixGaebCharset;
    { Code page of OEM (default gocCp850), for the decision and for
      gcsOem.
      DE: Codepage von OEM (Standard gocCp850), fuer die Entscheidung und
      fuer gcsOem. }
    OemCodePage: TLandrixGaebOemCodePage;
  end;

{ The default options. DE: Die Standardoptionen. }
function LandrixGaebDA90DefaultReadOptions: TLandrixGaebDA90ReadOptions;

{ Reads a GAEB 90 file held in Buffer into a new document the caller owns.
  ADetection describes the input (Format gfDA90, SourceVersion VERSDTA,
  SourcePhase DP; its Target stays unknown), ATarget the returned
  document: GAEB DA XML 3.3, edition 2021-05, with the phase of the file.
  ADiagnostics may be nil.
  Raises ELandrixGaebError for input larger than AOptions.MaxSize, input
  that is no GAEB 90, a file without record 00 and an exchange phase other
  than 81 to 86. Other faults (record types GAEB 90 does not define,
  unusable values, records out of place) do not raise: they are reported
  in ADiagnostics and left out or read as far as they go.
  DE: Liest eine GAEB-90-Datei aus Buffer in ein neues Dokument, das dem
  Aufrufer gehoert. ADetection beschreibt die Eingabe (Format gfDA90,
  SourceVersion VERSDTA, SourcePhase DP; ihr Target bleibt unbekannt),
  ATarget das gelieferte Dokument: GAEB DA XML 3.3, Ausgabe 2021-05, mit
  der Phase der Datei. ADiagnostics darf nil sein. Loest
  ELandrixGaebError aus fuer Eingaben ueber AOptions.MaxSize, Eingaben,
  die kein GAEB 90 sind, eine Datei ohne Satz 00 und eine andere
  Austauschphase als 81 bis 86. Andere Fehler (Satzarten, die GAEB 90
  nicht definiert, unbrauchbare Werte, Saetze an falscher Stelle) loesen
  nichts aus: sie werden in ADiagnostics gemeldet und ausgelassen oder so
  weit wie moeglich gelesen. }
function LandrixGaebDA90ReadBuffer(Buffer: Pointer; Size: Integer;
  const AOptions: TLandrixGaebDA90ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

{ As LandrixGaebDA90ReadBuffer, from the position of AStream to its end;
  AStream must know its Size (a seekable stream), stays with the caller
  and is left at its end. The size limit is checked before anything is
  read.
  DE: Wie LandrixGaebDA90ReadBuffer, ab der Position von AStream bis zu
  seinem Ende; AStream muss seine Groesse kennen (ein positionierbarer
  Stream), bleibt beim Aufrufer und steht danach an seinem Ende. Die
  Groessengrenze wird geprueft, bevor etwas gelesen wird. }
function LandrixGaebDA90ReadStream(AStream: TStream;
  const AOptions: TLandrixGaebDA90ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

{ As LandrixGaebDA90ReadStream for a file, also with the file errors of the
  runtime library (EFOpenError, EReadError).
  DE: Wie LandrixGaebDA90ReadStream fuer eine Datei, auch mit den
  Dateifehlern der Laufzeitbibliothek (EFOpenError, EReadError). }
function LandrixGaebDA90ReadFile(const AFileName: string;
  const AOptions: TLandrixGaebDA90ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

implementation

uses
  LandrixGaebCharsets,
  LandrixGaebDA90Mapping;

function LandrixGaebDA90DefaultReadOptions: TLandrixGaebDA90ReadOptions;
begin
  Result.MaxSize := 0;
  Result.Charset := gcsUnknown;
  Result.OemCodePage := gocCp850;
end;

function OemOf(const AOptions: TLandrixGaebDA90ReadOptions): TLandrixGaebCodePage;
begin
  if AOptions.OemCodePage = gocCp437 then
    Result := gcpCp437
  else
    Result := gcpCp850;
end;

function LandrixGaebDA90ReadBuffer(Buffer: Pointer; Size: Integer;
  const AOptions: TLandrixGaebDA90ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  NoKind: Integer;
begin
  Result := LandrixGaebDA90ReadMapped(Buffer, Size, AOptions.MaxSize, AOptions.Charset,
    OemOf(AOptions), ADiagnostics, nil, NoKind, ADetection, ATarget);
end;

function LandrixGaebDA90ReadStream(AStream: TStream;
  const AOptions: TLandrixGaebDA90ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  NoKind: Integer;
begin
  Result := LandrixGaebDA90ReadMappedStream(AStream, AOptions.MaxSize, AOptions.Charset,
    OemOf(AOptions), ADiagnostics, nil, NoKind, ADetection, ATarget);
end;

function LandrixGaebDA90ReadFile(const AFileName: string;
  const AOptions: TLandrixGaebDA90ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LandrixGaebDA90ReadStream(Stream, AOptions, ADiagnostics, ADetection, ATarget);
  finally
    Stream.Free;
  end;
end;

end.

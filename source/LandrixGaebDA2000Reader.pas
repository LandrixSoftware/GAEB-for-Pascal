{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Reading GAEB DA 2000 files (exchange phases 81 to 86) into the GAEB DA
  XML 3.3 (2021-05) syntax model. The result is the mapping of the file as
  it is: totals the file leaves out stay missing (the bill of quantities
  fills them when loading, see TLandrixGaebBillOfQuantities.LoadFromDA2000File
  and LandrixGaebFillMissingTotals). What the target has no counterpart for
  or is not mapped yet, formatting of texts and unusable values are
  reported in ADiagnostics; the messages name keys and lines, never
  values. Since 1.3.0.

  DE: Lesen von GAEB-DA-2000-Dateien (Austauschphasen 81 bis 86) in das
  Syntaxmodell GAEB DA XML 3.3 (2021-05). Das Ergebnis ist die Abbildung
  der Datei, wie sie ist: Summen, die die Datei auslaesst, bleiben fehlend
  (das LV fuellt sie beim Laden, siehe
  TLandrixGaebBillOfQuantities.LoadFromDA2000File und
  LandrixGaebFillMissingTotals). Was im Ziel kein Gegenstueck hat oder
  noch nicht abgebildet ist, Formatierungen der Texte und unbrauchbare
  Werte werden in ADiagnostics gemeldet; die Meldungen nennen Schluessel
  und Zeilen, nie Werte. Seit 1.3.0. }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixGaebDA2000Reader;

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
  { Options for reading GAEB DA 2000. Always start from
    LandrixGaebDA2000DefaultReadOptions and change single fields: later
    versions add fields.
    DE: Optionen fuer das Lesen von GAEB DA 2000. Immer mit
    LandrixGaebDA2000DefaultReadOptions beginnen und einzelne Felder
    aendern: spaetere Versionen ergaenzen Felder. }
  TLandrixGaebDA2000ReadOptions = record
    { Size limit in bytes; <= 0 means LandrixGaebDefaultMaxSize (default 0).
      DE: Groessengrenze in Byte; <= 0 bedeutet LandrixGaebDefaultMaxSize
      (Standard 0). }
    MaxSize: Int64;
    { Character set of the file. gcsUnknown (default): as declared in
      GAEBInfo/Zeichensatz, ANSI when missing or unknown. gcsAnsi
      (Windows-1252), gcsOem (code page 850) and gcsUnicode (UTF-8)
      override the declaration, e.g. a wrong header. A UTF-8 byte order
      mark always means UTF-8. Detection.SourceCharset stays the declared
      one.
      DE: Zeichensatz der Datei. gcsUnknown (Standard): wie in
      GAEBInfo/Zeichensatz angegeben, ANSI, wenn er fehlt oder unbekannt
      ist. gcsAnsi (Windows-1252), gcsOem (Codepage 850) und gcsUnicode
      (UTF-8) uebersteuern die Angabe, etwa einen falschen Kopf. Eine
      UTF-8-Bytereihenfolgemarke bedeutet immer UTF-8.
      Detection.SourceCharset bleibt der angegebene. }
    Charset: TLandrixGaebCharset;
  end;

{ The default options. DE: Die Standardoptionen. }
function LandrixGaebDA2000DefaultReadOptions: TLandrixGaebDA2000ReadOptions;

{ Reads a GAEB DA 2000 file held in Buffer into a new document the caller
  owns. ADetection describes the input (Format gfDA2000, SourceVersion,
  SourcePhase, SourceCharset; its Target stays unknown), ATarget the
  returned document: GAEB DA XML 3.3, edition 2021-05, with the phase of
  the file. ADiagnostics may be nil.
  Raises ELandrixGaebError for input larger than AOptions.MaxSize, input
  that is no GAEB DA 2000, a file that cannot be read as a whole (no
  #begin[GAEB], ending inside an object or value, nesting too deep), a
  file without the object Vergabe and an exchange phase other than 81 to
  86. Other faults (stray lines, unpaired #end, unusable values) do not
  raise: they are reported in ADiagnostics and left out.
  DE: Liest eine GAEB-DA-2000-Datei aus Buffer in ein neues Dokument, das
  dem Aufrufer gehoert. ADetection beschreibt die Eingabe (Format
  gfDA2000, SourceVersion, SourcePhase, SourceCharset; ihr Target bleibt
  unbekannt), ATarget das gelieferte Dokument: GAEB DA XML 3.3, Ausgabe
  2021-05, mit der Phase der Datei. ADiagnostics darf nil sein. Loest
  ELandrixGaebError aus fuer Eingaben ueber AOptions.MaxSize, Eingaben,
  die kein GAEB DA 2000 sind, eine Datei, die sich nicht als Ganzes lesen
  laesst (kein #begin[GAEB], Ende innerhalb eines Objekts oder Werts, zu
  tiefe Schachtelung), eine Datei ohne Objekt Vergabe und eine andere
  Austauschphase als 81 bis 86. Andere Fehler (verirrte Zeilen, #end ohne
  Gegenstueck, unbrauchbare Werte) loesen nichts aus: sie werden in
  ADiagnostics gemeldet und ausgelassen. }
function LandrixGaebDA2000ReadBuffer(Buffer: Pointer; Size: Integer;
  const AOptions: TLandrixGaebDA2000ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

{ As LandrixGaebDA2000ReadBuffer, from the position of AStream to its end;
  AStream must know its Size (a seekable stream), stays with the caller
  and is left at its end. The size limit is checked before anything is
  read.
  DE: Wie LandrixGaebDA2000ReadBuffer, ab der Position von AStream bis zu
  seinem Ende; AStream muss seine Groesse kennen (ein positionierbarer
  Stream), bleibt beim Aufrufer und steht danach an seinem Ende. Die
  Groessengrenze wird geprueft, bevor etwas gelesen wird. }
function LandrixGaebDA2000ReadStream(AStream: TStream;
  const AOptions: TLandrixGaebDA2000ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

{ As LandrixGaebDA2000ReadStream for a file, also with the file errors of
  the runtime library (EFOpenError, EReadError).
  DE: Wie LandrixGaebDA2000ReadStream fuer eine Datei, auch mit den
  Dateifehlern der Laufzeitbibliothek (EFOpenError, EReadError). }
function LandrixGaebDA2000ReadFile(const AFileName: string;
  const AOptions: TLandrixGaebDA2000ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

implementation

uses
  LandrixGaebDA2000Mapping;

function LandrixGaebDA2000DefaultReadOptions: TLandrixGaebDA2000ReadOptions;
begin
  Result.MaxSize := 0;
  Result.Charset := gcsUnknown;
end;

function LandrixGaebDA2000ReadBuffer(Buffer: Pointer; Size: Integer;
  const AOptions: TLandrixGaebDA2000ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
begin
  Result := LandrixGaebDA2000ReadMapped(Buffer, Size, AOptions.MaxSize, AOptions.Charset,
    ADiagnostics, nil, ADetection, ATarget);
end;

function LandrixGaebDA2000ReadStream(AStream: TStream;
  const AOptions: TLandrixGaebDA2000ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
begin
  Result := LandrixGaebDA2000ReadMappedStream(AStream, AOptions.MaxSize, AOptions.Charset,
    ADiagnostics, nil, ADetection, ATarget);
end;

function LandrixGaebDA2000ReadFile(const AFileName: string;
  const AOptions: TLandrixGaebDA2000ReadOptions; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LandrixGaebDA2000ReadStream(Stream, AOptions, ADiagnostics, ADetection, ATarget);
  finally
    Stream.Free;
  end;
end;

end.

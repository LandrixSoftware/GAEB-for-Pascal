{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Detection of the format family (GAEB DA XML, GAEB DA 2000, GAEB 90) from
  the content, never from the file extension, and for GAEB DA XML of the
  target (version, schema edition, exchange phase). Only the beginning of
  the input is examined; a file larger than the size limit is rejected
  before anything is read.

  DE: Erkennung der Formatfamilie (GAEB DA XML, GAEB DA 2000, GAEB 90) am
  Inhalt, nie an der Dateiendung, und bei GAEB DA XML der Zielangabe
  (Version, Schema-Ausgabe, Austauschphase). Untersucht wird nur der Anfang
  der Eingabe; eine Datei ueber der Groessengrenze wird abgewiesen, bevor
  etwas gelesen wird.

  Diagnostics (rule identifiers):
    GAEB-DET-001 fatal    input larger than the size limit
    GAEB-DET-002 fatal    empty input or format not recognised
    GAEB-DET-003 error    XML with a document type declaration (rejected)
    GAEB-DET-004 error    XML root element is not GAEB
    GAEB-DET-005 error    XML namespace is not a known GAEB namespace
    GAEB-DET-006 warning  DP does not match the namespace phase
    GAEB-DET-007 warning  GAEBInfo/Version does not match the namespace
    GAEB-DET-008 fatal    XML is not well-formed
    GAEB-DET-009 warning  DP or GAEBInfo/Version not found at the beginning
    GAEB-DET-010 information  schema edition not recognised from VersDate
    GAEB-DET-011 warning  DP, Version or VersDate holds child elements instead
                          of a value (not used for the detection)
    GAEB-DET-012 warning  GAEB DA 2000: GAEBInfo/Version missing, not found at
                          the beginning, unusable or not 1.0/1.1/1.2
    GAEB-DET-013 warning  GAEB DA 2000: DP missing, not found at the
                          beginning, unusable or no GAEB DA 2000 phase
    GAEB-DET-014 information  GAEB DA 2000: GAEBInfo/Zeichensatz missing
                          (ANSI is assumed in practice; the reader decides)
    GAEB-DET-015 warning  GAEB DA 2000: Zeichensatz UNICODE (encoding not
                          defined), unknown, unusable or not found at the
                          beginning

  A value of the GAEB DA 2000 header is taken only when it is 1 to 16
  letters, digits or dots on one line; anything else is reported as
  unusable and left empty, so no file content reaches the result.
  DE: Ein Wert aus dem Kopf von GAEB DA 2000 wird nur uebernommen, wenn er
  aus 1 bis 16 Buchstaben, Ziffern oder Punkten auf einer Zeile besteht;
  alles andere wird als unbrauchbar gemeldet und bleibt leer, damit kein
  Dateiinhalt ins Ergebnis gelangt.

  DE: Die Meldungen oben haben dieselben Regelkennungen; die Texte sind
  englisch und enthalten keinen Dateiinhalt. }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixGaebDetect;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebDiagnostics;

const
  { Default size limit for a GAEB file (bytes).
    DE: Standard-Groessengrenze fuer eine GAEB-Datei (Byte). }
  LandrixGaebDefaultMaxSize = 256 * 1024 * 1024;

type
  { Format family. Later releases add values: handle
    unknown values in an else branch and do not store ordinal values.
    DE: Formatfamilie. Spaetere Versionen ergaenzen Werte:
    unbekannte Werte in einem else-Zweig behandeln, keine Ordinalwerte
    speichern. }
  TLandrixGaebFormat = (gfUnknown, gfXml, gfDA2000, gfDA90);

  { Result of a detection. Target is set for GAEB DA XML only; its fields
    stay unknown where the input does not tell. Accepted is False when the
    input must not be processed (size limit, document type declaration,
    not well-formed, unknown format, root element not GAEB, unknown
    namespace).
    DE: Ergebnis einer Erkennung. Target wird nur bei GAEB DA XML gesetzt;
    Felder bleiben unbekannt, wo die Eingabe nichts sagt. Accepted ist
    False, wenn die Eingabe nicht verarbeitet werden darf (Groessengrenze,
    Dokumenttyp-Deklaration, nicht wohlgeformt, Format unbekannt,
    Wurzelelement nicht GAEB, Namespace unbekannt). }
  TLandrixGaebDetection = record
    Format: TLandrixGaebFormat;
    Target: TLandrixGaebTarget;
    { Namespace URI of the XML root element. DE: Namespace-URI des
      XML-Wurzelelements. }
    Namespace: TLandrixXmlUtf8;
    Accepted: Boolean;
    { GAEB DA 2000 only: GAEBInfo/Version as found ('1.0', '1.1', '1.2'),
      '' when missing or unusable. Since 1.3.0.
      DE: Nur GAEB DA 2000: GAEBInfo/Version wie gefunden, '' wenn sie
      fehlt oder unbrauchbar ist. Seit 1.3.0. }
    SourceVersion: string;
    { GAEB DA 2000 only: DP of the main object as found ('83', '88'),
      also for phases this library does not read; '' when missing or
      unusable. Since 1.3.0.
      DE: Nur GAEB DA 2000: DP des Hauptobjekts wie gefunden, auch fuer
      Phasen, die die Bibliothek nicht liest; '' wenn er fehlt oder
      unbrauchbar ist. Seit 1.3.0. }
    SourcePhase: string;
    { GAEB DA 2000 only: declared character set; gcsUnknown when missing,
      unknown or not found at the beginning. Since 1.3.0.
      DE: Nur GAEB DA 2000: angegebener Zeichensatz; gcsUnknown, wenn er
      fehlt, unbekannt ist oder am Anfang nicht gefunden wurde. Seit
      1.3.0. }
    SourceCharset: TLandrixGaebCharset;
  end;

{ Format family from the first bytes only (BOM and leading white space are
  skipped). DE: Formatfamilie nur aus den ersten Bytes (BOM und fuehrender
  Leerraum werden uebersprungen). }
function LandrixGaebDetectFormat(Buffer: Pointer; Size: Integer): TLandrixGaebFormat;

{ Detection on a buffer that holds the whole input, or only its beginning
  when AIsPrefix is True: then a character or element cut off at the end of
  the buffer is not reported as an error. ADiagnostics may be nil.
  DE: Erkennung auf einem Puffer mit der ganzen Eingabe oder, wenn
  AIsPrefix True ist, nur ihrem Anfang: dann gilt ein am Pufferende
  abgeschnittenes Zeichen oder Element nicht als Fehler. ADiagnostics darf
  nil sein. }
function LandrixGaebDetectBuffer(Buffer: Pointer; Size: Integer; AIsPrefix: Boolean;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDetection;

{ Detection on a stream from its current position; the stream position is
  restored. AMaxSize <= 0 means LandrixGaebDefaultMaxSize. The stream must
  be seekable (Size and Position are used).
  DE: Erkennung auf einem Stream ab der aktuellen Position; die Position
  wird wiederhergestellt. AMaxSize <= 0 bedeutet
  LandrixGaebDefaultMaxSize. Der Stream muss positionierbar sein (Size und
  Position werden benutzt). }
function LandrixGaebDetectStream(AStream: TStream;
  ADiagnostics: TLandrixGaebDiagnostics; AMaxSize: Int64): TLandrixGaebDetection;

{ Detection on a file. DE: Erkennung auf einer Datei. }
function LandrixGaebDetectFile(const AFileName: string;
  ADiagnostics: TLandrixGaebDiagnostics; AMaxSize: Int64): TLandrixGaebDetection;

{ Name of a format family ('GAEB DA XML', 'GAEB DA 2000', 'GAEB 90',
  'unknown'). DE: Name einer Formatfamilie. }
function LandrixGaebFormatToStr(AFormat: TLandrixGaebFormat): string;

implementation

uses
  LandrixXmlReader;

const
  { Number of bytes examined for detection. }
  DetectPrefixSize = 1024 * 1024;

const
  NamespacePrefix = 'http://www.gaeb.de/GAEB_DA_XML/';

procedure AddDiag(ADiagnostics: TLandrixGaebDiagnostics; const ARuleId: string;
  ASeverity: TLandrixGaebSeverity; ALine, AColumn: Integer; AOffset: Int64;
  const AMessage: string);
begin
  if ADiagnostics <> nil then
    ADiagnostics.AddAt(ARuleId, ASeverity, '', ALine, AColumn, AOffset, AMessage);
end;

function LandrixGaebFormatToStr(AFormat: TLandrixGaebFormat): string;
begin
  case AFormat of
    gfXml: Result := 'GAEB DA XML';
    gfDA2000: Result := 'GAEB DA 2000';
    gfDA90: Result := 'GAEB 90';
  else
    Result := 'unknown';
  end;
end;

function IsDigit(C: AnsiChar): Boolean;
begin
  Result := (C >= '0') and (C <= '9');
end;

{ True if Line (without line end) looks like a GAEB 90 record: 80 columns,
  record number in columns 75-80, record type in columns 1-2 (two digits,
  or T and a digit for the text records T0/T1/T9). }
function IsDA90Record(P: PAnsiChar; Len: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Len <> 80 then
    Exit;
  for I := 74 to 79 do
    if not IsDigit(P[I]) then
      Exit;
  Result := (IsDigit(P[0]) or (P[0] = 'T')) and IsDigit(P[1]);
end;

{ Lower-case code of an ASCII letter, other bytes unchanged. }
function LowerAscii(C: AnsiChar): Integer;
begin
  Result := Ord(C);
  if (C >= 'A') and (C <= 'Z') then
    Inc(Result, 32);
end;

function LandrixGaebDetectFormat(Buffer: Pointer; Size: Integer): TLandrixGaebFormat;
const
  BeginTag = '#begin[gaeb]';
var
  P, Stop, LineStart: PAnsiChar;
  I, Lines, Matches: Integer;
  Same: Boolean;
begin
  Result := gfUnknown;
  if Size <= 0 then
    Exit;
  P := PAnsiChar(Buffer);
  Stop := P + Size;
  { UTF-16 byte order mark: only XML is possible }
  if (Size >= 2) and (((P[0] = #$FF) and (P[1] = #$FE)) or ((P[0] = #$FE) and (P[1] = #$FF))) then
  begin
    I := 2;
    while I + 1 < Size do
    begin
      if (P[I] = '<') or (P[I + 1] = '<') then
      begin
        Result := gfXml;
        Exit;
      end;
      if not ((P[I] in [#0, ' ', #9, #10, #13]) and (P[I + 1] in [#0, ' ', #9, #10, #13])) then
        Exit;
      Inc(I, 2);
    end;
    Exit;
  end;
  { UTF-8 byte order mark }
  if (Size >= 3) and (P[0] = #$EF) and (P[1] = #$BB) and (P[2] = #$BF) then
    Inc(P, 3);
  while (P < Stop) and (P^ in [' ', #9, #10, #13]) do
    Inc(P);
  if P >= Stop then
    Exit;
  if P^ = '<' then
  begin
    Result := gfXml;
    Exit;
  end;
  { GAEB DA 2000: "#begin[GAEB]" (keywords are case-insensitive) }
  if Stop - P >= Length(BeginTag) then
  begin
    Same := True;
    for I := 1 to Length(BeginTag) do
      if LowerAscii(P[I - 1]) <> Ord(BeginTag[I]) then
      begin
        Same := False;
        Break;
      end;
    if Same then
    begin
      Result := gfDA2000;
      Exit;
    end;
  end;
  { GAEB 90: records of 80 columns; CR, LF and NUL separate records (NUL
    glued records occur in practice). One of the first five lines must be a
    record: parts of split files may start with a foreign line. }
  P := PAnsiChar(Buffer);
  Lines := 0;
  Matches := 0;
  LineStart := P;
  while (P <= Stop) and (Lines < 5) do
  begin
    if (P = Stop) or (P^ in [#0, #10, #13, #26]) then
    begin
      if P > LineStart then
      begin
        Inc(Lines);
        if IsDA90Record(LineStart, Integer(P - LineStart)) then
          Inc(Matches);
      end;
      LineStart := P + 1;
    end;
    Inc(P);
  end;
  if Matches > 0 then
    Result := gfDA90;
end;

{ Splits a 3.2+ namespace '.../DA<suffix>/<version>' into its parts. }
function SplitNamespace(const Ns: string; out Suffix, VersionText: string): Boolean;
var
  Rest: string;
  Slash: Integer;
begin
  Result := False;
  Suffix := '';
  VersionText := '';
  if Copy(Ns, 1, Length(NamespacePrefix) + 2) <> NamespacePrefix + 'DA' then
    Exit;
  Rest := Copy(Ns, Length(NamespacePrefix) + 3, MaxInt);
  Slash := Pos('/', Rest);
  if Slash <= 1 then
    Exit;
  Suffix := Copy(Rest, 1, Slash - 1);
  VersionText := Copy(Rest, Slash + 1, MaxInt);
  Result := VersionText <> '';
end;

{ Length of a prefix that does not end inside a character: drops an
  incomplete UTF-8 sequence, or for UTF-16 an odd byte and a trailing high
  surrogate. LandrixXml checks the encoding of the whole buffer. }
function CharBoundary(P: PAnsiChar; Size: Integer): Integer;
var
  I, Need: Integer;
  B: Byte;
  Utf16LE, Utf16BE: Boolean;
begin
  Result := Size;
  if Size < 2 then
    Exit;
  Utf16LE := ((P[0] = #$FF) and (P[1] = #$FE)) or ((P[0] = '<') and (P[1] = #0));
  Utf16BE := ((P[0] = #$FE) and (P[1] = #$FF)) or ((P[0] = #0) and (P[1] = '<'));
  if Utf16LE or Utf16BE then
  begin
    Result := Size - Size mod 2;
    if Utf16LE then
      B := Ord(P[Result - 1])
    else
      B := Ord(P[Result - 2]);
    if (B and $FC) = $D8 then
      Dec(Result, 2);
    Exit;
  end;
  I := Size - 1;
  while (I > 0) and (Size - I <= 3) and ((Ord(P[I]) and $C0) = $80) do
    Dec(I);
  B := Ord(P[I]);
  if B >= $C0 then
  begin
    if B >= $F0 then
      Need := 4
    else if B >= $E0 then
      Need := 3
    else
      Need := 2;
    if I + Need > Size then
      Result := I;
  end;
end;

{ Namespace suffix of a phase ('50' for 50.1 and 50.2). }
function PhaseSuffix(APhase: TLandrixGaebPhase): string;
var
  S: string;
  Dot: Integer;
begin
  S := LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(APhase));
  Dot := Pos('.', S);
  if Dot > 0 then
    S := Copy(S, 1, Dot - 1);
  Result := S;
end;

procedure DetectXml(Buffer: Pointer; Size: Integer; AIsPrefix: Boolean;
  ADiagnostics: TLandrixGaebDiagnostics;
  var R: TLandrixGaebDetection);
var
  Reader: TLandrixXmlReader;
  RootSeen, InInfo, Done: Boolean;
  VersionText, VersDateText, DPText, Ns, Suffix, NsVersion: string;
  NsKnown: Boolean;
  Local: TLandrixXmlUtf8;
  NsVersionValue: TLandrixGaebVersion;
  DPPhase: TLandrixGaebPhase;

  { The value of the current element; an element with child elements is
    well-formed XML but no value: GAEB-DET-011, '' }
  function ElementText(const AName: string): string;
  begin
    try
      Result := LandrixXmlUtf8ToString(Reader.ReadElementTextUtf8);
    except
      on E: ELandrixXmlError do
      begin
        if E.Code <> xecUnexpectedElement then
          raise;
        AddDiag(ADiagnostics, 'GAEB-DET-011', gsWarning, E.Line, E.Column, E.Offset,
          'element ' + AName + ' holds child elements instead of a value; not used for the detection');
        Result := '';
      end;
    end;
  end;

begin
  RootSeen := False;
  InInfo := False;
  Done := False;
  VersionText := '';
  VersDateText := '';
  DPText := '';
  if AIsPrefix then
    Size := CharBoundary(PAnsiChar(Buffer), Size);
  Reader := TLandrixXmlReader.Create;
  try
    try
      Reader.LoadFromBuffer(PAnsiChar(Buffer)^, Size);
      while (not Done) and Reader.Read do
        case Reader.TokenType of
          xttDocumentType:
            begin
              AddDiag(ADiagnostics, 'GAEB-DET-003', gsError, Reader.Line, Reader.Column,
                Reader.Offset, 'document type declaration is not allowed in GAEB DA XML');
              R.Accepted := False;
              Exit;
            end;
          xttStartElement:
            begin
              Local := Reader.LocalNameUtf8;
              if not RootSeen then
              begin
                RootSeen := True;
                R.Namespace := Reader.NamespaceUriUtf8;
                if Local <> 'GAEB' then
                begin
                  AddDiag(ADiagnostics, 'GAEB-DET-004', gsError, Reader.Line,
                    Reader.Column, Reader.Offset, 'root element is not GAEB');
                  R.Accepted := False;
                  Exit;
                end;
              end
              else if Reader.NamespaceUriUtf8 <> R.Namespace then
                { elements of other namespaces (vendor extensions) are not
                  part of the detection }
                Reader.Skip
              else if Reader.Depth = 1 then
              begin
                { DP in GAEBInfo (X61) is complete once GAEBInfo is left }
                if (DPText <> '') and (Local <> 'GAEBInfo') then
                  Done := True;
                InInfo := Local = 'GAEBInfo';
              end
              else if (Reader.Depth = 2) and InInfo and (Local = 'DP') then
                { 3.3 X61 (beta) carries DP in GAEBInfo }
                DPText := ElementText('DP')
              else if (Reader.Depth = 2) and InInfo and (Local = 'Version') then
                VersionText := ElementText('Version')
              else if (Reader.Depth = 2) and InInfo and (Local = 'VersDate') then
                VersDateText := ElementText('VersDate')
              else if (Reader.Depth = 2) and (not InInfo) and (Local = 'DP') then
              begin
                DPText := ElementText('DP');
                Done := True;
              end;
            end;
        else
          ;
        end;
    except
      on E: ELandrixXmlError do
      begin
        { an error caused by the end of a truncated prefix is not an error
          of the input; genuine errors after the root element in a prefix
          are left to the full read }
        if (not AIsPrefix) or not RootSeen then
        begin
          AddDiag(ADiagnostics, 'GAEB-DET-008', gsFatal, E.Line, E.Column,
            E.Offset, 'not well-formed XML: ' + E.Message);
          R.Accepted := False;
          Exit;
        end;
      end;
    end;
  finally
    Reader.Free;
  end;

  if not RootSeen then
  begin
    AddDiag(ADiagnostics, 'GAEB-DET-002', gsFatal, 0, 0, -1, 'no root element found');
    R.Accepted := False;
    Exit;
  end;

  { version: from the namespace (3.2+) or from GAEBInfo/Version (3.0/3.1) }
  Ns := LandrixXmlUtf8ToString(R.Namespace);
  NsKnown := False;
  Suffix := '';
  if (Ns = NamespacePrefix + '200407') or (Ns = NamespacePrefix + '200706') then
  begin
    NsKnown := True;
    R.Target.Version := LandrixGaebVersionFromText(LandrixXmlStringToUtf8(VersionText));
    if not (R.Target.Version in [gv30, gv31]) then
    begin
      { 200706 is used by 3.1 only; for 200407 the version stays open }
      if Ns = NamespacePrefix + '200706' then
        R.Target.Version := gv31
      else
        R.Target.Version := gvUnknown;
      if VersionText <> '' then
        AddDiag(ADiagnostics, 'GAEB-DET-007', gsWarning, 0, 0, -1,
          'GAEBInfo/Version does not match the namespace of GAEB DA XML 3.0/3.1');
    end;
  end
  else if SplitNamespace(Ns, Suffix, NsVersion) then
  begin
    NsVersionValue := LandrixGaebVersionFromText(LandrixXmlStringToUtf8(NsVersion));
    if NsVersionValue in [gv32, gv33, gv34] then
    begin
      NsKnown := True;
      R.Target.Version := NsVersionValue;
      if (VersionText <> '') and (LandrixGaebVersionFromText(LandrixXmlStringToUtf8(VersionText)) <> NsVersionValue) then
        AddDiag(ADiagnostics, 'GAEB-DET-007', gsWarning, 0, 0, -1,
          'GAEBInfo/Version does not match the namespace version');
    end;
  end;
  if not NsKnown then
  begin
    AddDiag(ADiagnostics, 'GAEB-DET-005', gsError, 0, 0, -1,
      'unknown namespace of the GAEB root element: ' + Ns);
    R.Accepted := False;
    Exit;
  end;

  { phase: DP decides (50.1/50.2 share one namespace), the namespace
    suffix must agree }
  DPPhase := LandrixGaebPhaseFromDP(LandrixXmlStringToUtf8(DPText));
  if DPPhase <> gpUnknown then
  begin
    R.Target.Phase := DPPhase;
    if (Suffix <> '') and (PhaseSuffix(DPPhase) <> Suffix) then
      AddDiag(ADiagnostics, 'GAEB-DET-006', gsWarning, 0, 0, -1,
        'DP ' + LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(DPPhase)) + ' does not match the namespace phase DA' + Suffix);
  end
  else
  begin
    if Suffix <> '' then
      R.Target.Phase := LandrixGaebPhaseFromDP(LandrixXmlStringToUtf8(Suffix));
    AddDiag(ADiagnostics, 'GAEB-DET-009', gsWarning, 0, 0, -1,
      'DP not found or not recognised at the beginning of the document');
  end;
  if VersionText = '' then
    AddDiag(ADiagnostics, 'GAEB-DET-009', gsWarning, 0, 0, -1,
      'GAEBInfo/Version not found at the beginning of the document');

  { edition: 3.0 and 3.1/2007-11 leave VersDate free (official samples
    carry 2004-08 and 2007-06); only 3.1/2009-12 fixes it }
  case R.Target.Version of
    gv30:
      R.Target.Edition := ge2004_07;
    gv31:
      if Trim(VersDateText) = '2009-12' then
        R.Target.Edition := ge2009_12
      else
        R.Target.Edition := ge2007_11;
  else
    R.Target.Edition := LandrixGaebEditionFromText(LandrixXmlStringToUtf8(VersDateText));
  end;
  if (R.Target.Edition = geUnknown) and (VersDateText <> '') then
    AddDiag(ADiagnostics, 'GAEB-DET-010', gsInformation, 0, 0, -1,
      'schema edition not recognised from VersDate');
end;

{ Every field of R, on every return path. }
procedure InitDetection(out R: TLandrixGaebDetection; AFormat: TLandrixGaebFormat);
begin
  R.Format := AFormat;
  R.Target := LandrixGaebTarget(gvUnknown, geUnknown, gpUnknown);
  R.Namespace := '';
  R.Accepted := AFormat <> gfUnknown;
  R.SourceVersion := '';
  R.SourcePhase := '';
  R.SourceCharset := gcsUnknown;
end;

{ True if P[0..Len-1] equals S ignoring ASCII case; S is lower case. }
function SameTextAt(P: PAnsiChar; Len: Integer; const S: string): Boolean;
var
  I: Integer;
begin
  Result := Len = Length(S);
  if not Result then
    Exit;
  for I := 1 to Len do
    if LowerAscii(P[I - 1]) <> Ord(S[I]) then
    begin
      Result := False;
      Exit;
    end;
end;

{ Index of the first '[end]' (any case) in P[0..Len-1], -1 if none. }
function FindEndMark(P: PAnsiChar; Len: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Len - 5 do
    if (P[I] = '[') and SameTextAt(P + I + 1, 4, 'end]') then
    begin
      Result := I;
      Exit;
    end;
end;

const
  { Longest header value taken into the detection result. }
  MaxSourceValue = 16;

  ValueEmpty = 0;
  ValueUsable = 1;
  ValueUnusable = 2;

{ Value P[0..Len-1] trimmed: ValueEmpty, ValueUsable (AValue set: 1 to
  MaxSourceValue letters, digits or dots) or ValueUnusable. }
function HeaderValue(P: PAnsiChar; Len: Integer; out AValue: string): Integer;
var
  I: Integer;
begin
  AValue := '';
  while (Len > 0) and (P^ in [' ', #9]) do
  begin
    Inc(P);
    Dec(Len);
  end;
  while (Len > 0) and (P[Len - 1] in [' ', #9]) do
    Dec(Len);
  if Len = 0 then
  begin
    Result := ValueEmpty;
    Exit;
  end;
  Result := ValueUnusable;
  if Len > MaxSourceValue then
    Exit;
  for I := 0 to Len - 1 do
    if not (P[I] in ['0'..'9', 'A'..'Z', 'a'..'z', '.']) then
      Exit;
  for I := 0 to Len - 1 do
    AValue := AValue + Char(P[I]);
  Result := ValueUsable;
end;

{ True if S is a phase of GAEB DA 2000, read or not. }
function IsDA2000Phase(const S: string): Boolean;
begin
  Result := (S = '40') or (S = '50') or (S = '51') or (S = '61') or (S = '71') or
    (S = '80') or (S = '81') or (S = '82') or (S = '83') or (S = '84') or
    (S = '85') or (S = '86') or (S = '88') or (S = '89') or (S = '93') or
    (S = '94') or (S = '96') or (S = '97');
end;

{ Reads the header of a GAEB DA 2000 file: GAEBInfo/Version,
  GAEBInfo/Zeichensatz and DP of the main object (Vergabe, LVKatalog, ...).
  A line-based scan of the structure only; values spanning lines are
  skipped, a closing #end that does not match the open object is ignored.
  The first occurrence counts, an empty one as missing. Messages name the
  element, never its value. }
procedure DetectDA2000(Buffer: Pointer; Size: Integer; AIsPrefix: Boolean;
  ADiagnostics: TLandrixGaebDiagnostics; var R: TLandrixGaebDetection);
const
  KindOther = 0;
  KindInfo = 1;
  KindMain = 2;
  { nesting depth followed; deeper input ends the scan as incomplete }
  MaxNames = 64;
var
  P, Stop, LineStart, LineEnd, Q, KeyStart: PAnsiChar;
  Depth, LineNo, Len, Close, Mark, Kind, State: Integer;
  InValue, InfoClosed, InfoPassed, MainDone, Incomplete: Boolean;
  VersionSeen, PhaseSeen, CharsetSeen: Boolean;
  Value, Name: string;
  Names: array[1..MaxNames] of string;

  procedure Report(const ARuleId: string; ASeverity: TLandrixGaebSeverity;
    const AMessage: string);
  begin
    AddDiag(ADiagnostics, ARuleId, ASeverity, LineNo, Integer(Q - LineStart) + 1,
      Q - PAnsiChar(Buffer), AMessage);
  end;

  function KeyIs(const S: string): Boolean;
  begin
    Result := SameTextAt(KeyStart, Close - 1, S);
  end;

  { Lower-case name of #begin[...] / #end[...] from index AStart of the
    line; '' if it has no closing bracket. An empty name never matches. }
  function BlockName(AStart: Integer): string;
  var
    I, Stop2: Integer;
  begin
    Result := '';
    Stop2 := AStart;
    while (Stop2 < Len) and (Q[Stop2] <> ']') do
      Inc(Stop2);
    if Stop2 >= Len then
      Exit;
    SetLength(Result, Stop2 - AStart);
    for I := AStart to Stop2 - 1 do
      Result[I - AStart + 1] := Char(LowerAscii(Q[I]));
  end;

  { True for the objects that carry DP as their first element. }
  function IsMainObject(const AName: string): Boolean;
  begin
    Result := (AName = 'vergabe') or (AName = 'lvkatalog') or (AName = 'katalog') or
      (AName = 'kosterm') or (AName = 'raumbuch') or (AName = 'ablaufplanung') or
      (AName = 'rechnung') or (AName = 'bestellung');
  end;

begin
  P := PAnsiChar(Buffer);
  Stop := P + Size;
  if (Size >= 3) and (P[0] = #$EF) and (P[1] = #$BB) and (P[2] = #$BF) then
    Inc(P, 3);
  Depth := 0;
  LineNo := 0;
  Kind := KindOther;
  InValue := False;
  InfoClosed := False;
  InfoPassed := False;
  MainDone := False;
  Incomplete := AIsPrefix;
  VersionSeen := False;
  PhaseSeen := False;
  CharsetSeen := False;
  while P < Stop do
  begin
    LineStart := P;
    while (P < Stop) and not (P^ in [#10, #13]) do
      Inc(P);
    LineEnd := P;
    if (P < Stop) and (P^ = #13) then
      Inc(P);
    if (P < Stop) and (P^ = #10) then
      Inc(P);
    Inc(LineNo);
    { the last line of a prefix may be cut off }
    if AIsPrefix and (LineEnd = Stop) then
      Break;
    Q := LineStart;
    while (Q < LineEnd) and (Q^ in [' ', #9]) do
      Inc(Q);
    Len := Integer(LineEnd - Q);
    if InValue then
    begin
      InValue := FindEndMark(Q, Len) < 0;
      Continue;
    end;
    if (Len = 0) or ((Len >= 2) and (Q[0] = '#') and (Q[1] = '#')) then
      Continue;
    if (Len >= 7) and SameTextAt(Q, 7, '#begin[') then
    begin
      Name := BlockName(7);
      if Depth >= MaxNames then
      begin
        Incomplete := True;
        Break;
      end;
      Inc(Depth);
      Names[Depth] := Name;
      if Depth = 2 then
        if Name = 'gaebinfo' then
          Kind := KindInfo
        else
        begin
          { GAEBInfo comes first: behind it, it is not searched for }
          InfoPassed := True;
          if IsMainObject(Name) then
            Kind := KindMain
          else
            Kind := KindOther;
        end;
      Continue;
    end;
    if (Len >= 5) and SameTextAt(Q, 5, '#end[') then
    begin
      Name := BlockName(5);
      if (Depth > 0) and (Name <> '') and (Names[Depth] = Name) then
      begin
        if Depth = 2 then
        begin
          if Kind = KindInfo then
            InfoClosed := True
          else if Kind = KindMain then
            MainDone := True;
          Kind := KindOther;
        end;
        Dec(Depth);
      end;
      if (InfoClosed or InfoPassed) and (PhaseSeen or MainDone) then
        Break;
      Continue;
    end;
    if Q[0] <> '[' then
      Continue;
    Close := 1;
    while (Close < Len) and (Q[Close] <> ']') do
      Inc(Close);
    if Close >= Len then
      Continue;
    KeyStart := Q + 1;
    Mark := FindEndMark(Q + Close + 1, Len - Close - 1);
    if Mark < 0 then
    begin
      InValue := True;
      State := ValueUnusable;
      Value := '';
    end
    else
      State := HeaderValue(Q + Close + 1, Mark, Value);
    if Depth <> 2 then
      Continue;
    if (Kind = KindInfo) and (not VersionSeen) and KeyIs('version') then
    begin
      VersionSeen := True;
      if State = ValueEmpty then
        Report('GAEB-DET-012', gsWarning, 'GAEBInfo/Version is empty')
      else if State = ValueUnusable then
        Report('GAEB-DET-012', gsWarning, 'GAEBInfo/Version is not a usable value')
      else
      begin
        R.SourceVersion := Value;
        if (Value <> '1.0') and (Value <> '1.1') and (Value <> '1.2') then
          Report('GAEB-DET-012', gsWarning,
            'GAEBInfo/Version is not a GAEB DA 2000 version (1.0, 1.1, 1.2)');
      end;
    end
    else if (Kind = KindInfo) and (not CharsetSeen) and KeyIs('zeichensatz') then
    begin
      CharsetSeen := True;
      Value := UpperCase(Value);
      if State = ValueEmpty then
        Report('GAEB-DET-014', gsInformation,
          'GAEBInfo/Zeichensatz is empty; ANSI is assumed in practice')
      else if State = ValueUnusable then
        Report('GAEB-DET-015', gsWarning, 'GAEBInfo/Zeichensatz is not a usable value')
      else if Value = 'ANSI' then
        R.SourceCharset := gcsAnsi
      else if Value = 'OEM' then
        R.SourceCharset := gcsOem
      else if Value = 'UNICODE' then
      begin
        R.SourceCharset := gcsUnicode;
        Report('GAEB-DET-015', gsWarning,
          'Zeichensatz UNICODE does not define an encoding; the reader decides');
      end
      else
        Report('GAEB-DET-015', gsWarning, 'Zeichensatz is not known (ANSI, OEM, UNICODE)');
    end
    else if (Kind = KindMain) and (not PhaseSeen) and KeyIs('dp') then
    begin
      PhaseSeen := True;
      if State = ValueEmpty then
        Report('GAEB-DET-013', gsWarning, 'DP is empty')
      else if State = ValueUnusable then
        Report('GAEB-DET-013', gsWarning, 'DP is not a usable value')
      else
      begin
        R.SourcePhase := Value;
        if not IsDA2000Phase(Value) then
          Report('GAEB-DET-013', gsWarning, 'DP is not a GAEB DA 2000 phase');
      end;
    end;
    if (InfoClosed or InfoPassed) and PhaseSeen then
      Break;
  end;

  { "missing" only where the scan saw the whole block or the whole input }
  if not VersionSeen then
    if InfoClosed or not Incomplete then
      AddDiag(ADiagnostics, 'GAEB-DET-012', gsWarning, 0, 0, -1, 'GAEBInfo/Version missing')
    else
      AddDiag(ADiagnostics, 'GAEB-DET-012', gsWarning, 0, 0, -1,
        'GAEBInfo/Version not found at the beginning of the document');
  if not CharsetSeen then
    if InfoClosed or not Incomplete then
      AddDiag(ADiagnostics, 'GAEB-DET-014', gsInformation, 0, 0, -1,
        'GAEBInfo/Zeichensatz missing; ANSI is assumed in practice')
    else
      AddDiag(ADiagnostics, 'GAEB-DET-015', gsWarning, 0, 0, -1,
        'GAEBInfo/Zeichensatz not found at the beginning of the document');
  if not PhaseSeen then
    if MainDone or not Incomplete then
      AddDiag(ADiagnostics, 'GAEB-DET-013', gsWarning, 0, 0, -1, 'DP missing')
    else
      AddDiag(ADiagnostics, 'GAEB-DET-013', gsWarning, 0, 0, -1,
        'DP not found at the beginning of the document');
end;

function LandrixGaebDetectBuffer(Buffer: Pointer; Size: Integer; AIsPrefix: Boolean;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDetection;
begin
  InitDetection(Result, LandrixGaebDetectFormat(Buffer, Size));
  case Result.Format of
    gfUnknown:
      if Size <= 0 then
        AddDiag(ADiagnostics, 'GAEB-DET-002', gsFatal, 0, 0, -1, 'empty input')
      else
        AddDiag(ADiagnostics, 'GAEB-DET-002', gsFatal, 0, 0, -1,
          'format not recognised (neither GAEB DA XML, GAEB DA 2000 nor GAEB 90)');
    gfXml:
      DetectXml(Buffer, Size, AIsPrefix, ADiagnostics, Result);
    gfDA2000:
      DetectDA2000(Buffer, Size, AIsPrefix, ADiagnostics, Result);
  else
    ;
  end;
end;

function LandrixGaebDetectStream(AStream: TStream;
  ADiagnostics: TLandrixGaebDiagnostics; AMaxSize: Int64): TLandrixGaebDetection;
var
  Start, Remaining: Int64;
  Buffer: AnsiString;
  Count: Integer;
begin
  if AMaxSize <= 0 then
    AMaxSize := LandrixGaebDefaultMaxSize;
  Start := AStream.Position;
  Remaining := AStream.Size - Start;
  if Remaining > AMaxSize then
  begin
    InitDetection(Result, gfUnknown);
    AddDiag(ADiagnostics, 'GAEB-DET-001', gsFatal, 0, 0, -1,
      'input of ' + IntToStr(Remaining) + ' bytes exceeds the size limit of ' +
      IntToStr(AMaxSize) + ' bytes');
    Exit;
  end;
  if Remaining > DetectPrefixSize then
    Count := DetectPrefixSize
  else
    Count := Integer(Remaining);
  Buffer := '';
  SetLength(Buffer, Count);
  if Count > 0 then
    Count := Integer(AStream.Read(Buffer[1], Count));
  AStream.Position := Start;
  Result := LandrixGaebDetectBuffer(Pointer(Buffer), Count, Remaining > Count,
    ADiagnostics);
end;

function LandrixGaebDetectFile(const AFileName: string;
  ADiagnostics: TLandrixGaebDiagnostics; AMaxSize: Int64): TLandrixGaebDetection;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LandrixGaebDetectStream(Stream, ADiagnostics, AMaxSize);
  finally
    Stream.Free;
  end;
end;

end.

{
  GAEB-for-pascal

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

  DE: Die Meldungen oben haben dieselben Regelkennungen; die Texte sind
  englisch und enthalten keinen Dateiinhalt. }

{ API: internal. May change in any release before 1.0.
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern. }

unit LandrixGaebDetect;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixXmlReader,
  LandrixGaebTypes,
  LandrixGaebDiagnostics;

const
  { Default size limit for a GAEB file (bytes).
    DE: Standard-Groessengrenze fuer eine GAEB-Datei (Byte). }
  LandrixGaebDefaultMaxSize = 256 * 1024 * 1024;

  { Number of bytes examined for detection.
    DE: Anzahl der Bytes, die fuer die Erkennung untersucht werden. }
  LandrixGaebDetectPrefixSize = 1024 * 1024;

type
  { Format family. DE: Formatfamilie. }
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
                DPText := LandrixXmlUtf8ToString(Reader.ReadElementTextUtf8)
              else if (Reader.Depth = 2) and InInfo and (Local = 'Version') then
                VersionText := LandrixXmlUtf8ToString(Reader.ReadElementTextUtf8)
              else if (Reader.Depth = 2) and InInfo and (Local = 'VersDate') then
                VersDateText := LandrixXmlUtf8ToString(Reader.ReadElementTextUtf8)
              else if (Reader.Depth = 2) and (not InInfo) and (Local = 'DP') then
              begin
                DPText := LandrixXmlUtf8ToString(Reader.ReadElementTextUtf8);
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

function LandrixGaebDetectBuffer(Buffer: Pointer; Size: Integer; AIsPrefix: Boolean;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDetection;
begin
  Result.Format := LandrixGaebDetectFormat(Buffer, Size);
  Result.Target := LandrixGaebTarget(gvUnknown, geUnknown, gpUnknown);
  Result.Namespace := '';
  Result.Accepted := Result.Format <> gfUnknown;
  case Result.Format of
    gfUnknown:
      if Size <= 0 then
        AddDiag(ADiagnostics, 'GAEB-DET-002', gsFatal, 0, 0, -1, 'empty input')
      else
        AddDiag(ADiagnostics, 'GAEB-DET-002', gsFatal, 0, 0, -1,
          'format not recognised (neither GAEB DA XML, GAEB DA 2000 nor GAEB 90)');
    gfXml:
      DetectXml(Buffer, Size, AIsPrefix, ADiagnostics, Result);
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
    Result.Format := gfUnknown;
    Result.Target := LandrixGaebTarget(gvUnknown, geUnknown, gpUnknown);
    Result.Namespace := '';
    Result.Accepted := False;
    AddDiag(ADiagnostics, 'GAEB-DET-001', gsFatal, 0, 0, -1,
      'input of ' + IntToStr(Remaining) + ' bytes exceeds the size limit of ' +
      IntToStr(AMaxSize) + ' bytes');
    Exit;
  end;
  if Remaining > LandrixGaebDetectPrefixSize then
    Count := LandrixGaebDetectPrefixSize
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

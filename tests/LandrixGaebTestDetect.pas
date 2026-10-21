{
  GAEB-for-pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of LandrixGaebDetect: synthetic samples, and the local corpus under
  tests/data/local (skipped when missing). The local tests print file names
  and results only, never file content. }

unit LandrixGaebTestDetect;

{$I LandrixGaeb.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlReader,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebTestFramework;

const
  CRLF = #13#10;

{ A GAEB 90 record: record type, content, record number in columns 75-80. }
function Record90(const TypeAndText: AnsiString; Number: Integer): AnsiString;
var
  Num: AnsiString;
begin
  Result := TypeAndText;
  while Length(Result) < 74 do
    Result := Result + ' ';
  Result := Copy(Result, 1, 74);
  Num := '';
  repeat
    Num := AnsiChar(Ord('0') + Number mod 10) + Num;
    Number := Number div 10;
  until Number = 0;
  while Length(Num) < 6 do
    Num := '0' + Num;
  Result := Result + Num;
end;

function Detect(const S: AnsiString; Diags: TLandrixGaebDiagnostics): TLandrixGaebDetection;
begin
  if S = '' then
    Result := LandrixGaebDetectBuffer(nil, 0, False, Diags)
  else
    Result := LandrixGaebDetectBuffer(Pointer(S), Length(S), False, Diags);
end;

{ A minimal GAEB DA XML document whose DP sits in the element Container. }
function XmlIn(const Ns, Version, VersDate, Container, DP: AnsiString): AnsiString;
begin
  Result := '<?xml version="1.0" encoding="UTF-8"?>' + CRLF +
    '<GAEB xmlns="' + Ns + '">' + CRLF +
    '  <GAEBInfo><Version>' + Version + '</Version><VersDate>' + VersDate +
    '</VersDate><ProgSystem>Test</ProgSystem></GAEBInfo>' + CRLF +
    '  <PrjInfo><NamePrj>P</NamePrj></PrjInfo>' + CRLF +
    '  <' + Container + '><DP>' + DP + '</DP></' + Container + '>' + CRLF +
    '</GAEB>' + CRLF;
end;

function Xml(const Ns, Version, VersDate, DP: AnsiString): AnsiString;
begin
  Result := XmlIn(Ns, Version, VersDate, 'Award', DP);
end;

procedure TestFormatFirstBytes;
var
  S: AnsiString;
begin
  S := '';
  Check(LandrixGaebDetectFormat(nil, 0) = gfUnknown, 'empty');
  S := '<?xml version="1.0"?><GAEB/>';
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfXml, 'XML');
  S := #$EF#$BB#$BF + '  ' + CRLF + '<GAEB/>';
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfXml, 'XML with UTF-8 BOM and white space');
  S := #$FF#$FE + '<'#0'G'#0;
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfXml, 'XML in UTF-16 LE');
  S := '#begin[GAEB]' + CRLF + '  #begin[GAEBInfo]' + CRLF;
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfDA2000, 'GAEB 2000');
  S := '#BEGIN[GAEB]' + CRLF;
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfDA2000, 'GAEB 2000 keywords are case-insensitive');
  S := Record90('00        83', 1) + CRLF + Record90('01Test', 2) + CRLF;
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfDA90, 'GAEB 90');
  S := Record90('T0', 1) + CRLF + Record90('T1Text', 2) + CRLF + Record90('T9', 3) + CRLF;
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfDA90, 'GAEB 90 with text records');
  S := Record90('00        83', 1) + #13#13#10 + Record90('01Test', 2) + #13#13#10;
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfDA90, 'GAEB 90 with CR CR LF');
  S := Record90('00        83', 1) + #0#0 + Record90('01Test', 2) + #26;
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfDA90, 'GAEB 90 with NUL glued records and Ctrl-Z');
  S := #9'  foreign first line   011577' + CRLF + Record90('26Text', 11578) + CRLF;
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfDA90, 'GAEB 90 split part with foreign first line');
  S := 'Hello world' + CRLF;
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfUnknown, 'plain text');
  S := Copy(Record90('00        83', 1), 1, 79) + CRLF;
  Check(LandrixGaebDetectFormat(Pointer(S), Length(S)) = gfUnknown, '79 columns are no GAEB 90 record');
end;

procedure TestXml33;
var
  Diags: TLandrixGaebDiagnostics;
  R: TLandrixGaebDetection;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    R := Detect(Xml('http://www.gaeb.de/GAEB_DA_XML/DA83/3.3', '3.3', '2021-05', '83'), Diags);
    Check(R.Accepted, 'accepted');
    Check(R.Format = gfXml, 'format');
    Check(R.Target.Version = gv33, 'version');
    Check(R.Target.Edition = ge2021_05, 'edition');
    Check(R.Target.Phase = gp83, 'phase');
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
  finally
    Diags.Free;
  end;
end;

procedure TestXmlDPDecidesSubPhase;
var
  Diags: TLandrixGaebDiagnostics;
  R: TLandrixGaebDetection;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    R := Detect(Xml('http://www.gaeb.de/GAEB_DA_XML/DA50/3.3', '3.3', '2019-11', '50.2'), Diags);
    Check(R.Target.Phase = gp50_2, '50.2 from DP');
    Check(R.Target.Edition = ge2019_11, 'edition 2019-11');
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
  finally
    Diags.Free;
  end;
end;

procedure TestXmlMismatches;
var
  Diags: TLandrixGaebDiagnostics;
  R: TLandrixGaebDetection;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    R := Detect(Xml('http://www.gaeb.de/GAEB_DA_XML/DA83/3.2', '3.3', '2013-10', '84'), Diags);
    Check(R.Accepted, 'mismatches are warnings, the file is accepted');
    Check(R.Target.Version = gv32, 'the namespace decides the version');
    Check(R.Target.Phase = gp84, 'DP decides the phase');
    CheckEquals(1, Diags.CountOf('GAEB-DET-006'), 'DP/namespace mismatch reported');
    CheckEquals(1, Diags.CountOf('GAEB-DET-007'), 'Version/namespace mismatch reported');
  finally
    Diags.Free;
  end;
end;

procedure TestXml31;
var
  Diags: TLandrixGaebDiagnostics;
  R: TLandrixGaebDetection;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    R := Detect(Xml('http://www.gaeb.de/GAEB_DA_XML/200407', '3.1', '2009-12', '86'), Diags);
    Check(R.Target.Version = gv31, '3.1 from GAEBInfo/Version');
    Check(R.Target.Edition = ge2009_12, 'edition 2009-12');
    Check(R.Target.Phase = gp86, 'phase 86');
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
    { 3.0 and 3.1/2007-11 leave VersDate free; the samples carry other dates }
    R := Detect(Xml('http://www.gaeb.de/GAEB_DA_XML/200407', '3.0', '2004-08', '83'), Diags);
    Check((R.Target.Version = gv30) and (R.Target.Edition = ge2004_07), '3.0 with VersDate 2004-08');
    R := Detect(Xml('http://www.gaeb.de/GAEB_DA_XML/200407', '3.1', '2007-06', '83'), Diags);
    Check((R.Target.Version = gv31) and (R.Target.Edition = ge2007_11), '3.1 with VersDate 2007-06');
    R := Detect(Xml('http://www.gaeb.de/GAEB_DA_XML/200706', '3.1', '2007-06', '93'), Diags);
    Check((R.Target.Version = gv31) and (R.Target.Phase = gp93), '3.1 trade');
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
    R := Detect(Xml('http://www.gaeb.de/GAEB_DA_XML/200407', '3.2', '2013-10', '83'), Diags);
    Check(R.Target.Version = gvUnknown, 'foreign Version with 200407 leaves the version open');
    CheckEquals(1, Diags.CountOf('GAEB-DET-007'), 'foreign Version reported');
    Diags.Clear;
    R := Detect(Xml('http://www.gaeb.de/GAEB_DA_XML/200706', '', '2007-06', '93'), Diags);
    Check(R.Target.Version = gv31, '200706 means 3.1');
    CheckEquals(0, Diags.CountOf('GAEB-DET-007'), 'missing Version is no mismatch');
    CheckEquals(1, Diags.CountOf('GAEB-DET-009'), 'missing Version reported');
  finally
    Diags.Free;
  end;
end;

procedure TestXmlDPLocations;
var
  Diags: TLandrixGaebDiagnostics;
  R: TLandrixGaebDetection;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    R := Detect(XmlIn('http://www.gaeb.de/GAEB_DA_XML/DA31/3.3', '3.3', '2023-01', 'QtyDeterm', '31'), Diags);
    Check((R.Target.Phase = gp31) and (R.Target.Edition = ge2023_01), 'X31 QtyDeterm/DP');
    R := Detect(XmlIn('http://www.gaeb.de/GAEB_DA_XML/DA89B/3.3', '3.3', '2021-05', 'Invoice', '89B'), Diags);
    Check(R.Target.Phase = gp89B, 'X89B Invoice/DP');
    R := Detect(XmlIn('http://www.gaeb.de/GAEB_DA_XML/DA50/3.3', '3.3', '2021-05', 'ElementalCosting', '50.1'), Diags);
    Check(R.Target.Phase = gp50_1, 'X50 ElementalCosting/DP');
    R := Detect(XmlIn('http://www.gaeb.de/GAEB_DA_XML/DA84P/3.3', '3.3', '2021-05', 'SC_Evaluation', '84P'), Diags);
    Check(R.Target.Phase = gp84P, 'X84P SC_Evaluation/DP');
    R := Detect(XmlIn('http://www.gaeb.de/GAEB_DA_XML/DA96/3.3', '3.3', '2021-05', 'Order', '96'), Diags);
    Check(R.Target.Phase = gp96, 'X96 Order/DP');
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
    { X61 (beta) carries DP in GAEBInfo }
    R := Detect('<?xml version="1.0" encoding="UTF-8"?>' + CRLF +
      '<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA61/3.3">' + CRLF +
      '  <GAEBInfo><DP>61</DP><Version>3.3</Version><VersDate>2021-05</VersDate>' +
      '<ProgSystem>Test</ProgSystem></GAEBInfo>' + CRLF +
      '  <PrjInfo><NamePrj>P</NamePrj></PrjInfo>' + CRLF + '</GAEB>' + CRLF, Diags);
    Check((R.Target.Phase = gp61) and (R.Target.Edition = ge2021_05), 'X61 GAEBInfo/DP');
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics for X61: ' + Diags.ToText);
    { elements of a vendor namespace before the DP are skipped }
    R := Detect('<?xml version="1.0" encoding="UTF-8"?>' + CRLF +
      '<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA83/3.3" xmlns:v="urn:vendor">' + CRLF +
      '  <GAEBInfo><Version>3.3</Version><VersDate>2021-05</VersDate></GAEBInfo>' + CRLF +
      '  <v:Extra><DP xmlns="http://www.gaeb.de/GAEB_DA_XML/DA83/3.3">84</DP></v:Extra>' + CRLF +
      '  <Award><DP>83</DP></Award>' + CRLF + '</GAEB>' + CRLF, Diags);
    Check(R.Target.Phase = gp83, 'vendor element skipped');
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics with vendor element: ' + Diags.ToText);
  finally
    Diags.Free;
  end;
end;

{ A document larger than the detection prefix whose prefix ends inside a
  two-byte UTF-8 character must still be accepted. }
procedure TestXmlTruncatedPrefix;
var
  Diags: TLandrixGaebDiagnostics;
  R: TLandrixGaebDetection;
  Stream: TMemoryStream;
  Head, Tail, S: AnsiString;
  I, Start: Integer;
begin
  Head := '<?xml version="1.0" encoding="UTF-8"?>' + CRLF +
    '<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA83/3.3">' + CRLF +
    '  <GAEBInfo><Version>3.3</Version><VersDate>2021-05</VersDate></GAEBInfo>' + CRLF +
    '  <Award><DP>83</DP><Text>';
  { the lead byte of a character must sit at the last byte of the prefix }
  if (LandrixGaebDetectPrefixSize - 1 - Length(Head)) mod 2 <> 0 then
    Head := Head + ' ';
  Tail := '</Text></Award>' + CRLF + '</GAEB>' + CRLF;
  S := '';
  SetLength(S, LandrixGaebDetectPrefixSize + 1000);
  for I := 1 to Length(Head) do
    S[I] := Head[I];
  Start := Length(Head) + 1;
  I := Start;
  while I + 1 <= Length(S) - Length(Tail) do
  begin
    S[I] := #$C3;
    S[I + 1] := #$A4;
    Inc(I, 2);
  end;
  SetLength(S, I - 1);
  S := S + Tail;
  Check(S[LandrixGaebDetectPrefixSize] = #$C3, 'prefix ends after a lead byte');
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := TMemoryStream.Create;
  try
    Stream.WriteBuffer(S[1], Length(S));
    Stream.Position := 0;
    R := LandrixGaebDetectStream(Stream, Diags, 0);
    Check(R.Accepted, 'accepted: ' + Diags.ToText);
    Check((R.Target.Version = gv33) and (R.Target.Phase = gp83), 'target');
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
  finally
    Stream.Free;
    Diags.Free;
  end;
end;

procedure TestXmlRejected;
var
  Diags: TLandrixGaebDiagnostics;
  R: TLandrixGaebDetection;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    R := Detect('<?xml version="1.0"?><!DOCTYPE GAEB [<!ENTITY a "b">]><GAEB/>', Diags);
    Check(not R.Accepted, 'DOCTYPE rejected');
    CheckEquals(1, Diags.CountOf('GAEB-DET-003'), 'DOCTYPE reported');
    Diags.Clear;
    R := Detect('<?xml version="1.0"?><GAEB><GAEBInfo></GAEB>', Diags);
    Check(not R.Accepted, 'not well-formed rejected');
    CheckEquals(1, Diags.CountOf('GAEB-DET-008'), 'not well-formed reported');
    Diags.Clear;
    R := Detect('<?xml version="1.0"?><Invoice xmlns="urn:x"/>', Diags);
    Check(not R.Accepted, 'wrong root rejected');
    CheckEquals(1, Diags.CountOf('GAEB-DET-004'), 'wrong root reported');
    Diags.Clear;
    R := Detect(Xml('urn:unknown', '3.3', '2021-05', '83'), Diags);
    Check(not R.Accepted, 'unknown namespace rejected');
    CheckEquals(1, Diags.CountOf('GAEB-DET-005'), 'unknown namespace reported');
    Diags.Clear;
    R := Detect('<?xml version="1.0"?><GAEB><GAEBInfo><Version>3.3</Version></GAEBInfo></GAEB>', Diags);
    Check(not R.Accepted, 'GAEB without namespace rejected');
    CheckEquals(1, Diags.CountOf('GAEB-DET-005'), 'missing namespace reported');
    Diags.Clear;
    R := Detect('', Diags);
    Check(not R.Accepted, 'empty input rejected');
    CheckEquals(1, Diags.CountOf('GAEB-DET-002'), 'empty input reported');
  finally
    Diags.Free;
  end;
end;

procedure TestSizeLimit;
var
  Diags: TLandrixGaebDiagnostics;
  R: TLandrixGaebDetection;
  Stream: TMemoryStream;
  S: AnsiString;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := TMemoryStream.Create;
  try
    S := Xml('http://www.gaeb.de/GAEB_DA_XML/DA83/3.3', '3.3', '2021-05', '83');
    Stream.WriteBuffer(S[1], Length(S));
    Stream.Position := 0;
    R := LandrixGaebDetectStream(Stream, Diags, Int64(Length(S)) - 1);
    Check(not R.Accepted, 'larger than the limit');
    CheckEquals(1, Diags.CountOf('GAEB-DET-001'), 'size limit reported');
    CheckEquals(0, Integer(Stream.Position), 'stream position restored');
    Diags.Clear;
    R := LandrixGaebDetectStream(Stream, Diags, Length(S));
    Check(R.Accepted and (R.Target.Phase = gp83), 'exactly at the limit');
  finally
    Stream.Free;
    Diags.Free;
  end;
end;

{ ---- local corpus ---- }

type
  TFileVisitor = procedure(const FileName, RelName: string);

var
  ExpectedFormat: TLandrixGaebFormat;
  Failures: TStringList;
  FaultyRejected: Integer;

function LocalDir: string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim;
end;

function IsDocument(const FileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  Result := (Ext = '.pdf') or (Ext = '.md') or (Ext = '.rtf');
end;

{ Calls Visit for every file below Dir (recursively), documents excluded. }
procedure ForEachFile(const Dir, RelPrefix: string; Visit: TFileVisitor; var Count: Integer);
var
  SR: TSearchRec;
begin
  if FindFirst(Dir + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        ForEachFile(Dir + SR.Name + PathDelim, RelPrefix + SR.Name + '/', Visit, Count)
      else if not IsDocument(SR.Name) then
      begin
        Inc(Count);
        Visit(Dir + SR.Name, RelPrefix + SR.Name);
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure VisitDetect(const FileName, RelName: string);
var
  Expected: TLandrixGaebFormat;
  Ext: string;
  R: TLandrixGaebDetection;
begin
  Expected := ExpectedFormat;
  if Expected = gfUnknown then
  begin
    { gaeb-multiformat: the extension names the format }
    Ext := UpperCase(ExtractFileExt(FileName));
    if Copy(Ext, 1, 2) = '.D' then
      Expected := gfDA90
    else if Copy(Ext, 1, 2) = '.P' then
      Expected := gfDA2000
    else
      Expected := gfXml;
  end;
  try
    R := LandrixGaebDetectFile(FileName, nil, 0);
    if R.Format <> Expected then
      Failures.Add(RelName + ': detected ' + LandrixGaebFormatToStr(R.Format) +
        ', expected ' + LandrixGaebFormatToStr(Expected));
  except
    on E: Exception do
      Failures.Add(RelName + ': ' + E.ClassName);
  end;
end;

procedure RunDetectFolder(const SubDir: string; Expected: TLandrixGaebFormat;
  var Total: Integer);
var
  Count: Integer;
begin
  if not DirectoryExists(LocalDir + SubDir) then
    Exit;
  ExpectedFormat := Expected;
  Count := 0;
  ForEachFile(LocalDir + SubDir + PathDelim, SubDir + '/', VisitDetect, Count);
  Inc(Total, Count);
end;

procedure TestLocalDetect;
var
  Total: Integer;
begin
  if not DirectoryExists(LocalDir) then
  begin
    Skip('tests/data/local not present');
    Exit;
  end;
  Failures := TStringList.Create;
  try
    Total := 0;
    RunDetectFolder('xml', gfXml, Total);
    RunDetectFolder('official', gfXml, Total);
    RunDetectFolder('gaeb90', gfDA90, Total);
    RunDetectFolder('gaeb2000', gfDA2000, Total);
    RunDetectFolder('gaeb-multiformat', gfUnknown, Total);
    WriteLn('  Local.Detect: ', Total, ' file(s), ', Failures.Count, ' mismatch(es)');
    if Failures.Count > 0 then
      Fail(IntToStr(Failures.Count) + ' file(s) detected wrongly:' + sLineBreak + Failures.Text);
    Check(Total > 0, 'local files found');
  finally
    Failures.Free;
    Failures := nil;
  end;
end;

procedure VisitSweep(const FileName, RelName: string);
var
  R: TLandrixGaebDetection;
  Diags: TLandrixGaebDiagnostics;
  Reader: TLandrixXmlReader;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    try
      R := LandrixGaebDetectFile(FileName, Diags, 0);
      if R.Format <> gfXml then
        Exit;
      if not R.Accepted then
      begin
        Failures.Add(RelName + ': not accepted: ' + Diags.ToText);
        Exit;
      end;
      if (R.Target.Version = gvUnknown) or (R.Target.Phase = gpUnknown) then
        Failures.Add(RelName + ': version or phase not detected: ' + Diags.ToText);
      { well-formedness of the whole file }
      Reader := TLandrixXmlReader.Create;
      try
        Reader.LoadFromFile(FileName);
        while Reader.Read do
          ;
      finally
        Reader.Free;
      end;
    except
      on E: Exception do
        Failures.Add(RelName + ': ' + E.ClassName + ': ' + E.Message);
    end;
  finally
    Diags.Free;
  end;
end;

procedure TestLocalSweep;
var
  Count: Integer;
begin
  if not DirectoryExists(LocalDir) then
  begin
    Skip('tests/data/local not present');
    Exit;
  end;
  Failures := TStringList.Create;
  try
    Count := 0;
    if DirectoryExists(LocalDir + 'xml') then
      ForEachFile(LocalDir + 'xml' + PathDelim, 'xml/', VisitSweep, Count);
    if DirectoryExists(LocalDir + 'official') then
      ForEachFile(LocalDir + 'official' + PathDelim, 'official/', VisitSweep, Count);
    WriteLn('  Local.Sweep: ', Count, ' file(s), ', Failures.Count, ' problem(s)');
    if Failures.Count > 0 then
      Fail(IntToStr(Failures.Count) + ' file(s) failed:' + sLineBreak + Failures.Text);
  finally
    Failures.Free;
    Failures := nil;
  end;
end;

procedure VisitFaulty(const FileName, RelName: string);
var
  Diags: TLandrixGaebDiagnostics;
  R: TLandrixGaebDetection;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    try
      R := LandrixGaebDetectFile(FileName, Diags, 0);
      { the not well-formed XML file with a GAEB 2000 extension
        (faulty/xml/*.p83) must be rejected with a position }
      if (Copy(RelName, 1, 11) = 'faulty/xml/') and
        (LowerCase(ExtractFileExt(FileName)) = '.p83') then
      begin
        if R.Accepted or (Diags.CountOf('GAEB-DET-008') <> 1) then
          Failures.Add(RelName + ': not rejected as not well-formed')
        else
          Inc(FaultyRejected);
      end;
    except
      on E: Exception do
        Failures.Add(RelName + ': detection raised ' + E.ClassName);
    end;
  finally
    Diags.Free;
  end;
end;

procedure TestLocalFaulty;
var
  Count: Integer;
begin
  if not DirectoryExists(LocalDir + 'faulty') then
  begin
    Skip('tests/data/local/faulty not present');
    Exit;
  end;
  Failures := TStringList.Create;
  try
    { detection never raises, whatever the input }
    Count := 0;
    FaultyRejected := 0;
    ForEachFile(LocalDir + 'faulty' + PathDelim, 'faulty/', VisitFaulty, Count);
    WriteLn('  Local.Faulty: ', Count, ' file(s), ', FaultyRejected,
      ' rejected as not well-formed, ', Failures.Count, ' problem(s)');
    if Failures.Count > 0 then
      Fail(Failures.Text);
    Check(Count > 0, 'faulty files found');
  finally
    Failures.Free;
    Failures := nil;
  end;
end;

procedure Register;
begin
  RegisterTest('Detect.FormatFirstBytes', TestFormatFirstBytes);
  RegisterTest('Detect.Xml33', TestXml33);
  RegisterTest('Detect.XmlDPDecidesSubPhase', TestXmlDPDecidesSubPhase);
  RegisterTest('Detect.XmlMismatches', TestXmlMismatches);
  RegisterTest('Detect.Xml31', TestXml31);
  RegisterTest('Detect.XmlDPLocations', TestXmlDPLocations);
  RegisterTest('Detect.XmlTruncatedPrefix', TestXmlTruncatedPrefix);
  RegisterTest('Detect.XmlRejected', TestXmlRejected);
  RegisterTest('Detect.SizeLimit', TestSizeLimit);
  RegisterTest('Local.Detect', TestLocalDetect);
  RegisterTest('Local.Sweep', TestLocalSweep);
  RegisterTest('Local.Faulty', TestLocalFaulty);
end;

end.

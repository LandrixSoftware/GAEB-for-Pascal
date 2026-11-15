{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of LandrixGaebCharsets and LandrixGaebDA90Parser: synthetic
  records, and the GAEB 90 files of the local corpus (skipped when
  missing). The local test prints counts only, never file names or
  content of the files. }
unit LandrixGaebTestDA90Parser;

{$I LandrixGaeb.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebCharsets,
  LandrixGaebDA90Parser,
  LandrixGaebTestFramework;

const
  CRLF = #13#10;

{ A record of 80 bytes: type, body padded to 72 columns, number. }
function Rec(const AKind, ABody: AnsiString; ANumber: Integer): AnsiString;
var
  I, N: Integer;
begin
  Result := AKind + ABody;
  while Length(Result) < 74 do
    Result := Result + ' ';
  Result := Copy(Result, 1, 74) + '000000';
  N := ANumber;
  for I := 80 downto 75 do
  begin
    Result[I] := AnsiChar(Ord('0') + N mod 10);
    N := N div 10;
  end;
end;

function U(ACode: Word): TLandrixGaebString;
begin
  Result := TLandrixGaebChar(ACode);
end;

function Parse(const S: AnsiString; Diags: TLandrixGaebDiagnostics): TLandrixGaebDA90Document;
begin
  Result := LandrixGaebDA90Parse(Pointer(S), Length(S), gcsUnknown, gcpCp850, Diags);
end;

function ParseAs(const S: AnsiString; ACharset: TLandrixGaebCharset; ACodePage: TLandrixGaebCodePage;
  Diags: TLandrixGaebDiagnostics): TLandrixGaebDA90Document;
begin
  Result := LandrixGaebDA90Parse(Pointer(S), Length(S), ACharset, ACodePage, Diags);
end;

{ Number of diagnostics with rule ARule and severity ASeverity. }
function CountRule(Diags: TLandrixGaebDiagnostics; const ARule: string;
  ASeverity: TLandrixGaebSeverity): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Integer(Diags.Count) - 1 do
    if (Diags[I].RuleId = ARule) and (Diags[I].Severity = ASeverity) then
      Inc(Result);
end;

procedure TestCodePages;
begin
  CheckEquals(Ord('A'), Integer(LandrixGaebCodePointOfByte(Ord('A'), gcpCp437)), 'ASCII');
  CheckEquals($20AC, Integer(LandrixGaebCodePointOfByte($80, gcpWindows1252)), '1252 euro');
  CheckEquals($0081, Integer(LandrixGaebCodePointOfByte($81, gcpWindows1252)), '1252 undefined byte');
  CheckEquals($00E4, Integer(LandrixGaebCodePointOfByte($E4, gcpWindows1252)), '1252 ae');
  CheckEquals($00E4, Integer(LandrixGaebCodePointOfByte($84, gcpCp850)), '850 ae');
  CheckEquals($00E4, Integer(LandrixGaebCodePointOfByte($84, gcpCp437)), '437 ae');
  CheckEquals($00DF, Integer(LandrixGaebCodePointOfByte($E1, gcpCp437)), '437 sharp s');
  CheckEquals($00F8, Integer(LandrixGaebCodePointOfByte($9B, gcpCp850)), '850 $9B');
  CheckEquals($00A2, Integer(LandrixGaebCodePointOfByte($9B, gcpCp437)), '437 $9B');
  CheckEquals($03A3, Integer(LandrixGaebCodePointOfByte($E4, gcpCp437)), '437 $E4');
  CheckEquals($00A0, Integer(LandrixGaebCodePointOfByte($FF, gcpCp850)), '850 $FF');
end;

procedure TestRecords;
var
  D: TLandrixGaebDA90Document;
  Diags: TLandrixGaebDiagnostics;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := Parse(Rec('00', '        83L', 1) + CRLF + Rec('01', 'Bez', 2) + CRLF + Rec('99', '', 3) + CRLF, Diags);
    try
      CheckEquals(3, D.Count, 'records');
      CheckEqualsStr('00', D.Kind(0), 'kind 00');
      CheckEqualsStr('99', D.Kind(2), 'kind 99');
      CheckEqualsGaebStr('83', D.Field(0, 11, 12), 'DP');
      CheckEqualsGaebStr('Bez  ', D.Field(1, 3, 7), 'field padded inside');
      CheckEquals(2, D.Number(1), 'number');
      CheckEquals(3, D.Line(2), 'line');
      CheckEquals(80, D.RecordLength(0), 'length');
      Check(D.Charset = gcsAnsi, 'ANSI without umlauts');
      CheckEquals(1, CountRule(Diags, 'GAEB-D90-FILE-001', gsInformation), 'charset reported');
      CheckEquals(1, Integer(Diags.Count), 'nothing else reported');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
end;

procedure TestCharsets;
var
  D: TLandrixGaebDA90Document;
  Diags: TLandrixGaebDiagnostics;
  S: AnsiString;
begin
  { ANSI umlauts }
  D := Parse(Rec('25', 'Ma'#$DF'e f'#$FC'r T'#$FC'ren', 1), nil);
  try
    Check(D.Charset = gcsAnsi, 'ANSI chosen');
    CheckEqualsGaebStr('Ma' + U($DF) + 'e', D.Field(0, 3, 6), 'ANSI decoded');
  finally
    D.Free;
  end;
  { OEM umlauts, ae between letters }
  D := Parse(Rec('25', 'Ma'#$E1'e f'#$81'r T'#$81'ren und L'#$84'nge', 1), nil);
  try
    Check(D.Charset = gcsOem, 'OEM chosen');
    Check(D.CodePage = gcpCp850, 'OEM is 850');
    CheckEqualsGaebStr('f' + U($FC) + 'r', D.Field(0, 8, 10), 'OEM decoded');
  finally
    D.Free;
  end;
  { typographic quotes of ANSI ($84, $93) are no OEM umlauts }
  D := Parse(Rec('25', #$84'Text'#$93' und '#$84'mehr'#$93' f'#$FC'r', 1), nil);
  try
    Check(D.Charset = gcsAnsi, 'quotes stay ANSI');
    CheckEqualsGaebStr(U($201E) + 'Text' + U($201C), D.Field(0, 3, 8), 'quotes decoded');
  finally
    D.Free;
  end;
  { caller overrides: OEM as code page 437 }
  D := ParseAs(Rec('25', 'x'#$9B'y', 1), gcsOem, gcpCp437, nil);
  try
    Check(D.Charset = gcsOem, 'OEM given');
    Check(D.CodePage = gcpCp437, '437 given');
    CheckEqualsGaebStr('x' + U($A2) + 'y', D.Field(0, 3, 5), '437 decoded');
  finally
    D.Free;
  end;
  { UTF-8: columns count characters }
  S := Rec('25', 'Lxnge', 1);
  S := Copy(S, 1, 3) + #$C3#$A4 + Copy(S, 5, MaxInt);
  D := Parse(S, nil);
  try
    Check(D.Charset = gcsUnicode, 'UTF-8 chosen');
    { the record is 81 bytes, but 80 characters }
    CheckEquals(80, D.RecordLength(0), 'UTF-8 record length in characters');
    CheckEqualsGaebStr('L' + U($E4) + 'nge', D.Field(0, 3, 7), 'UTF-8 decoded');
    CheckEquals(1, D.Number(0), 'UTF-8 record number in place');
  finally
    D.Free;
  end;
  { byte order mark }
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := Parse(#$EF#$BB#$BF + Rec('25', 'abc', 1), Diags);
    try
      Check(D.Charset = gcsUnicode, 'BOM means UTF-8');
      CheckEqualsGaebStr('25abc', D.Field(0, 1, 5), 'BOM skipped');
      CheckEquals(1, CountRule(Diags, 'GAEB-D90-FILE-003', gsInformation), 'BOM reported');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
  { UTF-8 asked for, but not UTF-8 }
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := ParseAs(Rec('25', 'f'#$FC'r', 1), gcsUnicode, gcpCp850, Diags);
    try
      CheckEqualsGaebStr('f' + U($FC) + 'r', D.Field(0, 3, 5), 'invalid UTF-8 byte as 1252');
      CheckEquals(1, CountRule(Diags, 'GAEB-D90-FILE-005', gsWarning), 'invalid UTF-8 reported');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
  { mixed: about as many ANSI as OEM umlauts }
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := Parse(Rec('26', 'f'#$81'r', 1) + CRLF + Rec('26', 'f'#$FC'r', 2) + CRLF, Diags);
    try
      CheckEquals(1, CountRule(Diags, 'GAEB-D90-FILE-002', gsWarning), 'mixed reported');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
end;

{ Regressions of the first review: characters above U+FFFF, OEM box
  drawing, blank line counts, BOM with an override. }
procedure TestReviewCases;
var
  D: TLandrixGaebDA90Document;
  Diags: TLandrixGaebDiagnostics;
  S, R: AnsiString;
  I: Integer;
  Found: Boolean;
begin
  { U+1F600 (four bytes in UTF-8, two UTF-16 units) is one column }
  S := Rec('25', 'x', 1);
  S := Copy(S, 1, 2) + #$F0#$9F#$98#$80 + Copy(S, 4, MaxInt);
  R := Rec('26', 'y', 2);
  D := Parse(S + #0#0 + R + CRLF, nil);
  try
    Check(D.Charset = gcsUnicode, 'UTF-8');
    CheckEquals(2, D.Count, 'chained after a surrogate pair');
    CheckEquals(80, D.RecordLength(0), 'surrogate pair counts as one column');
    CheckEquals(1, D.Number(0), 'number after a surrogate pair');
    CheckEquals(2, Length(D.Field(0, 3, 3)), 'column 3 is the whole pair');
    CheckEqualsGaebStr(' ', D.Field(0, 4, 4), 'column 4 after the pair');
    CheckEqualsStr('26', D.Kind(1), 'chained record kind');
  finally
    D.Free;
  end;
  { OEM: one umlaut and a line of box drawing characters ($C4 is the ANSI
    upper-case ae) }
  S := 'f'#$81'r ';
  for I := 1 to 10 do
    S := S + AnsiChar($C4);
  D := Parse(Rec('T1', S, 1), nil);
  try
    Check(D.Charset = gcsOem, 'box drawing does not count for ANSI');
  finally
    D.Free;
  end;
  { the same between two words: the box line does not count for ANSI }
  S := 'f'#$81'r links';
  for I := 1 to 10 do
    S := S + AnsiChar($C4);
  D := Parse(Rec('T1', S + 'rechts', 1), nil);
  try
    Check(D.Charset = gcsOem, 'box drawing between words');
  finally
    D.Free;
  end;
  { $B7 is no box drawing character in code page 850: an ANSI text with
    three middle dots stays ANSI }
  D := Parse(Rec('T1', 'Text '#$B7#$B7#$B7' Text', 1), nil);
  try
    Check(D.Charset = gcsAnsi, 'middle dots stay ANSI');
  finally
    D.Free;
  end;
  { a surrogate pair in column 1: the kind is '?' and the digit }
  S := Rec('x9', '', 1);
  S := #$F0#$9F#$98#$80 + Copy(S, 2, MaxInt);
  D := Parse(S, nil);
  try
    CheckEqualsStr('?9', D.Kind(0), 'kind after a surrogate pair');
  finally
    D.Free;
  end;
  { CR CR CR LF: one empty line and the CR CR LF line end }
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := Parse(Rec('00', '', 1) + #13#13#13#10 + Rec('01', '', 2), Diags);
    try
      CheckEquals(3, D.Line(1), 'line after CR CR CR LF');
      Found := False;
      for I := 0 to Integer(Diags.Count) - 1 do
        if Diags[I].Message = '1 blank line(s) ignored' then
          Found := True;
      Check(Found, 'one blank line before CR CR LF');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
  { blank lines: CR CR between records is one, a chain ending with NUL NUL
    leaves none }
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := Parse(Rec('00', '', 1) + #13#13 + Rec('01', '', 2) + #0#0, Diags);
    try
      CheckEquals(2, D.Count, 'records');
      CheckEquals(3, D.Line(1), 'line after CR CR');
      Found := False;
      for I := 0 to Integer(Diags.Count) - 1 do
        if Diags[I].Message = '1 blank line(s) ignored' then
          Found := True;
      Check(Found, 'one blank line');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
  { a byte order mark with ANSI given by the caller }
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := ParseAs(#$EF#$BB#$BF + Rec('25', '', 1), gcsAnsi, gcpCp850, Diags);
    try
      Check(D.Charset = gcsAnsi, 'caller wins');
      Found := False;
      for I := 0 to Integer(Diags.Count) - 1 do
        if Diags[I].Message = 'character set ANSI (Windows-1252), as given by the caller' then
          Found := True;
      Check(Found, 'source named correctly');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
end;

procedure TestPhysics;
var
  D: TLandrixGaebDA90Document;
  Diags: TLandrixGaebDiagnostics;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    { CR CR LF, LF, lone CR, a blank line, chained records, NUL inside,
      Ctrl-Z at the end followed by CR LF }
    D := Parse(Rec('00', '', 1) + #13#13#10 + Rec('01', '', 2) + #10 + '   ' + #10 +
      Rec('02', 'a'#0'b', 3) + #13 + Rec('03', '', 4) + #0#0 + Rec('04', 'x', 5) + CRLF + #26 + CRLF, Diags);
    try
      CheckEquals(5, D.Count, 'records');
      CheckEquals(1, D.Line(0), 'line 1');
      CheckEquals(2, D.Line(1), 'line 2');
      CheckEquals(4, D.Line(2), 'line 4 after the blank line');
      CheckEquals(5, D.Line(3), 'line 5');
      CheckEquals(5, D.Line(4), 'chained record shares line 5');
      CheckEqualsStr('04', D.Kind(4), 'chained record kind');
      CheckEqualsGaebStr('a b', D.Field(2, 3, 5), 'NUL read as space');
      CheckEquals(4, CountRule(Diags, 'GAEB-D90-FILE-003', gsInformation),
        'CR CR LF, chained, Ctrl-Z and blank line reported');
      CheckEquals(1, CountRule(Diags, 'GAEB-D90-FILE-005', gsWarning), 'NUL reported');
      CheckEquals(0, CountRule(Diags, 'GAEB-BR-D90-002', gsWarning), 'numbers fine');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
  { short and long records }
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := Parse('26kurz' + CRLF + Rec('26', '', 2) + 'zu lang' + CRLF, Diags);
    try
      CheckEquals(2, D.Count, 'records');
      CheckEqualsGaebStr('kurz  ', D.Field(0, 3, 8), 'short record padded');
      CheckEquals(-1, D.Number(0), 'short record without a number');
      CheckEquals(87, D.RecordLength(1), 'long record as read');
      CheckEqualsGaebStr('000002', D.Field(1, 75, 85), 'columns after 80 ignored');
      CheckEquals(1, CountRule(Diags, 'GAEB-D90-FILE-004', gsInformation), 'short reported');
      CheckEquals(1, CountRule(Diags, 'GAEB-D90-FILE-004', gsWarning), 'long reported');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
end;

procedure TestNumbers;
var
  D: TLandrixGaebDA90Document;
  Diags: TLandrixGaebDiagnostics;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := Parse(Rec('00', '', 1) + CRLF + Rec('01', '', 3) + CRLF + Rec('99', '', 4) + CRLF, Diags);
    try
      { one break (1 -> 3); 99 carries 4 at position 3 }
      CheckEquals(2, CountRule(Diags, 'GAEB-BR-D90-002', gsWarning), 'break and 99 reported');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
  { a T block after 99 keeps the numbers consecutive: no warning }
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := Parse(Rec('00', '', 1) + CRLF + Rec('99', '', 2) + CRLF + Rec('T0', '', 3) + CRLF, Diags);
    try
      CheckEquals(0, CountRule(Diags, 'GAEB-BR-D90-002', gsWarning), 'consecutive');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
end;

procedure TestRejected;
var
  Raised: Boolean;
  D: TLandrixGaebDA90Document;
  S: AnsiString;
begin
  S := '';
  Raised := False;
  try
    D := Parse(S, nil);
    D.Free;
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'empty input rejected');
  Raised := False;
  try
    D := Parse('   ' + CRLF + CRLF + #26, nil);
    D.Free;
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'blank input rejected');
end;

procedure TestStream;
var
  M: TMemoryStream;
  S: AnsiString;
  D: TLandrixGaebDA90Document;
begin
  S := 'xx' + Rec('00', '', 1) + CRLF;
  M := TMemoryStream.Create;
  try
    M.WriteBuffer(S[1], Length(S));
    M.Position := 2;
    D := LandrixGaebDA90ParseStream(M, gcsUnknown, gcpCp850, nil);
    try
      CheckEquals(1, D.Count, 'stream from its position');
      CheckEqualsStr('00', D.Kind(0), 'stream kind');
    finally
      D.Free;
    end;
  finally
    M.Free;
  end;
end;

{ Input is untrusted: many tiny lines, one huge line and long runs of NUL
  must stay linear. }
procedure TestLargeInput;
var
  S, R: AnsiString;
  I, J: Integer;
  D: TLandrixGaebDA90Document;
begin
  S := '';
  SetLength(S, 400000);
  for I := 1 to Length(S) do
    if Odd(I) then
      S[I] := 'x'
    else
      S[I] := #10;
  D := Parse(S, nil);
  try
    CheckEquals(200000, D.Count, 'tiny lines');
  finally
    D.Free;
  end;
  for I := 1 to Length(S) do
    S[I] := #0;
  S[1] := 'x';
  D := Parse(S, nil);
  try
    CheckEquals(1, D.Count, 'one line of NUL');
  finally
    D.Free;
  end;
  { 5000 records chained by NUL NUL in one line }
  S := '';
  SetLength(S, 5000 * 82);
  for I := 0 to 4999 do
  begin
    R := Rec('26', '', I + 1);
    for J := 1 to 80 do
      S[I * 82 + J] := R[J];
    S[I * 82 + 81] := #0;
    S[I * 82 + 82] := #0;
  end;
  D := Parse(S, nil);
  try
    CheckEquals(5000, D.Count, 'chained records');
    CheckEquals(5000, D.Number(4999), 'last chained record number');
  finally
    D.Free;
  end;
end;

var
  LocalFiles, LocalParsed, LocalRejected, LocalRecords: Integer;
  LocalFailures, LocalRules: TStringList;
  LocalCounts: array of Integer;

procedure ParseLocalFile(const FileName: string);
var
  Stream: TFileStream;
  Det: TLandrixGaebDetection;
  Diags: TLandrixGaebDiagnostics;
  D: TLandrixGaebDA90Document;
  I, K: Integer;
begin
  Det := LandrixGaebDetectFile(FileName, nil, 0);
  if Det.Format <> gfDA90 then
    Exit;
  Inc(LocalFiles);
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    try
      D := LandrixGaebDA90ParseStream(Stream, gcsUnknown, gcpCp850, Diags);
      try
        Inc(LocalParsed);
        Inc(LocalRecords, D.Count);
      finally
        D.Free;
      end;
      for I := 0 to Integer(Diags.Count) - 1 do
      begin
        K := LocalRules.IndexOf(Diags[I].RuleId);
        if K < 0 then
        begin
          K := LocalRules.Add(Diags[I].RuleId);
          SetLength(LocalCounts, K + 1);
          LocalCounts[K] := 0;
        end;
        Inc(LocalCounts[K]);
      end;
    except
      on ELandrixGaebError do
        Inc(LocalRejected);
      on E: Exception do
        LocalFailures.Add(E.ClassName);
    end;
  finally
    Stream.Free;
    Diags.Free;
  end;
end;

procedure WalkLocal(const Dir: string);
var
  SR: TSearchRec;
begin
  if FindFirst(Dir + '*', faAnyFile, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        WalkLocal(Dir + SR.Name + PathDelim)
      else
        ParseLocalFile(Dir + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TestLocalParse;
var
  I: Integer;
  Summary: string;
begin
  if not DirectoryExists(LocalDataDir) then
  begin
    Skip('local corpus not present');
    Exit;
  end;
  LocalFiles := 0;
  LocalParsed := 0;
  LocalRejected := 0;
  LocalRecords := 0;
  LocalFailures := TStringList.Create;
  LocalRules := TStringList.Create;
  try
    LocalCounts := nil;
    WalkLocal(LocalDataDir);
    Summary := '';
    for I := 0 to LocalRules.Count - 1 do
      Summary := Summary + ' ' + LocalRules[I] + 'x' + IntToStr(LocalCounts[I]);
    WriteLn('  Local.DA90Parse: ', LocalFiles, ' file(s), ', LocalParsed, ' parsed (',
      LocalRecords, ' records), ', LocalRejected, ' rejected, ', LocalFailures.Count, ' failed;', Summary);
    if LocalFailures.Count > 0 then
      Fail('unexpected exceptions: ' + LocalFailures.CommaText);
    Check(LocalFiles > 0, 'GAEB 90 files found');
    CheckEquals(LocalFiles, LocalParsed, 'every GAEB 90 file read');
  finally
    LocalFailures.Free;
    LocalRules.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('DA90Parser.CodePages', TestCodePages);
  RegisterTest('DA90Parser.Records', TestRecords);
  RegisterTest('DA90Parser.Charsets', TestCharsets);
  RegisterTest('DA90Parser.Physics', TestPhysics);
  RegisterTest('DA90Parser.ReviewCases', TestReviewCases);
  RegisterTest('DA90Parser.Numbers', TestNumbers);
  RegisterTest('DA90Parser.Rejected', TestRejected);
  RegisterTest('DA90Parser.Stream', TestStream);
  RegisterTest('DA90Parser.LargeInput', TestLargeInput);
  RegisterTest('Local.DA90Parse', TestLocalParse);
end;

end.

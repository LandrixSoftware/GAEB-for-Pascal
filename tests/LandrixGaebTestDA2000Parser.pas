{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of LandrixGaebDA2000Parser: synthetic samples, and the GAEB DA 2000
  files of the local corpus (skipped when missing). The local test prints
  counts only, never file names or content of the files. }

unit LandrixGaebTestDA2000Parser;

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
  LandrixGaebDA2000Parser,
  LandrixGaebTestFramework;

const
  CRLF = #13#10;

function Parse(const S: AnsiString; Diags: TLandrixGaebDiagnostics): TLandrixGaebDA2000Document;
begin
  Result := LandrixGaebDA2000Parse(Pointer(S), Length(S), gcsUnknown, Diags);
end;

function ParseAs(const S: AnsiString; ACharset: TLandrixGaebCharset;
  Diags: TLandrixGaebDiagnostics): TLandrixGaebDA2000Document;
begin
  Result := LandrixGaebDA2000Parse(Pointer(S), Length(S), ACharset, Diags);
end;

{ A GAEB DA 2000 file with Zeichensatz ACharset ('' = none) and Body inside
  the object Vergabe. }
function Doc(const ACharset, Body: AnsiString): AnsiString;
begin
  Result := '#begin[GAEB]' + CRLF + '  #begin[GAEBInfo]' + CRLF +
    '    [Version]1.2[end]' + CRLF;
  if ACharset <> '' then
    Result := Result + '    [Zeichensatz]' + ACharset + '[end]' + CRLF;
  Result := Result + '  #end[GAEBInfo]' + CRLF + '  #begin[Vergabe]' + CRLF +
    '    [DP]83[end]' + CRLF + Body + '  #end[Vergabe]' + CRLF + '#end[GAEB]' + CRLF;
end;

function W(C: Word): TLandrixGaebString;
begin
  Result := WideChar(C);
end;

{ S with every CR LF replaced by ALineEnd. }
function WithLineEnd(const S, ALineEnd: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
    if (S[I] = #13) and (I < Length(S)) and (S[I + 1] = #10) then
    begin
      Result := Result + ALineEnd;
      Inc(I, 2);
    end
    else
    begin
      Result := Result + S[I];
      Inc(I);
    end;
end;

procedure TestTree;
var
  Diags: TLandrixGaebDiagnostics;
  D: TLandrixGaebDA2000Document;
  V: TLandrixGaebDA2000Node;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  D := Parse(Doc('ANSI', '    #begin[LV]1' + CRLF + '      [Bez]Rohbau[end]' + CRLF +
    '    #end[LV]' + CRLF), Diags);
  try
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
    Check(D.Root.IsObject and (D.Root.Key = 'GAEB'), 'root');
    CheckEquals(2, D.Root.Count, 'GAEBInfo and Vergabe');
    V := D.Root.Find('vergabe');
    Check((V <> nil) and V.IsObject and (V.Line = 6), 'Vergabe found ignoring case, line 6');
    CheckEqualsGaebStr('83', V.ValueOf('dp'), 'DP');
    Check(V.Find('LV').Suffix = '1', 'level marker after #begin[LV]');
    CheckEqualsGaebStr('Rohbau', V.Find('LV').ValueOf('Bez'), 'element in LV');
    CheckEquals(9, V.Find('LV').Find('Bez').Line, 'line of the element');
    Check(V.Find('LV').Find('Bez').Parent = V.Find('LV'), 'parent');
    Check(D.Charset = gcsAnsi, 'ANSI');
    CheckEqualsGaebStr('', V.ValueOf('Missing'), 'missing element');
    Check(V.Find('Missing') = nil, 'missing node');
  finally
    D.Free;
    Diags.Free;
  end;
end;

procedure TestContinuationLines;
var
  Diags: TLandrixGaebDiagnostics;
  D: TLandrixGaebDA2000Document;
  Text: TLandrixGaebString;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    { text column; white space beyond it is text }
    Text := 'erste Zeile' + #10 + 'zweite Zeile' + #10 + '  eingerueckt';
    D := Parse(Doc('ANSI', '    [Langtext]erste Zeile' + CRLF +
      '              zweite Zeile' + CRLF + '                eingerueckt[end]' + CRLF), Diags);
    try
      CheckEqualsGaebStr(Text, D.Root.Find('Vergabe').ValueOf('Langtext'), 'text column');
      CheckEquals(0, Integer(Diags.Count), 'text column: ' + Diags.ToText);
    finally
      D.Free;
    end;
    Text := 'erste Zeile' + #10 + 'zweite Zeile' + #10 + 'dritte Zeile';
    { column 1 (V1.1) }
    D := Parse(Doc('ANSI', '    [Langtext]erste Zeile' + CRLF + 'zweite Zeile' + CRLF +
      'dritte Zeile[end]' + CRLF), Diags);
    try
      CheckEqualsGaebStr(Text, D.Root.Find('Vergabe').ValueOf('Langtext'), 'column 1');
      CheckEquals(0, Integer(Diags.Count), 'column 1: ' + Diags.ToText);
    finally
      D.Free;
    end;
    { column of the bracket (practice): same text, one information }
    D := Parse(Doc('ANSI', '    [Langtext]erste Zeile' + CRLF + '    zweite Zeile' + CRLF +
      '    dritte Zeile' + CRLF + '    [end]' + CRLF), Diags);
    try
      CheckEqualsGaebStr(Text, D.Root.Find('Vergabe').ValueOf('Langtext'), 'bracket column, [end] alone');
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-029'), 'bracket column reported once');
    finally
      D.Free;
    end;
    { ## and # inside a value are text; ## outside is a comment }
    Diags.Clear;
    D := Parse(Doc('ANSI', '## a comment [Bez]x[end]' + CRLF + '    [Langtext]a' + CRLF +
      '              ## kein Kommentar' + CRLF + '              #begin[LV]' + CRLF +
      '              b[end]' + CRLF), Diags);
    try
      CheckEqualsGaebStr('a' + #10 + '## kein Kommentar' + #10 + '#begin[LV]' + #10 + 'b',
        D.Root.Find('Vergabe').ValueOf('Langtext'), 'structure inside a value is text');
      Check(D.Root.Find('Vergabe').Find('Bez') = nil, 'comment line ignored');
      CheckEquals(0, Integer(Diags.Count), 'comments: ' + Diags.ToText);
    finally
      D.Free;
    end;
    { a value whose first line is empty (RTF on the next lines) }
    D := Parse(Doc('ANSI', '    [Langtext]' + CRLF + '    {\rtf1 x\par' + CRLF + '    }[end]' + CRLF), Diags);
    try
      CheckEqualsGaebStr(#10 + '{\rtf1 x\par' + #10 + '}', D.Root.Find('Vergabe').ValueOf('Langtext'),
        'value starting on the next line');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
end;

procedure TestEscapes;
var
  Diags: TLandrixGaebDiagnostics;
  D: TLandrixGaebDA2000Document;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := Parse(Doc('ANSI', '    [Bez]a&#91;end&#93;b&#38;c&#124;d&#35;&#128;&#228;[end]' + CRLF +
      '    [Kurztext]x&#y;&#;&#12[end]' + CRLF), Diags);
    try
      CheckEqualsGaebStr('a[end]b&c|d#' + W($20AC) + W($E4), D.Root.Find('Vergabe').ValueOf('Bez'),
        'escapes in Windows-1252');
      CheckEqualsGaebStr('x&#y;&#;&#12', D.Root.Find('Vergabe').ValueOf('Kurztext'),
        'no escapes kept as text');
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-004'), 'invalid escapes reported once');
    finally
      D.Free;
    end;
    { a short invalid escape at the end of a value is reported as well }
    Diags.Clear;
    D := Parse(Doc('ANSI', '    [Bez]&#;[end]' + CRLF), Diags);
    try
      CheckEqualsGaebStr('&#;', D.Root.Find('Vergabe').ValueOf('Bez'), 'short invalid escape kept');
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-004'), 'short invalid escape reported');
    finally
      D.Free;
    end;
    Diags.Clear;
    D := Parse(Doc('ANSI', '    [Bez]a&#[end]' + CRLF), Diags);
    try
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-004'), 'trailing &# reported');
    finally
      D.Free;
    end;
    { in OEM, &#nn; is a character of code page 850 }
    D := Parse(Doc('OEM', '    [Bez]&#132;' + #$94 + '[end]' + CRLF), nil);
    try
      CheckEqualsGaebStr(W($E4) + W($F6), D.Root.Find('Vergabe').ValueOf('Bez'), 'OEM escape and byte');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
end;

procedure TestCharsets;
var
  Diags: TLandrixGaebDiagnostics;
  D: TLandrixGaebDA2000Document;
  Body: AnsiString;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    D := Parse(Doc('ANSI', '    [Bez]' + #$E4 + #$80 + #$81 + '[end]' + CRLF), Diags);
    try
      CheckEqualsGaebStr(W($E4) + W($20AC) + W($81), D.Root.Find('Vergabe').ValueOf('Bez'), 'ANSI');
    finally
      D.Free;
    end;
    D := Parse(Doc('', '    [Bez]' + #$E4 + '[end]' + CRLF), Diags);
    try
      Check(D.Charset = gcsAnsi, 'missing: ANSI');
      CheckEqualsGaebStr(W($E4), D.Root.Find('Vergabe').ValueOf('Bez'), 'missing: Windows-1252');
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-006'), 'missing reported');
    finally
      D.Free;
    end;
    Body := '    [Bez]' + #$C3#$A4 + #$F0#$9F#$98#$80 + '[end]' + CRLF;
    { UNICODE with byte order mark: UTF-8, no diagnostic }
    Diags.Clear;
    D := Parse(#$EF#$BB#$BF + Doc('UNICODE', Body), Diags);
    try
      Check(D.Charset = gcsUnicode, 'UTF-8 with BOM');
      CheckEqualsGaebStr(W($E4) + W($D83D) + W($DE00), D.Root.Find('Vergabe').ValueOf('Bez'),
        'UTF-8 incl. a character outside the BMP');
      CheckEquals(0, Integer(Diags.Count), 'UTF-8 with BOM: ' + Diags.ToText);
    finally
      D.Free;
    end;
    { UNICODE without byte order mark: UTF-8 when the bytes are UTF-8 }
    D := Parse(Doc('UNICODE', Body), Diags);
    try
      Check(D.Charset = gcsUnicode, 'UTF-8 without BOM');
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-006'), 'UNICODE without BOM reported');
      Check(not Diags.HasErrors, 'UNICODE with UTF-8 bytes is no error');
    finally
      D.Free;
    end;
    Diags.Clear;
    D := Parse(Doc('UNICODE', '    [Bez]' + #$E4 + '[end]' + CRLF), Diags);
    try
      Check(D.Charset = gcsAnsi, 'UNICODE with other bytes: ANSI');
      Check(Diags.HasErrors, 'UNICODE with other bytes is an error');
      CheckEqualsGaebStr(W($E4), D.Root.Find('Vergabe').ValueOf('Bez'), 'read as ANSI');
    finally
      D.Free;
    end;
    { the caller overrides the declaration }
    Diags.Clear;
    D := ParseAs(Doc('ANSI', '    [Bez]' + #$84 + '[end]' + CRLF), gcsOem, Diags);
    try
      Check(D.Charset = gcsOem, 'override');
      CheckEqualsGaebStr(W($E4), D.Root.Find('Vergabe').ValueOf('Bez'), 'read as OEM');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
end;

procedure TestEmptyAndStructure;
var
  Diags: TLandrixGaebDiagnostics;
  D: TLandrixGaebDA2000Document;
  V: TLandrixGaebDA2000Node;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    { empty elements count as missing }
    D := Parse(Doc('ANSI', '    [Bez][end]' + CRLF + '    [Kurztext]   [end]' + CRLF +
      '    [Langtext]' + CRLF + '    [end]' + CRLF), Diags);
    try
      V := D.Root.Find('Vergabe');
      Check((V.Find('Bez') = nil) and (V.Find('Kurztext') = nil) and (V.Find('Langtext') = nil),
        'empty elements dropped');
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-014'), 'empty elements reported once');
    finally
      D.Free;
    end;
    { an #end of an outer object closes the inner one; a foreign #end is
      ignored; lines outside elements; text after #end[GAEB]; counters }
    Diags.Clear;
    D := Parse('#begin[GAEB]' + CRLF + '#begin[Vergabe]' + CRLF + '#begin[LV]' + CRLF +
      '[Bez]x[end]' + CRLF + '#end[Vergabe]' + CRLF + '#end[Foreign]' + CRLF +
      'stray text' + CRLF + '#end[GAEB]12|34' + CRLF + 'trailing' + CRLF + 'more' + CRLF, Diags);
    try
      CheckEquals(1, D.Root.Count, 'Vergabe only');
      CheckEqualsGaebStr('x', D.Root.Find('Vergabe').Find('LV').ValueOf('Bez'), 'content kept');
      Check(D.EndCounters = '12|34', 'counters after #end[GAEB]');
      CheckEquals(3, Diags.CountOf('GAEB-BR-D2000-002'),
        'unclosed LV, foreign #end, stray line: ' + Diags.ToText);
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-001'), 'text after the end reported once');
    finally
      D.Free;
    end;
    { #begin[GAEB] not in line 1 }
    Diags.Clear;
    D := Parse(CRLF + Doc('ANSI', ''), Diags);
    try
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-001'), 'not in line 1');
      Check(Diags.HasErrors, 'not in line 1 is an error');
    finally
      D.Free;
    end;
  finally
    Diags.Free;
  end;
end;

procedure ExpectRejected(const S: AnsiString; ALine: Integer; const AMsg: string);
var
  D: TLandrixGaebDA2000Document;
begin
  try
    D := Parse(S, nil);
    D.Free;
    FailNotRaised('ELandrixGaebError');
  except
    on E: ELandrixGaebError do
      Check(Pos('line ' + IntToStr(ALine) + ':', E.Message) > 0, AMsg + ': ' + E.Message);
  end;
end;

procedure TestRejected;
var
  S: AnsiString;
  I: Integer;
begin
  ExpectRejected('#begin[GAEB]' + CRLF + '#begin[Vergabe]' + CRLF + '#begin[LV]' + CRLF +
    '[Bez]x[end]' + CRLF, 3, 'truncated file');
  ExpectRejected('#begin[GAEB]' + CRLF + '#begin[Vergabe]' + CRLF + '[Langtext]x' + CRLF +
    'y' + CRLF, 3, 'value without [end]');
  ExpectRejected('', 1, 'empty input');
  S := '#begin[GAEB]' + CRLF;
  for I := 1 to 70 do
    S := S + '#begin[A]' + CRLF;
  ExpectRejected(S, 65, 'nesting too deep');
end;

procedure TestLineEnds;
const
  Ends: array[0..2] of AnsiString = (#10, #13, #13#13#10);
var
  D: TLandrixGaebDA2000Document;
  I: Integer;
begin
  for I := 0 to 2 do
  begin
    D := Parse(WithLineEnd(Doc('ANSI', '    [Langtext]a' + CRLF + '              b[end]' + CRLF), Ends[I]), nil);
    try
      CheckEqualsGaebStr('a' + #10 + 'b', D.Root.Find('Vergabe').ValueOf('Langtext'),
        'line end variant ' + IntToStr(I));
    finally
      D.Free;
    end;
  end;
  { an empty line stays a line: CR CR is two line ends, CR CR LF one }
  D := Parse('#begin[GAEB]'#13'#begin[A]'#13'[B]x'#13#13'y[end]'#13'[C]z[end]'#13'#end[A]'#13'#end[GAEB]', nil);
  try
    CheckEqualsGaebStr('x' + #10 + #10 + 'y', D.Root.Find('A').ValueOf('B'), 'empty line with CR');
    CheckEquals(6, D.Root.Find('A').Find('C').Line, 'line numbers after CR CR');
  finally
    D.Free;
  end;
  D := Parse('#begin[GAEB]'#13#13#10'#begin[A]'#13#10'[B]x'#13#13#10#13#13#10'y[end]'#10'#end[A]'#10'#end[GAEB]', nil);
  try
    CheckEqualsGaebStr('x' + #10 + #10 + 'y', D.Root.Find('A').ValueOf('B'), 'empty line with CR CR LF');
  finally
    D.Free;
  end;
end;

procedure TestSplitStructure;
var
  A: TLandrixGaebStringArray;
  Big: TLandrixGaebString;
  I: Integer;
begin
  A := LandrixGaebDA2000SplitStructure('a|b\|c|');
  CheckEquals(3, Length(A), 'three components');
  CheckEqualsGaebStr('a', A[0], 'first');
  CheckEqualsGaebStr('b|c', A[1], 'escaped bar');
  CheckEqualsGaebStr('', A[2], 'empty last');
  A := LandrixGaebDA2000SplitStructure('');
  CheckEquals(1, Length(A), 'one empty component');
  A := LandrixGaebDA2000SplitStructure('\|x\||y|\');
  CheckEquals(3, Length(A), 'escapes at the edges');
  CheckEqualsGaebStr('|x|', A[0], 'escaped bars at both ends');
  CheckEqualsGaebStr('\', A[2], 'a lone backslash is text');
  A := LandrixGaebDA2000SplitStructure('a|');
  CheckEquals(2, Length(A), 'trailing separator');
  { linear in the length: many escapes and many separators }
  Big := '';
  SetLength(Big, 200000);
  for I := 1 to 100000 do
  begin
    Big[2 * I - 1] := '\';
    Big[2 * I] := '|';
  end;
  A := LandrixGaebDA2000SplitStructure(Big);
  CheckEquals(1, Length(A), 'one component of escapes');
  CheckEquals(100000, Length(A[0]), 'escapes resolved');
  for I := 1 to 100000 do
    Big[2 * I - 1] := 'x';
  A := LandrixGaebDA2000SplitStructure(Big);
  CheckEquals(100001, Length(A), 'many components');
end;

{ ---- local corpus ---- }

var
  LocalFiles, LocalParsed, LocalRejected, LocalElements: Integer;
  LocalFailures: TStringList;
  LocalRules: TStringList;
  LocalCounts: array of Integer;

function CountElements(N: TLandrixGaebDA2000Node): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to N.Count - 1 do
    if N[I].IsObject then
      Inc(Result, CountElements(N[I]))
    else
      Inc(Result);
end;

procedure ParseLocalFile(const FileName: string);
var
  Stream: TFileStream;
  Det: TLandrixGaebDetection;
  Diags: TLandrixGaebDiagnostics;
  D: TLandrixGaebDA2000Document;
  I, K: Integer;
begin
  Det := LandrixGaebDetectFile(FileName, nil, 0);
  if Det.Format <> gfDA2000 then
    Exit;
  Inc(LocalFiles);
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    try
      D := LandrixGaebDA2000ParseStream(Stream, gcsUnknown, Diags);
      try
        Inc(LocalParsed);
        Inc(LocalElements, CountElements(D.Root));
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
  LocalElements := 0;
  LocalFailures := TStringList.Create;
  LocalRules := TStringList.Create;
  try
    LocalCounts := nil;
    WalkLocal(LocalDataDir);
    Summary := '';
    for I := 0 to LocalRules.Count - 1 do
      Summary := Summary + ' ' + LocalRules[I] + 'x' + IntToStr(LocalCounts[I]);
    WriteLn('  Local.DA2000Parse: ', LocalFiles, ' file(s), ', LocalParsed, ' parsed (',
      LocalElements, ' elements), ', LocalRejected, ' rejected, ', LocalFailures.Count, ' failed;', Summary);
    if LocalFailures.Count > 0 then
      Fail('unexpected exceptions: ' + LocalFailures.CommaText);
    Check(LocalFiles > 0, 'GAEB DA 2000 files found');
  finally
    LocalFailures.Free;
    LocalRules.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('DA2000Parser.Tree', TestTree);
  RegisterTest('DA2000Parser.ContinuationLines', TestContinuationLines);
  RegisterTest('DA2000Parser.Escapes', TestEscapes);
  RegisterTest('DA2000Parser.Charsets', TestCharsets);
  RegisterTest('DA2000Parser.EmptyAndStructure', TestEmptyAndStructure);
  RegisterTest('DA2000Parser.Rejected', TestRejected);
  RegisterTest('DA2000Parser.LineEnds', TestLineEnds);
  RegisterTest('DA2000Parser.SplitStructure', TestSplitStructure);
  RegisterTest('Local.DA2000Parse', TestLocalParse);
end;

end.

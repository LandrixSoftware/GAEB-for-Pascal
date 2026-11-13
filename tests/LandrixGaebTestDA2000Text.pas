{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of LandrixGaebDA2000Text: synthetic RTF and plain texts, and the
  texts of the GAEB DA 2000 files of the local corpus (skipped when
  missing; counts only, never content). }

unit LandrixGaebTestDA2000Text;

{$I LandrixGaeb.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixGaebTypes,
  LandrixGaebDetect,
  LandrixGaebDA2000Parser,
  LandrixGaebDA2000Text,
  LandrixGaebTestFramework;

function W(C: Word): TLandrixGaebString;
begin
  Result := WideChar(C);
end;

function ReadText(const S: TLandrixGaebString): TLandrixGaebDA2000Text;
begin
  Result := LandrixGaebDA2000ReadText(S);
end;

{ The text of paragraph I when it is one plain part. }
function ParaText(T: TLandrixGaebDA2000Text; I: Integer): TLandrixGaebString;
var
  J: Integer;
begin
  Result := '';
  for J := 0 to T[I].Count - 1 do
    if T[I][J].Kind = tpkText then
      Result := Result + T[I][J].Text
    else
      Result := Result + '<C>';
end;

const
  Head = '{\rtf1\ansi\ansicpg1252\deff0{\fonttbl{\f0\fnil Arial;}}' +
    '{\colortbl ;\red0\green0\blue0;}{\*\generator Test;}\viewkind4\uc1\pard\f0\fs20 ';

procedure TestPlain;
var
  T: TLandrixGaebDA2000Text;
begin
  T := ReadText('erste Zeile' + #10 + #10 + 'dritte Zeile' + #10);
  try
    Check(not T.IsRtf, 'plain');
    CheckEquals(3, T.Count, 'three paragraphs, the empty last line dropped');
    CheckEqualsGaebStr('erste Zeile', ParaText(T, 0), 'first');
    CheckEquals(0, T[1].Count, 'empty paragraph kept inside');
    CheckEqualsGaebStr('dritte Zeile', ParaText(T, 2), 'third');
    Check(T.Losses = [], 'no losses');
  finally
    T.Free;
  end;
  T := ReadText('a' + #13#10 + 'b' + #13 + 'c' + #13#10 + #13#10);
  try
    CheckEquals(3, T.Count, 'CR LF and CR end lines');
    CheckEqualsGaebStr('a' + #10 + 'b' + #10 + 'c', T.PlainText, 'no CR left');
  finally
    T.Free;
  end;
  T := ReadText('');
  try
    CheckEquals(0, T.Count, 'empty value');
  finally
    T.Free;
  end;
end;

procedure TestRtfParagraphs;
var
  T: TLandrixGaebDA2000Text;
begin
  T := ReadText(Head + 'Erste Zeile\par' + #13#10 + 'Zweite \b fett\b0  Zeile\par' + #13#10 +
    '\par Vierte\line mit Umbruch\tab und Tab\par }');
  try
    Check(T.IsRtf, 'RTF');
    CheckEquals(4, T.Count, 'four paragraphs, the trailing \par adds none: ' + IntToStr(T.Count));
    CheckEqualsGaebStr('Erste Zeile', ParaText(T, 0), 'header groups dropped');
    CheckEqualsGaebStr('Zweite fett Zeile', ParaText(T, 1), 'bold dropped, text kept');
    CheckEquals(0, T[2].Count, 'empty paragraph');
    CheckEqualsGaebStr('Vierte' + #10 + 'mit Umbruch' + #9 + 'und Tab', ParaText(T, 3), 'line and tab');
    Check(T.Losses = [tlCharFormat], 'character format reported');
  finally
    T.Free;
  end;
end;

procedure TestRtfCharacters;
var
  T: TLandrixGaebDA2000Text;
begin
  T := ReadText(Head + 'Ma\''dfe \''e4\''80 \u8364?\u-3971? x\~y a\-b \{\}\\ ' +
    '\emdash\endash\bullet\lquote\rquote\ldblquote\rdblquote\par}');
  try
    CheckEqualsGaebStr('Ma' + W($DF) + 'e ' + W($E4) + W($20AC) + ' ' + W($20AC) + W($F07D) +
      ' x' + W($A0) + 'y ab {}\ ' + W($2014) + W($2013) + W($2022) + W($2018) + W($2019) +
      W($201C) + W($201D), ParaText(T, 0), 'characters');
  finally
    T.Free;
  end;
  { \ansicpg850: \'xx is code page 850 }
  T := ReadText('{\rtf1\ansi\ansicpg850 \''84\''94\par}');
  try
    CheckEqualsGaebStr(W($E4) + W($F6), ParaText(T, 0), 'code page 850');
  finally
    T.Free;
  end;
  { \uc0: no fallback character; \uc2: two }
  T := ReadText('{\rtf1 {\uc0\u228 x}{\uc2\u246 ??y}\par}');
  try
    CheckEqualsGaebStr(W($E4) + 'x' + W($F6) + 'y', ParaText(T, 0), 'uc');
  finally
    T.Free;
  end;
end;

procedure TestRtfDropped;
var
  T: TLandrixGaebDA2000Text;
begin
  T := ReadText(Head + 'Bild {\pict\pngblip 89504e47}da{\*\shppict x}' +
    '{\object\objemb {\*\objdata 0102}}\par' +
    '\trowd\cellx1000\cellx2000 A\cell B\cell\row ' +
    'Seite {\field{\*\fldinst PAGE}{\fldrslt 3}}\par}');
  try
    CheckEquals(3, T.Count, 'three paragraphs');
    CheckEqualsGaebStr('Bild da', ParaText(T, 0), 'picture and object dropped');
    CheckEqualsGaebStr('A' + #9 + 'B' + #9, ParaText(T, 1), 'table cells as tabs, row as paragraph');
    CheckEqualsGaebStr('Seite 3', ParaText(T, 2), 'field result kept, instruction dropped');
    Check(T.Losses = [tlTable, tlPicture, tlObject], 'losses');
  finally
    T.Free;
  end;
end;

procedure TestComplements;
var
  T: TLandrixGaebDA2000Text;
  P: TLandrixGaebDA2000TextPart;
begin
  T := ReadText(Head + 'Liefern {\*\bkmkstart TB01}Fabrikat: {\*\bkmkstart Feld01}' +
    '\''85\''85....{\*\bkmkend Feld01} einsetzen{\*\bkmkend TB01} und ' +
    '{\*\bkmkstart TA2}Farbe {\*\bkmkstart Feld2}RAL 7016{\*\bkmkend Feld2}{\*\bkmkend TA2}.\par}');
  try
    CheckEquals(1, T.Count, 'one paragraph');
    CheckEquals(5, T[0].Count, 'text, complement, text, complement, text');
    CheckEquals(2, T.ComplementCount, 'two complements');
    CheckEquals(0, T.MarkProblems, 'no problems');
    CheckEqualsGaebStr('Liefern ', T[0][0].Text, 'text before');
    P := T[0][1];
    Check((P.Kind = tpkComplement) and P.Bidder and (P.Number = 1), 'TB01');
    CheckEqualsGaebStr('Fabrikat: ', P.Caption, 'caption');
    Check(P.Empty and (P.Body = ''), 'dots and ellipses are a placeholder');
    CheckEqualsGaebStr(' einsetzen', P.Tail, 'tail');
    CheckEqualsGaebStr(' und ', T[0][2].Text, 'text between');
    P := T[0][3];
    Check((not P.Bidder) and (P.Number = 2) and (not P.Empty), 'TA2 filled');
    CheckEqualsGaebStr('RAL 7016', P.Body, 'body');
    CheckEqualsGaebStr('', P.Tail, 'no tail');
    CheckEqualsGaebStr('.', T[0][4].Text, 'text after');
    CheckEqualsGaebStr('Liefern Fabrikat:  einsetzen und Farbe RAL 7016.', T.PlainText, 'plain text');
  finally
    T.Free;
  end;
  { a complement spanning a paragraph end keeps it as a line break }
  T := ReadText(Head + '{\*\bkmkstart TB03}Frage\par {\*\bkmkstart Feld03}{\*\bkmkend Feld03}' +
    '{\*\bkmkend TB03}\par}');
  try
    CheckEquals(1, T.Count, 'one paragraph');
    CheckEqualsGaebStr('Frage' + #10, T[0][0].Caption, 'paragraph end inside the caption');
    Check(T[0][0].Empty, 'empty field');
  finally
    T.Free;
  end;
end;

procedure TestComplementProblems;
var
  T: TLandrixGaebDA2000Text;
begin
  { start without end: text kept }
  T := ReadText(Head + 'a {\*\bkmkstart TB01}b {\*\bkmkstart Feld01}c{\*\bkmkend Feld01} d\par}');
  try
    CheckEquals(0, T.ComplementCount, 'no complement');
    CheckEquals(1, T.MarkProblems, 'one problem');
    CheckEqualsGaebStr('a b c d' + #10, ParaText(T, 0), 'text kept, the paragraph end as a line break');
  finally
    T.Free;
  end;
  { nested start: the first is dropped, the second kept }
  T := ReadText(Head + '{\*\bkmkstart TB01}a {\*\bkmkstart TB02}b{\*\bkmkstart Feld02}c' +
    '{\*\bkmkend Feld02}{\*\bkmkend TB02}{\*\bkmkend TB01}\par}');
  try
    CheckEquals(1, T.ComplementCount, 'inner complement kept');
    CheckEquals(2, T.MarkProblems, 'nested start and the orphan end');
    CheckEqualsGaebStr('a <C>', ParaText(T, 0), 'outer text kept as text');
  finally
    T.Free;
  end;
  { a field outside a mark, an end without start, other bookmarks }
  T := ReadText(Head + '{\*\bkmkstart Feld01}x{\*\bkmkend Feld01}{\*\bkmkend TA05}' +
    '{\*\bkmkstart Anker}y{\*\bkmkend Anker}\par}');
  try
    CheckEquals(0, T.ComplementCount, 'no complement');
    CheckEquals(3, T.MarkProblems, 'field start, field end, mark end');
    CheckEqualsGaebStr('xy', ParaText(T, 0), 'text kept, other bookmark ignored');
  finally
    T.Free;
  end;
  { field opened, mark closed before the field: text kept }
  T := ReadText(Head + '{\*\bkmkstart TB01}a{\*\bkmkstart Feld01}b{\*\bkmkend TB01}\par}');
  try
    CheckEquals(0, T.ComplementCount, 'field not closed');
    CheckEqualsGaebStr('ab', ParaText(T, 0), 'text kept');
  finally
    T.Free;
  end;
end;

procedure TestRobust;
const
  Inputs: array[0..9] of string = ('{\rtf', '{\rtf1 \', '{\rtf1 \''', '{\rtf1 \''4',
    '{\rtf1 }}}}}x', '{\rtf1 {{{{', '{\rtf1 \u', '{\rtf1 \bin99 x', '{\rtf1 {\*\bkmkstart',
    '{\rtf1 \uc99\u65 abc');
var
  T: TLandrixGaebDA2000Text;
  I: Integer;
  S: TLandrixGaebString;
begin
  for I := 0 to High(Inputs) do
  begin
    T := ReadText(TLandrixGaebString(Inputs[I]));
    T.Free;
  end;
  { deep nesting beyond the stack limit }
  S := '{\rtf1 ';
  for I := 1 to 2000 do
    S := S + '{';
  S := S + 'x';
  for I := 1 to 2000 do
    S := S + '}';
  S := S + 'y}';
  T := ReadText(S);
  try
    CheckEqualsGaebStr('xy', T.PlainText, 'deep nesting');
  finally
    T.Free;
  end;
end;

{ RTF with ` in place of the backslash (keeps the test sources free of
  escape sequences that tools might interpret). }
function Rtf(const S: string): TLandrixGaebString;
var
  I: Integer;
  R: string;
begin
  R := S;
  for I := 1 to Length(R) do
    if R[I] = '`' then
      R[I] := Chr(92);
  Result := TLandrixGaebString(R);
end;

function TextOf(const S: string): TLandrixGaebString;
var
  T: TLandrixGaebDA2000Text;
begin
  T := ReadText(Rtf(S));
  try
    Result := T.PlainText;
  finally
    T.Free;
  end;
end;

procedure TestRtfEdgeCases;
var
  T: TLandrixGaebDA2000Text;
  S: string;
  I: Integer;
  Big: TLandrixGaebString;
begin
  { a pending fallback ends at a group boundary }
  CheckEqualsGaebStr('AB', TextOf('{`rtf1{`u65}B}'), 'fallback ends at }');
  T := ReadText(Rtf('{`rtf1`u65{`*`bkmkstart TB1}x{`*`bkmkstart Feld1}{`*`bkmkend Feld1}{`*`bkmkend TB1}}'));
  try
    CheckEquals(1, T.ComplementCount, 'fallback does not eat a bookmark name');
  finally
    T.Free;
  end;
  { control words and symbols count as one fallback character }
  CheckEqualsGaebStr('AB', TextOf('{`rtf1`u65`~B}'), 'control symbol as fallback');
  CheckEqualsGaebStr('AB', TextOf('{`rtf1`u65`bin1 xB}'), '\bin with its data as fallback');
  CheckEqualsGaebStr('AB', TextOf('{`rtf1`u65`par B}'), 'control word as fallback');
  { parameters: the value counts }
  CheckEqualsGaebStr('AX', TextOf('{`rtf1`u0000000065?X}'), 'leading zeros');
  CheckEqualsGaebStr('B', TextOf('{`rtf1`bin0000000001 xB}'), '\bin with leading zeros');
  { skipped groups produce no text and no paragraph }
  CheckEqualsGaebStr('AB', TextOf('{`rtf1 A{`*`bin1 xhidden}B}'), '\bin as first word of a \* group');
  T := ReadText(Rtf('{`rtf1 A{`*`unknown `' + #10 + 'hidden}B}'));
  try
    CheckEquals(1, T.Count, 'escaped line end in a skipped group');
    CheckEqualsGaebStr('AB', T.PlainText, 'skipped group');
  finally
    T.Free;
  end;
  { different field numbers do not pair }
  T := ReadText(Rtf('{`rtf1{`*`bkmkstart TB1}C{`*`bkmkstart Feld1}...{`*`bkmkend Feld2}{`*`bkmkend TB1}}'));
  try
    CheckEquals(0, T.ComplementCount, 'Feld1 with Feld2 is no complement');
    Check(T.MarkProblems >= 2, 'reported');
    CheckEqualsGaebStr('C...', T.PlainText, 'text kept');
  finally
    T.Free;
  end;
  { state is restored at any depth }
  S := '{`rtf1 ';
  for I := 1 to 600 do
    S := S + '{';
  S := S + '{`*`unknown hidden}KEEP';
  for I := 1 to 600 do
    S := S + '}';
  CheckEqualsGaebStr('KEEPTAIL', TextOf(S + 'TAIL}'), 'deep groups');
  { losses: pictures inside skipped groups count, sizes do not }
  T := ReadText(Rtf('{`rtf1{`*`shppict{`pict 00}}X}'));
  try
    Check(T.Losses = [tlPicture], 'picture inside shppict');
  finally
    T.Free;
  end;
  T := ReadText(Rtf('{`rtf1`uldb X`ulnone`ulc2 Y}'));
  try
    Check(T.Losses = [tlCharFormat], 'underline variants');
  finally
    T.Free;
  end;
  { a nested field breaks the complement; its text is kept }
  T := ReadText(Rtf('{`rtf1{`*`bkmkstart TB1}{`*`bkmkstart Feld1}{`*`bkmkstart Feld2}___' +
    '{`*`bkmkend Feld2}{`*`bkmkend Feld1}{`*`bkmkend TB1}}'));
  try
    CheckEquals(0, T.ComplementCount, 'nested field');
    CheckEqualsGaebStr('___', T.PlainText, 'text of a broken complement kept');
  finally
    T.Free;
  end;
  { a mark without its field is no complement }
  T := ReadText(Rtf('{`rtf1{`*`bkmkstart TB1}caption{`*`bkmkend TB1}}'));
  try
    CheckEquals(0, T.ComplementCount, 'mark without field');
    CheckEquals(1, T.MarkProblems, 'mark without field reported');
    CheckEqualsGaebStr('caption', T.PlainText, 'its text kept');
  finally
    T.Free;
  end;
  T := ReadText(Rtf('{`rtf1`fs48`f1`cf2 X}'));
  try
    Check(T.Losses = [], 'font, size and colour are no reported loss');
  finally
    T.Free;
  end;
  { PlainText is linear }
  Big := '';
  SetLength(Big, 200000);
  for I := 1 to 100000 do
  begin
    Big[2 * I - 1] := 'x';
    Big[2 * I] := #10;
  end;
  T := ReadText(Big);
  try
    CheckEquals(100000, T.Count, 'many paragraphs');
    CheckEquals(199999, Length(T.PlainText), 'plain text of many paragraphs');
  finally
    T.Free;
  end;
end;

{ ---- local corpus ---- }

var
  LocalRtf, LocalPlain, LocalOwner, LocalBidder, LocalEmpty, LocalProblems: Integer;
  LocalLosses: array[TLandrixGaebDA2000Loss] of Integer;

procedure VisitNode(N: TLandrixGaebDA2000Node);
var
  I, P, J: Integer;
  T: TLandrixGaebDA2000Text;
  L: TLandrixGaebDA2000Loss;
begin
  for I := 0 to N.Count - 1 do
    if N[I].IsObject then
      VisitNode(N[I])
    else if (CompareText(N[I].Key, 'Langtext') = 0) or (CompareText(N[I].Key, 'Kurztext') = 0) or
      (CompareText(N[I].Key, 'TextRTF') = 0) or (CompareText(N[I].Key, 'ZusText') = 0) or
      (Copy(N[I].Value, 1, 5) = '{\rtf') then
    begin
      T := LandrixGaebDA2000ReadText(N[I].Value);
      try
        if T.IsRtf then
          Inc(LocalRtf)
        else
          Inc(LocalPlain);
        Inc(LocalProblems, T.MarkProblems);
        for L := Low(TLandrixGaebDA2000Loss) to High(TLandrixGaebDA2000Loss) do
          if L in T.Losses then
            Inc(LocalLosses[L]);
        for P := 0 to T.Count - 1 do
          for J := 0 to T[P].Count - 1 do
            if T[P][J].Kind = tpkComplement then
            begin
              if T[P][J].Bidder then
                Inc(LocalBidder)
              else
                Inc(LocalOwner);
              if T[P][J].Empty then
                Inc(LocalEmpty);
            end;
      finally
        T.Free;
      end;
    end;
end;

{ The parsed file, nil when the parser rejects it. }
function TryParse(Stream: TStream): TLandrixGaebDA2000Document;
begin
  try
    Result := LandrixGaebDA2000ParseStream(Stream, gcsUnknown, nil);
  except
    on ELandrixGaebError do
      Result := nil;
  end;
end;

procedure VisitFile(const FileName: string);
var
  Stream: TFileStream;
  D: TLandrixGaebDA2000Document;
begin
  if LandrixGaebDetectFile(FileName, nil, 0).Format <> gfDA2000 then
    Exit;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    D := TryParse(Stream);
    if D = nil then
      Exit;
    try
      VisitNode(D.Root);
    finally
      D.Free;
    end;
  finally
    Stream.Free;
  end;
end;

procedure Walk(const Dir: string);
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
        Walk(Dir + SR.Name + PathDelim)
      else
        VisitFile(Dir + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TestLocalTexts;
var
  L: TLandrixGaebDA2000Loss;
begin
  if not DirectoryExists(LocalDataDir) then
  begin
    Skip('local corpus not present');
    Exit;
  end;
  LocalRtf := 0;
  LocalPlain := 0;
  LocalOwner := 0;
  LocalBidder := 0;
  LocalEmpty := 0;
  LocalProblems := 0;
  for L := Low(TLandrixGaebDA2000Loss) to High(TLandrixGaebDA2000Loss) do
    LocalLosses[L] := 0;
  Walk(LocalDataDir);
  WriteLn('  Local.DA2000Texts: ', LocalRtf, ' RTF, ', LocalPlain, ' plain; complements ',
    LocalOwner, ' owner, ', LocalBidder, ' bidder, ', LocalEmpty, ' empty; ', LocalProblems,
    ' mark problem(s); dropped: format ', LocalLosses[tlCharFormat], ', table ',
    LocalLosses[tlTable], ', picture ', LocalLosses[tlPicture], ', object ', LocalLosses[tlObject]);
  Check(LocalRtf + LocalPlain > 0, 'texts found');
end;

procedure Register;
begin
  RegisterTest('DA2000Text.Plain', TestPlain);
  RegisterTest('DA2000Text.RtfParagraphs', TestRtfParagraphs);
  RegisterTest('DA2000Text.RtfCharacters', TestRtfCharacters);
  RegisterTest('DA2000Text.RtfDropped', TestRtfDropped);
  RegisterTest('DA2000Text.Complements', TestComplements);
  RegisterTest('DA2000Text.ComplementProblems', TestComplementProblems);
  RegisterTest('DA2000Text.Robust', TestRobust);
  RegisterTest('DA2000Text.RtfEdgeCases', TestRtfEdgeCases);
  RegisterTest('Local.DA2000Texts', TestLocalTexts);
end;

end.

{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of LandrixGaebDA90Reader, of the detection of GAEB 90 and of
  loading GAEB 90 into the bill of quantities (LoadFromFile/LoadFromStream,
  LoadFromDA90File/Stream), and the local corpus loaded through the facade
  (skipped when missing; counts only, never values). }

unit LandrixGaebTestDA90Reader;

{$I LandrixGaeb.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlWriter,
  LandrixGaebXmlCheck,
  LandrixGaebBoQ,
  LandrixGaebDA90Reader,
  LandrixGaebTestXmlCompare,
  LandrixGaebTestFramework;

const
  CRLF = #13#10;

var
  NextNo: Integer;

{ An empty record of type AKind (74 columns). }
function B(const AKind: AnsiString): AnsiString;
begin
  Result := AKind;
  while Length(Result) < 74 do
    Result := Result + ' ';
end;

{ S with AValue in columns ACol onwards. }
function F(const S: AnsiString; ACol: Integer; const AValue: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(AValue) do
    Result[ACol + I - 1] := AValue[I];
end;

{ S as a record with the next record number and a line end. }
function R(const S: AnsiString): AnsiString;
var
  I, N: Integer;
begin
  Inc(NextNo);
  Result := Copy(S, 1, 74) + '000000';
  N := NextNo;
  for I := 80 downto 75 do
  begin
    Result[I] := AnsiChar(Ord('0') + N mod 10);
    N := N div 10;
  end;
  Result := Result + CRLF;
end;

{ A bill of phase ADP: category 01 with a basic item (20.00) and an item
  for a provision only (1000.00, does not count), no 32; category 02 with
  one item (5.00) and a 32 of 999.00; 99 without LVSUMME. AWith21 False
  leaves out the records 21 (a bid of 23 records only). }
function Priced(const ADP: AnsiString; AWith21: Boolean): AnsiString;

  function Item(const AOZ, AKind, AGB: AnsiString): AnsiString;
  begin
    Result := '';
    if AWith21 then
      Result := R(F(F(F(F(B('21'), 3, AOZ), 12, AKind), 24, '00000001000'), 35, 'St'));
    Result := Result + R(F(F(F(B('23'), 3, AOZ), 13, '0000000000'), 25, AGB));
  end;

begin
  NextNo := 0;
  Result := R(F(F(F(B('00'), 11, ADP), 63, '11PPPP000'), 72, '90')) +
    R(F(B('01'), 3, 'Rohbau')) +
    R(F(B('02'), 3, 'Neubau')) +
    Item('010010', 'NNN', '000000002000') +
    Item('010020', 'NEN', '000000100000') +
    Item('020010', 'NNN', '000000000500') +
    R(F(F(B('32'), 3, '02'), 13, '000000099900')) +
    R(F(B('99'), 70, '00003'));
end;

function StreamOf(const S: AnsiString): TMemoryStream;
begin
  Result := TMemoryStream.Create;
  if S <> '' then
    Result.WriteBuffer(S[1], Length(S));
  Result.Position := 0;
end;

function TotalText(ATotals: TLandrixGaebTotals): string;
begin
  Result := LandrixXmlUtf8ToString(ATotals.Value(gtfTotal).Text);
end;

procedure TestDetect;
var
  S, U: AnsiString;
  Det: TLandrixGaebDetection;
  Diags: TLandrixGaebDiagnostics;
  I: Integer;
begin
  S := Priced('83', True);
  Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), False, nil);
  Check(Det.Format = gfDA90, 'GAEB 90');
  CheckEqualsStr('83', Det.SourcePhase, 'DP of record 00');
  CheckEqualsStr('90', Det.SourceVersion, 'VERSDTA of record 00');
  Check(Det.SourceCharset = LandrixGaebTypes.gcsUnknown, 'no declared character set');
  { a byte order mark before the first record }
  U := #$EF#$BB#$BF + S;
  Det := LandrixGaebDetectBuffer(Pointer(U), Length(U), False, nil);
  Check(Det.Format = gfDA90, 'GAEB 90 after a byte order mark');
  CheckEqualsStr('83', Det.SourcePhase, 'DP after a byte order mark');
  { UTF-8: every record with a two-byte character in column 5 (81 bytes,
    80 characters); the columns of DP and VERSDTA count characters }
  U := '';
  I := 1;
  while I <= Length(S) do
  begin
    U := U + Copy(S, I, 4) + #$C3#$A4 + Copy(S, I + 5, 77);
    Inc(I, 82);
  end;
  Det := LandrixGaebDetectBuffer(Pointer(U), Length(U), False, nil);
  Check(Det.Format = gfDA90, 'GAEB 90 in UTF-8');
  CheckEqualsStr('83', Det.SourcePhase, 'DP in UTF-8');
  CheckEqualsStr('90', Det.SourceVersion, 'VERSDTA in UTF-8');
  { contract terms before record 00; VERSDTA left empty }
  NextNo := 0;
  S := R(B('T0')) + R(F(B('T1'), 3, 'Bedingungen')) + R(B('T9')) +
    R(F(F(B('00'), 11, '88'), 63, '11PPPP000')) + R(B('99'));
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), False, Diags);
    CheckEqualsStr('88', Det.SourcePhase, 'DP after T records, also a phase not read');
    CheckEqualsStr('', Det.SourceVersion, 'empty VERSDTA');
    CheckEquals(0, Diags.CountOf('GAEB-DET-016'), 'nothing to report');
    { no record 00, and a DP that is no digits }
    NextNo := 0;
    S := R(F(B('01'), 3, 'LV')) + R(B('99'));
    Diags.Clear;
    Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), False, Diags);
    Check(Det.Format = gfDA90, 'still GAEB 90');
    CheckEquals(1, Diags.CountOf('GAEB-DET-016'), 'record 00 missing');
    NextNo := 0;
    S := R(F(B('00'), 11, 'X3')) + R(B('99'));
    Diags.Clear;
    Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), False, Diags);
    CheckEqualsStr('', Det.SourcePhase, 'unusable DP left empty');
    CheckEquals(1, Diags.CountOf('GAEB-DET-016'), 'unusable DP reported');
    Check(Pos('X3', Diags.ToText) = 0, 'no value in the message');
    { the first record 00 counts, as for the mapping, also without a
      record number }
    NextNo := 0;
    S := F(F(B('00'), 11, '83'), 63, '11PPPP000') + CRLF + R(F(F(B('00'), 11, '84'), 63, '11PPPP000')) +
      R(B('99'));
    Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), False, nil);
    Check(Det.Format = gfDA90, 'GAEB 90 with a short first record');
    CheckEqualsStr('83', Det.SourcePhase, 'DP of the first record 00');
    { a short record 00 in UTF-8 (74 characters, a two-byte character in
      column 5) counts characters as well }
    NextNo := 0;
    S := F(F(F(B('00'), 11, '83'), 63, '11PPPP000'), 72, '90');
    S := Copy(S, 1, 4) + #$C3#$A4 + Copy(S, 6, MaxInt) + CRLF + R(F(B('01'), 3, 'LV')) + R(B('99'));
    Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), False, nil);
    CheckEqualsStr('83', Det.SourcePhase, 'DP of a short UTF-8 record 00');
    CheckEqualsStr('90', Det.SourceVersion, 'VERSDTA of a short UTF-8 record 00');
    { NUL inside a record is a space for the record reader, no line end }
    NextNo := 0;
    S := R(F(F(F(B('00'), 11, '83'), 63, '11PPPP000'), 72, '90'));
    S[5] := #0;
    S := S + R(B('99'));
    Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), False, nil);
    CheckEqualsStr('83', Det.SourcePhase, 'DP after a NUL in the record');
    { records chained by NUL NUL: record 00 after a T record on one line }
    NextNo := 0;
    S := R(B('T0'));
    S := Copy(S, 1, 80) + #0#0 + R(F(F(F(B('00'), 11, '84'), 63, '11PPPP000'), 72, '90')) + R(B('99'));
    Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), False, nil);
    CheckEqualsStr('84', Det.SourcePhase, 'DP of a chained record 00');
    { a prefix of chained records without any line end: the complete ones
      count, the one cut off at the end does not }
    S := Copy(R(F(F(F(B('00'), 11, '83'), 63, '11PPPP000'), 72, '90')), 1, 80) + #0#0 +
      Copy(R(F(B('01'), 3, 'LV')), 1, 40);
    Diags.Clear;
    Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), True, Diags);
    CheckEqualsStr('83', Det.SourcePhase, 'DP of a chained record 00 in a prefix');
    CheckEquals(0, Diags.CountOf('GAEB-DET-016'), 'nothing reported for the prefix');
    S := Copy(R(B('T0')), 1, 80) + #0#0 + Copy(R(F(F(F(B('00'), 11, '83'), 63, '11PPPP000'), 72, '90')), 1, 60);
    Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), True, Diags);
    CheckEqualsStr('', Det.SourcePhase, 'a record 00 cut off at the end does not count');
    { the same in UTF-8, the prefix ending inside a two-byte character }
    S := F(F(F(B('00'), 11, '83'), 63, '11PPPP000'), 72, '90') + '000001';
    S := Copy(S, 1, 4) + #$C3#$A4 + Copy(S, 6, MaxInt) + #0#0 + Copy(R(F(B('02'), 3, 'Neubau')), 1, 10) + #$C3;
    Diags.Clear;
    Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), True, Diags);
    CheckEqualsStr('83', Det.SourcePhase, 'DP of a chained UTF-8 record 00 in a prefix');
    CheckEqualsStr('90', Det.SourceVersion, 'VERSDTA of a chained UTF-8 record 00 in a prefix');
    { a long chain without any line end and without record 00 is read once,
      not again for every record (32768 records, 2.7 MB) }
    S := Copy(R(F(B('T1'), 3, 'Text')), 1, 80) + #0#0;
    U := S;
    for I := 1 to 15 do
      U := U + U;
    Diags.Clear;
    Det := LandrixGaebDetectBuffer(Pointer(U), Length(U), False, Diags);
    Check(Det.Format = gfDA90, 'a long chain is GAEB 90');
    CheckEquals(1, Diags.CountOf('GAEB-DET-016'), 'a long chain without record 00');
  finally
    Diags.Free;
  end;
  { an overlong UTF-8 sequence is no UTF-8 (as for the record reader): the
    lines have 82 bytes and are no records }
  S := Priced('83', True);
  U := '';
  I := 1;
  while I <= Length(S) do
  begin
    U := U + Copy(S, I, 4) + #$E0#$80#$80 + Copy(S, I + 5, 77);
    Inc(I, 82);
  end;
  Det := LandrixGaebDetectBuffer(Pointer(U), Length(U), False, nil);
  Check(Det.Format <> gfDA90, 'invalid UTF-8 is not counted in characters');
end;

procedure TestReadBuffer;
var
  S, U: AnsiString;
  I: Integer;
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  T: TLandrixGaebTarget;
begin
  S := Priced('86', True);
  Diags := TLandrixGaebDiagnostics.Create;
  try
    G := LandrixGaebDA90ReadBuffer(Pointer(S), Length(S), LandrixGaebDA90DefaultReadOptions, Diags, Det, T);
    try
      Check(Det.Format = gfDA90, 'format of the input');
      Check(Det.Target.Version = gvUnknown, 'the detection keeps no target');
      CheckEqualsStr('86', Det.SourcePhase, 'phase as found');
      CheckEqualsStr('90', Det.SourceVersion, 'version as found');
      Check(Det.SourceCharset = LandrixGaebTypes.gcsUnknown, 'no declared character set');
      Check((T.Version = gv33) and (T.Edition = ge2021_05) and (T.Phase = gp86), 'mapped target');
      CheckEquals(2, Integer(G.Award.BoQ.BoQBody.Children.Count), 'categories mapped');
      { the reader maps only: no total is computed }
      CheckEquals(0, Diags.CountOf('GAEB-PRC-005'), 'nothing filled by the reader');
      CheckEquals(1, Diags.CountOf('GAEB-D90-FILE-001'), 'character set reported once');
    finally
      G.Free;
    end;
    { UTF-8 with a byte order mark: a two-byte character before DP and a
      byte that is no UTF-8 behind it; DP and VERSDTA are those of record 00
      as the record reader reads it }
    NextNo := 0;
    S := R(F(F(F(B('00'), 11, '83L'), 63, '11PPPP000'), 72, '90'));
    S := #$EF#$BB#$BF + Copy(S, 1, 4) + #$C3#$A4 + Copy(S, 6, 14) + #$FF + Copy(S, 21, MaxInt) +
      R(F(B('01'), 3, 'LV')) + R(B('99'));
    Diags.Clear;
    G := LandrixGaebDA90ReadBuffer(Pointer(S), Length(S), LandrixGaebDA90DefaultReadOptions, Diags, Det, T);
    try
      CheckEqualsStr('83', Det.SourcePhase, 'DP of record 00 as read');
      CheckEqualsStr('90', Det.SourceVersion, 'VERSDTA of record 00 as read');
      CheckEquals(0, Diags.CountOf('GAEB-DET-016'), 'no detection message on record 00');
      Check(T.Phase = gp83, 'mapped phase');
    finally
      G.Free;
    end;
    { the same in every record: the format is still recognised }
    NextNo := 0;
    S := #$EF#$BB#$BF;
    U := R(F(F(F(B('00'), 11, '83L'), 63, '11PPPP000'), 72, '90')) + R(F(B('01'), 3, 'LV')) + R(B('99'));
    I := 1;
    while I <= Length(U) do
    begin
      S := S + Copy(U, I, 4) + #$C3#$A4 + Copy(U, I + 5, 14) + #$FF + Copy(U, I + 20, 62);
      Inc(I, 82);
    end;
    Det := LandrixGaebDetectBuffer(Pointer(S), Length(S), False, nil);
    Check(Det.Format = gfDA90, 'GAEB 90 with a byte order mark and bytes that are no UTF-8');
    G := LandrixGaebDA90ReadBuffer(Pointer(S), Length(S), LandrixGaebDA90DefaultReadOptions, nil, Det, T);
    try
      CheckEqualsStr('83', Det.SourcePhase, 'DP in every record with such bytes');
    finally
      G.Free;
    end;
  finally
    Diags.Free;
  end;
end;

procedure TestOptions;
var
  S: AnsiString;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  T: TLandrixGaebTarget;
  Options: TLandrixGaebDA90ReadOptions;
  Expected: TLandrixGaebString;
begin
  Options := LandrixGaebDA90DefaultReadOptions;
  CheckEqualsInt64(0, Options.MaxSize, 'default size limit');
  Check(Options.Charset = LandrixGaebTypes.gcsUnknown, 'default: decided from the bytes');
  Check(Options.OemCodePage = gocCp850, 'default OEM code page');
  { byte $9B is o with stroke in code page 850, a cent sign in 437 }
  NextNo := 0;
  S := R(F(F(B('00'), 11, '83L'), 63, '11PPPP000')) + R(F(B('02'), 3, 'A' + #$9B)) + R(B('99'));
  Options.Charset := gcsOem;
  G := LandrixGaebDA90ReadBuffer(Pointer(S), Length(S), Options, nil, Det, T);
  try
    Expected := 'A';
    Expected := Expected + WideChar($00F8);
    CheckEqualsGaebStr(Expected, G.PrjInfo.LblPrj, 'OEM 850');
  finally
    G.Free;
  end;
  Options.OemCodePage := gocCp437;
  G := LandrixGaebDA90ReadBuffer(Pointer(S), Length(S), Options, nil, Det, T);
  try
    Expected := 'A';
    Expected := Expected + WideChar($00A2);
    CheckEqualsGaebStr(Expected, G.PrjInfo.LblPrj, 'OEM 437');
    Check(Det.SourceCharset = LandrixGaebTypes.gcsUnknown, 'SourceCharset stays unknown');
  finally
    G.Free;
  end;
  Options.Charset := gcsAnsi;
  G := LandrixGaebDA90ReadBuffer(Pointer(S), Length(S), Options, nil, Det, T);
  try
    Expected := 'A';
    Expected := Expected + WideChar($203A);
    CheckEqualsGaebStr(Expected, G.PrjInfo.LblPrj, 'ANSI as given');
  finally
    G.Free;
  end;
end;

procedure TestRejected;
var
  S, Part: AnsiString;
  Det: TLandrixGaebDetection;
  T: TLandrixGaebTarget;
  Options: TLandrixGaebDA90ReadOptions;
  Stream: TMemoryStream;
  Raised: Boolean;
begin
  { XML is no GAEB 90 }
  S := '<?xml version="1.0"?><GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA83/3.3"/>';
  Raised := False;
  try
    LandrixGaebDA90ReadBuffer(Pointer(S), Length(S), LandrixGaebDA90DefaultReadOptions, nil, Det, T).Free;
  except
    on E: ELandrixGaebError do
      Raised := Pos('GAEB 90', E.Message) > 0;
  end;
  Check(Raised, 'XML rejected');
  { a later part of a split file: a foreign line, records without 00 }
  S := Priced('83', True);
  Part := #9'rest of a record' + CRLF + Copy(S, 82 * 3 + 1, MaxInt);
  Raised := False;
  try
    LandrixGaebDA90ReadBuffer(Pointer(Part), Length(Part), LandrixGaebDA90DefaultReadOptions, nil,
      Det, T).Free;
  except
    on E: ELandrixGaebError do
      Raised := Pos('record 00', E.Message) > 0;
  end;
  Check(Raised, 'later part rejected');
  { a phase not read }
  NextNo := 0;
  S := R(F(F(B('00'), 11, '88'), 63, '11PPPP000')) + R(B('99'));
  Raised := False;
  try
    LandrixGaebDA90ReadBuffer(Pointer(S), Length(S), LandrixGaebDA90DefaultReadOptions, nil, Det, T).Free;
  except
    on E: ELandrixGaebError do
      Raised := Pos('88', E.Message) > 0;
  end;
  Check(Raised, 'phase 88 rejected');
  { the size limit holds for buffers and streams; a stream is not read }
  S := Priced('83', True);
  Options := LandrixGaebDA90DefaultReadOptions;
  Options.MaxSize := 100;
  Raised := False;
  try
    LandrixGaebDA90ReadBuffer(Pointer(S), Length(S), Options, nil, Det, T).Free;
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'buffer over the size limit');
  Stream := StreamOf(S);
  try
    Raised := False;
    try
      LandrixGaebDA90ReadStream(Stream, Options, nil, Det, T).Free;
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'stream over the size limit');
    CheckEqualsInt64(0, Stream.Position, 'stream not read');
    Raised := False;
    try
      TLandrixGaebBillOfQuantities.LoadFromStream(Stream, nil, 100).Free;
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'the facade passes AMaxSize on');
  finally
    Stream.Free;
  end;
end;

{ A markup item 020020 of a bid from a 23 without 21. }
function MarkupWithout21: AnsiString;
begin
  Result := R(F(F(F(B('23'), 3, '020020'), 57, '00300'), 63, '000000050000'));
end;

procedure TestLoadBill;
var
  S: AnsiString;
  Stream: TMemoryStream;
  Diags: TLandrixGaebDiagnostics;
  B: TLandrixGaebBillOfQuantities;
  Options: TLandrixGaebDA90ReadOptions;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := StreamOf(Priced('86', True));
  try
    B := TLandrixGaebBillOfQuantities.LoadFromStream(Stream, Diags, 0);
    try
      Check(B.SourceFormat = gfDA90, 'read from GAEB 90');
      CheckEqualsStr('86', B.Source.SourcePhase, 'source phase');
      CheckEqualsStr('90', B.Source.SourceVersion, 'source version');
      Check(B.Source.SourceCharset = LandrixGaebTypes.gcsUnknown, 'source character set');
      Check((B.Target.Version = gv33) and (B.Target.Phase = gp86), 'target');
      Check((B.OutputTarget.Version = gv33) and (B.OutputTarget.Edition = ge2021_05), 'output target');
      CheckEquals(1, Diags.CountOf('GAEB-BOQ-003'), 'reading noted');
      CheckEquals(0, Diags.CountOf('GAEB-BOQ-002'), 'not noted as GAEB DA 2000');
      CheckEqualsStr('20', TotalText(TLandrixGaebCategory(B.Root[0]).Totals), 'missing total computed');
      CheckEqualsStr('999.00', TotalText(TLandrixGaebCategory(B.Root[1]).Totals), 'total of the file kept');
      { the bill adds the items: 20.00 + 5.00 }
      CheckEqualsStr('25', TotalText(B.Totals), 'total of the bill computed');
      CheckEquals(1, Diags.CountOf('GAEB-PRC-005'), 'filled totals reported');
    finally
      B.Free;
    end;
    { with options }
    Diags.Clear;
    Stream.Position := 0;
    Options := LandrixGaebDA90DefaultReadOptions;
    Options.Charset := gcsOem;
    B := TLandrixGaebBillOfQuantities.LoadFromDA90Stream(Stream, Options, Diags);
    try
      Check(B.SourceFormat = gfDA90, 'LoadFromDA90Stream: format');
      CheckEquals(2, B.Root.Count, 'LoadFromDA90Stream: categories');
      CheckEquals(1, Diags.CountOf('GAEB-BOQ-003'), 'LoadFromDA90Stream: reading noted');
    finally
      B.Free;
    end;
  finally
    Stream.Free;
    Diags.Free;
  end;
  { a bid whose items carry their kinds (21) counts by them }
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := StreamOf(Priced('84', True));
  try
    B := TLandrixGaebBillOfQuantities.LoadFromStream(Stream, Diags, 0);
    try
      CheckEqualsStr('20', TotalText(TLandrixGaebCategory(B.Root[0]).Totals), 'bid: total computed');
      CheckEqualsStr('25', TotalText(B.Totals), 'bid: total of the bill computed');
      CheckEquals(0, Diags.CountOf('GAEB-BOQ-004'), 'bid with kinds: no warning');
    finally
      B.Free;
    end;
  finally
    Stream.Free;
    Diags.Free;
  end;
  { a markup item from a 23 without 21 has no kind either }
  Diags := TLandrixGaebDiagnostics.Create;
  S := Priced('84', True);
  Insert(MarkupWithout21, S, Length(S) - 2 * 82 + 1);
  Stream := StreamOf(S);
  try
    B := TLandrixGaebBillOfQuantities.LoadFromStream(Stream, Diags, 0);
    try
      CheckEquals(2, TLandrixGaebCategory(B.Root[1]).Children.Count, 'markup item read');
      CheckEquals(1, Diags.CountOf('GAEB-BOQ-004'), 'markup item without kind: warned');
      CheckEquals(0, Diags.CountOf('GAEB-PRC-005'), 'markup item without kind: nothing filled');
    finally
      B.Free;
    end;
  finally
    Stream.Free;
    Diags.Free;
  end;
  { a bid of 23 records only: no kinds, nothing filled }
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := StreamOf(Priced('84', False));
  try
    B := TLandrixGaebBillOfQuantities.LoadFromStream(Stream, Diags, 0);
    try
      Check(not TLandrixGaebCategory(B.Root[0]).Totals.Value(gtfTotal).HasValue, 'bid without kinds: left missing');
      Check(not B.Totals.Value(gtfTotal).HasValue, 'bid without kinds: no total of the bill');
      CheckEquals(1, Diags.CountOf('GAEB-BOQ-004'), 'bid without kinds: warned');
      Check(Pos('3 item(s)', Diags.ToText) > 0, 'items counted: ' + Diags.ToText);
      CheckEquals(0, Diags.CountOf('GAEB-PRC-005'), 'bid without kinds: nothing filled');
    finally
      B.Free;
    end;
  finally
    Stream.Free;
    Diags.Free;
  end;
end;

var
  LocalFiles, LocalLoaded, LocalRejected, LocalValid, LocalFilled, LocalLeft, LocalNoKind: Integer;

procedure LoadLocalFile(const FileName: string);
var
  Diags, CheckDiags: TLandrixGaebDiagnostics;
  B: TLandrixGaebBillOfQuantities;
  Options: TLandrixGaebXmlWriteOptions;
  Xml: TLandrixXmlUtf8;
  Errors, Warnings: Integer;
begin
  if LandrixGaebDetectFile(FileName, nil, 0).Format <> gfDA90 then
    Exit;
  Inc(LocalFiles);
  Diags := TLandrixGaebDiagnostics.Create;
  CheckDiags := TLandrixGaebDiagnostics.Create;
  try
    try
      B := TLandrixGaebBillOfQuantities.LoadFromFile(FileName, Diags, 0);
    except
      on ELandrixGaebError do
        B := nil;
    end;
    if B = nil then
    begin
      Inc(LocalRejected);
      Exit;
    end;
    try
      Inc(LocalLoaded);
      if Diags.CountOf('GAEB-PRC-005') > 0 then
        Inc(LocalFilled);
      if Diags.CountOf('GAEB-PRC-006') > 0 then
        Inc(LocalLeft);
      if Diags.CountOf('GAEB-BOQ-004') > 0 then
        Inc(LocalNoKind);
      Options := LandrixGaebXmlDefaultWriteOptions;
      Options.Mode := gwmBestEffort;
      Options.Check := False;
      Xml := LandrixGaebXmlWriteCollect(B.Document, B.OutputTarget, Options, Diags, Errors, Warnings);
      if LandrixGaebXmlCheckTarget(Pointer(Xml), Length(Xml), B.OutputTarget, CheckDiags) then
        Inc(LocalValid);
    finally
      B.Free;
    end;
  finally
    CheckDiags.Free;
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
        LoadLocalFile(Dir + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TestLocalLoad;
begin
  if not DirectoryExists(LocalDataDir) then
  begin
    Skip('local corpus not present');
    Exit;
  end;
  LocalFiles := 0;
  LocalLoaded := 0;
  LocalRejected := 0;
  LocalValid := 0;
  LocalFilled := 0;
  LocalLeft := 0;
  LocalNoKind := 0;
  WalkLocal(LocalDataDir);
  WriteLn('  Local.DA90Load: ', LocalFiles, ' file(s), ', LocalLoaded, ' loaded into the bill, ',
    LocalRejected, ' rejected, ', LocalValid, ' valid against the content model; ', LocalFilled,
    ' with totals filled, ', LocalLeft, ' with totals left missing, ', LocalNoKind,
    ' bid(s) without kinds');
  Check(LocalFiles > 0, 'GAEB 90 files found');
end;

const
  { Differences between the model read from the .D83 of the local
    multi-format bill and the one read from its .X83 (written by the GAEB
    Toolbox) that are expected (paths without indexes):
    - PrjInfo/NamePrj and BoQInfo/Name: GAEB 90 has no source; the reader
      fills them by the owner's rule (PROBEZ, VERGAG, LVBEZ), the Toolbox
      by its own.
    - OWN/Address/PCode: the Toolbox takes a postal code out of the free
      text AGBEZ; the reader does not guess parts of an address.
    - BoQBkdn/LblBoQBkdn: the Toolbox writes its own names of the levels;
      the reader takes KENNWORT of record 11 only.
    - BoQBkdn/Num: the Toolbox writes No for every level; the reader says
      Yes for a level written with digits only.
    - BoQInfo/Totals: record 99 holds the VAT rate; X83 has no totals (the
      writer leaves them out for X83).
    - Item/LumpSumItem: the reader sets it for the unit psch, the X83 keeps
      the unit without the flag. }
  Documented: array[0..6] of string = (
    '/GAEB/PrjInfo/NamePrj',
    '/GAEB/Award/OWN/Address/PCode',
    '/GAEB/Award/BoQ/BoQInfo/Name',
    '/GAEB/Award/BoQ/BoQInfo/BoQBkdn/LblBoQBkdn',
    '/GAEB/Award/BoQ/BoQInfo/BoQBkdn/Num',
    '/GAEB/Award/BoQ/BoQInfo/Totals (presence)',
    '/GAEB/Award/BoQ/BoQBody/BoQCtgy/BoQBody/Itemlist/Item/LumpSumItem');

function StripIndexes(const APath: string): string;
var
  I: Integer;
  Skip: Boolean;
begin
  Result := '';
  Skip := False;
  for I := 1 to Length(APath) do
    if APath[I] = '[' then
      Skip := True
    else if APath[I] = ']' then
      Skip := False
    else if not Skip then
      Result := Result + APath[I];
end;

function IsDocumented(const APath: string): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := Low(Documented) to High(Documented) do
    if APath = Documented[I] then
      Exit;
  Result := False;
end;

{ Clears what describes the file, not the bill. }
procedure Neutral(ADoc: TLandrixGaebXmlGAEB);
begin
  ADoc.GAEBInfo.Version := '';
  ADoc.GAEBInfo.VersDate := '';
  ADoc.GAEBInfo.Date := '';
  ADoc.GAEBInfo.Time := '';
  ADoc.GAEBInfo.ProgSystem := '';
  ADoc.GAEBInfo.ProgName := '';
end;

{ Semantic acceptance (plan, phase 8): the .D83 of the local multi-format
  bill against its .X83, compared with CompareGaebModelsAccept (IDs and
  text formatting are not compared). Prints paths and counts, never
  values. }
procedure TestLocalAccept;
var
  SR: TSearchRec;
  Dir, XmlName, DAName, Key: string;
  Diags: TLandrixGaebDiagnostics;
  X, P: TLandrixGaebBillOfQuantities;
  Diffs, Paths: TStringList;
  Counts: array of Integer;
  I, K, Known: Integer;
begin
  Dir := LocalDataDir + 'gaeb-multiformat' + PathDelim;
  XmlName := '';
  if FindFirst(Dir + '*.X83', faAnyFile, SR) = 0 then
  try
    XmlName := Dir + SR.Name;
  finally
    FindClose(SR);
  end;
  DAName := ChangeFileExt(XmlName, '.D83');
  if (XmlName = '') or not FileExists(DAName) then
  begin
    Skip('local multi-format bill not present');
    Exit;
  end;
  Diags := TLandrixGaebDiagnostics.Create;
  Diffs := TStringList.Create;
  Paths := TStringList.Create;
  X := nil;
  P := nil;
  try
    X := TLandrixGaebBillOfQuantities.LoadFromFile(XmlName, Diags, 0);
    P := TLandrixGaebBillOfQuantities.LoadFromFile(DAName, Diags, 0);
    Check(P.SourceFormat = gfDA90, 'the D83 is read as GAEB 90');
    Neutral(X.Document);
    Neutral(P.Document);
    CompareGaebModelsAccept(X.Document, P.Document, Diffs);
    Counts := nil;
    Known := 0;
    for I := 0 to Diffs.Count - 1 do
    begin
      Key := StripIndexes(Diffs[I]);
      if IsDocumented(Key) then
        Inc(Known);
      K := Paths.IndexOf(Key);
      if K < 0 then
      begin
        K := Paths.Add(Key);
        SetLength(Counts, K + 1);
        Counts[K] := 0;
      end;
      Inc(Counts[K]);
    end;
    for I := 0 to Paths.Count - 1 do
      if (GetEnvironmentVariable('LANDRIX_ACCEPTPATHS') <> '') or not IsDocumented(Paths[I]) then
        WriteLn('    ', Counts[I]: 6, '  ', Paths[I]);
    CheckEquals(Known, Diffs.Count, 'only documented differences');
    WriteLn('  Local.DA90Accept: D83 against X83: ', Diffs.Count, ' difference(s), ', Known,
      ' of them documented');
  finally
    P.Free;
    X.Free;
    Paths.Free;
    Diffs.Free;
    Diags.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('DA90Reader.Detect', TestDetect);
  RegisterTest('DA90Reader.ReadBuffer', TestReadBuffer);
  RegisterTest('DA90Reader.Options', TestOptions);
  RegisterTest('DA90Reader.Rejected', TestRejected);
  RegisterTest('DA90Reader.LoadBill', TestLoadBill);
  RegisterTest('Local.DA90Load', TestLocalLoad);
  RegisterTest('Local.DA90Accept', TestLocalAccept);
end;

end.

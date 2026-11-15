{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of LandrixGaebDA90Mapping: synthetic GAEB 90 files, and the GAEB
  90 files of the local corpus (skipped when missing). The local test
  prints counts and rule identifiers only, never file names or content of
  the files. }
unit LandrixGaebTestDA90Mapping;

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
  LandrixGaebXmlBase,
  LandrixGaebXmlModel,
  LandrixGaebXmlWriter,
  LandrixGaebXmlCheck,
  LandrixGaebCharsets,
  LandrixGaebDA90Parser,
  LandrixGaebDA90Mapping,
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

function MapText(const S: AnsiString; Diags: TLandrixGaebDiagnostics;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  D: TLandrixGaebDA90Document;
begin
  D := LandrixGaebDA90Parse(Pointer(S), Length(S), gcsUnknown, gcpCp850, Diags);
  try
    Result := LandrixGaebDA90Map(D, Diags, nil, ATarget);
  finally
    D.Free;
  end;
end;

function WriteXml(G: TLandrixGaebXmlGAEB; const T: TLandrixGaebTarget): TLandrixXmlUtf8;
var
  Errors, Warnings: Integer;
begin
  Result := LandrixGaebXmlWriteCollect(G, T, LandrixGaebXmlDefaultWriteOptions, nil, Errors, Warnings);
end;

function Contains(const AXml: TLandrixXmlUtf8; const APart: AnsiString): Boolean;
begin
  Result := Pos(LandrixXmlBufToUtf8(PAnsiChar(APart), Length(APart)), AXml) > 0;
end;

{ The messages of rule ARule, joined. }
function DiagnosticText(Diags: TLandrixGaebDiagnostics; const ARule: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Integer(Diags.Count) - 1 do
    if Diags[I].RuleId = ARule then
      Result := Result + Diags[I].Message + '|';
end;

function Sample83: AnsiString;
begin
  NextNo := 0;
  Result :=
    R(F(F(F(F(F(B('00'), 11, '83L'), 14, 'V-1'), 29, 'DV1'), 63, '1122PPPPI'), 72, '90')) +
    R(F(F(F(F(B('01'), 3, 'Rohbau'), 43, '15.11.26'), 51, '01.12.26'), 59, '10:30')) +
    R(F(B('02'), 3, 'Neubau Halle')) +
    R(F(B('03'), 3, 'Stadt Musterstadt')) +
    R(F(F(B('08'), 3, 'EUR'), 9, 'Euro')) +
    R(F(B('07'), 3, 'K1')) +
    R(F(F(F(B('11'), 3, '01'), 12, 'N'), 17, 'Titel')) +
    R(F(B('12'), 3, 'Erdarbeiten')) +
    R(B('20')) +
    R(F(B('26'), 6, 'Vorbemerkung')) +
    R(F(F(F(F(F(B('21'), 3, '01  0010'), 12, 'NNN'), 24, '00000012500'), 35, 'm3'), 43, 'X')) +
    R(F(B('25'), 3, 'Boden ausheben')) +
    R(F(B('26'), 6, 'Boden ausheben lang')) +
    R(F(F(F(B('26'), 3, '01'), 5, 'B'), 6, 'Fabrikat ''....''')) +
    R(B('26')) +
    R(F(F(F(B('21'), 3, '01  0020'), 12, 'NEN'), 35, 'psch')) +
    R(F(F(F(F(B('23'), 3, '01  0020'), 13, '0000012345'), 23, '6'), 25, '000000012346')) +
    R(F(F(F(B('21'), 3, '01  0030'), 12, 'NNN'), 20, 'Z')) +
    R(F(F(F(B('23'), 3, '01  0030'), 57, '00500'), 63, '000000100000')) +
    R(F(F(B('21'), 3, '0201  10A'), 12, 'SNN')) +
    R(F(F(B('75'), 3, '0201  10A'), 74, ' ')) +
    R(F(F(B('32'), 3, '01'), 13, '000000012345')) +
    R(F(F(B('99'), 3, '000000012345'), 70, '00004'));
end;

procedure TestMapSample;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  C1, C2: TLandrixGaebXmlBoQCtgy;
  It: TLandrixGaebXmlItem;
  M: TLandrixGaebXmlMarkupItem;
  Xml: TLandrixXmlUtf8;
  Info: TLandrixGaebXmlBoQInfo;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(Sample83, Diags, T);
  try
    Check((T.Version = gv33) and (T.Edition = ge2021_05) and (T.Phase = gp83), 'target X83');
    CheckEqualsGaebStr('83', G.Award.DP, 'DP');
    Info := G.Award.BoQ.BoQInfo;
    CheckEqualsGaebStr('AllTxt', Info.OutlCompl, 'long form');
    CheckEqualsGaebStr('V-1', G.Award.OWN.AwardNo, 'VERGAG');
    CheckEqualsGaebStr('DV1', G.Award.OWN.DPNo, 'DVNRAG');
    CheckEqualsGaebStr('Rohbau', Info.LblBoQ, 'LVBEZ');
    CheckEqualsGaebStr('2026-11-15', Info.Date, 'LVDATUM');
    CheckEqualsGaebStr('2026-12-01', G.Award.AwardInfo.OpenDate, 'DATANG');
    CheckEqualsGaebStr('10:30:00', G.Award.AwardInfo.OpenTime, 'DATUHR');
    CheckEqualsGaebStr('Neubau Halle', G.PrjInfo.LblPrj, 'PROBEZ');
    CheckEqualsGaebStr('Stadt Musterstadt', G.Award.OWN.Address.Name1, 'AGBEZ');
    CheckEqualsGaebStr('EUR', G.PrjInfo.Cur, 'currency of the project');
    CheckEqualsGaebStr('Euro', G.Award.AwardInfo.CurLbl, 'currency of the award');
    { breakdown from the mask }
    CheckEquals(4, Integer(Info.BoQBkdn.Count), 'breakdown levels');
    CheckEqualsGaebStr('BoQLevel', Info.BoQBkdn[1].TypeElement, 'level 2');
    CheckEqualsGaebStr('Item', Info.BoQBkdn[2].TypeElement, 'item level');
    CheckEqualsGaebStr('4', Info.BoQBkdn[2].LengthElement, 'item length');
    CheckEqualsGaebStr('Index', Info.BoQBkdn[3].TypeElement, 'index level');
    CheckEqualsGaebStr('Titel', Info.BoQBkdn[0].LblBoQBkdn, 'KENNWORT');
    CheckEqualsGaebStr('right', Info.BoQBkdn[0].Alignment, 'alignment');
    CheckEqualsGaebStr('Yes', Info.BoQBkdn[0].Num, 'numeric level');
    CheckEqualsGaebStr('No', Info.BoQBkdn[2].Num, 'item numbers with spaces in front');
    { categories: 01 from its 11, 02 and 02/01 derived }
    CheckEquals(2, Integer(G.Award.BoQ.BoQBody.Children.Count), 'two categories on top');
    C1 := TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]);
    CheckEqualsGaebStr('01', C1.RNoPart, 'category number');
    CheckEquals(4, Integer(C1.BoQBody.Itemlist.Children.Count), 'remark, two items and a markup item');
    Check(C1.BoQBody.Itemlist.Children[0] is TLandrixGaebXmlRemark, 'remark first');
    It := TLandrixGaebXmlItem(C1.BoQBody.Itemlist.Children[1]);
    CheckEqualsGaebStr('0010', It.RNoPart, 'item number');
    CheckEqualsGaebStr('12.500', LandrixXmlUtf8ToWide(It.Qty.Text), 'quantity');
    CheckEqualsGaebStr('m3', It.QU, 'unit');
    CheckEqualsGaebStr('Yes', It.Description.CompleteText.ComplTSB, 'TB');
    It := TLandrixGaebXmlItem(C1.BoQBody.Itemlist.Children[2]);
    CheckEqualsGaebStr('Yes', It.LumpSumItem, 'psch');
    CheckEqualsGaebStr('WithoutTotal', It.Provis, 'POSART2 E');
    CheckEqualsGaebStr('123.456', LandrixXmlUtf8ToWide(It.UP.Text), 'price with EPZPF');
    CheckEqualsGaebStr('123.46', LandrixXmlUtf8ToWide(It.IT.Text), 'total');
    Check(C1.BoQBody.Itemlist.Children[3] is TLandrixGaebXmlMarkupItem, 'markup item');
    M := TLandrixGaebXmlMarkupItem(C1.BoQBody.Itemlist.Children[3]);
    CheckEqualsGaebStr('IdentAsMark', M.MarkupType, 'markup type');
    CheckEqualsGaebStr('5.00', LandrixXmlUtf8ToWide(M.Markup.Text), 'ZUSCHPR');
    CheckEqualsGaebStr('1000.00', LandrixXmlUtf8ToWide(M.ITMarkup.Text), 'ZUSCHSU');
    CheckEqualsGaebStr('123.45', LandrixXmlUtf8ToWide(C1.Totals.Total.Text), 'group total');
    CheckEqualsGaebStr('123.45', LandrixXmlUtf8ToWide(Info.Totals.Total.Text), 'bill total');
    C2 := TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[1]);
    CheckEqualsGaebStr('02', C2.RNoPart, 'derived category');
    C2 := TLandrixGaebXmlBoQCtgy(C2.BoQBody.Children[0]);
    CheckEqualsGaebStr('01', C2.RNoPart, 'derived sub category');
    CheckEquals(1, Integer(C2.LblTx.Children.Count), 'empty label of a derived category');
    CheckEqualsGaebStr('V-1', Info.Name, 'BoQInfo/Name from VERGAG');
    CheckEquals(2, Diags.CountOf('GAEB-D90-MAP-014'), 'Name and empty labels reported');
    It := TLandrixGaebXmlItem(C2.BoQBody.Itemlist.Children[0]);
    CheckEqualsGaebStr('10', It.RNoPart, 'item part without spaces');
    CheckEqualsGaebStr('A', It.RNoIndex, 'index');
    CheckEqualsGaebStr('Yes', It.HourIt, 'POSART1 S');
    Xml := WriteXml(G, T);
    Check(Contains(Xml, '<ComplCaption><p><span>Fabrikat</span></p></ComplCaption>'), 'caption');
    Check(Contains(Xml, 'Empty="Yes"'), 'placeholder body');
    Check(Contains(Xml, '<p><span>Boden ausheben lang</span></p>'), 'long text line');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-005'), 'derived categories reported');
    CheckEquals(0, Diags.CountOf('GAEB-BR-D90-003'), 'ANZTEIL fits');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-001'), 'record 07 not mapped');
    CheckEquals(1, Diags.CountOf('GAEB-BR-D90-014'), 'record 75 skipped');
    CheckEquals(0, Diags.CountOf('GAEB-D90-MAP-011'), 'no mixed levels');
    CheckEquals(0, Diags.CountOf('GAEB-D90-MAP-009'), 'no orphans');
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ A tender (84): items from 23 without 21, the quantity from FREIEMEN, a
  bidder complement with text. }
procedure TestMap84;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  It: TLandrixGaebXmlItem;
  S: AnsiString;
  Xml: TLandrixXmlUtf8;
begin
  NextNo := 0;
  S := R(F(F(B('00'), 11, '84'), 63, '11PPPP000')) +
    R(F(B('01'), 3, 'Rohbau')) +
    R(F(B('02'), 3, 'Neubau')) +
    R(F(B('03'), 3, 'Stadt')) +
    R(F(B('04'), 3, 'Bauunternehmung Mustermann GmbH und Co. KG Niederlassung')) +
    R(F(F(B('08'), 3, 'EUR'), 9, 'Euro')) +
    R(F(F(F(F(B('23'), 3, '010010'), 13, '0000001000'), 25, '000000002000'), 38, '00000002000')) +
    R(F(F(F(B('26'), 3, '01'), 5, 'B'), 6, 'Fabrikat ''Muster''')) +
    R(F(B('99'), 70, '00001'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    Check(T.Phase = gp84, 'X84');
    CheckEqualsGaebStr('', G.Award.BoQ.BoQInfo.OutlCompl, 'no form in 84');
    CheckEqualsGaebStr('Bauunternehmung Mustermann GmbH und Co.', G.Award.CTR.Address.Name1, 'Name1 cut');
    CheckEqualsGaebStr('KG Niederlassung', G.Award.CTR.Address.Name2, 'rest in Name2');
    It := TLandrixGaebXmlItem(TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]).BoQBody.Itemlist.Children[0]);
    CheckEqualsGaebStr('0010', It.RNoPart, 'item from 23');
    CheckEqualsGaebStr('10.00', LandrixXmlUtf8ToWide(It.UP.Text), 'EP');
    CheckEqualsGaebStr('2.000', LandrixXmlUtf8ToWide(It.Qty.Text), 'quantity from FREIEMEN');
    Xml := WriteXml(G, T);
    Check(Contains(Xml, '<ComplBody><p><span>Muster</span></p></ComplBody>'), 'bidder text');
    Check(not Contains(Xml, 'Empty="Yes"'), 'not empty');
    CheckEquals(0, Diags.CountOf('GAEB-BR-D90-003'), 'one position');
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ Masks with spaces and masks that cannot be read; categories and items on
  one level; values outside GAEB 90. }
procedure TestMasksAndRules;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  S: AnsiString;
  It: TLandrixGaebXmlItem;
begin
  NextNo := 0;
  S := R(F(F(B('00'), 11, '83L'), 63, '11PPPP   ')) +
    R(F(F(B('21'), 3, '010010'), 12, 'NNN')) + R(F(B('99'), 70, '00001'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    CheckEquals(1, Diags.CountOf('GAEB-BR-D90-005'), 'spaces in the mask');
    It := TLandrixGaebXmlItem(TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]).BoQBody.Itemlist.Children[0]);
    CheckEqualsGaebStr('0010', It.RNoPart, 'read with the mask');
  finally
    G.Free;
    Diags.Free;
  end;
  NextNo := 0;
  S := R(F(F(B('00'), 11, '83L'), 63, '111222333')) +
    R(F(F(B('21'), 3, '010010'), 12, 'NNN')) + R(F(B('99'), 70, '00001'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    CheckEquals(1, Diags.CountOf('GAEB-BR-D90-001'), 'mask without P');
    It := TLandrixGaebXmlItem(G.Award.BoQ.BoQBody.Itemlist.Children[0]);
    CheckEqualsGaebStr('010010', It.RNoPart, 'whole number as item');
  finally
    G.Free;
    Diags.Free;
  end;
  { an item of level 1 next to a group of level 2; ZUSCHLAG A; TEKZ s; a
    complement with one apostrophe; NNH }
  NextNo := 0;
  S := R(F(F(B('00'), 11, '83L'), 63, '1122PPPPI')) +
    R(F(F(B('11'), 3, '01'), 12, 'N')) +
    R(F(F(F(B('21'), 3, '01  0010'), 12, 'NNN'), 20, 'A')) +
    R(F(F(F(B('26'), 3, '01'), 5, 's'), 6, 'Text')) +
    R(F(F(F(B('26'), 3, '02'), 5, 'B'), 6, 'Fabrikat ''offen')) +
    R(F(F(B('11'), 3, '0101'), 12, 'N')) +
    R(F(F(B('21'), 3, '01010020'), 12, 'NNH')) +
    R(F(B('26'), 6, 'Hinweis')) +
    R(B('20')) +
    R(F(F(F(B('21'), 3, '01010030'), 12, 'NNN'), 39, 'N01')) +
    R(F(B('99'), 70, '00005'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-011'), 'categories and items on one level');
    CheckEquals(1, Diags.CountOf('GAEB-BR-D90-006'), 'ZUSCHLAG A');
    CheckEquals(1, Diags.CountOf('GAEB-BR-D90-011'), 'TEKZ s');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-003'), 'one apostrophe');
    CheckEquals(1, Diags.CountOf('GAEB-BR-D90-007'), 'NNH');
    CheckEquals(1, Diags.CountOf('GAEB-BR-D90-003'), 'ANZTEIL differs');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-009'), 'note text without text left out');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-002'), 'NACHTRKZ not mapped');
    Check(TLandrixGaebXmlBoQCtgy(TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]).BoQBody.Children[0]).
      BoQBody.Itemlist.Children[0] is TLandrixGaebXmlRemark, 'NNH as remark');
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ Regressions of the first review of the mapping, and a file that is valid
  against the content model apart from GAEBInfo/Date (owner decision). }
procedure TestReviewCases;
var
  Diags, CheckDiags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  S: AnsiString;
  It: TLandrixGaebXmlItem;
  M: TLandrixGaebXmlMarkupItem;
  Xml: TLandrixXmlUtf8;
  List: TLandrixGaebXmlItemlist;
  I, Errors, Warnings: Integer;
  Options: TLandrixGaebXmlWriteOptions;
begin
  { phase 84: a negative price below a cent, a markup item from a 23 }
  NextNo := 0;
  S := R(F(F(B('00'), 11, '84'), 63, '11PPPP000')) +
    R(F(F(F(F(B('23'), 3, '010010'), 12, '-'), 13, '0000000000'), 23, '1')) +
    R(F(F(F(B('23'), 3, '010020'), 57, '00300'), 63, '000000050000')) +
    R(F(B('99'), 70, '00002'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    List := TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]).BoQBody.Itemlist;
    It := TLandrixGaebXmlItem(List.Children[0]);
    CheckEqualsGaebStr('-0.001', LandrixXmlUtf8ToWide(It.UP.Text), 'negative price below a cent');
    Check(List.Children[1] is TLandrixGaebXmlMarkupItem, 'markup item from a 23');
    M := TLandrixGaebXmlMarkupItem(List.Children[1]);
    CheckEqualsGaebStr('3.00', LandrixXmlUtf8ToWide(M.Markup.Text), 'its percentage');
  finally
    G.Free;
    Diags.Free;
  end;
  { calendar dates, numbers with spaces behind, TA on the short text,
    marks counted per line }
  NextNo := 0;
  S := R(F(F(B('00'), 11, '81L'), 63, '11PPPP000')) +
    R(F(F(B('01'), 3, 'LV'), 43, '31.02.26')) +
    R(F(F(F(F(B('21'), 3, '010010'), 12, 'NNN'), 24, '0000001000 '), 42, 'X')) +
    R(F(B('25'), 3, 'Kurz')) +
    R(F(F(B('26'), 3, '01'), 6, 'eins')) +
    R(F(F(B('26'), 3, '01'), 6, 'zwei')) +
    R(F(B('99'), 70, '00001'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    CheckEqualsGaebStr('', G.Award.BoQ.BoQInfo.Date, '31.02. is no date');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-010'), 'date reported');
    It := TLandrixGaebXmlItem(TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]).BoQBody.Itemlist.Children[0]);
    Check(not It.Qty.HasValue, 'spaces behind: no number');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-008'), 'number reported');
    CheckEqualsGaebStr('Yes', It.Description.CompleteText.OutlineText.OutlTSA, 'TA on the short text');
    Check(Pos('2 text line(s)', DiagnosticText(Diags, 'GAEB-BR-D90-011')) > 0, 'two lines with KNR without TEKZ');
  finally
    G.Free;
    Diags.Free;
  end;
  { valid apart from GAEBInfo/Date }
  NextNo := 0;
  S := R(F(F(B('00'), 11, '81L'), 63, '11PPPP000')) +
    R(F(F(B('01'), 3, 'Rohbau'), 43, '15.11.26')) +
    R(F(B('02'), 3, 'Neubau')) +
    R(F(F(B('11'), 3, '01'), 12, 'N')) +
    R(F(B('12'), 3, 'Erdarbeiten')) +
    R(F(F(F(F(B('21'), 3, '010010'), 12, 'NNN'), 24, '00000001000'), 35, 'm3')) +
    R(F(B('25'), 3, 'Boden ausheben')) +
    R(F(B('26'), 6, 'Boden ausheben, lang')) +
    R(F(B('99'), 70, '00001'));
  Diags := TLandrixGaebDiagnostics.Create;
  CheckDiags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    Options := LandrixGaebXmlDefaultWriteOptions;
    Options.Mode := gwmBestEffort;
    Options.Check := False;
    Xml := LandrixGaebXmlWriteCollect(G, T, Options, Diags, Errors, Warnings);
    CheckEquals(0, Errors, 'written without error');
    LandrixGaebXmlCheckTarget(Pointer(Xml), Length(Xml), T, CheckDiags);
    for I := 0 to Integer(CheckDiags.Count) - 1 do
      Check((CheckDiags[I].RuleId = 'GAEB-CHK-002') and (Pos('GAEBInfo', CheckDiags[I].Path) > 0) and
        (Pos('expected Date', CheckDiags[I].Message) > 0), 'only GAEBInfo/Date missing: ' + CheckDiags[I].Message);
    CheckEquals(1, Integer(CheckDiags.Count), 'one finding of the check');
  finally
    G.Free;
    CheckDiags.Free;
    Diags.Free;
  end;
end;

{ Regressions of the second review: complements over lines and in the
  short text, OutlTSA without long text, marks on a blank line, leap days,
  alternatives numbered 0, control characters in an ordinal number. }
procedure TestReviewCases2;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  S: AnsiString;
  List: TLandrixGaebXmlItemlist;
  It: TLandrixGaebXmlItem;
  Xml: TLandrixXmlUtf8;
begin
  NextNo := 0;
  S := R(F(F(B('00'), 11, '83L'), 63, '11PPPP000')) +
    R(F(F(B('01'), 3, 'LV'), 43, '29.02.24')) +
    R(F(F(F(B('21'), 3, '010010'), 12, 'NNN'), 42, 'X')) +
    R(F(F(B('25'), 3, 'Farbe ''weiss'''), 73, '03')) +
    R(F(F(F(B('26'), 3, '02'), 5, 'A'), 6, 'Fabrikat:')) +
    R(F(F(F(B('26'), 3, '02'), 5, 'A'), 6, '''Muster')) +
    R(F(F(F(B('26'), 3, '02'), 5, 'A'), 6, 'AG'' oder gleich')) +
    R(F(B('26'), 3, '04')) +
    R(F(F(F(B('21'), 3, '010020'), 12, 'NNN'), 42, 'X')) +
    R(F(B('25'), 3, 'nur kurz')) +
    R(F(F(F(B('21'), 3, '010030'), 12, 'ANN'), 15, '0010')) +
    R(F(F(B('21'), 3, '0100'#1'4'), 12, 'NNN')) +
    R(F(B('99'), 70, '00004'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    CheckEqualsGaebStr('2024-02-29', G.Award.BoQ.BoQInfo.Date, 'leap day');
    List := TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]).BoQBody.Itemlist;
    It := TLandrixGaebXmlItem(List.Children[1]);
    CheckEqualsGaebStr('Yes', It.Description.OutlineText.OutlTSA, 'OutlTSA without long text');
    It := TLandrixGaebXmlItem(List.Children[2]);
    CheckEqualsGaebStr('', It.ALNSerNo, 'alternative 0 left out');
    It := TLandrixGaebXmlItem(List.Children[3]);
    CheckEqualsGaebStr('004', It.RNoPart, 'control character removed from the number');
    Xml := WriteXml(G, T);
    Check(Contains(Xml, '<ComplBody><p><span>Muster</span><br/><span>AG</span></p></ComplBody>'), 'body over lines');
    Check(Contains(Xml, '<ComplTail><p><span> oder gleich</span></p></ComplTail>'), 'tail');
    Check(Contains(Xml, 'MarkLbl="03"'), 'short text complement');
    Check(Contains(Xml, 'Kind="Owner"'), 'owner complement');
    Check(Pos('1 text line(s)', DiagnosticText(Diags, 'GAEB-BR-D90-011')) > 0, 'KNR on a blank line');
    Check(Pos('21/ZZ', DiagnosticText(Diags, 'GAEB-D90-MAP-004')) > 0, 'alternative 0 reported');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-006'), 'control character reported');
  finally
    G.Free;
    Diags.Free;
  end;
  { a 32 with a gap in its number names no group }
  NextNo := 0;
  S := R(F(F(B('00'), 11, '83L'), 63, '123PPPP00')) +
    R(F(F(B('11'), 3, '1'), 12, 'N')) +
    R(F(F(B('21'), 3, '1  0010'), 12, 'NNN')) +
    R(F(F(B('32'), 3, '1 3'), 13, '000000012345')) +
    R(F(B('99'), 70, '00001'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    Check(not TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]).Totals.Total.HasValue, 'no total taken');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-013'), 'gap reported');
  finally
    G.Free;
    Diags.Free;
  end;
  NextNo := 0;
  S := R(F(F(B('00'), 11, '83L'), 63, '11PPPP000')) + R(F(F(B('01'), 3, 'LV'), 43, '29.02.25')) + R(B('99'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    CheckEqualsGaebStr('', G.Award.BoQ.BoQInfo.Date, 'no leap day in 2025');
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ Remarks in a row and the look-ahead: linear time. }
procedure TestManyRemarks;
var
  S, Block: AnsiString;
  I: Integer;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
begin
  NextNo := 0;
  S := R(F(F(B('00'), 11, '81L'), 63, '11PPPP000'));
  { 2^14 remarks, doubled (the record numbers repeat; not checked here) }
  Block := R(B('20')) + R(F(B('26'), 6, 'Hinweis'));
  for I := 1 to 14 do
    Block := Block + Block;
  S := S + Block + R(F(F(B('21'), 3, '010010'), 12, 'NNN')) + R(B('99'));
  G := MapText(S, nil, T);
  try
    CheckEquals(16385, Integer(TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]).BoQBody.Itemlist.Children.Count),
      'remarks and the item');
  finally
    G.Free;
  end;
end;

procedure TestRejected;
var
  S: AnsiString;
  T: TLandrixGaebTarget;
  G: TLandrixGaebXmlGAEB;
  Msg: string;
begin
  NextNo := 0;
  S := R(F(F(B('00'), 11, '88'), 63, '11PPPP000')) + R(B('99'));
  Msg := '';
  try
    G := MapText(S, nil, T);
    G.Free;
  except
    on E: ELandrixGaebError do
      Msg := E.Message;
  end;
  Check(Pos('phase 88 is not read', Msg) > 0, 'phase 88 rejected');
  NextNo := 0;
  S := R(F(B('01'), 3, 'x')) + R(B('99'));
  Msg := '';
  try
    G := MapText(S, nil, T);
    G.Free;
  except
    on E: ELandrixGaebError do
      Msg := E.Message;
  end;
  Check(Pos('no record 00', Msg) > 0, 'file without 00 rejected');
end;

var
  LocalFiles, LocalParseRejected, LocalMapRejected, LocalMapped, LocalValid, LocalValidButDate: Integer;
  LocalRules: TStringList;
  LocalCounts: array of Integer;
  LocalFailures: TStringList;

procedure AddRule(const AName: string);
var
  K: Integer;
begin
  K := LocalRules.IndexOf(AName);
  if K < 0 then
  begin
    K := LocalRules.Add(AName);
    SetLength(LocalCounts, K + 1);
    LocalCounts[K] := 0;
  end;
  Inc(LocalCounts[K]);
end;

function StripIndexes(const APath: TLandrixGaebString): string;
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
      Result := Result + Char(Ord(APath[I]));
end;

procedure MapLocalFile(const FileName: string);
var
  Stream: TFileStream;
  Diags, CheckDiags: TLandrixGaebDiagnostics;
  D: TLandrixGaebDA90Document;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  I: Integer;
  Options: TLandrixGaebXmlWriteOptions;
  Xml: TLandrixXmlUtf8;
  Errors, Warnings: Integer;
begin
  if LandrixGaebDetectFile(FileName, nil, 0).Format <> gfDA90 then
    Exit;
  Inc(LocalFiles);
  Diags := TLandrixGaebDiagnostics.Create;
  CheckDiags := TLandrixGaebDiagnostics.Create;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    D := nil;
    try
      D := LandrixGaebDA90ParseStream(Stream, gcsUnknown, gcpCp850, Diags);
    except
      on ELandrixGaebError do
        Inc(LocalParseRejected);
    end;
    if D = nil then
      Exit;
    try
      G := nil;
      try
        G := LandrixGaebDA90Map(D, Diags, nil, T);
      except
        on ELandrixGaebError do
          Inc(LocalMapRejected);
        on E: Exception do
          LocalFailures.Add(E.ClassName);
      end;
      if G = nil then
        Exit;
      try
        Inc(LocalMapped);
        Options := LandrixGaebXmlDefaultWriteOptions;
        Options.Mode := gwmBestEffort;
        Options.Check := False;
        Xml := LandrixGaebXmlWriteCollect(G, T, Options, Diags, Errors, Warnings);
        if LandrixGaebXmlCheckTarget(Pointer(Xml), Length(Xml), T, CheckDiags) then
          Inc(LocalValid)
        else if (CheckDiags.Count = 1) and (CheckDiags[0].RuleId = 'GAEB-CHK-002') and
          (StripIndexes(CheckDiags[0].Path) = '/GAEB/GAEBInfo') then
          { GAEB 90 has no date of the file (owner decision: left missing) }
          Inc(LocalValidButDate);
      finally
        G.Free;
      end;
    finally
      D.Free;
    end;
    for I := 0 to Integer(Diags.Count) - 1 do
      AddRule(Diags[I].RuleId);
    for I := 0 to Integer(CheckDiags.Count) - 1 do
    begin
      AddRule('check:' + CheckDiags[I].RuleId);
      { element paths only, never messages or values }
      if GetEnvironmentVariable('LANDRIX_CHECKPATHS') <> '' then
        AddRule('check ' + CheckDiags[I].RuleId + ' ' + StripIndexes(CheckDiags[I].Path));
      { the messages of these two name elements only }
      if (GetEnvironmentVariable('LANDRIX_CHECKPATHS') = '2') and
        ((CheckDiags[I].RuleId = 'GAEB-CHK-001') or (CheckDiags[I].RuleId = 'GAEB-CHK-002')) then
        AddRule('message ' + StringReplace(CheckDiags[I].Message, ' ', '_', [rfReplaceAll]));
    end;
  finally
    Stream.Free;
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
        MapLocalFile(Dir + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TestLocalMap;
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
  LocalParseRejected := 0;
  LocalMapRejected := 0;
  LocalMapped := 0;
  LocalValid := 0;
  LocalValidButDate := 0;
  LocalRules := TStringList.Create;
  LocalFailures := TStringList.Create;
  LocalCounts := nil;
  try
    WalkLocal(LocalDataDir);
    Summary := '';
    for I := 0 to LocalRules.Count - 1 do
      Summary := Summary + ' ' + LocalRules[I] + 'x' + IntToStr(LocalCounts[I]);
    WriteLn('  Local.DA90Map: ', LocalFiles, ' file(s), ', LocalParseRejected, ' rejected by the parser, ',
      LocalMapRejected, ' by the mapping, ', LocalMapped, ' mapped, ', LocalValid,
      ' valid against the content model, ', LocalValidButDate, ' valid apart from GAEBInfo/Date;', Summary);
    if LocalFailures.Count > 0 then
      Fail('unexpected exceptions: ' + LocalFailures.CommaText);
    Check(LocalFiles > 0, 'GAEB 90 files found');
  finally
    LocalFailures.Free;
    LocalRules.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('DA90Mapping.Sample', TestMapSample);
  RegisterTest('DA90Mapping.Tender', TestMap84);
  RegisterTest('DA90Mapping.MasksAndRules', TestMasksAndRules);
  RegisterTest('DA90Mapping.ReviewCases', TestReviewCases);
  RegisterTest('DA90Mapping.ReviewCases2', TestReviewCases2);
  RegisterTest('DA90Mapping.ManyRemarks', TestManyRemarks);
  RegisterTest('DA90Mapping.Rejected', TestRejected);
  RegisterTest('Local.DA90Map', TestLocalMap);
end;

end.

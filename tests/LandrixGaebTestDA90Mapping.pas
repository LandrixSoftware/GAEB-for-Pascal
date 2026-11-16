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
    CheckEqualsGaebStr('Neubau Halle', G.PrjInfo.NamePrj, 'NamePrj from PROBEZ');
    CheckEquals(4, Diags.CountOf('GAEB-D90-MAP-014'), 'Name, NamePrj, GAEBInfo/Date and empty labels reported');
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
  against the content model (GAEBInfo/Date from LVDATUM, owner decision
  16.11.2026). }
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
  Errors, Warnings: Integer;
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
    CheckEqualsGaebStr('', G.GAEBInfo.Date, 'GAEBInfo/Date without LVDATUM');
    Check(Pos('stays missing', DiagnosticText(Diags, 'GAEB-D90-MAP-014')) > 0, 'GAEBInfo/Date missing reported');
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
  { valid against the content model: GAEBInfo/Date from LVDATUM }
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
    CheckEqualsGaebStr('2026-11-15', G.GAEBInfo.Date, 'GAEBInfo/Date from LVDATUM');
    Check(Pos('taken from LVDATUM', DiagnosticText(Diags, 'GAEB-D90-MAP-014')) > 0, 'GAEBInfo/Date reported');
    Check(LandrixGaebXmlCheckTarget(Pointer(Xml), Length(Xml), T, CheckDiags),
      'valid against the content model: ' + CheckDiags.ToText);
    CheckEquals(0, Integer(CheckDiags.Count), 'no finding of the check');
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

{ Part 2b-1: sub descriptions, quantity splits, references, execution
  descriptions, StLNo, STLB-Bau, contract terms. }
procedure TestDescriptionsAndRefs;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  S: AnsiString;
  List: TLandrixGaebXmlItemlist;
  It, It2: TLandrixGaebXmlItem;
  Perf: TLandrixGaebXmlPerfDescr;
  Sub: TLandrixGaebXmlSubDescr;
  Xml: TLandrixXmlUtf8;
begin
  NextNo := 0;
  S := R(F(B('T0'), 3, ' ')) + R(F(B('T1'), 3, 'Vertragsbedingungen')) + R(B('T9')) +
    R(F(F(B('00'), 11, '83L'), 63, '11PPPP000')) +
    R(F(B('01'), 3, 'LV')) +
    R(F(F(B('41'), 3, '0001'), 7, 'Mauerwerk allgemein')) +
    R(F(F(B('42'), 5, '1'), 6, '01234567890123456')) +
    R(F(B('25'), 3, 'Block eins')) +
    R(B('42')) +
    R(F(B('26'), 6, 'Block zwei lang')) +
    R(F(F(F(F(F(B('21'), 3, '010010'), 12, 'NNL'), 24, '00000010000'), 35, 'm2'), 44, '1')) +
    R(F(B('25'), 3, 'Leitbeschreibung')) +
    R(F(F(F(B('24'), 3, '01'), 6, '00000004000'), 17, 'm2')) +
    R(F(B('25'), 3, 'Unter eins')) +
    R(F(F(F(B('24'), 3, '02'), 17, 'm2'), 41, 'X')) +
    R(F(B('24'), 3, ' 0')) +
    R(F(B('28'), 3, 'Unter zwei kurz')) +
    R(F(F(B('27'), 33, '00000006000'), 3, 'K1')) +
    R(F(B('27'), 3, 'K2')) +
    R(F(F(F(B('21'), 3, '010020'), 12, 'NNN'), 21, 'W')) +
    R(F(F(B('28'), 3, 'Leitbeschreibung'), 58, '010010')) +
    R(F(F(F(B('21'), 3, '010030'), 12, 'NNN'), 21, 'A')) +
    R(F(F(B('28'), 3, 'nach Ausfuehrung'), 67, '1')) +
    R(F(F(F(B('21'), 3, '010040'), 12, 'NNN'), 21, 'W')) +
    R(F(F(B('28'), 3, 'fehlt'), 58, '019999')) +
    R(F(F(F(B('21'), 3, '010050'), 12, 'NNN'), 21, 'X')) +
    R(F(B('25'), 3, 'STLB-Bau')) +
    R(F(F(B('79'), 3, 'STLB-Bau'), 13, 'VJ 1996 VM 10 LB 012 TLG 60')) +
    R(F(B('79'), 13, 'BM 2 BMI 0 AP 16')) +
    R(F(B('T1'), 3, 'mitten im LV')) +
    R(F(B('99'), 70, '00005'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    CheckEquals(2, Integer(G.Award.AddText.Count), 'two blocks of contract terms');
    CheckEquals(1, Diags.CountOf('GAEB-BR-D90-013'), 'one inside the bill');
    List := TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]).BoQBody.Itemlist;
    Check(List.Children[0] is TLandrixGaebXmlPerfDescr, 'execution description first');
    Perf := TLandrixGaebXmlPerfDescr(List.Children[0]);
    CheckEqualsGaebStr('0001', Perf.PerfNo, 'AUSNR');
    CheckEqualsGaebStr('Mauerwerk allgemein', Perf.PerfLbl, 'AUSBEZ');
    CheckEquals(2, Integer(Perf.Description.Count), 'two blocks');
    CheckEqualsGaebStr('01234567890123456', Perf.Description[0].StLNo.Value, 'STLNR of the block');
    CheckEqualsGaebStr('StLB', Perf.Description[0].StLNo.TypeAttr, 'TEXTSYST 1');
    It := TLandrixGaebXmlItem(List.Children[1]);
    CheckEqualsGaebStr('Yes', It.SumDescr, 'lead description');
    CheckEquals(3, Integer(It.SubDescr.Count), 'three sub descriptions');
    CheckEqualsGaebStr('', It.SubDescr[2].SubDNo, 'UB 0 left out');
    Check(Pos('24/UB', DiagnosticText(Diags, 'GAEB-D90-MAP-004')) > 0, 'UB 0 reported');
    Sub := It.SubDescr[0];
    CheckEqualsGaebStr('01', Sub.SubDNo, 'UB');
    CheckEqualsGaebStr('4.000', LandrixXmlUtf8ToWide(Sub.Qty.Text), 'UBMENGE');
    CheckEqualsGaebStr('m2', Sub.QU, 'unit with quantity');
    CheckEqualsGaebStr('', It.SubDescr[1].QU, 'no unit without quantity');
    CheckEquals(1, Integer(It.QtySplit.Count), 'quantity split');
    CheckEqualsGaebStr('6.000', LandrixXmlUtf8ToWide(It.QtySplit[0].Qty.Text), 'TEILMENG');
    It2 := TLandrixGaebXmlItem(List.Children[2]);
    CheckEqualsGaebStr('Rep', It2.RefDescr, 'repetition');
    CheckEqualsGaebStr(It.ID, It2.RefRNo.IDRef, 'reference to the item');
    It2 := TLandrixGaebXmlItem(List.Children[3]);
    CheckEqualsGaebStr(Perf.ID, It2.RefPerfNo.IDRef, 'reference to the execution description');
    It2 := TLandrixGaebXmlItem(List.Children[5]);
    CheckEqualsGaebStr('STLB-Bau', It2.Description.STLBBau.STLBBauCtlg.CtlgName, 'catalogue');
    CheckEqualsGaebStr('1996-10', It2.Description.STLBBau.STLBBauCtlg.VersDate, 'version');
    CheckEqualsGaebStr('60', It2.Description.STLBBau.STLBBauCtlg.Group, 'TLG');
    CheckEquals(1, Integer(It2.Description.STLBBau.STLBBauID.Count), 'one characteristic');
    CheckEqualsGaebStr('16', It2.Description.STLBBau.STLBBauID[0].ChVIdent, 'AP');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-016'), 'unresolved reference');
    CheckEquals(0, Diags.CountOf('GAEB-BR-D90-009'), 'WIEVOR fits');
    Xml := WriteXml(G, T);
    Check(Contains(Xml, '<span>Unter zwei kurz</span>'), 'KURZAN of a sub description as its short text');
    CheckEquals(1, Integer(It.QtySplit.Count), 'a 27 without TEILMENG adds no split');
    CheckEqualsGaebStr('Yes', It.SubDescr[1].QtySpec, 'free quantity: QtySpec');
    CheckEqualsGaebStr('Yes', It.SubDescr[1].QtyTBD, 'free quantity');
    Check(Pos('21/WIEVOR: 1 ', DiagnosticText(Diags, 'GAEB-D90-MAP-004')) > 0, 'WIEVOR X counted once');
    Check(Contains(Xml, '<span>Vertragsbedingungen</span>'), 'contract terms');
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ Part 2b-2: lots on a level of their own, lot groups, wage changes,
  discounts, cash discount. }
procedure TestLotsAndMoney;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  S: AnsiString;
  Lot1, Lot2, C: TLandrixGaebXmlBoQCtgy;
  It, It2: TLandrixGaebXmlItem;
  Info: TLandrixGaebXmlBoQInfo;
begin
  NextNo := 0;
  S := R(F(F(F(B('00'), 11, '83L'), 63, '11PPPP000'), 74, 'X')) +
    R(F(F(B('10'), 3, '01'), 5, 'Rohbau')) +
    R(F(F(B('11'), 3, '01'), 12, 'N')) +
    R(F(F(F(F(B('21'), 3, '010010'), 12, 'NNN'), 24, '00000001000'), 35, 'm3')) +
    R(F(F(F(B('23'), 3, '010010'), 13, '0000010000'), 49, '0980000')) +
    R(F(F(F(B('32'), 3, '01'), 13, '000000100000'), 25, '0980000')) +
    R(F(F(F(F(B('33'), 3, '01'), 5, '000000100000'), 40, '-'), 41, '000000002000')) +
    R(F(F(B('10'), 3, '02'), 5, 'Ausbau')) +
    R(F(F(B('11'), 3, '01'), 12, 'N')) +
    R(F(F(F(F(B('21'), 3, '010010'), 12, 'NNN'), 24, '00000001000'), 35, 'm3')) +
    R(F(F(F(B('21'), 3, '010020'), 12, 'NNN'), 21, 'W')) +
    R(F(F(B('28'), 3, 'wie'), 58, '010010')) +
    R(F(F(F(F(B('32'), 3, '01'), 13, '000000050000'), 25, '1020000'), 46, '000000040000')) +
    R(F(F(B('33'), 3, '02'), 5, '000000050000')) +
    R(F(F(B('34'), 3, '01'), 5, '000000150000')) +
    R(F(F(F(B('35'), 3, '01'), 5, '01'), 7, '02')) +
    R(F(B('46'), 3, 'Ecklohn Facharbeiter')) +
    R(F(F(B('45'), 12, '01'), 19, '0005')) +
    R(F(B('47'), 6, '0005')) +
    R(F(F(F(F(B('99'), 3, '000000150000'), 15, '0980000'), 64, '0300'), 68, '14')) +
    R(F(F(B('21'), 3, '010030'), 12, 'NNN'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    Info := G.Award.BoQ.BoQInfo;
    CheckEquals(3, Integer(Info.BoQBkdn.Count), 'lot, level, item (no index)');
    CheckEqualsGaebStr('Lot', Info.BoQBkdn[0].TypeElement, 'lot level on top');
    CheckEqualsGaebStr('2', Info.BoQBkdn[0].LengthElement, 'lot length');
    Lot1 := TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]);
    Lot2 := TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[1]);
    CheckEqualsGaebStr('01', Lot1.RNoPart, 'lot 01');
    CheckEqualsGaebStr('02', Lot2.RNoPart, 'lot 02');
    CheckEquals(1, Integer(Lot1.LblTx.Children.Count), 'LOSBEZ');
    CheckEqualsGaebStr('1000.00', LandrixXmlUtf8ToWide(Lot1.Totals.Total.Text), 'LOSUMME');
    CheckEqualsGaebStr('20.00', LandrixXmlUtf8ToWide(Lot1.Totals.DiscountAmt.Text), 'AUFABDM with minus: discount');
    CheckEqualsGaebStr('980.00', LandrixXmlUtf8ToWide(Lot1.Totals.TotAfterDisc.Text), 'total after the discount');
    C := TLandrixGaebXmlBoQCtgy(Lot1.BoQBody.Children[0]);
    CheckEqualsGaebStr('2.000000', LandrixXmlUtf8ToWide(C.Totals.DiscountPcnt.Text), 'factor 0.98: 2 percent');
    CheckEqualsGaebStr('980.00', LandrixXmlUtf8ToWide(C.Totals.TotAfterDisc.Text), 'group total after');
    It := TLandrixGaebXmlItem(C.BoQBody.Itemlist.Children[0]);
    CheckEqualsGaebStr('2.000000', LandrixXmlUtf8ToWide(It.DiscountPcnt.Text), 'item factor');
    { the same number in the second lot is another item; 28 refers within the lot }
    C := TLandrixGaebXmlBoQCtgy(Lot2.BoQBody.Children[0]);
    It2 := TLandrixGaebXmlItem(C.BoQBody.Itemlist.Children[1]);
    CheckEqualsGaebStr(TLandrixGaebXmlItem(C.BoQBody.Itemlist.Children[0]).ID, It2.RefRNo.IDRef,
      'reference within the lot');
    Check(not C.Totals.DiscountPcnt.HasValue, 'no discount beside a lump sum');
    CheckEquals(1, Integer(G.Award.BoQ.LotGrp.Count), 'lot group');
    CheckEqualsGaebStr('01', G.Award.BoQ.LotGrp[0].LotGrNo, 'LOSGRNR');
    CheckEquals(2, Integer(G.Award.BoQ.LotGrp[0].RefLotNo.Count), 'two lots');
    CheckEqualsGaebStr(Lot2.ID, G.Award.BoQ.LotGrp[0].RefLotNo[1].IDRef, 'lot reference');
    CheckEqualsGaebStr('Ecklohn Facharbeiter', G.Award.WgChange.LblRefWage, 'LAENTEXT');
    CheckEquals(2, Integer(G.Award.WgChange.RefGroup.Count), 'wage change of a lot and of the bill');
    CheckEqualsGaebStr('2.000000', LandrixXmlUtf8ToWide(Info.Totals.DiscountPcnt.Text), 'bill factor 0.98');
    CheckEqualsGaebStr('1470.00', LandrixXmlUtf8ToWide(Info.Totals.TotAfterDisc.Text), 'bill total after');
    CheckEquals(1, Integer(G.Award.AwardInfo.CashDiscount.Count), 'cash discount');
    CheckEqualsGaebStr('3.00', LandrixXmlUtf8ToWide(G.Award.AwardInfo.CashDiscount[0].DiscountPcnt.Text), 'SKONTO');
    CheckEqualsGaebStr('14', G.Award.AwardInfo.CashDiscount[0].CashDiscDays.Days, 'ZAFRIST');
    CheckEquals(1, Diags.CountOf('GAEB-BR-D90-017'), 'position outside the lots');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-017'), 'discount beside a lump sum');
    CheckEquals(0, Diags.CountOf('GAEB-D90-MAP-016'), 'all references resolved');
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ Lot and lot group numbers used twice, totals twice, remarks around the end
  of a lot, a wage change without references, a factor 0. }
procedure TestLotsReview;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  S: AnsiString;
  I: Integer;
  Body: TLandrixGaebXmlBoQBody;
  Lot1, Lot2, Lot3, C: TLandrixGaebXmlBoQCtgy;
  It: TLandrixGaebXmlItem;
begin
  NextNo := 0;
  S := R(F(F(F(B('00'), 11, '83L'), 63, '11PPPP000'), 74, 'X')) +
    R(F(F(B('10'), 3, '01'), 5, 'Rohbau')) +
    R(F(F(B('11'), 3, '01'), 12, 'N')) +
    R(F(F(F(F(B('21'), 3, '010010'), 12, 'NNN'), 24, '00000001000'), 35, 'm3')) +
    R(F(F(B('21'), 3, '010050'), 12, 'NNN')) +
    R(B('20')) + R(F(B('26'), 6, 'Hinweis im Los')) +
    R(F(F(B('32'), 3, '01'), 13, '000000010000')) +
    R(F(F(B('32'), 3, '01'), 46, '000000020000')) +
    R(F(F(F(B('33'), 3, '01'), 5, '000000010000'), 17, '0000000')) +
    R(B('20')) + R(F(B('26'), 6, 'Hinweis nach dem Los')) +
    R(F(F(B('10'), 3, '02'), 5, 'Ausbau')) +
    R(F(F(B('11'), 3, '01'), 12, 'N')) +
    R(F(F(B('21'), 3, '010010'), 12, 'NNN')) +
    R(B('20')) + R(F(B('26'), 6, 'Hinweis vor 11 ohne Nummer')) +
    R(F(B('11'), 12, 'N')) +
    R(F(F(F(B('21'), 3, '010020'), 12, 'NNN'), 21, 'W')) +
    R(F(F(B('28'), 3, 'wie'), 58, '010050')) +
    R(F(B('32'), 13, '000000099900')) +
    R(F(F(B('33'), 3, '02'), 5, '000000020000')) +
    R(F(F(B('10'), 3, '01'), 5, 'Rohbau 2')) +
    R(F(F(B('11'), 3, '01'), 12, 'N')) +
    R(F(F(B('21'), 3, '010010'), 12, 'NNN')) +
    R(F(F(B('21'), 3, '010050'), 12, 'NNN')) +
    R(F(F(B('32'), 3, '01'), 13, '000000030000')) +
    R(F(F(B('33'), 3, '01'), 5, '000000030000')) +
    R(F(F(B('34'), 3, '01'), 5, '000000060000')) +
    R(F(F(B('34'), 3, '01'), 5, '000000060000')) +
    R(F(F(B('34'), 3, '05'), 5, '000000060000')) +
    R(F(F(F(B('35'), 3, '05'), 5, '01'), 7, '02')) +
    R(F(F(B('35'), 3, '01'), 5, '02')) +
    R(F(B('46'), 3, 'Ecklohn')) +
    R(F(B('99'), 3, '000000060000'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    Body := G.Award.BoQ.BoQBody;
    CheckEquals(4, Integer(Body.Children.Count), 'three lots and the remark after the first');
    Check(Body.Children[1] is TLandrixGaebXmlRemark, 'remark after the end of a lot: on top');
    Lot1 := TLandrixGaebXmlBoQCtgy(Body.Children[0]);
    Lot2 := TLandrixGaebXmlBoQCtgy(Body.Children[2]);
    Lot3 := TLandrixGaebXmlBoQCtgy(Body.Children[3]);
    CheckEqualsGaebStr('01', Lot3.RNoPart, 'the lot number again');
    C := TLandrixGaebXmlBoQCtgy(Lot1.BoQBody.Children[0]);
    CheckEquals(3, Integer(C.BoQBody.Itemlist.Children.Count), 'remark before the end of a lot: in it');
    It := TLandrixGaebXmlItem(C.BoQBody.Itemlist.Children[1]);
    CheckEqualsGaebStr('100.00', LandrixXmlUtf8ToWide(C.Totals.Total.Text), 'first 32 counts');
    Check(not C.Totals.TotalLSUM.HasValue, 'second 32 not mapped');
    CheckEqualsGaebStr('100.00', LandrixXmlUtf8ToWide(Lot1.Totals.Total.Text), 'first lot keeps its totals');
    Check(not Lot1.Totals.DiscountPcnt.HasValue, 'factor 0 is none');
    CheckEqualsGaebStr('200.00', LandrixXmlUtf8ToWide(Lot2.Totals.Total.Text), 'second lot');
    CheckEqualsGaebStr('300.00', LandrixXmlUtf8ToWide(Lot3.Totals.Total.Text), '33 of the open lot');
    C := TLandrixGaebXmlBoQCtgy(Lot3.BoQBody.Children[0]);
    CheckEqualsGaebStr('300.00', LandrixXmlUtf8ToWide(C.Totals.Total.Text), '32 of the open group');
    Check(C.LblTx.IsPresent, 'LblTx of a group in a reopened lot');
    CheckEquals(1, Integer(Lot2.BoQBody.Children.Count), '11 without number: no new group');
    C := TLandrixGaebXmlBoQCtgy(Lot2.BoQBody.Children[0]);
    CheckEquals(3, Integer(C.BoQBody.Itemlist.Children.Count), 'remark before an 11 without number stays');
    CheckEqualsGaebStr(It.ID, TLandrixGaebXmlItem(C.BoQBody.Itemlist.Children[2]).RefRNo.IDRef,
      'reference into another lot');
    CheckEquals(2, Integer(G.Award.BoQ.LotGrp.Count), 'the first 34 without lots left out');
    CheckEquals(1, Integer(G.Award.BoQ.LotGrp[0].RefLotNo.Count), '35 to the last 34 of its number');
    CheckEqualsGaebStr('05', G.Award.BoQ.LotGrp[1].LotGrNo, 'groups after the left out one in order');
    Check(Pos('32 without its group', DiagnosticText(Diags, 'GAEB-D90-MAP-009')) > 0, '32 without a number');
    Check(Pos('34 without a lot', DiagnosticText(Diags, 'GAEB-D90-MAP-009')) > 0, 'group without lots reported');
    Check(not G.PrjInfo.IsPresent, 'PrjInfo without anything left out');
    Check(not G.Award.WgChange.IsPresent, 'wage change without a reference left out');
    Check(Pos('used a second time', DiagnosticText(Diags, 'GAEB-BR-D90-017')) > 0, 'numbers twice');
    Check(Pos('32 a second time', DiagnosticText(Diags, 'GAEB-D90-MAP-002')) > 0, '32 twice');
    Check(Pos('wage change', DiagnosticText(Diags, 'GAEB-D90-MAP-009')) > 0, 'wage change reported');
  finally
    G.Free;
    Diags.Free;
  end;
  { phase 84 takes a lot group without lots; a description of the project
    alone gets NamePrj from VERGAG }
  NextNo := 0;
  S := R(F(F(F(F(B('00'), 11, '84L'), 63, '11PPPP000'), 74, 'X'), 14, 'Vergabe 7')) +
    R(B('02')) + R(F(B('02'), 3, 'Projektzeile')) +
    R(F(F(B('10'), 3, '01'), 5, 'Rohbau')) +
    R(F(F(B('11'), 3, '01'), 12, 'N')) +
    R(F(F(B('21'), 3, '010010'), 12, 'NNN')) +
    R(F(F(B('33'), 3, '01'), 5, '000000010000')) +
    R(F(F(B('34'), 3, '07'), 5, '000000010000')) +
    R(F(B('46'), 3, 'Ecklohn')) +
    R(F(B('45'), 14, '07')) +
    R(F(B('99'), 3, '000000010000'));
  G := MapText(S, nil, T);
  try
    CheckEquals(1, Integer(G.Award.BoQ.LotGrp.Count), 'phase 84: lot group without lots kept');
    Check(G.Award.WgChange.IsPresent, 'wage change of the lot group');
    CheckEqualsGaebStr('Vergabe 7', G.PrjInfo.NamePrj, 'NamePrj from VERGAG');
  finally
    G.Free;
  end;
  { a 47 without 46, and many 46 }
  NextNo := 0;
  S := R(F(F(B('00'), 11, '83L'), 63, '11PPPP000')) +
    R(F(F(F(B('21'), 3, '010010'), 12, 'NNN'), 21, ' ')) +
    R(F(B('47'), 6, '0005')) + R(B('99'));
  G := MapText(S, nil, T);
  try
    Check(not G.Award.WgChange.IsPresent, 'wage change without LblRefWage left out');
  finally
    G.Free;
  end;
  NextNo := 0;
  S := R(F(F(B('00'), 11, '83L'), 63, '11PPPP000')) +
    R(F(F(B('21'), 3, '010010'), 12, 'NNN'));
  for I := 1 to 5000 do
    S := S + R(F(B('46'), 3, 'Ecklohn Facharbeiter'));
  S := S + R(F(B('47'), 6, '0005')) + R(B('99'));
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(S, Diags, T);
  try
    Check(G.Award.WgChange.IsPresent, 'wage change with label and reference');
    Check(Length(G.Award.WgChange.LblRefWage) <= 120, 'LblRefWage cut');
    CheckEquals(1, Diags.CountOf('GAEB-D90-MAP-017'), 'cut reported');
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
      { the messages of these name elements and XSD codes only }
      if (GetEnvironmentVariable('LANDRIX_CHECKPATHS') = '2') and
        ((CheckDiags[I].RuleId = 'GAEB-CHK-001') or (CheckDiags[I].RuleId = 'GAEB-CHK-002') or
        (CheckDiags[I].RuleId = 'GAEB-CHK-006')) then
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
  RegisterTest('DA90Mapping.DescriptionsAndRefs', TestDescriptionsAndRefs);
  RegisterTest('DA90Mapping.LotsAndMoney', TestLotsAndMoney);
  RegisterTest('DA90Mapping.LotsReview', TestLotsReview);
  RegisterTest('DA90Mapping.ManyRemarks', TestManyRemarks);
  RegisterTest('DA90Mapping.Rejected', TestRejected);
  RegisterTest('Local.DA90Map', TestLocalMap);
end;

end.

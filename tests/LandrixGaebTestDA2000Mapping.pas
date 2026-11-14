{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of LandrixGaebDA2000Mapping: synthetic GAEB DA 2000 files mapped
  into GAEB DA XML 3.3 and checked against its content model, and the
  local corpus (skipped when missing; counts and keys only, never
  values). }

unit LandrixGaebTestDA2000Mapping;

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
  LandrixGaebDA2000Parser,
  LandrixGaebDA2000Mapping,
  LandrixGaebTestFramework;

const
  CRLF = #13#10;

{ S with ` in place of the backslash (RTF in the test sources). }
function BS(const S: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I] = '`' then
      Result[I] := AnsiChar(92);
end;

function Lines(const A: array of AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Integer(High(A)) do
    Result := Result + A[I] + CRLF;
end;

function Head(const DP: AnsiString): AnsiString;
begin
  Result := Lines(['#begin[GAEB]', '#begin[GAEBInfo]', '[Version]1.2[end]',
    '[Datum]13.11.2026[end]', '[Uhrzeit]10:30[end]', '[ProgSystem]Test[end]',
    '[Zeichensatz]ANSI[end]', '#end[GAEBInfo]', '#begin[PrjInfo]', '[Name]P1[end]',
    '[Bez]Projekt[end]', '[Wae]EUR[end]', '#end[PrjInfo]', '#begin[Vergabe]',
    '[DP]' + DP + '[end]', '#begin[VergabeInfo]', '[Wae]EUR[end]', '[ErDatum]01.12.2026[end]',
    '#end[VergabeInfo]', '#begin[AG]', '#begin[Adresse]', '[Name1]Bauherr[end]',
    '[Strasse]Weg 1[end]', '[PLZ]12345[end]', '[Ort]Stadt[end]', '#end[Adresse]', '#end[AG]']);
end;

function Tail: AnsiString;
begin
  Result := Lines(['#end[Vergabe]', '#end[GAEB]']);
end;

function Glied: AnsiString;
begin
  Result := Lines(['#begin[LVGlied]', '[Typ]LVStufe[end]', '[Laenge]2[end]', '#end[LVGlied]',
    '#begin[LVGlied]', '[Typ]Position[end]', '[Laenge]4[end]', '#end[LVGlied]',
    '#begin[LVGlied]', '[Typ]Index[end]', '[Laenge]1[end]', '#end[LVGlied]']);
end;

function Sample(const AGlied: AnsiString): AnsiString;
begin
  Result := Head('83') + Lines(['#begin[LV]', '#begin[LVInfo]', '[Name]LV1[end]', '[Bez]Rohbau[end]', '[KurzLang]1[end]', '[AnzEPAnteile]2[end]',
    '[BezEPAnteil1]Lohn[end]', '[BezEPAnteil2]Stoffe[end]']) +
    AGlied + Lines(['#end[LVInfo]',
    '#begin[LVBereich]', '[OZ]01[end]', '[Bez]Erdarbeiten[end]',
    '#begin[Hinweis]', '#begin[Beschreibung]', '[Kurztext]Vorbemerkung[end]',
    '[Langtext]Vorbemerkung lang[end]', '#end[Beschreibung]',
    '#end[Hinweis]',
    '#begin[Position]', '[OZ]010010[end]', '[Menge]12,5[end]', '[ME]m3[end]',
    '#begin[Beschreibung]', '[Kurztext]Boden ausheben[end]', '[LangtextTB]J[end]',
    BS('[Langtext]{`rtf1 Boden ausheben`par Fabrikat {`*`bkmkstart TB01}Fabrikat: ' +
    '{`*`bkmkstart Feld01}....{`*`bkmkend Feld01}{`*`bkmkend TB01}`par}[end]'),
    '#end[Beschreibung]', '#begin[KatZuord]', '[KatSchl]X[end]', '#end[KatZuord]', '#end[Position]',
    '#begin[Position]', '[OZ]010020[end]', '[ME]psch[end]', '[Bedarf]E[end]', '#end[Position]',
    '#end[LVBereich]', '#end[LV]']) + Tail;
end;

function MapText(const S: AnsiString; Diags: TLandrixGaebDiagnostics;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  D: TLandrixGaebDA2000Document;
begin
  D := LandrixGaebDA2000Parse(Pointer(S), Length(S), gcsUnknown, Diags);
  try
    Result := LandrixGaebDA2000Map(D, Diags, nil, ATarget);
  finally
    D.Free;
  end;
end;

{ The document as XML, also when the writer reports errors. }
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

procedure TestMapSample;
var
  Diags, CheckDiags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  Ctgy: TLandrixGaebXmlBoQCtgy;
  Xml: TLandrixXmlUtf8;
  Errors, Warnings: Integer;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  CheckDiags := TLandrixGaebDiagnostics.Create;
  G := MapText(Sample(Glied), Diags, T);
  try
    Check((T.Version = gv33) and (T.Edition = ge2021_05) and (T.Phase = gp83), 'target 3.3/2021-05 X83');
    CheckEqualsGaebStr('P1', G.PrjInfo.NamePrj, 'project name');
    CheckEqualsGaebStr('83', G.Award.DP, 'DP');
    CheckEqualsGaebStr('Bauherr', G.Award.OWN.Address.Name1, 'owner');
    CheckEqualsGaebStr('2026-12-01', G.Award.AwardInfo.OpenDate, 'date');
    CheckEqualsGaebStr('2026-11-13', G.GAEBInfo.Date, 'GAEBInfo date');
    CheckEqualsGaebStr('10:30:00', G.GAEBInfo.Time, 'GAEBInfo time');
    CheckEquals(3, Integer(G.Award.BoQ.BoQInfo.BoQBkdn.Count), 'breakdown');
    CheckEqualsGaebStr('No', G.Award.BoQ.BoQInfo.BoQBkdn[2].Num, 'unused index: No');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-007'), 'unused level reported');
    CheckEqualsGaebStr('BoQLevel', G.Award.BoQ.BoQInfo.BoQBkdn[0].TypeElement, 'level type');
    CheckEqualsGaebStr('4', G.Award.BoQ.BoQInfo.BoQBkdn[1].LengthElement, 'item length');
    CheckEqualsGaebStr('Yes', G.Award.BoQ.BoQInfo.BoQBkdn[0].Num, 'numeric levels');
    CheckEqualsGaebStr('Unknown', G.Award.BoQ.BoQInfo.LblUPComp1.TypeAttr, 'component type unknown');
    CheckEquals(1, Integer(G.Award.BoQ.BoQBody.Children.Count), 'one category');
    Ctgy := TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]);
    CheckEqualsGaebStr('01', Ctgy.RNoPart, 'category number');
    CheckEquals(3, Integer(Ctgy.BoQBody.Itemlist.Children.Count), 'remark and two items');
    Check(Ctgy.BoQBody.Itemlist.Children[0] is TLandrixGaebXmlRemark, 'remark first');
    with TLandrixGaebXmlItem(Ctgy.BoQBody.Itemlist.Children[1]) do
    begin
      CheckEqualsGaebStr('0010', RNoPart, 'item number');
      CheckEqualsUtf8('12.5', Qty.Text, 'quantity');
      CheckEqualsGaebStr('m3', QU, 'unit');
      CheckEqualsGaebStr('Yes', Description.CompleteText.ComplTSB, 'bidder complements flagged');
    end;
    with TLandrixGaebXmlItem(Ctgy.BoQBody.Itemlist.Children[2]) do
    begin
      CheckEqualsGaebStr('Yes', LumpSumItem, 'psch is a lump sum item');
      CheckEqualsGaebStr('WithoutTotal', Provis, 'Bedarf E');
    end;
    Xml := LandrixGaebXmlWriteCollect(G, T, LandrixGaebXmlDefaultWriteOptions, CheckDiags, Errors, Warnings);
    CheckEquals(0, Errors, 'written without errors: ' + CheckDiags.ToText);
    CheckDiags.Clear;
    Check(Contains(Xml, '<TextComplement') and Contains(Xml, 'Kind="Bidder"') and
      Contains(Xml, 'MarkLbl="01"') and Contains(Xml, 'Empty="Yes"'), 'text complement written');
    Check(Contains(Xml, '<ComplCaption><p><span>Fabrikat: </span></p></ComplCaption>'), 'caption');
    Check(Contains(Xml, '<span>Boden ausheben</span>'), 'long text paragraph');
    Check(LandrixGaebXmlCheckModel(G, T, CheckDiags), 'content model: ' + CheckDiags.ToText);
    CheckEquals(0, Diags.CountOf('GAEB-D2000-MAP-001'), 'everything mapped: ' + Diags.ToText);
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-009'), 'KatZuord without catalogue: ' + Diags.ToText);
    Check(not Diags.HasErrors, 'no errors: ' + Diags.ToText);
  finally
    G.Free;
    CheckDiags.Free;
    Diags.Free;
  end;
end;

procedure TestDerivedBreakdown;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  Ctgy: TLandrixGaebXmlBoQCtgy;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(Sample(''), Diags, T);
  try
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-005'), 'derived breakdown reported');
    CheckEquals(2, Integer(G.Award.BoQ.BoQInfo.BoQBkdn.Count), 'two levels derived');
    CheckEqualsGaebStr('2', G.Award.BoQ.BoQInfo.BoQBkdn[0].LengthElement, 'category length');
    CheckEqualsGaebStr('Item', G.Award.BoQ.BoQInfo.BoQBkdn[1].TypeElement, 'item level');
    Ctgy := TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]);
    CheckEqualsGaebStr('0020', TLandrixGaebXmlItem(Ctgy.BoQBody.Itemlist.Children[2]).RNoPart, 'item number');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestValueFindings;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  It: TLandrixGaebXmlItem;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(Head('84') + Lines(['#begin[LV]', '#begin[LVInfo]', '[Datum]13112026[end]']) + Glied +
    Lines(['#end[LVInfo]', '#begin[Position]', '[OZ]  0010[end]', '[Menge]1.234,5[end]',
    '[Bedarf]X[end]', '[EP]-,5[end]', '[GB]1234,50[end]', '[_Vendor]x[end]', '[KatBez]y[end]',
    '#begin[Beschreibung]', '[Kurztext]a' + #31 + 'b[end]', '#end[Beschreibung]', '#end[Position]',
    '#end[LV]']) + Tail, Diags, T);
  try
    Check(T.Phase = gp84, 'X84');
    CheckEqualsGaebStr('2026-11-13', G.Award.BoQ.BoQInfo.Date, 'date without points read');
    CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-009'), 'date without points reported');
    It := TLandrixGaebXmlItem(G.Award.BoQ.BoQBody.Itemlist.Children[0]);
    CheckEqualsGaebStr('0010', It.RNoPart, 'number without its level part');
    Check(not It.Qty.HasValue, 'grouped number not mapped');
    CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-008'), 'grouped number reported');
    CheckEqualsUtf8('-0.5', It.UP.Text, 'minus and comma');
    CheckEqualsUtf8('1234.50', It.IT.Text, 'total price with a comma');
    CheckEqualsGaebStr('', It.Provis, 'unknown Bedarf not mapped');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-004'), 'unknown value reported');
    CheckEquals(2, Diags.CountOf('GAEB-D2000-MAP-001'), 'vendor and unknown keys');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-006'), 'control character reported');
    CheckEqualsGaebStr('ab', TLandrixGaebXmlSpan(TLandrixGaebXmlPMLText(TLandrixGaebXmlMLText(
      It.Description.OutlineText.OutlTxt.Children[0]).Children[0]).Children[0]).Value,
      'control character removed');
    Check(Pos('Position/_* not mapped', Diags.ToText) > 0, 'vendor keys grouped');
    Check(Pos('x', Copy(Diags.ToText, Pos('_*', Diags.ToText), 40)) = 0, 'no values in messages');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestLevels;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := MapText(Head('83') + Lines(['#begin[LV]', '#begin[LVInfo]']) + Glied +
    Lines(['#end[LVInfo]', '#begin[LVBereich]', '[OZ]01[end]', '#end[LVBereich]',
    '#begin[Position]', '[OZ]010010[end]', '#end[Position]', '#end[LV]']) + Tail, Diags, T);
  try
    CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-016'), 'categories and items on one level');
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ A file with the parties AG/AN and one item in the LV; Body is the
  content of the item. }
function WithItem(const DP, AParties, AOZ, ABody: AnsiString): AnsiString;
begin
  Result := Head(DP) + AParties + Lines(['#begin[LV]', '#begin[LVInfo]']) + Glied +
    Lines(['#end[LVInfo]', '#begin[Position]', '[OZ]' + AOZ + '[end]']) + ABody +
    Lines(['#end[Position]', '#end[LV]']) + Tail;
end;

function FirstItem(G: TLandrixGaebXmlGAEB): TLandrixGaebXmlItem;
begin
  Result := TLandrixGaebXmlItem(G.Award.BoQ.BoQBody.Itemlist.Children[0]);
end;

procedure TestReviewCases;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  Xml: TLandrixXmlUtf8;
  Raised: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    { a number holding only its own part is taken whole, never cut }
    G := MapText(WithItem('83', '', '1234', ''), Diags, T);
    try
      CheckEqualsGaebStr('1234', FirstItem(G).RNoPart, 'own part not cut');
    finally
      G.Free;
    end;
    { own part with index }
    G := MapText(WithItem('83', '', '1234A', ''), Diags, T);
    try
      CheckEqualsGaebStr('1234', FirstItem(G).RNoPart, 'own part with index: item');
      CheckEqualsGaebStr('A', FirstItem(G).RNoIndex, 'own part with index: index');
    finally
      G.Free;
    end;
    { a number ending inside the item part is not taken in part }
    Diags.Clear;
    G := MapText(Head('83') + Lines(['#begin[LV]', '#begin[LVInfo]', '#begin[LVGlied]', '[Typ]LVStufe[end]',
      '[Laenge]2[end]', '#end[LVGlied]', '#begin[LVGlied]', '[Typ]Position[end]', '[Laenge]4[end]',
      '#end[LVGlied]', '#end[LVInfo]', '#begin[Position]', '[OZ]01001[end]', '#end[Position]', '#end[LV]']) + Tail,
      Diags, T);
    try
      CheckEqualsGaebStr('', FirstItem(G).RNoPart, 'truncated number not taken');
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-015'), 'truncated number reported');
    finally
      G.Free;
    end;
    { a picture-only text reports its loss }
    Diags.Clear;
    G := MapText(WithItem('83', '', '010010', Lines(['#begin[Beschreibung]',
      BS('[Langtext]{`rtf1{`pict`pngblip 00}}[end]'), '#end[Beschreibung]'])), Diags, T);
    try
      CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-002'), 'picture loss reported');
    finally
      G.Free;
    end;
    { half a surrogate pair is removed and counted }
    Diags.Clear;
    G := MapText(WithItem('83', '', '010010', Lines(['#begin[Beschreibung]',
      BS('[Langtext]{`rtf1 A`u-10240?B}[end]'), '#end[Beschreibung]'])), Diags, T);
    try
      CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-006'), 'lone surrogate reported');
      Check(Contains(WriteXml(G, T), '<span>AB</span>'), 'lone surrogate removed');
    finally
      G.Free;
    end;
    { the derived breakdown takes the cleaned numbers }
    G := MapText(Head('83') + Lines(['#begin[LV]', '#begin[LVInfo]', '#end[LVInfo]', '#begin[LVBereich]',
      '[OZ]0' + #31 + '1[end]', '#begin[Position]', '[OZ]010010[end]', '#end[Position]', '#end[LVBereich]',
      '#end[LV]']) + Tail, nil, T);
    try
      CheckEqualsGaebStr('0010', TLandrixGaebXmlItem(TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]).
        BoQBody.Itemlist.Children[0]).RNoPart, 'derived from cleaned numbers');
    finally
      G.Free;
    end;
    { codes of the parties are translated }
    G := MapText(WithItem('84', Lines(['#begin[AN]', '[ArtStaat]anderer[end]', '[NameStaat]CH[end]',
      '[ArtBranche]Handwerk[end]', '[ArtBevBew]5[end]', '[ArtNU]3[end]', '#end[AN]']), '010010', ''), Diags, T);
    try
      CheckEqualsGaebStr('Other', G.Award.CTR.CntryType, 'ArtStaat');
      CheckEqualsGaebStr('CH', G.Award.CTR.CntryName, 'NameStaat');
      CheckEqualsGaebStr('Crafts', G.Award.CTR.SectorType, 'ArtBranche');
      CheckEqualsGaebStr('WrkShopForBli', G.Award.CTR.PrefBidType, 'ArtBevBew');
      CheckEqualsGaebStr('LackOfInHouseCap', G.Award.CTR.SCType, 'ArtNU');
    finally
      G.Free;
    end;
    { a long text holding only an empty complement keeps it }
    G := MapText(WithItem('83', '', '010010', Lines(['#begin[Beschreibung]', BS('[Langtext]{`rtf1' +
      '{`*`bkmkstart TB01}{`*`bkmkstart Feld01}...{`*`bkmkend Feld01}{`*`bkmkend TB01}}[end]'),
      '#end[Beschreibung]'])), Diags, T);
    try
      Xml := WriteXml(G, T);
      Check(Contains(Xml, '<TextComplement') and Contains(Xml, 'Empty="Yes"'), 'empty complement kept');
    finally
      G.Free;
    end;
    { characters RTF produces through escapes are cleaned as well }
    Diags.Clear;
    G := MapText(WithItem('83', '', '010010', Lines(['#begin[Beschreibung]',
      BS('[Langtext]{`rtf1 A`u31?B}[end]'), '#end[Beschreibung]'])), Diags, T);
    try
      CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-006'), 'control character from RTF reported');
      Check(Contains(WriteXml(G, T), '<span>AB</span>'), 'control character from RTF removed');
    finally
      G.Free;
    end;
    { empty paragraphs of a short text stay }
    G := MapText(WithItem('83', '', '010010', Lines(['#begin[Beschreibung]',
      BS('[Kurztext]{`rtf1 A`par`par B}[end]'), '#end[Beschreibung]'])), Diags, T);
    try
      Check(Contains(WriteXml(G, T), '<p><span>A</span></p><p/><p><span>B</span></p>'), 'empty paragraph kept');
    finally
      G.Free;
    end;
    { the phase message names no other value }
    Raised := False;
    try
      MapText(Head('VERTRAULICH') + Tail, nil, T).Free;
    except
      on E: ELandrixGaebError do
      begin
        Raised := True;
        Check(Pos('VERTRAULICH', E.Message) = 0, 'no value in the message: ' + E.Message);
      end;
    end;
    Check(Raised, 'DP without a phase rejected');
    { a category deeper than the breakdown is reported once }
    Diags.Clear;
    G := MapText(Head('83') + Lines(['#begin[LV]', '#begin[LVInfo]']) + Glied +
      Lines(['#end[LVInfo]', '#begin[LVBereich]', '[OZ]01[end]', '#begin[LVBereich]', '[OZ]0102[end]',
      '#end[LVBereich]', '#end[LVBereich]', '#end[LV]']) + Tail, Diags, T);
    try
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-015'), 'misfit reported once');
      Check(Pos(' 1 ordinal', Diags.ToText) > 0, 'counted once: ' + Diags.ToText);
    finally
      G.Free;
    end;
  finally
    Diags.Free;
  end;
end;

{ AusfBeschr -> PerfDescr; the GAEB Toolbox forms LVGlied/Format,
  LVGlied/_GAEBXML_Alignment and complements marked in plain text. }
procedure TestToolboxForms;
var
  Diags, CheckDiags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  Ctgy: TLandrixGaebXmlBoQCtgy;
  Perf: TLandrixGaebXmlPerfDescr;
  Xml: TLandrixXmlUtf8;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  CheckDiags := TLandrixGaebDiagnostics.Create;
  G := MapText(Head('83') + Lines(['#begin[LV]', '#begin[LVInfo]', '[Name]LV1[end]', '[Bez]Rohbau[end]', '[KurzLang]1[end]',
    '#begin[LVGlied]', '[Typ]LVStufe[end]', '[Bez]Titel[end]', '[Laenge]2[end]', '[Format]N[end]',
    '[_GAEBXML_Alignment]right[end]', '#end[LVGlied]',
    '#begin[LVGlied]', '[Typ]Position[end]', '[Laenge]4[end]', '[Format]A[end]',
    '[_GAEBXML_Alignment]Left[end]', '#end[LVGlied]',
    '#begin[LVGlied]', '[Typ]Index[end]', '[Laenge]1[end]', '[Format]X[end]',
    '[_GAEBXML_Alignment]middle[end]', '#end[LVGlied]',
    '#end[LVInfo]',
    '#begin[AusfBeschr]', '[AusfNr]7[end]', '[AusfBez]Allgemein[end]', '#begin[Beschreibung]',
    '[Kurztext]Vorgabe[end]', '#end[Beschreibung]', '#end[AusfBeschr]',
    '#begin[LVBereich]', '[OZ]A1[end]', '[Bez]Bereich[end]',
    '#begin[AusfBeschr]', '[AusfNr]0012[end]', '[AusfBez]Beton[end]',
    '#begin[Beschreibung]', '[Kurztext]Erste[end]', '[Langtext]Lang eins[end]', '#end[Beschreibung]',
    '#begin[Beschreibung]', '[Kurztext]Zweite[end]', '#end[Beschreibung]', '#end[AusfBeschr]',
    '#begin[Position]', '[OZ]A10010[end]', '[Menge]1[end]', '[ME]m[end]',
    '#begin[Beschreibung]', '[Kurztext]Liefern[end]',
    '[Langtext]Liefern &#91;TB01Fabrikat: &#91;&#93; einsetzen&#93;[end]', '#end[Beschreibung]',
    '#end[Position]', '#end[LVBereich]', '#end[LV]']) + Tail, Diags, T);
  try
    with G.Award.BoQ.BoQInfo do
    begin
      CheckEqualsGaebStr('No', BoQBkdn[0].Num, 'Format N contradicted by the number A1');
      CheckEqualsGaebStr('right', BoQBkdn[0].Alignment, 'alignment right');
      CheckEqualsGaebStr('No', BoQBkdn[1].Num, 'Format A');
      CheckEqualsGaebStr('left', BoQBkdn[1].Alignment, 'alignment in any case');
      CheckEqualsGaebStr('No', BoQBkdn[2].Num, 'unknown Format: derived (unused index)');
      CheckEqualsGaebStr('', BoQBkdn[2].Alignment, 'unknown alignment left out');
    end;
    CheckEquals(2, Diags.CountOf('GAEB-D2000-MAP-004'), 'unknown Format and alignment: ' + Diags.ToText);
    CheckEquals(3, Diags.CountOf('GAEB-D2000-MAP-008'), 'Format, alignment, plain marks: ' + Diags.ToText);
    CheckEquals(0, Diags.CountOf('GAEB-D2000-MAP-001'), 'everything mapped: ' + Diags.ToText);
    CheckEquals(0, Diags.CountOf('GAEB-D2000-MAP-009'), 'descriptions complete');
    Check(G.Award.BoQ.BoQBody.Children[0] is TLandrixGaebXmlPerfDescr, 'PerfDescr beside the categories');
    Perf := TLandrixGaebXmlPerfDescr(G.Award.BoQ.BoQBody.Children[0]);
    CheckEqualsGaebStr('7', Perf.PerfNo, 'PerfNo');
    CheckEqualsGaebStr('Allgemein', Perf.PerfLbl, 'PerfLbl');
    CheckEquals(1, Integer(Perf.Description.Count), 'one description');
    Check(Perf.Description[0].HasOutlineText, 'short text alone');
    Ctgy := TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[1]);
    Check(Ctgy.BoQBody.Itemlist.Children[0] is TLandrixGaebXmlPerfDescr, 'PerfDescr in the item list');
    Perf := TLandrixGaebXmlPerfDescr(Ctgy.BoQBody.Itemlist.Children[0]);
    CheckEqualsGaebStr('12', Perf.PerfNo, 'leading zeros dropped');
    CheckEquals(2, Integer(Perf.Description.Count), 'every Beschreibung a description');
    Check(Perf.Description[0].CompleteText.HasDetailTxt, 'long text');
    Check(Perf.ID <> '', 'ID generated');
    Xml := WriteXml(G, T);
    Check(Contains(Xml, '<TextComplement') and Contains(Xml, 'Kind="Bidder"') and Contains(Xml, 'MarkLbl="01"'),
      'plain mark read');
    Check(Contains(Xml, '<ComplCaption><p><span>Fabrikat: </span></p></ComplCaption>'), 'caption');
    Check(Contains(Xml, '<ComplTail><p><span> einsetzen</span></p></ComplTail>'), 'tail');
    Check(LandrixGaebXmlCheckModel(G, T, CheckDiags), 'content model: ' + CheckDiags.ToText);
  finally
    G.Free;
  end;
  { an AusfNr that is no whole number from 0 to 9999 }
  Diags.Clear;
  G := MapText(Head('83') + Lines(['#begin[LV]', '#begin[LVInfo]']) + Glied +
    Lines(['#end[LVInfo]', '#begin[AusfBeschr]', '[AusfNr]12,5[end]', '#end[AusfBeschr]',
    '#begin[AusfBeschr]', '[AusfNr]10000[end]', '#end[AusfBeschr]', '#begin[Position]',
    '[OZ]010010[end]', '#end[Position]', '#end[LV]']) + Tail, Diags, T);
  try
    CheckEqualsGaebStr('', TLandrixGaebXmlPerfDescr(G.Award.BoQ.BoQBody.Itemlist.Children[0]).PerfNo,
      'fraction left out');
    CheckEqualsGaebStr('', TLandrixGaebXmlPerfDescr(G.Award.BoQ.BoQBody.Itemlist.Children[1]).PerfNo,
      'too large left out');
    CheckEquals(2, Diags.CountOf('GAEB-D2000-MAP-004'), 'both reported');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-009'), 'incomplete descriptions reported once');
    Check(Pos('2 execution description(s)', Diags.ToText) > 0, 'with their count');
    Check((Pos('12,5', Diags.ToText) = 0) and (Pos('10000', Diags.ToText) = 0), 'no values in messages');
  finally
    G.Free;
    CheckDiags.Free;
    Diags.Free;
  end;
end;

{ N times C. }
function Repeated(C: AnsiChar; N: Integer): AnsiString;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, N);
  for I := 1 to N do
    Result[I] := C;
end;

{ BezugBeschr, BezugOZ, BezugAusfNr and KatZuord. }
procedure TestReferences;
var
  Diags, CheckDiags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  Ctgy: TLandrixGaebXmlBoQCtgy;
  Perf: TLandrixGaebXmlPerfDescr;
  I1, I2, I3: TLandrixGaebXmlItem;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  CheckDiags := TLandrixGaebDiagnostics.Create;
  G := MapText(Head('83') + Lines(['#begin[LV]', '#begin[LVInfo]', '[Name]LV1[end]', '[Bez]Rohbau[end]',
    '[KurzLang]1[end]', '#begin[KatZuord]', '[KatNam]DIN276[end]', '[KatBez]Kostengruppen[end]',
    '[KatSchl]300[end]', '#end[KatZuord]']) + Glied + Lines(['#end[LVInfo]',
    '#begin[LVBereich]', '[OZ]01[end]', '[Bez]Bereich[end]',
    '#begin[AusfBeschr]', '[AusfNr]5[end]', '[AusfBez]Beton[end]', '#begin[Beschreibung]',
    '[Kurztext]Vorgabe[end]', '#end[Beschreibung]', '#end[AusfBeschr]',
    '#begin[Position]', '[OZ]010010[end]', '[Menge]1[end]', '[ME]m[end]', '[BezugBeschr]B[end]',
    '[BezugAusfNr]0005[end]', '#begin[Beschreibung]', '[Kurztext]Eins[end]', '#end[Beschreibung]',
    '#begin[KatZuord]', '[KatNam]DIN276[end]', '[KatSchl]310[end]', '#end[KatZuord]',
    '#begin[KatZuord]', '[ExtDat]STLB.KAT|Standardleistungsbuch[end]', '[KatSchl]A1[end]',
    '#end[KatZuord]', '#begin[KatZuord]', '[KatSchl]ohne[end]', '#end[KatZuord]', '#end[Position]',
    '#begin[Position]', '[OZ]010020[end]', '[Menge]2[end]', '[ME]m[end]', '[BezugBeschr]W[end]',
    '[BezugOZ] 010010 [end]', '#begin[Beschreibung]', '[Kurztext]Zwei[end]', '#end[Beschreibung]',
    '#end[Position]',
    '#begin[Position]', '[OZ]010030[end]', '[Menge]3[end]', '[ME]m[end]', '[BezugOZ]019999[end]',
    '[BezugAusfNr]77[end]', '#begin[Beschreibung]', '[Kurztext]Drei[end]', '#end[Beschreibung]',
    '#end[Position]', '#end[LVBereich]', '#end[LV]']) + Tail, Diags, T);
  try
    with G.Award.BoQ.BoQInfo do
    begin
      CheckEquals(2, Integer(Ctlg.Count), 'two catalogues');
      CheckEqualsGaebStr('DIN276', Ctlg[0].CtlgID, 'catalogue ID: KatNam');
      CheckEqualsGaebStr('DIN276', Ctlg[0].CtlgType, 'catalogue type: KatNam');
      CheckEqualsGaebStr('Kostengruppen', Ctlg[0].CtlgName, 'catalogue name: KatBez');
      CheckEqualsGaebStr('STLB.KAT', Ctlg[1].CtlgID, 'catalogue of ExtDat');
      CheckEqualsGaebStr('Standardleistungsbuch', Ctlg[1].CtlgName, 'ExtDatBeschr');
      CheckEquals(1, Integer(CtlgAssign.Count), 'LVInfo assignment');
      CheckEqualsGaebStr('300', CtlgAssign[0].CtlgCode, 'its key');
    end;
    Ctgy := TLandrixGaebXmlBoQCtgy(G.Award.BoQ.BoQBody.Children[0]);
    Perf := TLandrixGaebXmlPerfDescr(Ctgy.BoQBody.Itemlist.Children[0]);
    I1 := TLandrixGaebXmlItem(Ctgy.BoQBody.Itemlist.Children[1]);
    I2 := TLandrixGaebXmlItem(Ctgy.BoQBody.Itemlist.Children[2]);
    I3 := TLandrixGaebXmlItem(Ctgy.BoQBody.Itemlist.Children[3]);
    CheckEqualsGaebStr('Ref', I1.RefDescr, 'BezugBeschr B');
    Check(I1.HasRefPerfNo, 'BezugAusfNr mapped');
    CheckEqualsGaebStr(Perf.ID, I1.RefPerfNo.IDRef, 'to the execution description');
    CheckEquals(2, Integer(I1.CtlgAssign.Count), 'two assignments, the incomplete one left out');
    CheckEqualsGaebStr('DIN276', I1.CtlgAssign[0].CtlgID, 'first catalogue');
    CheckEqualsGaebStr('310', I1.CtlgAssign[0].CtlgCode, 'first key');
    CheckEqualsGaebStr('STLB.KAT', I1.CtlgAssign[1].CtlgID, 'second catalogue');
    CheckEqualsGaebStr('Rep', I2.RefDescr, 'BezugBeschr W');
    Check(I2.HasRefRNo, 'BezugOZ mapped');
    CheckEqualsGaebStr(I1.ID, I2.RefRNo.IDRef, 'to the item, spaces ignored');
    Check(not I3.HasRefRNo and not I3.HasRefPerfNo, 'unknown numbers left out');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-010'), 'reported once');
    Check(Pos('2 reference(s)', Diags.ToText) > 0, 'with their count');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-009'), 'assignment without catalogue');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-008'), 'KatNam form reported');
    Check(Pos('(2 time(s))', Diags.ToText) > 0, 'with its count');
    CheckEquals(0, Diags.CountOf('GAEB-D2000-MAP-001'), 'everything mapped: ' + Diags.ToText);
    Check((Pos('019999', Diags.ToText) = 0) and (Pos('DIN276', Diags.ToText) = 0), 'no values in messages');
    Check(LandrixGaebXmlCheckModel(G, T, CheckDiags), 'content model: ' + CheckDiags.ToText);
  finally
    G.Free;
  end;
  { a description is no name; too long values; the V1.0 structure with a
    control character }
  Diags.Clear;
  G := MapText(WithItem('83', '', '010010', Lines(['#begin[KatZuord]', '[KatBez]Nur Bezeichnung[end]',
    '[KatSchl]1[end]', '#end[KatZuord]', '#begin[KatZuord]', '[ExtDat]K|' + Repeated('A', 81) + '[end]',
    '[KatSchl]2[end]', '#end[KatZuord]', '[KatZuord]V10|Alt|A&#1;B[end]'])), Diags, T);
  try
    CheckEquals(2, Integer(FirstItem(G).CtlgAssign.Count), 'the one without name left out');
    CheckEqualsGaebStr('V10', FirstItem(G).CtlgAssign[1].CtlgID, 'V1.0 structure: name');
    CheckEqualsGaebStr('AB', FirstItem(G).CtlgAssign[1].CtlgCode, 'V1.0 structure: key');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-009'), 'without name: ' + Diags.ToText);
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-004'), 'too long description');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-006'), 'control character counted');
  finally
    G.Free;
  end;
  { too long: the name standing for the description, a description given
    by a later assignment }
  Diags.Clear;
  G := MapText(WithItem('83', '', '010010', Lines(['[KatZuord]' + Repeated('B', 81) + '||1[end]',
    '[KatZuord]K||1[end]', '[KatZuord]K|' + Repeated('A', 81) + '|2[end]'])), Diags, T);
  try
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-004'), 'reported once: ' + Diags.ToText);
    Check(Pos('2 catalogue(s)', Diags.ToText) > 0, 'both catalogues counted: ' + Diags.ToText);
  finally
    G.Free;
  end;
  { an address catalogue in a file without LV }
  Diags.Clear;
  G := MapText(Head('83') + Lines(['#begin[AN]', '#begin[Adresse]', '[Name1]Firma[end]',
    '#begin[KatZuord]', '[ExtDat]CAT|Kat[end]', '[KatSchl]300[end]', '#end[KatZuord]',
    '#end[Adresse]', '#end[AN]']) + Tail, Diags, T);
  try
    CheckEquals(1, Integer(G.Award.CTR.Address.CtlgAssign.Count), 'address assignment');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-009'), 'catalogue without LV reported: ' + Diags.ToText);
  finally
    G.Free;
    CheckDiags.Free;
    Diags.Free;
  end;
end;

{ A bill with the given body (execution descriptions and items) directly
  in the LV. }
function WithBody(const ABody: AnsiString): AnsiString;
begin
  Result := Head('83') + Lines(['#begin[LV]', '#begin[LVInfo]', '[Name]LV1[end]', '[Bez]Rohbau[end]',
    '[KurzLang]1[end]']) + Glied + Lines(['#end[LVInfo]']) + ABody + Lines(['#end[LV]']) + Tail;
end;

{ STLBBau, StLNr, TLKNr, LeitBeschr and UnterBeschr. }
procedure TestStandard;
var
  Diags, CheckDiags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  I: TLandrixGaebXmlItem;
  Perf: TLandrixGaebXmlPerfDescr;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  CheckDiags := TLandrixGaebDiagnostics.Create;
  G := MapText(WithBody(Lines(['#begin[AusfBeschr]', '[AusfNr]1[end]', '[AusfBez]Beton[end]',
    '#begin[Beschreibung]', '[StLNr]0123[end]', '[Kurztext]Vorgabe[end]', '#end[Beschreibung]',
    '#end[AusfBeschr]',
    '#begin[Position]', '[OZ]010010[end]', '[Menge]1[end]', '[ME]m[end]',
    '#begin[Beschreibung]', '#begin[STLBBau]', '[STLBBauKat]STLB-Bau|4|1998|012|60|[end]',
    '[STLBBauIdent]2795|0|10[end]', '[StLBBauIdent]-8|0|11[end]', '[STLBBauIdent]||[end]',
    '#end[STLBBau]', '[StLNr]9601220001040201[end]', '[TLKNr]T1[end]', '[Kurztext]Eins[end]',
    '#end[Beschreibung]', '[LeitBeschr]J[end]',
    '#begin[UnterBeschr]', '[UbNr]01[end]', '#begin[Beschreibung]', '[StLNr]9601220001040201[end]',
    '[Kurztext]Unter eins[end]', '#end[Beschreibung]', '[MeAng]J[end]', '[Menge]2,5[end]', '[ME]m2[end]',
    '#end[UnterBeschr]',
    '#begin[UnterBeschr]', '[UbNr]2[end]', '#begin[Beschreibung]', '[Kurztext]Unter zwei[end]',
    '#end[Beschreibung]', '[MeAng]J[end]', '[FrMenge]J[end]', '#end[UnterBeschr]',
    '#end[Position]'])), Diags, T);
  try
    Perf := TLandrixGaebXmlPerfDescr(G.Award.BoQ.BoQBody.Itemlist.Children[0]);
    I := TLandrixGaebXmlItem(G.Award.BoQ.BoQBody.Itemlist.Children[1]);
    CheckEqualsGaebStr('0123', Perf.Description[0].StLNo.Value, 'StLNr of an execution description');
    Check(I.Description.HasSTLBBau, 'STLBBau mapped');
    with I.Description.STLBBau do
    begin
      CheckEqualsGaebStr('STLB-Bau', STLBBauCtlg.CtlgName, 'catalogue name');
      CheckEqualsGaebStr('1998-04', STLBBauCtlg.VersDate, 'version from year and month');
      CheckEqualsGaebStr('012', STLBBauCtlg.WCtg, 'LB');
      CheckEqualsGaebStr('60', STLBBauCtlg.Group, 'group');
      CheckEqualsGaebStr('', STLBBauCtlg.CostGrp, 'no cost group');
      CheckEquals(2, Integer(STLBBauID.Count), 'two identifiers, the blank one left out');
      CheckEqualsGaebStr('2795', STLBBauID[0].ArtChrIdent, 'SmeId');
      CheckEqualsGaebStr('0', STLBBauID[0].ArtChIdx, 'SmtSmi');
      CheckEqualsGaebStr('10', STLBBauID[0].ChVIdent, 'AprId');
      CheckEqualsGaebStr('-8', STLBBauID[1].ArtChrIdent, 'negative, other spelling of the key');
    end;
    Check(not I.Description.HasStLNo, 'StLNr next to STLBBau not mapped');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-001'), 'and reported: ' + Diags.ToText);
    Check(Pos('Beschreibung/StLNr', Diags.ToText) > 0, 'the key is named');
    CheckEqualsGaebStr('T1', I.Description.WICNo, 'TLKNr');
    CheckEqualsGaebStr('Yes', I.SumDescr, 'LeitBeschr');
    CheckEquals(2, Integer(I.SubDescr.Count), 'two sub descriptions');
    CheckEqualsGaebStr('1', I.SubDescr[0].SubDNo, 'UbNr');
    CheckEqualsGaebStr('9601220001040201', I.SubDescr[0].Description.StLNo.Value, 'its StLNr');
    CheckEqualsGaebStr('Yes', I.SubDescr[0].QtySpec, 'MeAng');
    CheckEqualsUtf8('2.5', I.SubDescr[0].Qty.Text, 'Menge');
    CheckEqualsGaebStr('m2', I.SubDescr[0].QU, 'ME');
    CheckEqualsGaebStr('Yes', I.SubDescr[1].QtyTBD, 'FrMenge');
    CheckEquals(0, Diags.CountOf('GAEB-D2000-MAP-004') + Diags.CountOf('GAEB-D2000-MAP-009'),
      'nothing outside: ' + Diags.ToText);
    Check(LandrixGaebXmlCheckModel(G, T, CheckDiags), 'content model: ' + CheckDiags.ToText);
  finally
    G.Free;
  end;
  { values outside: a version that is none, identifiers without SmeId or
    with a letter, STLBBau without group (then StLNr, here no number), an
    UbNr out of range and one missing, a key of blank components }
  Diags.Clear;
  G := MapText(WithBody(Lines(['#begin[Position]', '[OZ]010010[end]', '[Menge]1[end]', '[ME]m[end]',
    '#begin[Beschreibung]', '#begin[STLBBau]', '[STLBBauKat]STLB-Bau|-1|-1|012|60|[end]',
    '[STLBBauIdent]x|0|1[end]', '[STLBBauIdent]5|y|1[end]', '#end[STLBBau]', '[Kurztext]Eins[end]',
    '#end[Beschreibung]',
    '#begin[UnterBeschr]', '[UbNr]100[end]', '[MeAng]J[end]', '#end[UnterBeschr]',
    '#begin[UnterBeschr]', '[MeAng]J[end]', '#end[UnterBeschr]', '#end[Position]',
    '#begin[Position]', '[OZ]010020[end]', '[Menge]1[end]', '[ME]m[end]',
    '#begin[Beschreibung]', '#begin[STLBBau]', '[STLBBauKat]STLB-Bau||||[end]',
    '[STLBBauIdent]1|2|3[end]', '#end[STLBBau]', '[StLNr]12AB[end]', '[Kurztext]Zwei[end]',
    '#end[Beschreibung]', '#end[Position]',
    '#begin[Position]', '[OZ]010030[end]', '[Menge]1[end]', '[ME]m[end]',
    '#begin[Beschreibung]', '#begin[STLBBau]', '[STLBBauKat]|||||[end]', '[STLBBauIdent]||[end]',
    '#end[STLBBau]', '[Kurztext]Drei[end]', '#end[Beschreibung]', '#end[Position]',
    '#begin[Position]', '[OZ]010040[end]', '[Menge]1[end]', '[ME]m[end]',
    '#begin[Beschreibung]', '#begin[STLBBau]',
    '[STLBBauKat]ABCDEFGHIJK|4|0000|1234|60|123456789012345678901[end]',
    '#end[STLBBau]', '[Kurztext]Vier[end]', '#end[Beschreibung]', '#end[Position]'])), Diags, T);
  try
    I := TLandrixGaebXmlItem(G.Award.BoQ.BoQBody.Itemlist.Children[0]);
    Check(I.Description.HasSTLBBau, 'kept without version');
    CheckEqualsGaebStr('', I.Description.STLBBau.STLBBauCtlg.VersDate, 'version left out');
    CheckEquals(1, Integer(I.Description.STLBBau.STLBBauID.Count), 'identifier without SmeId left out');
    CheckEqualsGaebStr('', I.Description.STLBBau.STLBBauID[0].ArtChIdx, 'letter left out');
    CheckEqualsGaebStr('', I.SubDescr[0].SubDNo, 'UbNr 100 left out');
    I := TLandrixGaebXmlItem(G.Award.BoQ.BoQBody.Itemlist.Children[1]);
    Check(not I.Description.HasSTLBBau, 'without group left out');
    Check(not I.Description.HasStLNo, 'StLNr with a letter left out');
    I := TLandrixGaebXmlItem(G.Award.BoQ.BoQBody.Itemlist.Children[2]);
    Check(not I.Description.HasSTLBBau, 'blank key left out');
    I := TLandrixGaebXmlItem(G.Award.BoQ.BoQBody.Itemlist.Children[3]);
    Check(I.Description.HasSTLBBau, 'too long names kept');
    CheckEqualsGaebStr('', I.Description.STLBBau.STLBBauCtlg.VersDate, 'year 0000 left out');
    Check(Pos('8 component(s)', Diags.ToText) > 0, 'components counted one by one: ' + Diags.ToText);
    Check(Pos('1 STLB-Bau key(s)', Diags.ToText) > 0, 'STLBBau without group counted');
    Check(Pos('2 sub description(s)', Diags.ToText) > 0, 'UnterBeschr without UbNr counted');
    CheckEquals(2, Diags.CountOf('GAEB-D2000-MAP-004'), 'UbNr and the components: ' + Diags.ToText);
    CheckEquals(2, Diags.CountOf('GAEB-D2000-MAP-009'), 'STLBBau and UnterBeschr');
    CheckEquals(0, Diags.CountOf('GAEB-D2000-MAP-001'), 'everything taken: ' + Diags.ToText);
    Check((Pos('12AB', Diags.ToText) = 0) and (Pos('STLB-Bau|', Diags.ToText) = 0), 'no values in messages');
  finally
    G.Free;
    CheckDiags.Free;
    Diags.Free;
  end;
end;

{ ZuschlPosition and Mengensplit. }
procedure TestMarkup;
var
  Diags, CheckDiags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  I1, I2: TLandrixGaebXmlItem;
  M1, M2: TLandrixGaebXmlMarkupItem;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  CheckDiags := TLandrixGaebDiagnostics.Create;
  G := MapText(WithBody(Lines(['#begin[Position]', '[OZ]010010[end]', '[Bezuschl]J[end]',
    '[Menge]10[end]', '#begin[Mengensplit]', '[Menge]4[end]', '#begin[KatZuord]', '[KatNam]BA[end]',
    '[KatBez]Bauabschnitt[end]', '[KatSchl]1[end]', '#end[KatZuord]', '#end[Mengensplit]',
    '#begin[Mengensplit]', '[MengeProz]60[end]', '#end[Mengensplit]',
    '#begin[Mengensplit]', '[Menge]1[end]', '[MengeProz]5[end]', '#end[Mengensplit]',
    '#begin[Mengensplit]', '[KatZuord]V10|Alt|A[end]', '#end[Mengensplit]',
    '[ME]m[end]', '#begin[Beschreibung]', '[Kurztext]Eins[end]',
    '#end[Beschreibung]', '#end[Position]',
    '#begin[Position]', '[OZ]010020[end]', '[Menge]5[end]', '[ME]m[end]',
    '#begin[Beschreibung]', '[Kurztext]Zwei[end]', '#end[Beschreibung]', '#end[Position]',
    '#begin[ZuschlPosition]', '[OZ]010030[end]', '[ZuschlArt]P[end]',
    '[ZuschlTMenge]010010|2,5[end]', '[ZuschlTMenge] 010020 |[end]', '[ZuschlTMenge]019999|1[end]',
    '[ZuschlTMenge]|3[end]',
    '#begin[Beschreibung]', '[Kurztext]Zuschlag[end]', '#end[Beschreibung]', '#end[ZuschlPosition]',
    '#begin[ZuschlPosition]', '[OZ]010040[end]', '[ZuschlArt]Z[end]',
    '#begin[Beschreibung]', '[Kurztext]Zuschlag auf bezuschlagte[end]', '#end[Beschreibung]',
    '#end[ZuschlPosition]'])), Diags, T);
  try
    CheckEquals(4, Integer(G.Award.BoQ.BoQBody.Itemlist.Children.Count), 'items and markup items');
    I1 := TLandrixGaebXmlItem(G.Award.BoQ.BoQBody.Itemlist.Children[0]);
    I2 := TLandrixGaebXmlItem(G.Award.BoQ.BoQBody.Itemlist.Children[1]);
    Check(G.Award.BoQ.BoQBody.Itemlist.Children[2] is TLandrixGaebXmlMarkupItem, 'ZuschlPosition');
    M1 := TLandrixGaebXmlMarkupItem(G.Award.BoQ.BoQBody.Itemlist.Children[2]);
    M2 := TLandrixGaebXmlMarkupItem(G.Award.BoQ.BoQBody.Itemlist.Children[3]);
    CheckEquals(3, Integer(I1.QtySplit.Count), 'three splits, the one without quantity left out');
    CheckEqualsUtf8('4', I1.QtySplit[0].Qty.Text, 'Menge');
    CheckEquals(1, Integer(I1.QtySplit[0].CtlgAssign.Count), 'its KatZuord');
    CheckEqualsUtf8('60', I1.QtySplit[1].QtyPcnt.Text, 'MengeProz');
    CheckEqualsUtf8('1', I1.QtySplit[2].Qty.Text, 'Menge before MengeProz');
    Check(not I1.QtySplit[2].QtyPcnt.HasValue, 'MengeProz next to Menge not mapped');
    CheckEqualsGaebStr('0030', M1.RNoPart, 'number of the markup item');
    CheckEqualsGaebStr('ListInSubQty', M1.MarkupType, 'ZuschlArt P');
    CheckEquals(2, Integer(M1.MarkupSubQty.Count), 'unknown and missing OZ left out');
    CheckEqualsGaebStr(I1.ID, M1.MarkupSubQty[0].RefItem.IDRef, 'first item');
    CheckEqualsUtf8('2.5', M1.MarkupSubQty[0].SubQty.Text, 'TMenge');
    CheckEqualsGaebStr(I2.ID, M1.MarkupSubQty[1].RefItem.IDRef, 'second item, spaces ignored');
    Check(not M1.MarkupSubQty[1].SubQty.HasValue, 'without TMenge the whole quantity');
    CheckEqualsGaebStr('IdentAsMark', M2.MarkupType, 'ZuschlArt Z');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-010'), 'references to no item: ' + Diags.ToText);
    Check(Pos('2 reference(s)', Diags.ToText) > 0, 'unknown and missing OZ counted');
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-009'), 'split without quantity');
    Check(Pos('1 quantity split(s)', Diags.ToText) > 0, 'counted');
    Check(Pos('Mengensplit/MengeProz not mapped', Diags.ToText) > 0, 'MengeProz next to Menge reported');
    Check(Pos('Mengensplit/KatZuord not mapped', Diags.ToText) > 0, 'KatZuord of the left out split');
    Check(Pos('019999', Diags.ToText) = 0, 'no values in messages');
    Check(LandrixGaebXmlCheckModel(G, T, CheckDiags), 'content model: ' + CheckDiags.ToText);
  finally
    G.Free;
  end;
  { the amounts of a markup item and keys X83 does not allow }
  Diags.Clear;
  G := MapText(WithBody(Lines(['#begin[Position]', '[OZ]010010[end]', '[Menge]1[end]', '[ME]m[end]',
    '[BedarfAuftr]J[end]', '#begin[Beschreibung]', '[Kurztext]Eins[end]', '#end[Beschreibung]', '#end[Position]',
    '#begin[ZuschlPosition]', '[OZ]010020[end]', '[ZuschlArt]A[end]', '[Entf]J[end]', '[GBZuschl]100[end]',
    '[Zuschlag]5[end]', '[NachlassProz]1[end]', '[GB]4,95[end]', '[ZuschlTMenge]010010|zwei[end]',
    '[ZuschlTMenge]010020|1[end]',
    '#end[ZuschlPosition]'])), Diags, T);
  try
    M1 := TLandrixGaebXmlMarkupItem(G.Award.BoQ.BoQBody.Itemlist.Children[1]);
    CheckEqualsGaebStr('Yes', TLandrixGaebXmlItem(G.Award.BoQ.BoQBody.Itemlist.Children[0]).ProvisAccpt, 'BedarfAuftr');
    CheckEqualsGaebStr('AllInCat', M1.MarkupType, 'ZuschlArt A');
    CheckEqualsGaebStr('Yes', M1.NotAppl, 'Entf');
    CheckEqualsUtf8('5', M1.Markup.Text, 'Zuschlag');
    CheckEqualsUtf8('100', M1.ITMarkup.Text, 'GBZuschl');
    CheckEqualsUtf8('1', M1.DiscountPcnt.Text, 'NachlassProz');
    CheckEqualsUtf8('4.95', M1.IT.Text, 'GB');
    CheckEquals(0, Integer(M1.MarkupSubQty.Count), 'TMenge no number and the own OZ left out');
    CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-008'), 'TMenge no number: ' + Diags.ToText);
    CheckEquals(1, Diags.CountOf('GAEB-D2000-MAP-010'), 'a markup item is no item to refer to');
    Check(Pos('zwei', Diags.ToText) = 0, 'no values in messages');
  finally
    G.Free;
    CheckDiags.Free;
    Diags.Free;
  end;
end;

{ GAEBInfo, VergabeInfo/Art, Bedarfstraeger, AusfOrt, BenachOrt and
  ZusText. }
procedure TestHeader;
var
  Diags, CheckDiags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  CheckDiags := TLandrixGaebDiagnostics.Create;
  G := MapText(Lines(['#begin[GAEB]', '#begin[GAEBInfo]', '[Version]1.2[end]', '[VersMon]04[end]',
    '[VersJahr]2002[end]', '[Datum]13.11.2026[end]', '[ProgSystem]Test[end]', '[Zertifikat]J[end]',
    '[Zeichensatz]ANSI[end]', '#end[GAEBInfo]',
    '#begin[PrjInfo]', '[Name]P1[end]', '[Wae]EUR[end]', '[Kommunikation]Frage|Antwort[end]',
    '[ZusText]Als Element[end]',
    '#begin[ZusText]', '[Text]Projekttext[end]', '#end[ZusText]', '#end[PrjInfo]',
    '#begin[Vergabe]', '[DP]83[end]', '#begin[VergabeInfo]', '[Wae]EUR[end]',
    '[ErDatum]01.12.2026[end]', '[Art]4[end]', '#end[VergabeInfo]',
    '#begin[AG]', '#begin[Adresse]', '[Name1]Bauherr[end]', '[Strasse]Weg 1[end]',
    '[PLZ]12345[end]', '[Ort]Stadt[end]', '#end[Adresse]', '#begin[ZusText]', '[Text]AG-Text[end]', '#end[ZusText]', '#end[AG]',
    '#begin[Bedarfstraeger]', '[BedarfTrName]Amt[end]', '#end[Bedarfstraeger]',
    '#begin[AusfOrt]', '[AusfOrtName]Baustelle[end]', '#begin[Adresse]', '[Name1]Bau[end]',
    '[Strasse]Weg 2[end]', '[PLZ]12345[end]', '[Ort]Stadt[end]',
    '#end[Adresse]', '#end[AusfOrt]',
    '#begin[BenachOrt]', '[BenachOrtNam]Nachbar eins[end]', '#end[BenachOrt]',
    '#begin[BenachOrt]', '[BenachOrtNam]Nachbar zwei[end]', '#end[BenachOrt]',
    '#begin[ZusText]', '[Text]Vertragstext[end]', BS('[TextRTF]{`rtf1 Vertragstext}[end]'),
    '[ExtDat]PLAN.PDF|Plan[end]', '#end[ZusText]',
    '#begin[ZusText]', BS('[TextRTF]{`rtf1 Nur RTF}[end]'), '#end[ZusText]',
    '#begin[ZusText]', '[ExtDat]BILD.BMP|[end]', '#end[ZusText]',
    '#end[Vergabe]', '#begin[ZusText]', '[Text]Schluss[end]', '#end[ZusText]', '#end[GAEB]']),
    Diags, T);
  try
    CheckEqualsGaebStr('Available', G.GAEBInfo.Certific, 'Zertifikat');
    CheckEqualsGaebStr('2021-05', G.GAEBInfo.VersDate, 'VersDate of GAEB DA XML');
    CheckEqualsGaebStr('OpenCall', G.Award.AwardInfo.Cat, 'Art 4');
    CheckEquals(1, Integer(G.PrjInfo.AddText.Count), 'ZusText of PrjInfo');
    CheckEquals(1, Integer(G.Award.OWN.AddText.Count), 'ZusText of AG');
    CheckEquals(1, Integer(G.Award.Requester.Count), 'Bedarfstraeger');
    CheckEqualsGaebStr('Amt', G.Award.Requester[0].RequestName, 'its name');
    CheckEquals(2, Integer(G.Award.CnstSiteGroup.Count), 'two pairs');
    with G.Award.CnstSiteGroup[0] do
    begin
      CheckEqualsGaebStr('Baustelle', CnstSite.CnstSiteName, 'AusfOrtName');
      CheckEqualsGaebStr('Stadt', CnstSite.Address.City, 'its address');
      CheckEqualsGaebStr('Nachbar eins', NotifSite.NotifSiteName, 'BenachOrtNam');
    end;
    with G.Award.CnstSiteGroup[1] do
    begin
      Check(CnstSite.IsPresent, 'an empty CnstSite for the second BenachOrt');
      CheckEqualsGaebStr('', CnstSite.CnstSiteName, 'empty');
      CheckEqualsGaebStr('Nachbar zwei', NotifSite.NotifSiteName, 'second BenachOrt');
    end;
    CheckEquals(2, Integer(G.Award.AddText.Count), 'Text and TextRTF alone; ExtDat alone adds nothing');
    Check(G.Award.AddText[1].DetailAddText.IsPresent, 'TextRTF read');
    CheckEquals(1, Integer(G.AddText.Count), 'ZusText of GAEB');
    CheckEquals(4, Diags.CountOf('GAEB-D2000-MAP-001'), 'Kommunikation, ZusText as an element, TextRTF next ' +
      'to Text, ExtDat: ' + Diags.ToText);
    Check(Pos('PrjInfo/ZusText not mapped', Diags.ToText) > 0, 'ZusText as an element reported');
    Check(Pos('ZusText/TextRTF not mapped (1 time(s))', Diags.ToText) > 0, 'TextRTF next to Text');
    Check(Pos('ZusText/ExtDat not mapped (2 time(s))', Diags.ToText) > 0, 'ExtDat');
    Check(Pos('Kommunikation', Diags.ToText) > 0, 'Kommunikation has no counterpart');
    Check(Pos('VersMon', Diags.ToText) = 0, 'VersMon taken');
    Check(LandrixGaebXmlCheckModel(G, T, CheckDiags), 'content model: ' + CheckDiags.ToText);
  finally
    G.Free;
    CheckDiags.Free;
    Diags.Free;
  end;
end;

procedure ExpectRejected(const S: AnsiString; const AMsg: string);
var
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
begin
  try
    G := MapText(S, nil, T);
    G.Free;
    FailNotRaised('ELandrixGaebError');
  except
    on E: ELandrixGaebError do
      Check(Pos('GAEB DA 2000', E.Message) > 0, AMsg);
  end;
end;

procedure TestRejected;
begin
  ExpectRejected(Head('88') + Tail, 'phase 88');
  ExpectRejected(Lines(['#begin[GAEB]', '#begin[LVKatalog]', '[DP]80[end]', '#end[LVKatalog]',
    '#end[GAEB]']), 'catalogue (80) not read yet');
end;

{ ---- local corpus ---- }

var
  LocalFiles, LocalParseRejected, LocalMapRejected, LocalMapped, LocalValid: Integer;
  LocalKeys, LocalRules: TStringList;
  LocalKeyCounts, LocalRuleCounts: array of Integer;

procedure AddCount(AList: TStringList; AIsKey: Boolean; const AKey: string; AAdd: Integer);
var
  K: Integer;
begin
  K := AList.IndexOf(AKey);
  if K < 0 then
  begin
    K := AList.Add(AKey);
    if AIsKey then
    begin
      SetLength(LocalKeyCounts, K + 1);
      LocalKeyCounts[K] := 0;
    end
    else
    begin
      SetLength(LocalRuleCounts, K + 1);
      LocalRuleCounts[K] := 0;
    end;
  end;
  if AIsKey then
    Inc(LocalKeyCounts[K], AAdd)
  else
    Inc(LocalRuleCounts[K], AAdd);
end;

{ A path without its [n] indexes (debug output of the corpus test). }
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

function TryParse(Stream: TStream; Diags: TLandrixGaebDiagnostics): TLandrixGaebDA2000Document;
begin
  try
    Result := LandrixGaebDA2000ParseStream(Stream, gcsUnknown, Diags);
  except
    on ELandrixGaebError do
      Result := nil;
  end;
end;

function TryMap(D: TLandrixGaebDA2000Document; Diags: TLandrixGaebDiagnostics;
  out T: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
begin
  try
    Result := LandrixGaebDA2000Map(D, Diags, nil, T);
  except
    on ELandrixGaebError do
      Result := nil;
  end;
end;

procedure MapLocalFile(const FileName: string);
var
  Stream: TFileStream;
  Diags, CheckDiags: TLandrixGaebDiagnostics;
  D: TLandrixGaebDA2000Document;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  I, P, N: Integer;
  Msg: string;
  Options: TLandrixGaebXmlWriteOptions;
  Xml: TLandrixXmlUtf8;
  Errors, Warnings: Integer;
begin
  if LandrixGaebDetectFile(FileName, nil, 0).Format <> gfDA2000 then
    Exit;
  Inc(LocalFiles);
  Diags := TLandrixGaebDiagnostics.Create;
  CheckDiags := TLandrixGaebDiagnostics.Create;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    D := TryParse(Stream, Diags);
    if D = nil then
    begin
      Inc(LocalParseRejected);
      Exit;
    end;
    try
      G := TryMap(D, Diags, T);
      if G = nil then
      begin
        Inc(LocalMapRejected);
        Exit;
      end;
      try
        Inc(LocalMapped);
        { members the target does not allow are left out with a warning
          (as the conversion does); what remains must fit the content
          model }
        Options := LandrixGaebXmlDefaultWriteOptions;
        Options.Mode := gwmBestEffort;
        Options.Check := False;
        Xml := LandrixGaebXmlWriteCollect(G, T, Options, Diags, Errors, Warnings);
        if LandrixGaebXmlCheckTarget(Pointer(Xml), Length(Xml), T, CheckDiags) then
          Inc(LocalValid);
      finally
        G.Free;
      end;
    finally
      D.Free;
    end;
    for I := 0 to Integer(Diags.Count) - 1 do
    begin
      AddCount(LocalRules, False, Diags[I].RuleId, 1);
      if Diags[I].RuleId = 'GAEB-D2000-MAP-001' then
      begin
        { "<path> not mapped (<n> time(s))": keys only }
        Msg := Diags[I].Message;
        P := Pos(' not mapped (', Msg);
        N := StrToIntDef(Copy(Msg, P + 13, Pos(' time', Msg) - P - 13), 0);
        AddCount(LocalKeys, True, Copy(Msg, 1, P - 1), N);
      end;
    end;
    for I := 0 to Integer(CheckDiags.Count) - 1 do
    begin
      AddCount(LocalRules, False, 'check:' + CheckDiags[I].RuleId, 1);
      if GetEnvironmentVariable('LANDRIX_CHECKPATHS') <> '' then
        AddCount(LocalKeys, True, 'check ' + CheckDiags[I].RuleId + ' ' + StripIndexes(CheckDiags[I].Path) +
          ': ' + Copy(CheckDiags[I].Message, 1, 60), 1);
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
  I, J, Best: Integer;
  Line: string;
  Done: array of Boolean;
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
  LocalKeyCounts := nil;
  LocalRuleCounts := nil;
  LocalKeys := TStringList.Create;
  LocalRules := TStringList.Create;
  try
    WalkLocal(LocalDataDir);
    Line := '';
    for I := 0 to LocalRules.Count - 1 do
      Line := Line + ' ' + LocalRules[I] + 'x' + IntToStr(LocalRuleCounts[I]);
    WriteLn('  Local.DA2000Map: ', LocalFiles, ' file(s), ', LocalParseRejected, ' rejected by the parser, ',
      LocalMapRejected, ' phase not read, ', LocalMapped, ' mapped, ', LocalValid,
      ' valid against the content model (members the phase does not allow left out);', Line);
    { the keys not mapped most often (keys only) }
    Done := nil;
    SetLength(Done, LocalKeys.Count);
    for I := 0 to LocalKeys.Count - 1 do
      Done[I] := False;
    for J := 1 to 45 do
    begin
      Best := -1;
      for I := 0 to LocalKeys.Count - 1 do
        if (not Done[I]) and ((Best < 0) or (LocalKeyCounts[I] > LocalKeyCounts[Best])) then
          Best := I;
      if Best < 0 then
        Break;
      Done[Best] := True;
      WriteLn('    ', LocalKeyCounts[Best]: 7, '  ', LocalKeys[Best]);
    end;
    Check(LocalFiles > 0, 'GAEB DA 2000 files found');
  finally
    LocalKeys.Free;
    LocalRules.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('DA2000Mapping.Sample', TestMapSample);
  RegisterTest('DA2000Mapping.DerivedBreakdown', TestDerivedBreakdown);
  RegisterTest('DA2000Mapping.ValueFindings', TestValueFindings);
  RegisterTest('DA2000Mapping.Levels', TestLevels);
  RegisterTest('DA2000Mapping.Rejected', TestRejected);
  RegisterTest('DA2000Mapping.ReviewCases', TestReviewCases);
  RegisterTest('DA2000Mapping.ToolboxForms', TestToolboxForms);
  RegisterTest('DA2000Mapping.References', TestReferences);
  RegisterTest('DA2000Mapping.Standard', TestStandard);
  RegisterTest('DA2000Mapping.Markup', TestMarkup);
  RegisterTest('DA2000Mapping.Header', TestHeader);
  RegisterTest('Local.DA2000Map', TestLocalMap);
end;

end.

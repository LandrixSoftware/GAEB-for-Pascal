{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The bid process X81 -> X83 -> X84 -> X86 on one synthetic project
  (tests/data/process): every document reads, checks and writes without a
  finding, the request X81 written as X83 is the X83, and the pair rules
  find nothing between request, bid and award (and do find a changed
  price). The process functions match request and bid, compute the
  totals and build the award from request and bid, which equals the
  award document but for owner and date. }

unit LandrixGaebTestProcess;

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
  LandrixGaebXmlReader,
  LandrixGaebXmlWriteBase,
  LandrixGaebXmlWriter,
  LandrixGaebXmlCheck,
  LandrixGaebRules,
  LandrixGaebBoQ,
  LandrixGaebProcess,
  LandrixGaebTestXmlCompare,
  LandrixGaebTestNoValues,
  LandrixGaebTestFramework;

const
  Names: array[0..3] of string = ('request.x81', 'request.x83', 'bid.x84', 'award.x86');
  Phases: array[0..3] of TLandrixGaebPhase = (gp81, gp83, gp84, gp86);

function ProcessFile(const AName: string): TLandrixXmlUtf8;
begin
  Result := ReadFileBytes(RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'process' + PathDelim + AName);
end;

function ReplaceAll(const S, APart, AWith: TLandrixXmlUtf8): TLandrixXmlUtf8;
var
  Rest: TLandrixXmlUtf8;
  P: Integer;
begin
  Result := '';
  Rest := S;
  P := Pos(APart, Rest);
  while P > 0 do
  begin
    Result := Result + Copy(Rest, 1, P - 1) + AWith;
    Rest := Copy(Rest, P + Integer(Length(APart)), MaxInt);
    P := Pos(APart, Rest);
  end;
  Result := Result + Rest;
end;

function RuleIds(ADiags: TLandrixGaebDiagnostics): string;
var
  I: TLandrixGaebListIndex;
begin
  Result := '';
  for I := 0 to ADiags.Count - 1 do
    Result := Result + ' ' + ADiags[I].RuleId;
end;

function Strict: TLandrixGaebXmlWriteOptions;
begin
  Result := LandrixGaebXmlDefaultWriteOptions;
  Result.Mode := gwmStrict;
end;

{ Reads a document of the process; the reader, the check and the rules add
  nothing, and it writes in strict mode for its own target. }
function Load(const ASource: TLandrixXmlUtf8; const AName: string; APhase: TLandrixGaebPhase;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Diags: TLandrixGaebDiagnostics;
  Det: TLandrixGaebDetection;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Result := nil;
  try
    Result := LandrixGaebXmlReadBuffer(Pointer(ASource), Integer(Length(ASource)), Diags, Det);
    ATarget := Det.Target;
    Check(Det.Target.Phase = APhase, AName + ': phase');
    CheckEquals(0, Integer(Diags.Count), AName + ': read without diagnostics:' + RuleIds(Diags));
    Diags.Clear;
    Check(LandrixGaebXmlCheckBuffer(Pointer(ASource), Integer(Length(ASource)), Diags, Det),
      AName + ': the check accepts it');
    CheckEquals(0, Integer(Diags.Count), AName + ': check without diagnostics:' + RuleIds(Diags));
    Diags.Clear;
    LandrixGaebCheckRules(Result, ATarget, Diags);
    CheckEquals(0, Integer(Diags.Count), AName + ': rules without finding:' + RuleIds(Diags));
    Diags.Clear;
    LandrixGaebXmlWriteUtf8(Result, ATarget, Strict, Diags);
    CheckEquals(0, Integer(Diags.Count), AName + ': written without diagnostics:' + RuleIds(Diags));
  except
    Result.Free;
    Diags.Free;
    raise;
  end;
  Diags.Free;
end;

procedure TestChain;
var
  Docs: array[0..3] of TLandrixGaebXmlGAEB;
  Targets: array[0..3] of TLandrixGaebTarget;
  Diags: TLandrixGaebDiagnostics;
  Diffs: TStringList;
  Converted, Changed: TLandrixGaebXmlGAEB;
  ConvertedTarget, ChangedTarget: TLandrixGaebTarget;
  Output: TLandrixXmlUtf8;
  I: Integer;
begin
  for I := 0 to 3 do
    Docs[I] := nil;
  Converted := nil;
  Changed := nil;
  Diags := TLandrixGaebDiagnostics.Create;
  Diffs := TStringList.Create;
  try
    for I := 0 to 3 do
      Docs[I] := Load(ProcessFile(Names[I]), Names[I], Phases[I], Targets[I]);

    { X81 -> X83: the request for bids is the description of the work with
      another DP; nothing is lost, the writer only reports the new DP }
    Output := LandrixGaebXmlWriteUtf8(Docs[0], LandrixGaebTarget(Targets[0].Version, Targets[0].Edition, gp83),
      Strict, Diags);
    CheckEqualsStr(' GAEB-WRT-003', RuleIds(Diags), 'request.x81 written as X83: only the DP is replaced');
    Converted := Load(Output, 'request.x81 as X83', gp83, ConvertedTarget);
    CompareGaebModels(Docs[1], Converted, Diffs);
    CheckEqualsStr('/GAEB/GAEBInfo/Date', Trim(Diffs.Text), 'request.x81 as X83 is request.x83 but for the date');

    { X83 -> X84 and X84 -> X86: the pair rules find nothing }
    Diags.Clear;
    Check(LandrixGaebCheckPair(Docs[1], Targets[1], Docs[2], Targets[2], Diags), 'request -> bid: no error');
    CheckEquals(0, Integer(Diags.Count), 'request -> bid: no finding:' + RuleIds(Diags));
    Diags.Clear;
    Check(LandrixGaebCheckPair(Docs[2], Targets[2], Docs[3], Targets[3], Diags), 'bid -> award: no error');
    CheckEquals(0, Integer(Diags.Count), 'bid -> award: no finding:' + RuleIds(Diags));

    { an award with another price of the alternative (not in the totals):
      the award itself stays consistent, the pair rule finds the change }
    Output := ReplaceAll(ReplaceAll(ProcessFile('award.x86'), '<UP>12.00</UP>', '<UP>13.00</UP>'),
      '<IT>48.00</IT>', '<IT>52.00</IT>');
    Changed := Load(Output, 'award.x86 changed', gp86, ChangedTarget);
    Diags.Clear;
    Check(LandrixGaebCheckPair(Docs[2], Targets[2], Changed, ChangedTarget, Diags),
      'bid -> changed award: a warning, no error');
    CheckEqualsStr(' GAEB-BR-PAIR-84-86-002', RuleIds(Diags), 'bid -> changed award: the unit price');
    if Diags.Count = 1 then
      Check(Diags[0].Severity = gsWarning, 'bid -> changed award: severity warning');
  finally
    Changed.Free;
    Converted.Free;
    for I := 0 to 3 do
      Docs[I].Free;
    Diffs.Free;
    Diags.Free;
  end;
end;

function ProcessPath(const AName: string): string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'process' + PathDelim + AName;
end;

function LoadBill(const AName: string): TLandrixGaebBillOfQuantities;
begin
  Result := TLandrixGaebBillOfQuantities.LoadFromFile(ProcessPath(AName), nil, 0);
end;

function NodeAt(ABill: TLandrixGaebBillOfQuantities; const AOZ: TLandrixGaebString;
  ACategory: Boolean): TLandrixGaebNode;
begin
  Check(ABill.FindByOZ(AOZ, '', ACategory, Result) = gfrFound, string(AOZ) + ' found');
end;

function DecOf(const S: string): TLandrixGaebDecimal;
begin
  Result.Clear;
  Check(Result.TrySetText(LandrixXmlStringToUtf8(S)), S + ' is a decimal');
end;

procedure CheckSum(const ASum: TLandrixGaebSum; const AExpected: string; const AMsg: string);
begin
  Check(ASum.Known, AMsg + ': known');
  Check(ASum.Blocker = nil, AMsg + ': no blocker');
  Check(ASum.Value.Equals(DecOf(AExpected)), AMsg + ': ' + LandrixXmlUtf8ToString(ASum.Value.Text) + ' = ' + AExpected);
end;

procedure TestMatching;
var
  Request, Bid: TLandrixGaebBillOfQuantities;
  M: TLandrixGaebMatching;
  E: TLandrixGaebMatch;
  N, I1, I4: TLandrixGaebNode;
  I: Integer;
begin
  Request := nil;
  Bid := nil;
  M := nil;
  try
    Request := LoadBill('request.x83');
    Bid := LoadBill('bid.x84');
    M := TLandrixGaebMatching.Create(Request, Bid);
    CheckEquals(7, M.Count, 'two categories and five items');
    CheckEquals(7, M.CountOf(gmkPair), 'all are pairs');
    for I := 0 to M.Count - 1 do
    begin
      E := M.Entries(I);
      Check(E.Left = Request.Nodes(I), 'left in document order');
      CheckEqualsGaebStr(E.Left.OZ, E.Right.OZ, 'pair with the same OZ');
      Check(E.Left.Kind = E.Right.Kind, 'pair of the same kind');
    end;
    I1 := NodeAt(Request, '01.0010', False);
    N := NodeAt(Bid, '1.10', False);
    Check(M.PartnerOf(I1) = N, 'partner of the request item');
    Check(M.PartnerOf(N) = I1, 'partner of the bid item');
    CheckEqualsGaebStr(I1.OZKey, N.OZKey, 'numeric parts by value');
    Check(NodeAt(Request, '01', True).OZKey <> '', 'a category has a key');
    M.Free;
    M := nil;

    { the bid changed: 01.0010 removed, 02.0010 twice, 02.0030 new }
    Bid.Remove(N);
    Bid.AddItem(TLandrixGaebCategory(NodeAt(Bid, '02', True)), '0010');
    Bid.AddItem(TLandrixGaebCategory(NodeAt(Bid, '02', True)), '30');
    M := TLandrixGaebMatching.Create(Request, Bid);
    CheckEquals(5, M.CountOf(gmkPair), 'pairs: two categories, three items');
    CheckEquals(1, M.CountOf(gmkOnlyLeft), 'only left: the removed item');
    CheckEquals(1, M.CountOf(gmkOnlyRight), 'only right: the new item');
    CheckEquals(3, M.CountOf(gmkAmbiguous), 'ambiguous: 02.0010 of the request and twice of the bid');
    CheckEquals(10, M.Count, 'all entries');
    Check(M.PartnerOf(I1) = nil, 'no partner of the removed item');
    I4 := NodeAt(Request, '02.0010', False);
    Check(M.PartnerOf(I4) = nil, 'no partner of an ambiguous item');
    E := M.Entries(M.Count - 1);
    Check((E.Kind = gmkOnlyRight) and (E.Left = nil) and (E.Right.OZ = '02.30'), 'the new item last');
    Check(M.PartnerOf(Request.Nodes(0)) = Bid.Nodes(0), 'categories stay pairs');
  finally
    M.Free;
    Bid.Free;
    Request.Free;
  end;
end;

procedure TestTotals;
var
  Request, Bid, Award: TLandrixGaebBillOfQuantities;
  M: TLandrixGaebMatching;
  C1, C2: TLandrixGaebCategory;
  S: TLandrixGaebSum;
begin
  Request := nil;
  Bid := nil;
  Award := nil;
  M := nil;
  try
    Request := LoadBill('request.x83');
    Bid := LoadBill('bid.x84');
    Award := LoadBill('award.x86');
    C1 := TLandrixGaebCategory(NodeAt(Award, '01', True));
    C2 := TLandrixGaebCategory(NodeAt(Award, '02', True));
    { the alternative 01.0030 and the eventual item 02.0010 do not count }
    CheckSum(LandrixGaebComputeSum(Award, C1, nil), '65', 'award 01');
    CheckSum(LandrixGaebComputeSum(Award, C2, nil), '300', 'award 02');
    CheckSum(LandrixGaebComputeSum(Award, nil, nil), '365', 'award');

    { a bid has no kinds of its own: they come from the request }
    S := LandrixGaebComputeSum(Bid, nil, nil);
    Check(not S.Known and not S.Value.HasValue, 'bid without request: unknown');
    Check(S.Blocker = Bid.Nodes(0), 'bid without request: the first category blocks');
    M := TLandrixGaebMatching.Create(Request, Bid);
    CheckSum(LandrixGaebComputeSum(Bid, nil, M), '365', 'bid with the kinds of the request');
    try
      LandrixGaebComputeSum(Award, nil, M);
      Check(False, 'kinds of another bill raise');
    except
      on ELandrixGaebError do
        ;
    end;

    { an item without total makes the sum unknown; ApplyTotals writes the
      rest }
    TLandrixGaebItem(NodeAt(Award, '01.0010', False)).ClearIT;
    C1.Totals.ClearValue(gtfTotal);
    C2.Totals.ClearValue(gtfTotal);
    S := LandrixGaebComputeSum(Award, nil, nil);
    Check(not S.Known and (S.Blocker = NodeAt(Award, '01.0010', False)), 'the item without IT blocks');
    CheckEquals(2, LandrixGaebApplyTotals(Award, nil), 'category 01 and the bill unknown');
    Check(not C1.Totals.Value(gtfTotal).HasValue, 'unknown total not written');
    Check(C2.Totals.Value(gtfTotal).Equals(DecOf('300')), 'total of 02 written');
    TLandrixGaebItem(NodeAt(Award, '01.0010', False)).SetIT(DecOf('25.00'));
    CheckEquals(0, LandrixGaebApplyTotals(Award, nil), 'all known');
    Check(C1.Totals.Value(gtfTotal).Equals(DecOf('65')), 'total of 01 written');
    Check(Award.Totals.Value(gtfTotal).Equals(DecOf('365')), 'total of the bill');

    { a category with TotAfterDisc adds that; with a discount but without
      it the sum is unknown }
    C1.Totals.SetValue(gtfTotAfterDisc, DecOf('60.00'));
    CheckSum(LandrixGaebComputeSum(Award, nil, nil), '360', 'TotAfterDisc counts');
    C1.Totals.ClearValue(gtfTotAfterDisc);
    C1.Totals.SetValue(gtfDiscountPcnt, DecOf('5'));
    S := LandrixGaebComputeSum(Award, nil, nil);
    Check(not S.Known and (S.Blocker = C1), 'discount without TotAfterDisc blocks');
  finally
    M.Free;
    Award.Free;
    Bid.Free;
    Request.Free;
  end;
end;

procedure TestBuildAward;
var
  Request, Bid, Expected, Award: TLandrixGaebBillOfQuantities;
  Diags: TLandrixGaebDiagnostics;
  Diffs: TStringList;
begin
  Request := nil;
  Bid := nil;
  Expected := nil;
  Award := nil;
  Diags := TLandrixGaebDiagnostics.Create;
  Diffs := TStringList.Create;
  try
    Request := LoadBill('request.x83');
    Bid := LoadBill('bid.x84');
    Expected := LoadBill('award.x86');
    Award := LandrixGaebBuildAward(Request, Bid, Diags);
    CheckEquals(0, Integer(Diags.Count), 'built without diagnostics:' + RuleIds(Diags));
    Check(Award.Target.Phase = gp86, 'an X86');
    Check(Award.Document.Award.DP = '86', 'DP 86 in the model');
    { owner and date are not part of request and bid }
    Award.Owner.Name1 := 'Auftraggeber';
    Award.Owner.Street := 'Weg 1';
    Award.Owner.PCode := '12345';
    Award.Owner.City := 'Ort';
    Award.Document.GAEBInfo.Date := '2026-11-13';
    CompareGaebModels(Expected.Document, Award.Document, Diffs);
    CheckEqualsStr('', Trim(Diffs.Text), 'the built award is award.x86');
    Diags.Clear;
    LandrixGaebCheckRules(Award.Document, Award.Target, Diags);
    CheckEquals(0, Integer(Diags.Count), 'rules without finding:' + RuleIds(Diags));
    Diags.Clear;
    Check(LandrixGaebCheckPair(Bid.Document, Bid.Target, Award.Document, Award.Target, Diags),
      'bid -> built award: no error');
    CheckEquals(0, Integer(Diags.Count), 'bid -> built award: no finding:' + RuleIds(Diags));
    Award.Free;
    Award := nil;

    { a changed bid: what has no unique partner is reported and not taken }
    Bid.Remove(NodeAt(Bid, '01.0010', False));
    Bid.AddItem(TLandrixGaebCategory(NodeAt(Bid, '02', True)), '0010');
    TLandrixGaebItem(Bid.AddItem(TLandrixGaebCategory(NodeAt(Bid, '02', True)), '0030')).SetUP(DecOf('1.00'));
    Diags.Clear;
    Award := LandrixGaebBuildAward(Request, Bid, Diags);
    CheckEqualsStr(' GAEB-PRC-002 GAEB-PRC-002 GAEB-PRC-001', RuleIds(Diags), 'ambiguous twice, one new');
    Check(not TLandrixGaebItem(NodeAt(Award, '01.0010', False)).UP.HasValue, 'no price without bid item');
    Check(not TLandrixGaebItem(NodeAt(Award, '02.0010', False)).UP.HasValue, 'no price for an ambiguous OZ');
    Check(TLandrixGaebItem(NodeAt(Award, '02.0020', False)).UP.Equals(DecOf('300')), 'the other prices');
    Check(Award.Contractor.Name1 = 'Bieter', 'contractor of the bid');

    { only X83 and X84 }
    Award.Free;
    Award := nil;
    try
      Award := LandrixGaebBuildAward(Bid, Request, nil);
      Check(False, 'swapped documents raise');
    except
      on ELandrixGaebError do
        ;
    end;
  finally
    Award.Free;
    Expected.Free;
    Bid.Free;
    Request.Free;
    Diffs.Free;
    Diags.Free;
  end;
end;

const
  DetailHead = '<Description><CompleteText><DetailTxt><Text><p><span>Text</span>';
  DetailTail = '</p></Text></DetailTxt></CompleteText></Description>';

function Envelope(const ADP, ABody: string): TLandrixXmlUtf8;
begin
  Result := LandrixXmlStringToUtf8('<?xml version="1.0" encoding="UTF-8"?>' +
    '<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA' + ADP + '/3.3"><GAEBInfo><Version>3.3</Version>' +
    '<VersDate>2021-05</VersDate><Date>2026-11-12</Date><ProgSystem>Test</ProgSystem></GAEBInfo>' +
    '<PrjInfo><NamePrj>P</NamePrj></PrjInfo><Award><DP>' + ADP + '</DP><BoQ ID="B1"><BoQInfo><Name>LV</Name>' +
    '<BoQBkdn><Type>BoQLevel</Type><Length>2</Length><Num>Yes</Num></BoQBkdn>' +
    '<BoQBkdn><Type>Item</Type><Length>4</Length><Num>Yes</Num></BoQBkdn></BoQInfo>' +
    '<BoQBody><BoQCtgy ID="C1" RNoPart="01"><BoQBody><Itemlist>' + ABody +
    '</Itemlist></BoQBody></BoQCtgy></BoQBody></BoQ></Award></GAEB>');
end;

function BillOf(const ASource: TLandrixXmlUtf8): TLandrixGaebBillOfQuantities;
var
  Det: TLandrixGaebDetection;
  Doc: TLandrixGaebXmlGAEB;
begin
  Doc := LandrixGaebXmlReadBuffer(Pointer(ASource), Integer(Length(ASource)), nil, Det);
  Result := TLandrixGaebBillOfQuantities.Create(Doc, Det.Target, True);
end;

{ What request.x83 and bid.x84 do not have: bidder complements of items
  and sub descriptions with numbers written differently, markup items. }
procedure TestBuildAwardDetails;
var
  Request, Bid, Award: TLandrixGaebBillOfQuantities;
  Diags: TLandrixGaebDiagnostics;
  Item: TLandrixGaebItem;
  Markup: TLandrixGaebMarkupItem;
begin
  Request := nil;
  Bid := nil;
  Award := nil;
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Request := BillOf(Envelope('83',
      '<Item ID="I1" RNoPart="0010"><Qty>1</Qty><QU>St</QU>' + DetailHead +
      '<TextComplement Kind="Bidder" MarkLbl="01"><ComplBody><p><span>Typ</span></p></ComplBody></TextComplement>' +
      '<TextComplement Kind="Bidder" MarkLbl="3"><ComplBodyInt Value="0"/><ComplBody><p><span>0</span></p></ComplBody>' +
      '</TextComplement>' + DetailTail + '<SumDescr>Yes</SumDescr><SubDescr><SubDNo>01</SubDNo>' + DetailHead +
      '<TextComplement Kind="Bidder" MarkLbl="002"><ComplBody><p><span>Farbe</span></p></ComplBody></TextComplement>' +
      DetailTail + '<Qty>2</Qty><QU>St</QU></SubDescr></Item>' +
      '<MarkupItem ID="M1" RNoPart="0020"><MarkupType>AllInCat</MarkupType>' + DetailHead + DetailTail +
      '</MarkupItem>' +
      '<MarkupItem ID="M2" RNoPart="0030"><MarkupType>AllInCat</MarkupType>' + DetailHead + DetailTail +
      '</MarkupItem>'));
    Bid := BillOf(Envelope('84',
      '<Item ID="I1" RNoPart="0010"><UP>3.00</UP><IT>3.00</IT>' + DetailHead +
      '<TextComplement Kind="Bidder" MarkLbl="1"><ComplBody><p><span>Typ B</span></p></ComplBody></TextComplement>' +
      '<TextComplement Kind="Bidder" MarkLbl="3"><ComplBodyInt Value=" 7 "/><ComplBody><p><span>7</span></p></ComplBody>' +
      '</TextComplement>' + DetailTail + '<SubDescr><SubDNo>1</SubDNo>' + DetailHead +
      '<TextComplement Kind="Bidder" MarkLbl="2"><ComplBody><p><span>Rot</span></p></ComplBody></TextComplement>' +
      DetailTail + '<UP>1.50</UP></SubDescr></Item>' +
      '<MarkupItem ID="M1" RNoPart="0020"><ITMarkup>100.00</ITMarkup><Markup>10.000</Markup>' +
      '<DiscountPcnt>5.000</DiscountPcnt><IT>9.50</IT></MarkupItem>' +
      '<MarkupItem ID="M2" RNoPart="0030"><IT>1.00</IT></MarkupItem>'));
    Award := LandrixGaebBuildAward(Request, Bid, Diags);
    CheckEqualsStr(' GAEB-PRC-004', RuleIds(Diags), 'only the markup item without Markup and ITMarkup');
    if Diags.Count = 1 then
      CheckEqualsGaebStr(Award.Nodes(3).Path, Diags[0].Path, 'at the markup item of the award');
    Item := TLandrixGaebItem(NodeAt(Award, '01.0010', False));
    Check(Item.UP.Equals(DecOf('3')), 'unit price');
    CheckEquals(2, Item.ComplementCount, 'two complements of the item');
    CheckEqualsGaebStr('Typ B', Item.Complements(0).BodyText, 'complement 01 taken from 1');
    CheckEqualsGaebStr('7', Item.Complements(1).SyntaxNode.ComplBodyInt.Value, 'integer without white space');
    CheckEqualsGaebStr('7', Item.Complements(1).BodyText, 'integer as body text');
    CheckEquals(1, Item.SubDescriptionCount, 'one sub description');
    Check(Item.SubDescriptions(0).UP.Equals(DecOf('1.5')), 'sub description 01 priced from 1');
    CheckEquals(1, Item.SubDescriptions(0).ComplementCount, 'one complement of the sub description');
    CheckEqualsGaebStr('Rot', Item.SubDescriptions(0).Complements(0).BodyText, 'complement 002 taken from 2');
    Markup := TLandrixGaebMarkupItem(NodeAt(Award, '01.0020', False));
    Check(Markup.ITMarkup.Equals(DecOf('100')) and Markup.MarkupPcnt.Equals(DecOf('10')) and
      Markup.DiscountPcnt.Equals(DecOf('5')) and Markup.IT.Equals(DecOf('9.5')), 'values of the markup item');
    Markup := TLandrixGaebMarkupItem(NodeAt(Award, '01.0030', False));
    Check(Markup.IT.Equals(DecOf('1')) and not Markup.ITMarkup.HasValue, 'what the bid has');
  finally
    Award.Free;
    Bid.Free;
    Request.Free;
    Diags.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Process.Chain', TestChain);
  RegisterTest('Process.Matching', TestMatching);
  RegisterTest('Process.Totals', TestTotals);
  RegisterTest('Process.BuildAward', TestBuildAward);
  RegisterTest('Process.BuildAwardDetails', TestBuildAwardDetails);
end;

end.

{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of the business facade (LandrixGaebBoQ): reading through the facade
  changes nothing in the model, the tree, OZ and search, values and kinds
  of the process documents, setters, text complements, the plain text,
  references, sub descriptions, lots, totals, parties and award data
  (legacy case 36: what the old adapters dropped), loading and saving. }

unit LandrixGaebTestBoQ;

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
  LandrixGaebXmlWriter,
  LandrixGaebBoQ,
  LandrixGaebTestXmlCompare,
  LandrixGaebTestNoValues,
  LandrixGaebTestFramework;

function DataDir(const ASub: string): string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + ASub + PathDelim;
end;

procedure ListFiles(const ADir: string; AList: TStrings);
var
  SR: TSearchRec;
begin
  if FindFirst(ADir + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        ListFiles(ADir + SR.Name + PathDelim, AList)
      else if SR.Name <> 'expected.txt' then
        AList.Add(ADir + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

function Load(const AFileName: string): TLandrixGaebBillOfQuantities;
var
  Source: TLandrixXmlUtf8;
  Det: TLandrixGaebDetection;
  G: TLandrixGaebXmlGAEB;
begin
  Source := ReadFileBytes(AFileName);
  G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
  Result := TLandrixGaebBillOfQuantities.Create(G, Det.Target, True);
end;

function WriteTarget(const ATarget: TLandrixGaebTarget): TLandrixGaebTarget;
begin
  Result := ATarget;
  if not LandrixGaebTargetIsSupported(Result, True) then
    Result := LandrixGaebTarget(gv33, ge2021_05, ATarget.Phase);
end;

function WrittenDoc(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget): TLandrixXmlUtf8;
var
  Options: TLandrixGaebXmlWriteOptions;
  E, W: Integer;
begin
  Options := LandrixGaebXmlDefaultWriteOptions;
  Options.Mode := gwmBestEffort;
  Options.PreserveScale := True;
  Result := LandrixGaebXmlWriteCollect(ADocument, WriteTarget(ATarget), Options, nil, E, W);
end;

function Written(ABill: TLandrixGaebBillOfQuantities): TLandrixXmlUtf8;
begin
  Result := WrittenDoc(ABill.Document, ABill.OutputTarget);
end;

function DecOf(const AText: string): TLandrixGaebDecimal;
begin
  Result.Clear;
  if not Result.TrySetText(LandrixXmlStringToUtf8(AText)) then
    raise Exception.Create('bad decimal in test: ' + AText);
end;

function DecText(const A: TLandrixGaebDecimal): string;
begin
  if A.HasValue then
    Result := LandrixXmlUtf8ToString(A.Text)
  else
    Result := '(none)';
end;

function S(const A: TLandrixGaebString): string;
begin
  Result := LandrixXmlUtf8ToString(LandrixXmlWideToUtf8(A));
end;

{ ---- reading changes nothing ---- }

type
  { Visits every text event (exercises the visitor). }
  TCountVisitor = class(TLandrixGaebTextVisitor)
  public
    Count: Integer;
    procedure Visit(const AEvent: TLandrixGaebTextEvent); override;
  end;

procedure TCountVisitor.Visit(const AEvent: TLandrixGaebTextEvent);
begin
  if AEvent.Kind = gteText then
    Inc(Count, Length(AEvent.Text))
  else
    Inc(Count);
end;

procedure ReadTotals(T: TLandrixGaebTotals);
var
  F: TLandrixGaebTotalField;
  K: Integer;
  D: TLandrixGaebDecimal;
  P: TLandrixGaebVATPart;
begin
  T.Exists;
  T.SyntaxNode;
  D := T.Amount;
  for F := Low(TLandrixGaebTotalField) to High(TLandrixGaebTotalField) do
    D := T.Value(F);
  for K := 1 to 6 do
    D := T.UPCompTotal(K);
  for K := 0 to T.VATPartCount - 1 do
    P := T.VATParts(K);
  if D.HasValue and P.VATPcnt.HasValue and (T = nil) then
    Check(False, 'never');
end;

procedure ReadItem(It: TLandrixGaebItem; V: TCountVisitor);
var
  K, J: Integer;
  Dummy: TLandrixGaebString;
  D: TLandrixGaebDecimal;
  R: TLandrixGaebReference;
  Q: TLandrixGaebQtySplit;
  Sub: TLandrixGaebSubDescription;
begin
  It.DescriptionRole;
  It.IsSumDescription;
  Dummy := It.HoldOutType;
  for K := 0 to It.RefBaseItemCount - 1 do
    R := It.RefBaseItem(K);
  for K := 0 to It.QtySplitCount - 1 do
    Q := It.QtySplits(K);
  for K := 0 to It.BidCommentCount - 1 do
    Dummy := Dummy + LandrixGaebPlainText(It.BidCommentNode(K));
  for K := 0 to It.SubDescriptionCount - 1 do
  begin
    Sub := It.SubDescriptions(K);
    Dummy := Dummy + Sub.Path + Sub.Number + Sub.QU + Sub.ShortText + Sub.LongText;
    LandrixGaebVisitText(Sub.DetailTextNode, V);
    LandrixGaebVisitText(Sub.OutlineTextNode, V);
    Sub.QtyTBD;
    D := Sub.Qty;
    D := Sub.UP;
    for J := 1 to 6 do
      D := Sub.UPComp(J);
    for J := 0 to Sub.ComplementCount - 1 do
      Dummy := Dummy + Sub.Complements(J).MarkLbl + Sub.Complements(J).CaptionText +
        Sub.Complements(J).BodyText + Sub.Complements(J).TailText;
  end;
  if (Dummy = #0) and D.HasValue and Q.Qty.HasValue and (R.Node = nil) then
    Check(False, 'never');
end;

procedure ReadNode(N: TLandrixGaebNode; V: TCountVisitor);
var
  K: Integer;
  Found: TLandrixGaebNode;
  FoundCat: TLandrixGaebCategory;
  Dummy: TLandrixGaebString;
  D: TLandrixGaebDecimal;
  R: TLandrixGaebReference;
  C: TLandrixGaebCatalogRef;
begin
  Dummy := N.OZ + N.RNoIndex + N.Path + N.ShortText + N.LongText;
  R := N.RefRNo;
  R := N.RefPerfNo;
  for K := 0 to N.CatalogCount - 1 do
    C := N.Catalogs(K);
  if (R.Node = nil) and (C.Code = #0) then
    Dummy := '';
  LandrixGaebVisitText(N.DetailTextNode, V);
  LandrixGaebVisitText(N.OutlineTextNode, V);
  for K := 0 to N.ComplementCount - 1 do
    Dummy := N.Complements(K).CaptionText + N.Complements(K).BodyText + N.Complements(K).TailText +
      N.Complements(K).MarkLbl;
  case N.Kind of
    gnkCategory:
      begin
        N.Bill.FindCategory(N.OZ, FoundCat);
        Dummy := TLandrixGaebCategory(N).Lbl + TLandrixGaebCategory(N).Accepted;
        D := TLandrixGaebCategory(N).Total;
        TLandrixGaebCategory(N).CountStatus;
        TLandrixGaebCategory(N).IsLot;
        ReadTotals(TLandrixGaebCategory(N).Totals);
        for K := 0 to TLandrixGaebCategory(N).Children.Count - 1 do
          ReadNode(TLandrixGaebCategory(N).Children[K], V);
      end;
    gnkItem:
      begin
        N.Bill.FindItem(N.OZ, N.RNoIndex, Found);
        D := TLandrixGaebItem(N).Qty;
        D := TLandrixGaebItem(N).UP;
        for K := 1 to 6 do
          D := TLandrixGaebItem(N).UPComp(K);
        D := TLandrixGaebItem(N).DiscountPcnt;
        D := TLandrixGaebItem(N).IT;
        Dummy := TLandrixGaebItem(N).QU + TLandrixGaebItem(N).AlternativeGroup + TLandrixGaebItem(N).HourIt +
          TLandrixGaebItem(N).Accepted + TLandrixGaebItem(N).ChangeOrderNo + TLandrixGaebItem(N).AlterBidStatus;
        TLandrixGaebItem(N).CountStatus;
        TLandrixGaebItem(N).Provisional;
        TLandrixGaebItem(N).IsBase;
        TLandrixGaebItem(N).NotOffered;
        ReadItem(TLandrixGaebItem(N), V);
      end;
    gnkMarkupItem:
      begin
        N.Bill.FindItem(N.OZ, N.RNoIndex, Found);
        D := TLandrixGaebMarkupItem(N).IT;
        D := TLandrixGaebMarkupItem(N).ITMarkup;
        D := TLandrixGaebMarkupItem(N).MarkupPcnt;
        Dummy := TLandrixGaebMarkupItem(N).MarkupType;
        TLandrixGaebMarkupItem(N).CountStatus;
      end;
    gnkPerfDescr:
      Dummy := TLandrixGaebPerfDescr(N).PerfNo + TLandrixGaebPerfDescr(N).PerfLbl;
  else
    ;
  end;
  if Dummy = #0 then
    Check(D.HasValue, 'never');
end;

procedure ReadAll(ABill: TLandrixGaebBillOfQuantities);
var
  I, K: Integer;
  V: TCountVisitor;
  Dummy: TLandrixGaebString;
  D: TLandrixGaebDecimal;
  Bk: TLandrixGaebBreakdown;
  R: TLandrixGaebReference;
begin
  Dummy := ABill.ProjectName + ABill.BoQName + ABill.Currency + ABill.UPCompLabel(1);
  Dummy := Dummy + ABill.Owner.Name1 + ABill.Owner.Email + ABill.Contractor.City + ABill.Contractor.VATID;
  Dummy := Dummy + ABill.ContractNo + ABill.ContractDate + ABill.BidDate + ABill.ConstructionStart +
    ABill.ConstructionEnd + ABill.Owner.RequestName;
  ABill.Owner.Exists;
  for I := 0 to ABill.RequesterCount - 1 do
  begin
    Dummy := Dummy + ABill.Requesters(I).Name1 + ABill.Requesters(I).RequestIDNo + ABill.Requesters(I).RequestName;
    ABill.Requesters(I).Exists;
  end;
  for I := 0 to ABill.BreakdownCount - 1 do
    Bk := ABill.Breakdowns(I);
  ABill.HasLots;
  for I := 0 to ABill.LotGroupCount - 1 do
  begin
    Dummy := Dummy + ABill.LotGroups(I).Number;
    for K := 0 to ABill.LotGroups(I).LotCount - 1 do
      R := ABill.LotGroups(I).Lots(K);
    ReadTotals(ABill.LotGroups(I).Totals);
  end;
  ReadTotals(ABill.Totals);
  if (Bk.Lbl = #0) and (R.Node = nil) then
    Dummy := '';
  D := ABill.Total;
  if ABill.UPFracDig + ABill.NoUPComps < -2 then
    Dummy := '';
  V := TCountVisitor.Create;
  try
    for I := 0 to ABill.Root.Count - 1 do
      ReadNode(ABill.Root[I], V);
  finally
    V.Free;
  end;
  if Dummy = #0 then
    Check(D.HasValue, 'never');
end;

{ The document in ASource; False if it is outside the model. }
function TryRead(const ASource: TLandrixXmlUtf8; out ADocument: TLandrixGaebXmlGAEB): Boolean;
var
  Det: TLandrixGaebDetection;
begin
  Result := True;
  try
    ADocument := LandrixGaebXmlReadBuffer(Pointer(ASource), Integer(Length(ASource)), nil, Det);
  except
    on ELandrixGaebError do
    begin
      ADocument := nil;
      Result := False;
    end;
  end;
end;

{ Reading through the facade (construction included) changes neither the
  output nor any field of the model (compared with a fresh read). }
procedure TestReadOnly;
var
  Files: TStringList;
  Diffs: TStringList;
  I, Checked: Integer;
  B: TLandrixGaebBillOfQuantities;
  Fresh, G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  Source, Before, After: TLandrixXmlUtf8;
  Name: string;
begin
  Files := TStringList.Create;
  Diffs := TStringList.Create;
  try
    ListFiles(DataDir('coverage'), Files);
    ListFiles(DataDir('legacy'), Files);
    ListFiles(DataDir('process'), Files);
    ListFiles(DataDir('rules'), Files);
    Checked := 0;
    for I := 0 to Files.Count - 1 do
    begin
      Name := ExtractFileName(Files[I]);
      if Pos('invalid', Name) > 0 then
        Continue;
      Source := ReadFileBytes(Files[I]);
      if not TryRead(Source, Fresh) then
        Continue;
      B := nil;
      try
        G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
        Before := WrittenDoc(G, Det.Target);
        B := TLandrixGaebBillOfQuantities.Create(G, Det.Target, True);
        ReadAll(B);
        After := Written(B);
        CheckEqualsUtf8(Before, After, Files[I] + ': reading through the facade changes no output');
        Diffs.Clear;
        CompareGaebModels(Fresh, B.Document, Diffs);
        CheckEquals(0, Diffs.Count, Files[I] + ': reading through the facade changes no field: ' + Diffs.Text);
        Inc(Checked);
      finally
        B.Free;
        Fresh.Free;
      end;
    end;
    Check(Checked > 300, 'documents read through the facade: ' + IntToStr(Checked));
  finally
    Diffs.Free;
    Files.Free;
  end;
end;

{ ---- the process documents ---- }

procedure TestTree;
var
  B: TLandrixGaebBillOfQuantities;
  N: TLandrixGaebNode;
  C, Cat: TLandrixGaebCategory;
  It: TLandrixGaebItem;
begin
  B := Load(DataDir('process') + 'request.x83');
  try
    CheckEquals(2, B.Root.Count, 'two categories at top level');
    CheckEquals(5, B.AllItems.Count, 'five items');
    C := B.Root[0] as TLandrixGaebCategory;
    CheckEqualsStr('01', S(C.OZ), 'OZ of the first category');
    CheckEqualsStr('Titel eins', S(C.Lbl), 'label');
    CheckEquals(3, C.Children.Count, 'items of the first category');
    It := C.Children[0] as TLandrixGaebItem;
    CheckEqualsStr('01.0010', S(It.OZ), 'OZ of the first item');
    Check(It.Parent = C, 'parent');
    CheckEqualsStr('Kurz eins', S(It.ShortText), 'short text');
    CheckEqualsStr('Leistung eins', S(It.LongText), 'long text');
    CheckEqualsStr('10', DecText(It.Qty), 'quantity');
    CheckEqualsStr('m', S(It.QU), 'unit');
    Check(not It.UP.HasValue, 'no unit price in the request');
    Check(It.CountStatus = gcsCounts, 'normal item counts');
    It := C.Children[1] as TLandrixGaebItem;
    Check(It.IsBase and not It.IsAlternative, 'base item');
    It := C.Children[2] as TLandrixGaebItem;
    Check(It.IsAlternative and not It.IsBase, 'alternative item');
    Check(It.CountStatus = gcsNotCounted, 'alternative does not count');
    It := (B.Root[1] as TLandrixGaebCategory).Children[0] as TLandrixGaebItem;
    Check(It.Provisional = gpvWithoutTotal, 'eventual item without total');
    Check(It.CountStatus = gcsNotCounted, 'eventual item without total does not count');
    It := (B.Root[1] as TLandrixGaebCategory).Children[1] as TLandrixGaebItem;
    Check(It.IsLumpSum, 'lump sum item');
    Check(B.FindItem('01.0010', '', N) = gfrFound, 'item found');
    Check(N = C.Children[0], 'the first item');
    Check(B.FindItem('1.10', '', N) = gfrFound, 'numeric parts by value');
    Check(B.FindCategory('01', Cat) = gfrFound, 'category found');
    Check(Cat = C, 'the first category');
    Check(B.FindCategory('1', Cat) = gfrFound, 'category by value');
    Check(B.FindCategory('01.0010', Cat) = gfrNotFound, 'an item is no category');
    Check(Cat = nil, 'nil when no category is found');
    Check(B.FindItem('01', '', N) = gfrNotFound, 'a category is no item');
    Check(B.FindItem('03.0010', '', N) = gfrNotFound, 'not found');
    Check(N = nil, 'nil when not found');
    CheckEqualsStr('Prozess', S(B.ProjectName), 'project name');
    Check(not B.Owner.Exists, 'no owner in the request');
    CheckEqualsStr('', S(B.Owner.Name1), 'absent party reads empty');
  finally
    B.Free;
  end;
end;

procedure TestBidAndAward;
var
  B: TLandrixGaebBillOfQuantities;
  N: TLandrixGaebNode;
  It: TLandrixGaebItem;
  Output: TLandrixXmlUtf8;
  T: TLandrixGaebTarget;
begin
  B := Load(DataDir('process') + 'bid.x84');
  try
    CheckEqualsStr('Bieter', S(B.Contractor.Name1), 'contractor');
    CheckEqualsStr('365.00', DecText(B.Total), 'total of the bill');
    Check(B.FindItem('01.0010', '', N) = gfrFound, 'item of the bid');
    It := N as TLandrixGaebItem;
    CheckEqualsStr('2.50', DecText(It.UP), 'unit price');
    Check(It.CountStatus = gcsUnknown, 'a bid does not carry the kinds of the request');
    { another output target converts on saving; the meaning stays }
    T := B.Target;
    T.Phase := gp86;
    B.OutputTarget := T;
    Check(B.Target.Phase = gp84, 'the target of the document stays');
    Check(It.CountStatus = gcsUnknown, 'the output target does not change the count status');
    Check(Pos(TLandrixXmlUtf8('<DP>86</DP>'), Written(B)) > 0, 'written for the output target');
    B.OutputTarget := B.Target;
    CheckEqualsStr('65.00', DecText(It.Parent.Total), 'total of the category');
    It.SetUP(DecOf('2.75'));
    It.SetIT(DecOf('27.50'));
    Output := Written(B);
    Check(Pos(TLandrixXmlUtf8('<UP>2.75</UP>'), Output) > 0, 'new unit price written');
    Check(Pos(TLandrixXmlUtf8('<IT>27.50</IT>'), Output) > 0, 'new total written');
    It.ClearUP;
    Check(not It.UP.HasValue, 'unit price cleared');
    It.SetNotOffered(True);
    Check(It.NotOffered, 'not offered set');
    B.Owner.Name1 := 'Neu';
    Check(B.Owner.Exists, 'writing a party creates it');
    CheckEqualsStr('Neu', S(B.Owner.Name1), 'party written');
  finally
    B.Free;
  end;
  B := Load(DataDir('process') + 'award.x86');
  try
    CheckEqualsStr('Auftraggeber', S(B.Owner.Name1), 'owner');
    Check(B.FindItem('02.0010', '', N) = gfrFound, 'eventual item of the award');
    Check((N as TLandrixGaebItem).CountStatus = gcsNotCounted, 'eventual item without total, award');
  finally
    B.Free;
  end;
end;

procedure TestAmbiguous;
var
  B: TLandrixGaebBillOfQuantities;
  N: TLandrixGaebNode;
begin
  B := Load(DataDir('rules') + 'GAEB-BR-OZ-001' + PathDelim + 'invalid-1.x83');
  try
    Check(B.AllItems.Count >= 2, 'items');
    Check(B.FindItem(B.AllItems[0].OZ, B.AllItems[0].RNoIndex, N) = gfrAmbiguous, 'duplicate OZ is ambiguous');
    Check(N = B.AllItems[0], 'the first of them');
  finally
    B.Free;
  end;
end;

procedure TestComplements;
var
  B: TLandrixGaebBillOfQuantities;
  N: TLandrixGaebNode;
  K: Integer;
  Output: TLandrixXmlUtf8;
  Raised: Boolean;
begin
  B := Load(DataDir('legacy') + '29-complements.x83');
  try
    N := B.AllItems[0];
    CheckEquals(4, N.ComplementCount, 'complements of long and outline text');
    CheckEqualsStr('1', S(N.Complements(0).MarkLbl), 'first number');
    Check(N.Complements(0).Kind = gckOwner, 'owner complement');
    CheckEqualsStr('Fabrikat', S(N.Complements(0).CaptionText), 'caption');
    CheckEqualsStr('Typ A', S(N.Complements(0).BodyText), 'body');
    CheckEqualsStr('oder gleichwertig', S(N.Complements(0).TailText), 'tail');
    Check(N.Complements(1).Kind = gckBidder, 'bidder complement');
    Check(N.Complements(1).IsEmptyMarked, 'empty mark');
    Check(N.Complements(2).WantsDecimal, 'decimal body');
    Check(N.Complements(3).WantsInteger, 'integer body');
    Check(Pos(TLandrixGaebString('[1: Typ A]'), N.LongText) > 0, 'complement inline in the plain long text');
    Raised := False;
    try
      N.Complements(0).SetBodyText('anders');
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'an owner complement is not filled in');
    Raised := False;
    try
      N.Complements(2).SetBodyText('12');
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'a decimal complement takes SetBodyNumber');
    Raised := False;
    try
      N.Complements(3).SetBodyNumber('x');
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'no integer');
    N.Complements(2).SetBodyNumber('12.5');
    N.Complements(3).SetBodyNumber('7');
    CheckEqualsStr('12.5', S(N.Complements(2).BodyText), 'decimal repeated as body text');
    N.Complements(1).SetBodyText('Fabrikat X');
    Check(not N.Complements(1).IsEmptyMarked, 'empty mark removed');
    CheckEqualsStr('Fabrikat X', S(N.Complements(1).BodyText), 'body set');
    Output := Written(B);
    Check(Pos(TLandrixXmlUtf8('Fabrikat X'), Output) > 0, 'body written');
    Check(Pos(TLandrixXmlUtf8('<ComplBodyDec Value="12.5"/>'), Output) > 0, 'decimal written');
    Check(Pos(TLandrixXmlUtf8('<ComplBodyInt Value="7"/>'), Output) > 0, 'integer written');
    K := Pos(TLandrixXmlUtf8('MarkLbl="2"'), Output);
    Check((K > 0) and (Pos(TLandrixXmlUtf8('Empty='), Copy(Output, K, 60)) = 0), 'no Empty on complement 2');
  finally
    B.Free;
  end;
end;

procedure TestPlainText;
var
  B: TLandrixGaebBillOfQuantities;
  T: TLandrixGaebString;
begin
  B := Load(DataDir('legacy') + '30-format.x83');
  try
    T := B.AllItems[0].LongText;
    Check(Pos(TLandrixGaebString('Spalte' + #10 + 'Zelle'), T) > 0, 'table rows on lines of their own');
    Check(Pos(TLandrixGaebString(#10), T) > 0, 'lines');
    Check((T <> '') and (T[Length(T)] <> #10), 'no trailing line feed');
    Check(Pos(TLandrixGaebString('Spalte'), T) > 1, 'table after text');
    Check(T[Pos(TLandrixGaebString('Spalte'), T) - 1] = #10, 'a table row starts on a new line');
  finally
    B.Free;
  end;
end;

{ ---- legacy case 36: what the old adapters dropped ---- }

function ItemAt(ABill: TLandrixGaebBillOfQuantities; const AOZ: string): TLandrixGaebItem;
var
  N: TLandrixGaebNode;
begin
  Result := nil;
  if ABill.FindItem(TLandrixGaebString(AOZ), '', N) = gfrFound then
    Result := N as TLandrixGaebItem;
  Check(Result <> nil, 'item ' + AOZ);
end;

procedure TestLosses;
var
  B: TLandrixGaebBillOfQuantities;
  Lot: TLandrixGaebCategory;
  It: TLandrixGaebItem;
  R: TLandrixGaebReference;
  G: TLandrixGaebLotGroup;
  Bk: TLandrixGaebBreakdown;
  Sub: TLandrixGaebSubDescription;
  Cat: TLandrixGaebCatalogRef;
begin
  B := Load(DataDir('legacy') + '36-losses.x86');
  try
    { parties, award data, currency }
    CheckEqualsStr('Auftraggeber', S(B.Owner.Name1), 'owner');
    CheckEqualsStr('Auftragnehmer', S(B.Contractor.Name1), 'contractor');
    CheckEquals(1, B.RequesterCount, 'one requester');
    Check(B.Requesters(0).Role = gprRequester, 'role of the requester');
    Check(B.Requesters(0).Exists, 'requester with address');
    CheckEqualsStr('Bedarfstraeger', S(B.Requesters(0).Name1), 'requester address');
    CheckEqualsStr('Bedarfsstelle', S(B.Requesters(0).RequestName), 'requester name');
    CheckEqualsStr('', S(B.Owner.RequestName), 'no request name of the owner');
    CheckEqualsStr('EUR', S(B.Currency), 'currency');
    CheckEqualsStr('V-1', S(B.ContractNo), 'contract number');
    CheckEqualsStr('2026-11-01', S(B.ContractDate), 'contract date');
    CheckEqualsStr('2027-01-04', S(B.ConstructionStart), 'start of construction');
    CheckEqualsStr('2027-06-30', S(B.ConstructionEnd), 'end of construction');
    CheckEqualsStr('', S(B.BidDate), 'no bid date');
    { lots, lot groups, breakdown }
    CheckEquals(3, B.BreakdownCount, 'three breakdown levels');
    Bk := B.Breakdowns(0);
    Check(Bk.Kind = gbkLot, 'first level is the lot');
    CheckEquals(1, Bk.Length, 'length of the lot');
    Bk := B.Breakdowns(1);
    Check((Bk.Kind = gbkLevel) and Bk.Numeric, 'numeric category level');
    CheckEqualsStr('Titel', S(Bk.Lbl), 'label of the level');
    CheckEquals(2, Bk.Length, 'length of the level');
    Check(B.Breakdowns(2).Kind = gbkItem, 'item level');
    Check(B.HasLots, 'bill with lots');
    CheckEquals(2, B.Root.Count, 'two lots');
    Lot := B.Root[0] as TLandrixGaebCategory;
    Check(Lot.IsLot, 'top level category is a lot');
    Check(not (Lot.Children[1] as TLandrixGaebCategory).IsLot, 'a category in a lot is no lot');
    CheckEqualsStr('Los eins', S(Lot.Lbl), 'label of the lot');
    CheckEquals(1, B.LotGroupCount, 'one lot group');
    G := B.LotGroups(0);
    CheckEqualsStr('1', S(G.Number), 'number of the lot group');
    CheckEquals(2, G.LotCount, 'lots of the group');
    R := G.Lots(1);
    Check((R.Status = grsResolved) and (R.Node = B.Root[1]), 'second lot resolved');
    CheckEqualsStr('L2', S(R.IDRef), 'IDRef of the lot');
    CheckEqualsStr('69.00', DecText(G.Totals.Amount), 'total of the lot group');
    { alternatives, change orders, variant bids }
    It := ItemAt(B, '1.01.0010');
    Check(It.IsBase and (It.AlternativeGroup = '1'), 'base item with its group');
    Check(ItemAt(B, '1.01.0020').IsAlternative, 'alternative item');
    It := ItemAt(B, '1.01.0060');
    CheckEqualsStr('1', S(It.ChangeOrderNo), 'change order number');
    CheckEqualsStr('Approved', S(It.ChangeOrderStatus), 'change order status');
    CheckEqualsStr('New', S(It.AlterBidStatus), 'status in the variant bid');
    { references }
    It := ItemAt(B, '1.01.0030');
    Check(It.DescriptionRole = gdrReference, 'reference description');
    It := ItemAt(B, '1.01.0040');
    Check(It.DescriptionRole = gdrRepetition, 'repetition description');
    R := It.RefRNo;
    Check((R.Status = grsResolved) and (R.Node = ItemAt(B, '1.01.0030')), 'repetition refers to its reference');
    CheckEqualsStr('I3', S(R.IDRef), 'raw IDRef');
    Check(It.RefPerfNo.Status = grsAbsent, 'no execution description');
    R := ItemAt(B, '1.01.0050').RefPerfNo;
    Check((R.Status = grsResolved) and (R.Node.Kind = gnkPerfDescr), 'execution description resolved');
    CheckEqualsStr('1', S((R.Node as TLandrixGaebPerfDescr).PerfNo), 'number of the execution description');
    R := ItemAt(B, '1.01.0070').RefRNo;
    Check((R.Status = grsWrongKind) and (R.Node = nil), 'RefRNo to an execution description has the wrong kind');
    It := ItemAt(B, '1.01.0080');
    CheckEqualsStr('ExtUseItem', S(It.HoldOutType), 'hold-out item');
    CheckEquals(2, It.RefBaseItemCount, 'two base item references');
    R := It.RefBaseItem(0);
    Check((R.Status = grsResolved) and (R.Node = ItemAt(B, '1.01.0010')), 'base item resolved');
    Check(It.RefBaseItem(1).Status = grsWrongKind, 'base item reference to a category');
    It := ItemAt(B, '1.01.0010');
    Check(It.RefRNo.Status = grsAbsent, 'no reference');
    { complements, sub descriptions with quantity, partial quantities }
    CheckEquals(1, It.ComplementCount, 'complement of the item');
    CheckEqualsStr('1', S(It.Complements(0).MarkLbl), 'number of the complement');
    CheckEquals(2, It.QtySplitCount, 'partial quantities');
    CheckEqualsStr('4.000', DecText(It.QtySplits(0).Qty), 'first partial quantity');
    CheckEqualsStr('6.000', DecText(It.QtySplits(1).Qty), 'second partial quantity');
    Check(not It.QtySplits(0).QtyPcnt.HasValue, 'no percentage');
    It := ItemAt(B, '1.01.0070');
    Check(It.IsSumDescription, 'sum description');
    CheckEquals(1, It.SubDescriptionCount, 'one sub description');
    Sub := It.SubDescriptions(0);
    Check(Sub.Item = It, 'item of the sub description');
    CheckEqualsStr('1', S(Sub.Number), 'number of the sub description');
    CheckEqualsStr('2.000', DecText(Sub.Qty), 'quantity of the sub description');
    CheckEqualsStr('St', S(Sub.QU), 'unit of the sub description');
    CheckEqualsStr('0.500', DecText(Sub.UP), 'unit price of the sub description');
    CheckEqualsStr('Leistung', S(Sub.LongText), 'text of the sub description');
    Check(Copy(S(Sub.Path), Length(S(Sub.Path)) - 11, 12) = '/SubDescr[1]', 'path of the sub description');
    { unit price components and their labels; 0.00 is a value }
    It := ItemAt(B, '1.01.0010');
    CheckEqualsStr('Lohn', S(B.UPCompLabel(1)), 'label of component 1');
    CheckEqualsStr('Stoffe', S(B.UPCompLabel(2)), 'label of component 2');
    CheckEqualsStr('1.500', DecText(It.UPComp(1)), 'component 1');
    CheckEqualsStr('0.000', DecText(ItemAt(B, '1.01.0050').UP), 'zero is a value');
    { totals, discount, VAT }
    CheckEqualsStr('69.00', DecText(B.Totals.Value(gtfTotal)), 'total');
    CheckEqualsStr('1.000', DecText(B.Totals.Value(gtfDiscountPcnt)), 'discount');
    CheckEqualsStr('68.31', DecText(B.Totals.Value(gtfTotAfterDisc)), 'total after discount');
    CheckEqualsStr('19.00', DecText(B.Totals.Value(gtfVAT)), 'VAT rate');
    CheckEqualsStr('12.98', DecText(B.Totals.Value(gtfVATAmount)), 'VAT amount');
    CheckEqualsStr('81.29', DecText(B.Totals.Value(gtfTotalGross)), 'gross total');
    CheckEqualsStr('68.31', DecText(B.Total), 'the amount that counts');
    Check(not B.Totals.Value(gtfDiscountAmt).HasValue, 'no discount amount');
    CheckEqualsStr('69.00', DecText(Lot.Totals.Value(gtfTotal)), 'total of the lot');
    { catalogues; comments of the bidder }
    CheckEquals(1, It.CatalogCount, 'catalogue assignment of the item');
    Cat := It.Catalogs(0);
    Check((Cat.CatalogID = 'C1') and (Cat.Code = 'KS1'), 'catalogue and code');
    CheckEquals(1, It.BidCommentCount, 'comment of the bidder');
    CheckEqualsStr('Hinweis des Bieters', S(LandrixGaebPlainText(It.BidCommentNode(0))), 'text of the comment');
  finally
    B.Free;
  end;
end;

{ Unresolved references and the setters of totals, sub descriptions,
  requesters and award data. }
procedure TestWriteValues;
var
  B: TLandrixGaebBillOfQuantities;
  It: TLandrixGaebItem;
  C: TLandrixGaebCategory;
  Output: TLandrixXmlUtf8;
  Raised: Boolean;
  R: TLandrixGaebReference;
begin
  B := Load(DataDir('legacy') + '36-losses.x86');
  try
    It := ItemAt(B, '1.01.0010');
    TLandrixGaebXmlItem(It.SyntaxNode).RefRNo.IDRef := 'nowhere';
    Check(It.RefRNo.Status = grsNotFound, 'IDRef without element');
    Check(It.RefRNo.Node = nil, 'no node when not found');
    TLandrixGaebXmlItem(It.SyntaxNode).RefRNo.IDRef := 'B1';
    Check(It.RefRNo.Status = grsWrongKind, 'IDRef to the BoQ has the wrong kind');
    TLandrixGaebXmlItem(It.SyntaxNode).RefRNo.IDRef := 'G1';
    Check(It.RefRNo.Status = grsWrongKind, 'IDRef to a lot group has the wrong kind');
    TLandrixGaebXmlItem(It.SyntaxNode).RefRNo.IDRef := '';
    TLandrixGaebXmlItem(ItemAt(B, '1.01.0020').SyntaxNode).ID := 'I1';
    B.Refresh;
    R := ItemAt(B, '1.01.0080').RefBaseItem(0);
    Check((R.Status = grsAmbiguous) and (R.Node = nil), 'duplicate ID is ambiguous');
    TLandrixGaebXmlItem(ItemAt(B, '1.01.0020').SyntaxNode).ID := 'I2';
    B.Refresh;
    B.Totals.SetValue(gtfDiscountAmt, DecOf('0.69'));
    B.Totals.ClearValue(gtfDiscountPcnt);
    It := ItemAt(B, '1.01.0070');
    It.SubDescriptions(0).SetQty(DecOf('3.000'));
    It.SubDescriptions(0).SetUPComp(1, DecOf('0.250'));
    B.Requesters(0).RequestIDNo := 'R-7';
    B.BidDate := '2026-10-30';
    C := (B.Root[1] as TLandrixGaebCategory).Children[0] as TLandrixGaebCategory;
    C.Totals.ClearValue(gtfTotal);
    Check(C.Totals.Exists, 'clearing a value keeps the block');
    Output := Written(B);
    Check(Pos(TLandrixXmlUtf8('<DiscountAmt>0.69</DiscountAmt>'), Output) > 0, 'discount amount written');
    Check(Pos(TLandrixXmlUtf8('<DiscountPcnt>'), Output) = 0, 'discount percentage removed');
    Check(Pos(TLandrixXmlUtf8('<Qty>3.000</Qty>'), Output) > 0, 'quantity of the sub description written');
    Check(Pos(TLandrixXmlUtf8('<UPComp1>0.250</UPComp1>'), Output) > 0, 'component of the sub description written');
    Check(Pos(TLandrixXmlUtf8('<RequestIDNo>R-7</RequestIDNo>'), Output) > 0, 'requester number written');
    Check(Pos(TLandrixXmlUtf8('<BidDate>2026-10-30</BidDate>'), Output) > 0, 'bid date written');
    Raised := False;
    try
      B.Owner.RequestName := 'x';
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'only a requester has a request name');
  finally
    B.Free;
  end;
  B := Load(DataDir('process') + 'request.x83');
  try
    Check(not B.Totals.Exists, 'no totals in the request');
    Check(not B.Totals.Value(gtfTotal).HasValue, 'absent block reads no value');
    B.Totals.ClearValue(gtfTotal);
    Check(not B.Totals.Exists, 'clearing does not create the block');
    CheckEquals(0, B.RequesterCount, 'no requester');
    CheckEquals(0, B.LotGroupCount, 'no lot group');
    Check(not B.HasLots, 'no lots');
    Check(not (B.Root[0] as TLandrixGaebCategory).IsLot, 'no lot without lot level');
    B.Totals.SetValue(gtfTotal, DecOf('1.00'));
    Check(B.Totals.Exists, 'setting creates the block');
    CheckEqualsStr('1.00', DecText(B.Total), 'total set');
  finally
    B.Free;
  end;
end;

procedure TestLoadSave;
var
  B, B2: TLandrixGaebBillOfQuantities;
  FileName: string;
  Stream: TMemoryStream;
  Diags: TLandrixGaebDiagnostics;
  Options: TLandrixGaebXmlWriteOptions;
begin
  FileName := DataDir('process') + 'bid.x84';
  Diags := TLandrixGaebDiagnostics.Create;
  B := nil;
  B2 := nil;
  Stream := TMemoryStream.Create;
  try
    B := TLandrixGaebBillOfQuantities.LoadFromFile(FileName, Diags, 0);
    Check(B.Target.Phase = gp84, 'target of the file');
    CheckEquals(5, B.AllItems.Count, 'items loaded');
    ItemAt(B, '01.0010').SetUP(DecOf('2.75'));
    Options := B.WriteOptions;
    Options.Indent := False;
    B.WriteOptions := Options;
    B.SaveToStream(Stream, Diags);
    Check(Stream.Size > 0, 'written to the stream');
    Stream.Position := 0;
    B2 := TLandrixGaebBillOfQuantities.LoadFromStream(Stream, Diags, 0);
    CheckEqualsStr('2.750', DecText(ItemAt(B2, '01.0010').UP), 'value saved and loaded (digits of the schema)');
    Check(not Diags.HasErrors, 'no errors: ' + Diags.ToText);
  finally
    B2.Free;
    B.Free;
    Stream.Free;
    Diags.Free;
  end;
end;

{ ---- structure operations ---- }

function Raises(ABill: TLandrixGaebBillOfQuantities; ACase: Integer; AParent: TLandrixGaebCategory): Boolean;
begin
  Result := False;
  try
    case ACase of
      0: ABill.AddItem(AParent, '0010');
      1: ABill.AddCategory(AParent, '01', 'x');
      3: ABill.Nodes(-1);
      4: ABill.Nodes(ABill.NodeCount);
      5:
        if ABill.Root[ABill.Root.Count] <> nil then
          Exit;
    else
      ABill.Remove(nil);
    end;
  except
    on ELandrixGaebError do
      Result := True;
  end;
end;

procedure TestStructure;
var
  B: TLandrixGaebBillOfQuantities;
  C1, C3, Cat: TLandrixGaebCategory;
  It, NewIt, Last: TLandrixGaebItem;
  N: TLandrixGaebNode;
  Output: TLandrixXmlUtf8;
  Version: Integer;
begin
  B := Load(DataDir('process') + 'request.x83');
  try
    Check(Raises(B, 3, nil), 'node index below 0');
    Check(Raises(B, 4, nil), 'node index beyond the end');
    Check(Raises(B, 5, nil), 'list index beyond the end');
    C1 := B.Root[0] as TLandrixGaebCategory;
    It := C1.Children[0] as TLandrixGaebItem;
    Last := C1.Children[2] as TLandrixGaebItem;
    Version := B.StructureVersion;
    C3 := B.AddCategory(nil, '03', 'Titel drei');
    Check(B.StructureVersion <> Version, 'AddCategory changes the structure version');
    CheckEquals(3, B.Root.Count, 'category appended');
    Check(B.Root[2] = C3, 'the new category is last');
    CheckEqualsStr('03', S(C3.OZ), 'OZ of the new category');
    CheckEqualsStr('Titel drei', S(C3.Lbl), 'label of the new category');
    Check(C3.Parent = nil, 'top level');
    CheckEqualsStr('01.0010', S(It.OZ), 'earlier views stay valid');
    Check(C1.Children[0] = It, 'children keep their views');
    NewIt := B.AddItem(C3, '0010');
    NewIt.SetQty(DecOf('5.000'));
    NewIt.QU := 'St';
    CheckEqualsStr('03.0010', S(NewIt.OZ), 'OZ of the new item');
    Check(NewIt.Parent = C3, 'parent of the new item');
    CheckEquals(1, C3.Children.Count, 'item in the new category');
    CheckEquals(6, B.AllItems.Count, 'item counted');
    Check(B.FindItem('3.10', '', N) = gfrFound, 'new item found');
    Check(N = NewIt, 'the new item');
    Check(TLandrixGaebXmlItem(NewIt.SyntaxNode).ID <> TLandrixGaebXmlItem(It.SyntaxNode).ID, 'new ID');
    Check(B.FindCategory('03', Cat) = gfrFound, 'new category found');
    Check(Cat = C3, 'the new category');
    Check(Raises(B, 0, nil), 'no item beside categories');
    Check(Raises(B, 1, C3), 'no category beside items');
    Check(Raises(B, 2, nil), 'no node to remove');
    Output := Written(B);
    Check(Pos(TLandrixXmlUtf8('RNoPart="03"'), Output) > 0, 'new category written');
    Check(Pos(TLandrixXmlUtf8('<Qty>5.000</Qty>'), Output) > 0, 'new item written');
    Version := B.StructureVersion;
    B.Remove(It);
    Check(B.StructureVersion <> Version, 'Remove changes the structure version');
    CheckEquals(2, C1.Children.Count, 'item removed from its category');
    CheckEquals(5, B.AllItems.Count, 'item removed from the bill');
    Check(B.FindItem('01.0010', '', N) = gfrNotFound, 'removed item not found');
    Check(C1.Children[1] = Last, 'other items keep their views');
    Output := Written(B);
    Check(Pos(TLandrixXmlUtf8('Leistung eins'), Output) = 0, 'removed item not written');
    B.Remove(C3);
    CheckEquals(2, B.Root.Count, 'category removed');
    CheckEquals(4, B.AllItems.Count, 'its items removed');
    Check(B.FindItem('03.0010', '', N) = gfrNotFound, 'item of the removed category not found');
    CheckEqualsStr('01.0030', S(Last.OZ), 'remaining view still valid');
    C3 := B.AddCategory(nil, '04', 'Titel vier');
    B.Remove(B.AddItem(C3, '0010'));
    CheckEquals(0, C3.Children.Count, 'last item removed');
    Check(Raises(B, 1, C3), 'the emptied item list stays: still no category beside it');
  finally
    B.Free;
  end;
end;

{ Errors when writing ABill with the default options (output checked). }
function WriteErrors(ABill: TLandrixGaebBillOfQuantities): Integer;
var
  E, W: Integer;
begin
  LandrixGaebXmlWriteCollect(ABill.Document, ABill.OutputTarget, LandrixGaebXmlDefaultWriteOptions,
    nil, E, W);
  Result := E;
end;

procedure TestTexts;
var
  B: TLandrixGaebBillOfQuantities;
  It, NewIt: TLandrixGaebItem;
  Output: TLandrixXmlUtf8;
begin
  B := Load(DataDir('process') + 'request.x83');
  try
    It := B.AllItems[0] as TLandrixGaebItem;
    It.SetShortText('Neuer Kurztext');
    CheckEqualsStr('Neuer Kurztext', S(It.ShortText), 'short text replaced');
    It.SetLongText('Zeile eins' + #13#10 + 'Zeile zwei');
    CheckEqualsStr('Zeile eins' + #10 + 'Zeile zwei', S(It.LongText), 'one paragraph per line');
    NewIt := B.AddItem(B.Root[0] as TLandrixGaebCategory, '0040');
    NewIt.SetQty(DecOf('1.000'));
    NewIt.QU := 'St';
    Check(NewIt.ShortText = '', 'a new item has no short text');
    NewIt.SetShortText('Kurz');
    NewIt.SetLongText('Lang');
    CheckEqualsStr('Kurz', S(NewIt.ShortText), 'short text created');
    CheckEqualsStr('Lang', S(NewIt.LongText), 'long text created');
    CheckEquals(0, WriteErrors(B), 'texts written and checked');
    Output := Written(B);
    Check(Pos(TLandrixXmlUtf8('Neuer Kurztext'), Output) > 0, 'short text written');
    Check(Pos(TLandrixXmlUtf8('<p><span>Zeile zwei</span></p>'), Output) > 0, 'paragraph written');
    Check(Pos(TLandrixXmlUtf8('Leistung eins'), Output) = 0, 'old text gone');
    NewIt.SetLongText('eins' + #10 + #10 + 'drei');
    CheckEqualsStr('eins' + #10 + 'drei', S(NewIt.LongText), 'the plain text skips empty paragraphs');
    CheckEquals(0, WriteErrors(B), 'empty paragraph written and checked');
    Check(Pos(TLandrixXmlUtf8('<p/>'), Written(B)) > 0, 'empty paragraph written');
    NewIt.SetLongText('');
    Check(NewIt.LongText = '', 'long text removed');
    Check(NewIt.DetailTextNode = nil, 'no detail text left');
    CheckEqualsStr('Kurz', S(NewIt.ShortText), 'short text kept');
    NewIt.SetShortText('');
    Check(NewIt.OutlineTextNode = nil, 'no outline text left');
    Check(not TLandrixGaebXmlItem(NewIt.SyntaxNode).HasDescription, 'empty description dropped');
    TLandrixGaebXmlItem(NewIt.SyntaxNode).Description.CompleteText.Present := True;
    NewIt.SetLongText('');
    Check(not TLandrixGaebXmlItem(NewIt.SyntaxNode).HasDescription, 'an empty marked container dropped too');
    NewIt.SetLongText('ende' + #13);
    CheckEqualsStr('ende' + #13, S(NewIt.LongText), 'a CR without LF stays');
  finally
    B.Free;
  end;
  B := Load(DataDir('legacy') + '29-complements.x83');
  try
    It := B.AllItems[0] as TLandrixGaebItem;
    CheckEquals(4, It.ComplementCount, 'complements before');
    It.SetLongText('ohne Ergaenzung');
    Check(It.ComplementCount < 4, 'complements of the long text gone');
    It.SetShortText('kurz');
    CheckEquals(0, It.ComplementCount, 'no complement left');
  finally
    B.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('BoQ.ReadOnly', TestReadOnly);
  RegisterTest('BoQ.Tree', TestTree);
  RegisterTest('BoQ.BidAndAward', TestBidAndAward);
  RegisterTest('BoQ.Ambiguous', TestAmbiguous);
  RegisterTest('BoQ.Complements', TestComplements);
  RegisterTest('BoQ.PlainText', TestPlainText);
  RegisterTest('BoQ.Losses', TestLosses);
  RegisterTest('BoQ.WriteValues', TestWriteValues);
  RegisterTest('BoQ.LoadSave', TestLoadSave);
  RegisterTest('BoQ.Structure', TestStructure);
  RegisterTest('BoQ.Texts', TestTexts);
end;

end.

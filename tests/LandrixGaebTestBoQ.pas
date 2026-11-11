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
  of the process documents, setters, text complements and the plain
  text. }

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
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebXmlWriteBase,
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
  Result := WrittenDoc(ABill.Document, ABill.Target);
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

procedure ReadNode(N: TLandrixGaebNode; V: TCountVisitor);
var
  K: Integer;
  Found: TLandrixGaebNode;
  Dummy: TLandrixGaebString;
  D: TLandrixGaebDecimal;
begin
  Dummy := N.OZ + N.Index + N.Path + N.ShortText + N.LongText;
  LandrixGaebVisitText(N.DetailTextNode, V);
  LandrixGaebVisitText(N.OutlineTextNode, V);
  for K := 0 to N.ComplementCount - 1 do
    Dummy := N.Complements(K).CaptionText + N.Complements(K).BodyText + N.Complements(K).TailText +
      N.Complements(K).MarkLbl;
  case N.Kind of
    gnkCategory:
      begin
        N.Bill.FindByOZ(N.OZ, '', True, Found);
        Dummy := TLandrixGaebCategory(N).Lbl + TLandrixGaebCategory(N).Accepted;
        D := TLandrixGaebCategory(N).Total;
        TLandrixGaebCategory(N).CountStatus;
        for K := 0 to TLandrixGaebCategory(N).Children.Count - 1 do
          ReadNode(TLandrixGaebCategory(N).Children[K], V);
      end;
    gnkItem:
      begin
        N.Bill.FindByOZ(N.OZ, N.Index, False, Found);
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
      end;
    gnkMarkupItem:
      begin
        N.Bill.FindByOZ(N.OZ, N.Index, False, Found);
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
  I: Integer;
  V: TCountVisitor;
  Dummy: TLandrixGaebString;
  D: TLandrixGaebDecimal;
begin
  Dummy := ABill.ProjectName + ABill.BoQName + ABill.Currency + ABill.UPCompLabel(1);
  Dummy := Dummy + ABill.Owner.Name1 + ABill.Owner.Email + ABill.Contractor.City + ABill.Contractor.VATID;
  ABill.Owner.Exists;
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
  C: TLandrixGaebCategory;
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
    Check(B.FindByOZ('01.0010', '', False, N) = gfrFound, 'item found');
    Check(N = C.Children[0], 'the first item');
    Check(B.FindByOZ('1.10', '', False, N) = gfrFound, 'numeric parts by value');
    Check(B.FindByOZ('01', '', True, N) = gfrFound, 'category found');
    Check(N = C, 'the first category');
    Check(B.FindByOZ('01', '', False, N) = gfrNotFound, 'a category is no item');
    Check(B.FindByOZ('03.0010', '', False, N) = gfrNotFound, 'not found');
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
begin
  B := Load(DataDir('process') + 'bid.x84');
  try
    CheckEqualsStr('Bieter', S(B.Contractor.Name1), 'contractor');
    CheckEqualsStr('365.00', DecText(B.Total), 'total of the bill');
    Check(B.FindByOZ('01.0010', '', False, N) = gfrFound, 'item of the bid');
    It := N as TLandrixGaebItem;
    CheckEqualsStr('2.50', DecText(It.UP), 'unit price');
    Check(It.CountStatus = gcsUnknown, 'a bid does not carry the kinds of the request');
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
    Check(B.FindByOZ('02.0010', '', False, N) = gfrFound, 'eventual item of the award');
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
    Check(B.FindByOZ(B.AllItems[0].OZ, B.AllItems[0].Index, False, N) = gfrAmbiguous, 'duplicate OZ is ambiguous');
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

procedure Register;
begin
  RegisterTest('BoQ.ReadOnly', TestReadOnly);
  RegisterTest('BoQ.Tree', TestTree);
  RegisterTest('BoQ.BidAndAward', TestBidAndAward);
  RegisterTest('BoQ.Ambiguous', TestAmbiguous);
  RegisterTest('BoQ.Complements', TestComplements);
  RegisterTest('BoQ.PlainText', TestPlainText);
end;

end.

{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Creates a new bill of quantities and writes it as a request (X83, GAEB DA
  XML 3.3): the document frame through the syntax model, categories, items,
  quantities and units through the business facade, texts through the
  syntax model. The writer checks the output against the schema of the
  target and refuses an invalid document.

  Usage: WriteBoQ <output folder>       writes <output folder>/request.x83 }

program WriteBoQ;

{$I LandrixGaeb.inc}

{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
{$IFDEF FPC}
  {$IFDEF UNIX}
  { converts between UTF-8 and the native string on Unix (output of texts) }
  cwstring,
  {$ENDIF}
{$ENDIF}
  SysUtils,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebXmlModel,
  LandrixGaebBoQ;

function Dec(const AText: string): TLandrixGaebDecimal;
begin
  Result.Clear;
  if not Result.TrySetText(LandrixXmlStringToUtf8(AText)) then
    raise Exception.Create('not a decimal: ' + AText);
end;

{ The short text (outline text) and the long text (detail text) of an item,
  each one paragraph. }
procedure SetTexts(AItem: TLandrixGaebItem; const AShort, ALong: TLandrixGaebString);
var
  Text: TLandrixGaebXmlCompleteText;
begin
  Text := TLandrixGaebXmlItem(AItem.SyntaxNode).Description.CompleteText;
  Text.DetailTxt.AddText.AddP.AddSpan.Value := ALong;
  Text.OutlineText.OutlTxt.AddTextOutlTxt.AddP.AddSpan.Value := AShort;
end;

{ A breakdown level of the ordinal number (OZ). }
procedure AddLevel(AInfo: TLandrixGaebXmlBoQInfo; const AType, ALabel: TLandrixGaebString; ALength: Integer);
var
  Level: TLandrixGaebXmlBoQBkdn;
begin
  Level := AInfo.BoQBkdn.Add;
  Level.TypeElement := AType;
  Level.LblBoQBkdn := ALabel;
  Level.LengthElement := TLandrixGaebString(IntToStr(ALength));
  Level.Num := 'Yes';
end;

procedure Run(const AFolder: string);
var
  Doc: TLandrixGaebXmlGAEB;
  Bill: TLandrixGaebBillOfQuantities;
  Category: TLandrixGaebCategory;
  Item: TLandrixGaebItem;
  Diags: TLandrixGaebDiagnostics;
  FileName: string;
begin
  { The frame: version, edition and DP are written from the target. }
  Doc := TLandrixGaebXmlGAEB.Create;
  try
    Doc.GAEBInfo.Date := TLandrixGaebString(FormatDateTime('yyyy"-"mm"-"dd', Date));
    Doc.GAEBInfo.ProgSystem := 'GAEB-for-Pascal example';
    Doc.PrjInfo.NamePrj := 'Example';
    Doc.PrjInfo.LblPrj := 'Example project';
    Doc.Award.BoQ.ID := 'BoQ1';
    Doc.Award.BoQ.BoQInfo.Name := 'LV';
    Doc.Award.BoQ.BoQInfo.LblBoQ := 'Example bill of quantities';
    { the texts this document carries: short and long texts }
    Doc.Award.BoQ.BoQInfo.OutlCompl := 'AllTxt';
    AddLevel(Doc.Award.BoQ.BoQInfo, 'BoQLevel', 'Title', 2);
    AddLevel(Doc.Award.BoQ.BoQInfo, 'Item', '', 4);
  except
    Doc.Free;
    raise;
  end;

  { The bill owns the document from here on (also if its constructor
    fails). }
  Bill := TLandrixGaebBillOfQuantities.Create(Doc, LandrixGaebTarget(gv33, ge2021_05, gp83), True);
  Diags := nil;
  try
    Diags := TLandrixGaebDiagnostics.Create;
    Category := Bill.AddCategory(nil, '01', 'Earthwork');
    Item := Bill.AddItem(Category, '0010');
    Item.SetQty(Dec('125.500'));
    Item.QU := 'm3';
    SetTexts(Item, 'Excavate soil', 'Excavate soil of classes 3 to 5 and store it beside the trench.');
    Item := Bill.AddItem(Category, '0020');
    Item.SetQty(Dec('40.000'));
    Item.QU := 'm3';
    SetTexts(Item, 'Backfill', 'Backfill the trench with the stored soil and compact it in layers.');

    Category := Bill.AddCategory(nil, '02', 'Concrete');
    Item := Bill.AddItem(Category, '0010');
    Item.SetQty(Dec('12.000'));
    Item.QU := 'm3';
    SetTexts(Item, 'Foundation C25/30', 'Strip foundation of concrete C25/30, including formwork.');

    FileName := IncludeTrailingPathDelimiter(AFolder) + 'request.x83';
    try
      Bill.SaveToFile(FileName, Diags);
      WriteLn('written: ', FileName, ' (', Bill.AllItems.Count, ' items)');
    finally
      { the findings of the writer, also when it refused the document }
      Write(Diags.ToText);
    end;
  finally
    Diags.Free;
    Bill.Free;
  end;
end;

begin
  if ParamCount <> 1 then
  begin
    WriteLn('Usage: WriteBoQ <output folder>');
    ExitCode := 2;
    Exit;
  end;
  try
    Run(ParamStr(1));
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

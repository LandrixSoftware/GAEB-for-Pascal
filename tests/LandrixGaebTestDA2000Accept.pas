{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Semantic acceptance of the GAEB DA 2000 reader (plan, phase 7): the model
  read from the .P83 of the local multi-format bill equals the model read
  from its .X83 (written by the GAEB Toolbox), compared with
  CompareGaebModelsAccept (IDs and text formatting are not compared), up
  to the documented differences below. Prints paths and counts, never
  values. }

unit LandrixGaebTestDA2000Accept;

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
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebBoQ,
  LandrixGaebTestXmlCompare,
  LandrixGaebTestFramework;

const
  { Differences between the two models that are expected (paths without
    indexes):
    - BoQInfo/Totals: the P83 holds the total of the bill; X83 has none,
      so the X83 lacks it. The model keeps it, the writer leaves it out for
      X83 (GAEB-WRT-001).
    - Item/LumpSumItem: GAEB DA 2000 marks a lump sum item by the unit
      psch, which the reader maps to LumpSumItem; the X83 keeps the unit
      without the flag. }
  Documented: array[0..1] of string = (
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

{ Clears what describes the file, not the bill: version, program and time
  of creation. }
procedure Neutral(ADoc: TLandrixGaebXmlGAEB);
begin
  ADoc.GAEBInfo.Version := '';
  ADoc.GAEBInfo.VersDate := '';
  ADoc.GAEBInfo.Date := '';
  ADoc.GAEBInfo.Time := '';
  ADoc.GAEBInfo.ProgSystem := '';
  ADoc.GAEBInfo.ProgName := '';
end;

function ReadXml(const ABoQ, AItem, AText: AnsiString): TLandrixGaebXmlGAEB;
var
  S: AnsiString;
  Det: TLandrixGaebDetection;
begin
  S := '<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA83/3.3"><GAEBInfo><Version>3.3</Version>' +
    '<VersDate>2021-05</VersDate></GAEBInfo><Award><DP>83</DP><BoQ ID="' + ABoQ +
    '"><BoQBody><Itemlist><Item ID="' + AItem + '" RNoPart="0010"><Qty>1.000</Qty><QU>m</QU>' +
    '<Description><CompleteText><DetailTxt>' + AText + '</DetailTxt></CompleteText></Description>' +
    '</Item></Itemlist></BoQBody></BoQ></Award></GAEB>';
  Result := LandrixGaebXmlReadBuffer(Pointer(S), Length(S), nil, Det);
end;

{ Two documents that differ in IDs, text formatting (spans, line breaks or
  paragraphs, spaces at line ends, empty lines) and the mark Empty of a
  complement are equal for the acceptance; a different caption is not. }
procedure TestCompareAccept;
const
  TextA = '<Text><p><span>Liefern und</span><br/><span>einbauen  </span></p><p><span></span></p></Text>' +
    '<TextComplement Kind="Bidder" MarkLbl="01"><ComplCaption><p><span>Fabrikat: </span></p>' +
    '</ComplCaption><ComplBody/></TextComplement>';
  TextB = '<Text><p><span style="font-weight:bold">Liefern</span><span> und</span></p><p>' +
    '<span>einbauen</span></p></Text><TextComplement Kind="Bidder" MarkLbl="01" Empty="Yes">' +
    '<ComplCaption><p><span>Fabrikat:</span></p></ComplCaption><ComplBody><p><span></span></p>' +
    '</ComplBody></TextComplement>';
  TextC = '<Text><p><span>Liefern und</span><br/><span>einbauen</span></p></Text>' +
    '<TextComplement Kind="Bidder" MarkLbl="01"><ComplCaption><p><span>Farbe: </span></p>' +
    '</ComplCaption><ComplBody/></TextComplement>';
  { the text of the caption moved into the body }
  TextD = '<Text><p><span>Liefern und</span><br/><span>einbauen</span></p></Text>' +
    '<TextComplement Kind="Bidder" MarkLbl="01"><ComplCaption><p><span>Fabrikat:</span></p>' +
    '</ComplCaption><ComplBody><p><span>|x</span></p></ComplBody></TextComplement>';
  TextE = '<Text><p><span>Liefern und</span><br/><span>einbauen</span></p></Text>' +
    '<TextComplement Kind="Bidder" MarkLbl="01"><ComplCaption><p><span>Fabrikat:|</span></p>' +
    '</ComplCaption><ComplBody><p><span>x</span></p></ComplBody></TextComplement>';
  { the same text with a picture }
  TextF = TextA + '<Text><p><image>AAAA</image></p></Text>';
  { the same picture in a list }
  TextN = TextA + '<Text><ul><li><p><image>AAAA</image></p></li></ul></Text>';
  { numeric bodies }
  TextG = '<Text><p><span>Anzahl</span></p></Text><TextComplement Kind="Bidder" MarkLbl="01">' +
    '<ComplBodyInt Value="1"/></TextComplement>';
  TextH = '<Text><p><span>Anzahl</span></p></Text><TextComplement Kind="Bidder" MarkLbl="01">' +
    '<ComplBodyInt Value="2"/></TextComplement>';
  TextM = '<Text><p><span>Anzahl</span></p></Text><TextComplement Kind="Bidder" MarkLbl="01">' +
    '<ComplBodyDec Value="1"/></TextComplement>';
  { what a complement holds stays its own }
  TextI = '<TextComplement Kind="Bidder" MarkLbl="01"><ComplBody><p><span>a</span></p></ComplBody>' +
    '<CtlgAssign><CtlgID>C</CtlgID><CtlgCode>X</CtlgCode></CtlgAssign></TextComplement>' +
    '<TextComplement Kind="Bidder" MarkLbl="02"><ComplBody><p><span>b</span></p></ComplBody></TextComplement>';
  TextJ = '<TextComplement Kind="Bidder" MarkLbl="01"><ComplBody><p><span>a</span></p></ComplBody>' +
    '</TextComplement><TextComplement Kind="Bidder" MarkLbl="02"><ComplBody><p><span>b</span></p>' +
    '</ComplBody><CtlgAssign><CtlgID>C</CtlgID><CtlgCode>X</CtlgCode></CtlgAssign></TextComplement>';
  { style sheets are formatting }
  TextK = '<Style type="text/css">p { color: red; }</Style><Text><p><span>a</span></p></Text>';
  TextL = '<Style type="text/css">p { color: blue; }</Style><Text><p><span>a</span></p></Text>';

  procedure Expect(const AText1, AText2: AnsiString; ACount: Integer; const AMsg: string);
  var
    X, Y: TLandrixGaebXmlGAEB;
    L: TStringList;
  begin
    L := TStringList.Create;
    X := ReadXml('B1', 'I1', AText1);
    Y := ReadXml('B1', 'I1', AText2);
    try
      CompareGaebModelsAccept(X, Y, L);
      CheckEquals(ACount, L.Count, AMsg + ': ' + L.Text);
    finally
      Y.Free;
      X.Free;
      L.Free;
    end;
  end;

var
  A, B, C, D, E, F: TLandrixGaebXmlGAEB;
  Diffs: TStringList;
begin
  Diffs := TStringList.Create;
  A := ReadXml('B1', 'I1', TextA);
  B := ReadXml('X', 'Y', TextB);
  C := ReadXml('B1', 'I1', TextC);
  D := ReadXml('B1', 'I1', TextD);
  E := ReadXml('B1', 'I1', TextE);
  F := ReadXml('B1', 'I1', TextF);
  try
    CompareGaebModelsAccept(A, B, Diffs);
    CheckEquals(0, Diffs.Count, 'equal for the acceptance: ' + Diffs.Text);
    Diffs.Clear;
    CompareGaebModels(A, B, Diffs);
    Check(Diffs.Count > 0, 'not equal for the strict comparison');
    Diffs.Clear;
    CompareGaebModelsAccept(A, C, Diffs);
    CheckEquals(1, Diffs.Count, 'another caption');
    if Diffs.Count = 1 then
      CheckEqualsStr('/GAEB/Award/BoQ/BoQBody/Itemlist/Item[1]/Description/CompleteText/DetailTxt (plain text)',
        Diffs[0], 'the text container is named');
    Diffs.Clear;
    CompareGaebModelsAccept(D, E, Diffs);
    CheckEquals(1, Diffs.Count, 'caption and body are kept apart');
    Diffs.Clear;
    CompareGaebModelsAccept(A, F, Diffs);
    { the picture shows in the plain text and, with its data, in the other
      content }
    CheckEquals(2, Diffs.Count, 'a picture more: ' + Diffs.Text);
    Check(Pos('(other content)', Diffs.Text) > 0, 'its data compared: ' + Diffs.Text);
    Expect(TextF, TextN, 0, 'a picture in a list: layout');
    Expect(TextG, TextH, 1, 'numeric body');
    Expect(TextG, TextM, 1, 'whole number or decimal');
    Expect(TextI, TextJ, 1, 'catalogue assignment moved to another complement');
    Expect(TextK, TextL, 0, 'style sheet');
  finally
    F.Free;
    E.Free;
    D.Free;
    C.Free;
    B.Free;
    A.Free;
    Diffs.Free;
  end;
end;

{ The pair X83/P83 in the local folder gaeb-multiformat (any name). }
function FindPair(out AXml, ADA2000: string): Boolean;
var
  SR: TSearchRec;
  Dir: string;
begin
  Result := False;
  Dir := LocalDataDir + 'gaeb-multiformat' + PathDelim;
  if FindFirst(Dir + '*.X83', faAnyFile, SR) <> 0 then
    Exit;
  try
    AXml := Dir + SR.Name;
  finally
    FindClose(SR);
  end;
  ADA2000 := ChangeFileExt(AXml, '.P83');
  Result := FileExists(ADA2000);
end;

procedure TestLocalAccept;
var
  XmlName, DAName: string;
  Diags: TLandrixGaebDiagnostics;
  X, P: TLandrixGaebBillOfQuantities;
  Diffs, Paths: TStringList;
  Counts: array of Integer;
  I, K, Known: Integer;
  Key: string;
begin
  if not FindPair(XmlName, DAName) then
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
    Check(P.SourceFormat = gfDA2000, 'the P83 is read as GAEB DA 2000');
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
    WriteLn('  Local.DA2000Accept: P83 against X83: ', Diffs.Count, ' difference(s), ', Known,
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
  RegisterTest('DA2000Accept.CompareAccept', TestCompareAccept);
  RegisterTest('Local.DA2000Accept', TestLocalAccept);
end;

end.

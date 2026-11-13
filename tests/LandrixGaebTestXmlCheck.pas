{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of the content model check (LandrixGaebXmlCheck): one negative case
  per rule, ID/IDREF, model check, the check in the writer, conversion
  between 3.2 and 3.3, and the local corpus (skipped when missing; prints
  counts only, never file content). }

unit LandrixGaebTestXmlCheck;

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
  LandrixGaebXmlCheck,
  LandrixGaebTestFramework;

const
  CRLF = #13#10;
  Desc =
    '<Description><CompleteText><DetailTxt><Text><p><span>a</span></p></Text></DetailTxt>' +
    '<OutlineText><OutlTxt><TextOutlTxt><p><span>b</span></p></TextOutlTxt></OutlTxt>' +
    '</OutlineText></CompleteText></Description>';
  ItemPath = '/GAEB[1]/Award[1]/BoQ[1]/BoQBody[1]/Itemlist[1]/Item[1]';

function DocIn(const ANamespace, AVersion, AVersDate, AItems: TLandrixXmlUtf8): TLandrixXmlUtf8;
begin
  Result := '<?xml version="1.0" encoding="UTF-8"?>' + CRLF +
    '<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/' + ANamespace + '">' + CRLF +
    '  <GAEBInfo><Version>' + AVersion + '</Version><VersDate>' + AVersDate + '</VersDate>' +
    '<Date>2026-10-21</Date><ProgSystem>Test</ProgSystem></GAEBInfo>' + CRLF +
    '  <PrjInfo><NamePrj>P</NamePrj></PrjInfo>' + CRLF +
    '  <Award><DP>83</DP><BoQ ID="B1"><BoQInfo><Name>LV</Name><LblBoQ>Test</LblBoQ>' +
    '<OutlCompl>AllTxt</OutlCompl><BoQBkdn><Type>Item</Type><Length>4</Length><Num>Yes</Num>' +
    '</BoQBkdn></BoQInfo><BoQBody><Itemlist>' + AItems + '</Itemlist></BoQBody></BoQ></Award>' + CRLF +
    '</GAEB>' + CRLF;
end;

function Doc(const AItems: TLandrixXmlUtf8): TLandrixXmlUtf8;
begin
  Result := DocIn('DA83/3.3', '3.3', '2021-05', AItems);
end;

function Item(const AAttrs, AContent: TLandrixXmlUtf8): TLandrixXmlUtf8;
begin
  Result := '<Item ' + AAttrs + '>' + AContent + '</Item>';
end;

const
  GoodItem = '<Item ID="I1" RNoPart="0010"><Qty>12.5</Qty><QU>m</QU>' + Desc + '</Item>';

function Replace(const S, AOld, ANew: TLandrixXmlUtf8): TLandrixXmlUtf8;
var
  P: Integer;
begin
  Result := S;
  P := Pos(AOld, S);
  if P > 0 then
    Result := Copy(S, 1, P - 1) + ANew + Copy(S, P + Length(AOld), MaxInt);
end;

function Contains(const S, Part: TLandrixXmlUtf8): Boolean;
begin
  Result := Pos(Part, S) > 0;
end;

function Run(const S: TLandrixXmlUtf8; ADiags: TLandrixGaebDiagnostics): Boolean;
var
  Det: TLandrixGaebDetection;
begin
  ADiags.Clear;
  Result := LandrixGaebXmlCheckBuffer(Pointer(S), Length(S), ADiags, Det);
end;

function PathOf(ADiags: TLandrixGaebDiagnostics; const ARuleId: string): string;
var
  I: TLandrixGaebListIndex;
begin
  Result := '';
  for I := 0 to ADiags.Count - 1 do
    if ADiags[I].RuleId = ARuleId then
    begin
      Result := string(ADiags[I].Path);
      Exit;
    end;
end;

function MessageOf(ADiags: TLandrixGaebDiagnostics; const ARuleId: string): string;
var
  I: TLandrixGaebListIndex;
begin
  Result := '';
  for I := 0 to ADiags.Count - 1 do
    if ADiags[I].RuleId = ARuleId then
    begin
      Result := ADiags[I].Message;
      Exit;
    end;
end;

procedure TestValid;
var
  Diags: TLandrixGaebDiagnostics;
  Ok: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Ok := Run(Doc(GoodItem), Diags);
    Check(Ok, '3.3: ' + Diags.ToText);
    CheckEquals(0, Integer(Diags.Count), '3.3 without diagnostics');
    Ok := Run(DocIn('DA83/3.2', '3.2', '2013-10', GoodItem), Diags);
    Check(Ok, '3.2: ' + Diags.ToText);
    Ok := Run(DocIn('DA83/3.3', '3.3', '2019-11', GoodItem), Diags);
    Check(Ok, '3.3/2019-11: ' + Diags.ToText);
  finally
    Diags.Free;
  end;
end;

procedure TestStructure;
var
  Diags: TLandrixGaebDiagnostics;
  Ok: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    { Qty repeated }
    Check(not Run(Doc(Item('ID="I1" RNoPart="0010"', '<Qty>1</Qty><Qty>2</Qty><QU>m</QU>')), Diags),
      'repetition');
    CheckEquals(1, Integer(Diags.Count), 'one finding: ' + Diags.ToText);
    CheckEqualsStr(ItemPath + '/Qty[2]', PathOf(Diags, 'GAEB-CHK-001'), 'path of the repetition');
    { wrong order: QU before Qty }
    Check(not Run(Doc(Item('ID="I1" RNoPart="0010"', '<QU>m</QU><Qty>1</Qty>')), Diags), 'order');
    CheckEquals(1, Diags.CountOf('GAEB-CHK-001'), 'order: ' + Diags.ToText);
    { Description before QU: one finding, QU is accepted at the place before
      the jump }
    Check(not Run(Doc(Item('ID="I1" RNoPart="0010"', '<Qty>1</Qty>' + Desc + '<QU>m</QU>')), Diags),
      'out of order');
    CheckEquals(1, Integer(Diags.Count), 'out of order, no follow-up findings: ' + Diags.ToText);
    CheckEqualsStr(ItemPath + '/Description[1]', PathOf(Diags, 'GAEB-CHK-001'), 'reported once');
    { whitespace-only CDATA in element content }
    Ok := Run(Doc('<![CDATA[ ]]>' + GoodItem), Diags);
    Check(Ok, 'blank CDATA is whitespace: ' + Diags.ToText);
    { unknown element }
    Check(not Run(Doc(Item('ID="I1" RNoPart="0010"', '<Foo/><Qty>1</Qty><QU>m</QU>')), Diags),
      'unknown element');
    CheckEquals(1, Integer(Diags.Count), 'unknown: ' + Diags.ToText);
    Check(Pos('element Foo not allowed here; expected ', MessageOf(Diags, 'GAEB-CHK-001')) = 1,
      'message names the element and the expected ones');
    { mandatory element missing: BoQBkdn without Num }
    Check(not Run(Replace(Doc(GoodItem), '<Num>Yes</Num>', ''), Diags), 'missing');
    CheckEquals(1, Integer(Diags.Count), 'missing: ' + Diags.ToText);
    CheckEqualsStr('/GAEB[1]/Award[1]/BoQ[1]/BoQInfo[1]/BoQBkdn[1]', PathOf(Diags, 'GAEB-CHK-002'),
      'reported on the incomplete element');
    CheckEqualsStr('element BoQBkdn incomplete; expected Num', MessageOf(Diags, 'GAEB-CHK-002'),
      'message names the missing element');
    { text in element-only content }
    Check(not Run(Doc('text' + GoodItem), Diags), 'text');
    CheckEquals(1, Diags.CountOf('GAEB-CHK-007'), 'text: ' + Diags.ToText);
    { element of another namespace }
    Check(not Run(Doc(Item('ID="I1" RNoPart="0010"',
      '<x:Foo xmlns:x="urn:x"/><Qty>1</Qty><QU>m</QU>')), Diags), 'foreign element');
    CheckEquals(1, Integer(Diags.Count), 'foreign: ' + Diags.ToText);
    CheckEquals(1, Diags.CountOf('GAEB-CHK-003'), 'foreign element reported');
    { element inside a simple element }
    Check(not Run(Doc(Item('ID="I1" RNoPart="0010"', '<Qty>1<b/></Qty><QU>m</QU>')), Diags),
      'element in simple content');
    CheckEquals(1, Diags.CountOf('GAEB-CHK-001'), 'child of a simple element: ' + Diags.ToText);
    { rule 8 of the item table (a change order item has CONo) is part of the
      schema: CONo and COStatus only come together }
    Check(Run(Doc(Item('ID="I1" RNoPart="0010"', '<CONo>1</CONo><COStatus>Recog</COStatus><Qty>1</Qty>' +
      '<QU>m</QU>' + Desc)), Diags), 'change order item: ' + Diags.ToText);
    Check(not Run(Doc(Item('ID="I1" RNoPart="0010"', '<COStatus>Recog</COStatus><Qty>1</Qty><QU>m</QU>' +
      Desc)), Diags), 'COStatus without CONo');
    CheckEquals(1, Diags.CountOf('GAEB-CHK-001'), 'COStatus without CONo: ' + Diags.ToText);
    Check(not Run(Doc(Item('ID="I1" RNoPart="0010"', '<CONo>1</CONo><Qty>1</Qty><QU>m</QU>' + Desc)), Diags),
      'CONo without COStatus');
  finally
    Diags.Free;
  end;
end;

procedure TestAttributes;
var
  Diags: TLandrixGaebDiagnostics;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Check(not Run(Doc(Item('xmlns:x="urn:x" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' +
      'ID="I1" Foo="1" x:Bar="2" xsi:nil="false"', '<Qty>1</Qty><QU>m</QU>')), Diags), 'attributes');
    CheckEquals(3, Integer(Diags.Count), 'three findings: ' + Diags.ToText);
    CheckEquals(1, Diags.CountOf('GAEB-CHK-004'), 'unknown attribute');
    CheckEquals(1, Diags.CountOf('GAEB-CHK-003'), 'attribute of another namespace');
    CheckEquals(1, Diags.CountOf('GAEB-CHK-005'), 'mandatory attribute missing');
    CheckEqualsStr('mandatory attribute RNoPart missing', MessageOf(Diags, 'GAEB-CHK-005'), 'names it');
  finally
    Diags.Free;
  end;
end;

procedure TestValues;
var
  Diags: TLandrixGaebDiagnostics;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Check(not Run(Doc(Item('ID="I1" RNoPart="a-b"', '<Qty>1.2345</Qty><QU>m</QU>')), Diags), 'values');
    CheckEquals(2, Diags.CountOf('GAEB-CHK-006'), 'two invalid values: ' + Diags.ToText);
    Check(Pos('cvc-pattern-valid', Diags.ToText) > 0, 'pattern of RNoPart');
    Check(Pos('cvc-fractionDigits-valid', Diags.ToText) > 0, 'fraction digits of Qty');
    Check(Pos('a-b', Diags.ToText) = 0, 'no values of the document in messages');
    Check(Pos('1.2345', Diags.ToText) = 0, 'no values of the document in messages');
    CheckEqualsStr(ItemPath, PathOf(Diags, 'GAEB-CHK-006'), 'attribute value reported on its element');
    { enumeration, length }
    Check(not Run(Replace(Doc(GoodItem), '<Num>Yes</Num>', '<Num>Maybe</Num>'), Diags),
      'enumeration');
    Check(Pos('cvc-enumeration-valid', Diags.ToText) > 0, 'enumeration: ' + Diags.ToText);
    Check(not Run(Replace(Doc(GoodItem), '<Name>LV</Name>',
      '<Name>123456789012345678901</Name>'), Diags), 'length');
    Check(Pos('cvc-maxLength-valid', Diags.ToText) > 0, 'length: ' + Diags.ToText);
  finally
    Diags.Free;
  end;
end;

procedure TestIds;
var
  Diags: TLandrixGaebDiagnostics;
  Ok: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Check(not Run(Doc(GoodItem + '<Item ID="I1" RNoPart="0020"><Qty>1</Qty><QU>m</QU></Item>'), Diags),
      'duplicate ID');
    CheckEquals(1, Diags.CountOf('GAEB-CHK-008'), 'duplicate: ' + Diags.ToText);
    Check(not Run(Doc(Item('ID="I1" RNoPart="0010"', '<RefRNo IDRef="I9"/><Qty>1</Qty><QU>m</QU>')),
      Diags), 'IDREF without ID');
    CheckEquals(1, Diags.CountOf('GAEB-CHK-009'), 'dangling: ' + Diags.ToText);
    CheckEqualsStr(ItemPath + '/RefRNo[1]', PathOf(Diags, 'GAEB-CHK-009'), 'path of the reference');
    Ok := Run(Doc(Item('ID="I1" RNoPart="0010"', '<RefRNo IDRef="I2"/><Qty>1</Qty><QU>m</QU>') +
      '<Item ID="I2" RNoPart="0020"><Qty>1</Qty><QU>m</QU></Item>'), Diags);
    Check(Ok, 'forward reference resolved: ' + Diags.ToText);
  finally
    Diags.Free;
  end;
end;

procedure TestTargetAndRoot;
var
  Diags: TLandrixGaebDiagnostics;
  S: TLandrixXmlUtf8;
  Det: TLandrixGaebDetection;
  Raised: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    S := Doc(GoodItem);
    Check(not LandrixGaebXmlCheckTarget(Pointer(S), Length(S),
      LandrixGaebTarget(gv33, ge2021_05, gp84), Diags), 'document of another phase');
    CheckEquals(1, Diags.CountOf('GAEB-CHK-010'), 'wrong root: ' + Diags.ToText);
    S := DocIn('DA83/3.4', '3.4', '2026-03', GoodItem);
    Raised := False;
    try
      LandrixGaebXmlCheckBuffer(Pointer(S), Length(S), nil, Det);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, '3.4 has no grammar');
  finally
    Diags.Free;
  end;
end;

function ReadDoc(const S: TLandrixXmlUtf8): TLandrixGaebXmlGAEB;
var
  Det: TLandrixGaebDetection;
begin
  Result := LandrixGaebXmlReadBuffer(Pointer(S), Length(S), nil, Det);
end;

procedure TestModel;
var
  G: TLandrixGaebXmlGAEB;
  Diags: TLandrixGaebDiagnostics;
  Ok: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := ReadDoc(Doc(GoodItem));
  try
    Ok := LandrixGaebXmlCheckModel(G, LandrixGaebTarget(gv33, ge2021_05, gp83), Diags);
    Check(Ok, 'model of a valid document: ' + Diags.ToText);
    CheckEquals(0, Integer(Diags.Count), 'valid model without diagnostics');
    G.Award.BoQ.BoQInfo.LblBoQ := '';
    Check(not LandrixGaebXmlCheckModel(G, LandrixGaebTarget(gv33, ge2021_05, gp83), Diags),
      'mandatory LblBoQ removed');
    CheckEquals(1, Integer(Diags.Count), 'one finding, the check goes on behind it: ' + Diags.ToText);
    CheckEqualsStr('element OutlCompl not allowed here; expected LblBoQ', MessageOf(Diags, 'GAEB-CHK-001'),
      'names the missing element');
    Diags.Clear;
    { AwardInfo/CtlgAssign does not exist in 3.2: a writer error }
    G.Award.BoQ.BoQInfo.LblBoQ := 'Test';
    G.Award.AwardInfo.CtlgAssign.Add.CtlgID := 'K1';
    Check(not LandrixGaebXmlCheckModel(G, LandrixGaebTarget(gv32, ge2013_10, gp83), Diags),
      'member the target does not have');
    CheckEquals(1, Diags.CountOf('GAEB-WRT-001'), 'reported by the writer: ' + Diags.ToText);
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestWriterCheck;
var
  G: TLandrixGaebXmlGAEB;
  Diags: TLandrixGaebDiagnostics;
  Options: TLandrixGaebXmlWriteOptions;
  S: TLandrixXmlUtf8;
  Raised: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := TLandrixGaebXmlGAEB.Create;
  try
    G.GAEBInfo.ProgSystem := 'Test';
    Options := LandrixGaebXmlDefaultWriteOptions;
    Raised := False;
    try
      LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp83), Options, Diags);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'incomplete document aborts in normal mode');
    Check(Diags.CountOf('GAEB-CHK-002') > 0, 'incomplete content reported: ' + Diags.ToText);
    Diags.Clear;
    Options.Mode := gwmBestEffort;
    S := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp83), Options, Diags);
    Check(S <> '', 'best effort writes');
    Check(Diags.HasErrors, 'and reports the findings as errors');
    Diags.Clear;
    Options.Mode := gwmNormal;
    Options.Check := False;
    S := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp83), Options, Diags);
    CheckEquals(0, Integer(Diags.Count), 'without check');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestConvert;
var
  G: TLandrixGaebXmlGAEB;
  Options: TLandrixGaebXmlWriteOptions;
  S: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
  Det: TLandrixGaebDetection;
  Ok: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Options := LandrixGaebXmlDefaultWriteOptions;
  Options.Mode := gwmStrict;
  G := ReadDoc(DocIn('DA83/3.2', '3.2', '2013-10', GoodItem));
  try
    S := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp83), Options, Diags);
    Check(Contains(S, 'DA83/3.3'), '3.2 converted to 3.3');
    Ok := LandrixGaebXmlCheckBuffer(Pointer(S), Length(S), Diags, Det);
    Check(Ok, 'and valid: ' + Diags.ToText);
    Check((Det.Target.Version = gv33) and (Det.Target.Edition = ge2021_05), 'declares 3.3/2021-05');
  finally
    G.Free;
  end;
  G := ReadDoc(Doc(GoodItem));
  try
    S := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv32, ge2013_10, gp83), Options, Diags);
    Ok := LandrixGaebXmlCheckBuffer(Pointer(S), Length(S), Diags, Det);
    Check(Ok, '3.3 to 3.2: ' + Diags.ToText);
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ ---- local corpus ---- }

var
  CorpusChecked, CorpusInvalid, CorpusBroken, CorpusFailed: Integer;
  CorpusFailures: TStringList;
  CorpusRules: TStringList;

procedure CountRules(ADiags: TLandrixGaebDiagnostics);
var
  I: TLandrixGaebListIndex;
begin
  for I := 0 to ADiags.Count - 1 do
    CorpusRules.Add(ADiags[I].RuleId);
end;

procedure CorpusFile(const FileName, RelName: string);
var
  Det: TLandrixGaebDetection;
  G: TLandrixGaebXmlGAEB;
  Diags: TLandrixGaebDiagnostics;
  Options: TLandrixGaebXmlWriteOptions;
  Errors, Warnings: Integer;
  Valid: Boolean;
begin
  Det := LandrixGaebDetectFile(FileName, nil, 0);
  if (Det.Format <> gfXml) or not Det.Accepted or not (Det.Target.Phase in [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]) or
    not ((Det.Target.Version = gv32) or (Det.Target.Version = gv33)) or
    not LandrixGaebTargetIsSupported(Det.Target, True) then
    Exit;
  Options := LandrixGaebXmlDefaultWriteOptions;
  Options.PreserveScale := True;
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    try
      Valid := LandrixGaebXmlCheckFile(FileName, Diags, 0, Det);
      Inc(CorpusChecked);
      if not Valid then
      begin
        Inc(CorpusInvalid);
        CountRules(Diags);
      end;
      Diags.Clear;
      G := LandrixGaebXmlReadFile(FileName, nil, 0, Det);
      LandrixGaebXmlWriteCollect(G, Det.Target, Options, Diags, Errors, Warnings);
      { a valid input must give a valid output }
      if Valid and (Errors > 0) then
      begin
        Inc(CorpusBroken);
        CorpusFailures.Add(RelName + ': valid input, ' + IntToStr(Errors) + ' error(s) in the output');
      end;
    except
      on E: Exception do
      begin
        Inc(CorpusFailed);
        CorpusFailures.Add(RelName + ': ' + E.ClassName);
      end;
    end;
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure CorpusDir(const Dir, Rel: string);
var
  SR: TSearchRec;
begin
  if FindFirst(Dir + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        CorpusDir(Dir + SR.Name + PathDelim, Rel + SR.Name + '/')
      else
        CorpusFile(Dir + SR.Name, Rel + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TestLocalCheck;
var
  Local, Summary: string;
  I, N: Integer;
begin
  Local := LocalDataDir;
  if not DirectoryExists(Local) then
  begin
    Skip('local corpus not present');
    Exit;
  end;
  CorpusChecked := 0;
  CorpusInvalid := 0;
  CorpusBroken := 0;
  CorpusFailed := 0;
  CorpusFailures := TStringList.Create;
  CorpusRules := TStringList.Create;
  try
    CorpusRules.Sorted := True;
    CorpusRules.Duplicates := dupAccept;
    CorpusDir(Local + 'xml' + PathDelim, 'xml/');
    CorpusDir(Local + 'official' + PathDelim, 'official/');
    Summary := '';
    I := 0;
    while I < CorpusRules.Count do
    begin
      N := 1;
      while (I + N < CorpusRules.Count) and (CorpusRules[I + N] = CorpusRules[I]) do
        Inc(N);
      Summary := Summary + ' ' + CorpusRules[I] + 'x' + IntToStr(N);
      Inc(I, N);
    end;
    WriteLn('  Local.Check: ', CorpusChecked, ' file(s) checked, ', CorpusInvalid, ' invalid,',
      Summary);
    if CorpusFailures.Count > 0 then
      Fail(IntToStr(CorpusFailures.Count) + ' problem(s):' + sLineBreak + CorpusFailures.Text);
    Check(CorpusChecked > 0, 'local files checked');
  finally
    CorpusRules.Free;
    CorpusRules := nil;
    CorpusFailures.Free;
    CorpusFailures := nil;
  end;
end;

procedure Register;
begin
  RegisterTest('XmlCheck.Valid', TestValid);
  RegisterTest('XmlCheck.Structure', TestStructure);
  RegisterTest('XmlCheck.Attributes', TestAttributes);
  RegisterTest('XmlCheck.Values', TestValues);
  RegisterTest('XmlCheck.Ids', TestIds);
  RegisterTest('XmlCheck.TargetAndRoot', TestTargetAndRoot);
  RegisterTest('XmlCheck.Model', TestModel);
  RegisterTest('XmlCheck.WriterCheck', TestWriterCheck);
  RegisterTest('XmlCheck.Convert', TestConvert);
  RegisterTest('Local.Check', TestLocalCheck);
end;

end.

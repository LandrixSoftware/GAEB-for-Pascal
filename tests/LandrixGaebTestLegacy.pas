{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Test cases from the review of the old Landrix GAEB implementation, GAEB
  DA XML part (cases 24 to 32, 34, 35, 37), on the syntax model: reader,
  check, rules and writer. The documents come from
  tools/legacy/make-legacy-cases.py (tests/data/legacy). Parts that need the
  business model (plain text view, unique OZ of the business model, labels
  of unit price components in the business model) follow with the facade.
  Every test also checks that no diagnostic message contains a value of
  its document (case 37). }

unit LandrixGaebTestLegacy;

{$I LandrixGaeb.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixXmlDecimal,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebXmlWriteBase,
  LandrixGaebXmlWriter,
  LandrixGaebXmlCheck,
  LandrixGaebRules,
  LandrixGaebTestNoValues,
  LandrixGaebTestFramework;

const
  CRLF = #13#10;

function LegacyFile(const AName: string): TLandrixXmlUtf8;
begin
  Result := ReadFileBytes(RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'legacy' +
    PathDelim + AName);
end;

function Contains(const S, Part: TLandrixXmlUtf8): Boolean;
begin
  Result := Pos(Part, S) > 0;
end;

function Occurrences(const S, Part: TLandrixXmlUtf8): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Integer(Length(S)) - Integer(Length(Part)) + 1 do
    if Copy(S, I, Integer(Length(Part))) = Part then
      Inc(Result);
end;

{ S without line breaks and the indentation after them (the writer indents
  element content, never text blocks). }
function Compact(const S: TLandrixXmlUtf8): TLandrixXmlUtf8;
var
  I, N: Integer;
begin
  Result := '';
  SetLength(Result, Integer(Length(S)));
  N := 0;
  I := 1;
  while I <= Integer(Length(S)) do
  begin
    if (S[I] = #13) or (S[I] = #10) then
    begin
      while (I <= Integer(Length(S))) and ((S[I] = #13) or (S[I] = #10) or (S[I] = ' ')) do
        Inc(I);
      Continue;
    end;
    Inc(N);
    Result[N] := S[I];
    Inc(I);
  end;
  SetLength(Result, N);
end;

function Spaces(N: Integer): TLandrixXmlUtf8;
begin
  Result := '';
  SetLength(Result, N);
  if N > 0 then
    FillChar(Result[1], N, Ord(' '));
end;

{ S with the first APart replaced by AWith. }
function ReplaceFirst(const S, APart, AWith: TLandrixXmlUtf8): TLandrixXmlUtf8;
var
  P: Integer;
begin
  Result := S;
  P := Pos(APart, S);
  if P > 0 then
    Result := Copy(S, 1, P - 1) + AWith + Copy(S, P + Integer(Length(APart)), MaxInt);
end;

function ReadSource(const ASource: TLandrixXmlUtf8; ADiags: TLandrixGaebDiagnostics;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Det: TLandrixGaebDetection;
begin
  Result := LandrixGaebXmlReadBuffer(Pointer(ASource), Integer(Length(ASource)), ADiags, Det);
  ATarget := Det.Target;
end;

function Errors(ADiags: TLandrixGaebDiagnostics): Integer;
var
  I: TLandrixGaebListIndex;
begin
  Result := 0;
  for I := 0 to ADiags.Count - 1 do
    if ADiags[I].Severity >= gsError then
      Inc(Result);
end;

{ Reads a valid document: no reader diagnostic, the check passes, the
  rules find no error, and write - read - write gives the same bytes.
  Returns the model and its first output. }
function ReadValid(const AName: string; out ATarget: TLandrixGaebTarget;
  out AOutput: TLandrixXmlUtf8): TLandrixGaebXmlGAEB;
var
  Source, Again: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
  Det: TLandrixGaebDetection;
  G2: TLandrixGaebXmlGAEB;
  Ok: Boolean;
  T2: TLandrixGaebTarget;
begin
  Source := LegacyFile(AName);
  Diags := TLandrixGaebDiagnostics.Create;
  Result := nil;
  G2 := nil;
  try
    Ok := LandrixGaebXmlCheckBuffer(Pointer(Source), Integer(Length(Source)), Diags, Det);
    Check(Ok, AName + ' passes the check: ' + Diags.ToText);
    Result := ReadSource(Source, Diags, ATarget);
    CheckEquals(0, Integer(Diags.Count), AName + ' reads without diagnostics: ' + Diags.ToText);
    LandrixGaebCheckRules(Result, ATarget, Diags);
    CheckEquals(0, Errors(Diags), AName + ': no rule error: ' + Diags.ToText);
    CheckNoFileValues(Source, Diags, AName);
    AOutput := LandrixGaebXmlWriteUtf8(Result, ATarget, LandrixGaebXmlDefaultWriteOptions, nil);
    G2 := ReadSource(AOutput, nil, T2);
    Again := LandrixGaebXmlWriteUtf8(G2, ATarget, LandrixGaebXmlDefaultWriteOptions, nil);
    Check(Again = AOutput, AName + ': write - read - write gives the same bytes');
  except
    Result.Free;
    G2.Free;
    Diags.Free;
    raise;
  end;
  G2.Free;
  Diags.Free;
end;

function FirstCategory(G: TLandrixGaebXmlGAEB): TLandrixGaebXmlBoQCtgy;
begin
  Result := G.Award.BoQ.BoQBody.Children[0] as TLandrixGaebXmlBoQCtgy;
end;

function ItemOf(ACtgy: TLandrixGaebXmlBoQCtgy; AIndex: Integer): TLandrixGaebXmlItem;
begin
  Result := ACtgy.BoQBody.Itemlist.Children[AIndex] as TLandrixGaebXmlItem;
end;

{ ---- 24: namespaces, versions, editions ---- }

function XmlDoc(const Ns, Version, VersDate, DP: TLandrixXmlUtf8): TLandrixXmlUtf8;
begin
  Result := '<?xml version="1.0" encoding="UTF-8"?>' + CRLF +
    '<GAEB xmlns="' + Ns + '">' + CRLF +
    '  <GAEBInfo><Version>' + Version + '</Version><VersDate>' + VersDate +
    '</VersDate><ProgSystem>Test</ProgSystem></GAEBInfo>' + CRLF +
    '  <PrjInfo><NamePrj>P</NamePrj></PrjInfo>' + CRLF +
    '  <Award><DP>' + DP + '</DP></Award>' + CRLF +
    '</GAEB>' + CRLF;
end;

procedure Test24Namespaces;
var
  Diags: TLandrixGaebDiagnostics;
  R: TLandrixGaebDetection;
  S: TLandrixXmlUtf8;
begin
  { 3.0/3.1 (200407, 200706) and contradictions: Detect.Xml31 and
    Detect.XmlMismatches }
  Diags := TLandrixGaebDiagnostics.Create;
  try
    S := XmlDoc('http://www.gaeb.de/GAEB_DA_XML/DA83/3.2', '3.2', '2013-10', '83');
    R := LandrixGaebDetectBuffer(Pointer(S), Integer(Length(S)), False, Diags);
    Check(R.Accepted and (R.Target.Version = gv32) and (R.Target.Phase = gp83), '3.2 X83');
    S := XmlDoc('http://www.gaeb.de/GAEB_DA_XML/DA84Z/3.2', '3.2', '2014-03', '84Z');
    R := LandrixGaebDetectBuffer(Pointer(S), Integer(Length(S)), False, Diags);
    Check(R.Accepted and (R.Target.Version = gv32) and (R.Target.Phase = gp84Z), '3.2 time contract X84Z');
    S := XmlDoc('http://www.gaeb.de/GAEB_DA_XML/DA86ZR/3.3', '3.3', '2021-05', '86ZR');
    R := LandrixGaebDetectBuffer(Pointer(S), Integer(Length(S)), False, Diags);
    Check(R.Accepted and (R.Target.Version = gv33) and (R.Target.Phase = gp86ZR), '3.3 time contract X86ZR');
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
    S := XmlDoc('http://www.gaeb.de/GAEB_DA_XML/DA84Z/3.2', '3.2', '2014-03', '84');
    R := LandrixGaebDetectBuffer(Pointer(S), Integer(Length(S)), False, Diags);
    Check(R.Accepted, 'a contradiction between namespace and DP is a warning');
    CheckEquals(1, Diags.CountOf('GAEB-DET-006'), 'DP/namespace mismatch reported');
    CheckNoFileValues(S, Diags, '24');
  finally
    Diags.Free;
  end;
end;

{ ---- 25: vendor namespaces ---- }

procedure Test25Vendor;
var
  Source: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
begin
  Source := LegacyFile('25-vendor-invalid.x83');
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    G := ReadSource(Source, Diags, T);
    CheckEquals(3, Diags.CountOf('GAEB-XML-002'), 'one diagnostic per vendor namespace: ' + Diags.ToText);
    CheckEquals(3, Integer(Diags.Count), 'nothing else');
    CheckEquals(0, Errors(Diags), 'vendor elements are warnings');
    CheckEquals(20, Integer(FirstCategory(G).BoQBody.Itemlist.Children.Count), 'all items read');
    Check(ItemOf(FirstCategory(G), 19).RNoPart = '0200', 'last item');
    CheckNoFileValues(Source, Diags, '25');
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ ---- 26: items above the deepest level, items without category, nested
  categories of the old writer ---- }

procedure Test26Structure;
var
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  Output, Source: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
begin
  G := ReadValid('26-levels.x83', T, Output);
  Output := Compact(Output);
  try
    Check(FirstCategory(G).BoQBody.HasItemlist, 'items on the first of two levels');
    Check(Contains(Output, '<BoQCtgy ID="C1" RNoPart="01"><LblTx><p><span>Titel</span></p></LblTx>' +
      '<BoQBody><Itemlist>'), 'structure kept on writing');
  finally
    G.Free;
  end;
  G := ReadValid('26-no-category.x83', T, Output);
  Output := Compact(Output);
  try
    Check(G.Award.BoQ.BoQBody.HasItemlist, 'items directly in the bill of quantities');
    Check(Contains(Output, '</BoQInfo><BoQBody><Itemlist><Item ID="I1"'), 'structure kept on writing');
  finally
    G.Free;
  end;
  { BoQCtgy directly in BoQCtgy: reported, never silently repaired }
  Source := LegacyFile('26-nested-invalid.x84');
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    G := ReadSource(Source, Diags, T);
    CheckEquals(1, Diags.CountOf('GAEB-XML-001'), 'nested category reported: ' + Diags.ToText);
    Check(not FirstCategory(G).HasBoQBody, 'and not moved into a BoQBody');
    CheckNoFileValues(Source, Diags, '26');
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ ---- 27: OZ parts ---- }

procedure Test27OZ;
var
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  Output: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
begin
  G := ReadValid('27-oz.x83', T, Output);
  Diags := TLandrixGaebDiagnostics.Create;
  try
    LandrixGaebCheckRules(G, T, Diags);
    CheckEquals(0, Integer(Diags.Count), 'shorter numeric part, alphanumeric level and index: ' + Diags.ToText);
    Check(FirstCategory(G).RNoPart = 'A1', 'alphanumeric part');
    Check(ItemOf(FirstCategory(G), 0).RNoPart = '10', 'shorter numeric part kept as read');
    Check(ItemOf(FirstCategory(G), 1).RNoIndex = 'B', 'index');
  finally
    Diags.Free;
    G.Free;
  end;
end;

{ ---- 28: encoding ---- }

procedure Test28Encoding;
var
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  Output, Source: TLandrixXmlUtf8;
  Raised: Boolean;
  Pass: Integer;
  Diags: TLandrixGaebDiagnostics;
begin
  G := ReadValid('28-bom.x83', T, Output);
  try
    Check(ItemOf(FirstCategory(G), 0).RNoPart = '0010', 'a file with BOM reads normally');
    Check(Copy(Output, 1, 5) = '<?xml', 'and is written without BOM');
  finally
    G.Free;
  end;
  { a byte that is not UTF-8, at the start and far behind the detection
    prefix: the whole input is checked for well-formedness first, so both
    are rejected with GAEB-DET-008 and the position, before reading }
  Source := LegacyFile('28-latin1-invalid.x83');
  for Pass := 1 to 2 do
  begin
    if Pass = 2 then
      Source := ReplaceFirst(Source, '<BoQBody>', '<BoQBody><!--' +
        Spaces(LandrixGaebDetectPrefixSize) + '-->');
    Diags := TLandrixGaebDiagnostics.Create;
    try
      Raised := False;
      try
        ReadSource(Source, Diags, T).Free;
      except
        on ELandrixGaebError do
          Raised := True;
      end;
      Check(Raised, 'a byte that is not UTF-8 is rejected, pass ' + IntToStr(Pass));
      CheckEquals(1, Diags.CountOf('GAEB-DET-008'), 'as not well-formed');
      Check(Diags[0].Line = 5, 'with the line');
      CheckNoFileValues(Source, Diags, '28');
    finally
      Diags.Free;
    end;
  end;
end;

{ ---- 29: text complements ---- }

procedure Test29Complements;
var
  A, B: TLandrixGaebXmlGAEB;
  TA, TB: TLandrixGaebTarget;
  OutA, OutB, Changed: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
begin
  A := ReadValid('29-complements.x83', TA, OutA);
  B := nil;
  Diags := TLandrixGaebDiagnostics.Create;
  try
    B := ReadValid('29-complements.x84', TB, OutB);
    OutA := Compact(OutA);
    OutB := Compact(OutB);
    Check(Contains(OutA, '<TextComplement MarkLbl="1" Kind="Owner"><ComplCaption>'), 'owner complement with caption');
    Check(Contains(OutA, '<TextComplement MarkLbl="2" Kind="Bidder" Empty="Yes">'), 'empty bidder complement');
    Check(Contains(OutA, '<span>Leuchte</span><TextComplement MarkLbl="1"'), 'complement inline in the paragraph');
    Check(Contains(OutA, '</TextOutlTxt><TextComplement MarkLbl="4"'), 'complement in the outline text');
    Check(Contains(OutB, '<ComplBodyDec Value="12.5"/>'), 'decimal filled in by the bidder');
    Check(Contains(OutB, '<ComplBodyInt Value="7"/>'), 'integer filled in by the bidder');
    Check(Contains(OutB, '<p><TextComplement MarkLbl="1" Kind="Owner">'), 'complement in a paragraph of the bid');
    LandrixGaebCheckPair(A, TA, B, TB, Diags);
    CheckEquals(0, Integer(Diags.Count), 'the bid keeps the numbers of the request: ' + Diags.ToText);
    { a changed number deep in the text is found }
    B.Free;
    B := nil;
    Changed := LegacyFile('29-complements.x84');
    Changed := ReplaceFirst(Changed, 'MarkLbl="1"', 'MarkLbl="9"');
    B := ReadSource(Changed, nil, TB);
    LandrixGaebCheckPair(A, TA, B, TB, Diags);
    CheckEquals(1, Diags.CountOf('GAEB-BR-PAIR-83-84-007'), 'changed number in a paragraph: ' + Diags.ToText);
    CheckNoFileValues(Changed, Diags, '29');
  finally
    Diags.Free;
    B.Free;
    A.Free;
  end;
end;

{ ---- 30: formatted text ---- }

procedure Test30Format;
var
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  Output: TLandrixXmlUtf8;
begin
  { the raw output: text blocks must come without line breaks or
    indentation }
  G := ReadValid('30-format.x83', T, Output);
  try
    Check(Contains(Output, '<Text><p><span>Zeile 1</span><br/><br/><br/><span>Zeile 2</span></p>'),
      'chain of br, text block not indented');
    Check(Contains(Output, '<p><span/></p>'), 'empty span');
    Check(Contains(Output, '<div><span>Block</span></div>'), 'div');
    Check(Contains(Output, '<ul><li><span>Punkt a</span></li><li><p><span>Punkt b</span></p></li></ul>'), 'ul');
    Check(Contains(Output, '<ol start="3"><li><span>Schritt 3</span></li></ol>'), 'ol with start');
    Check(Contains(Output, '<table><tr><th><span>Spalte</span></th></tr><tr><td><span>Zelle</span></td></tr></table>'),
      'table with th');
    Check(Contains(Output, '<p><image Type="image/png">iVBORw0KGgo=</image></p>'), 'image in a paragraph');
    Check(Contains(Output, 'Name="bild.png"'), 'Image block with name');
    Check(Contains(Output, '<page/>'), 'page');
  finally
    G.Free;
  end;
end;

{ ---- 31 and 35: element list ---- }

procedure Test31Elements;
var
  A, B: TLandrixGaebXmlGAEB;
  TA, TB: TLandrixGaebTarget;
  OutA, OutB: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
begin
  A := ReadValid('31-elements.x83', TA, OutA);
  B := nil;
  Diags := TLandrixGaebDiagnostics.Create;
  try
    B := ReadValid('31-elements.x84', TB, OutB);
    OutA := Compact(OutA);
    OutB := Compact(OutB);
    LandrixGaebCheckPair(A, TA, B, TB, Diags);
    CheckEquals(0, Integer(Diags.Count), 'the bid fits the request: ' + Diags.ToText);
    Check(Contains(OutA, '<ALNGroupNo>1</ALNGroupNo><ALNSerNo>1</ALNSerNo>'), 'alternative');
    Check(Contains(OutA, '<Provis>WithoutTotal</Provis>'), 'eventual item');
    Check(Contains(OutA, '<RefDescr>Rep</RefDescr><RefRNo IDRef="I6"/>'), 'repetition description');
    Check(Contains(OutA, '<RefPerfNo IDRef="P1"/><QtyTBD>Yes</QtyTBD>'), 'execution description, QtyTBD');
    Check(Contains(OutA, '<QtySplit><Qty>4.000</Qty><CtlgAssign><CtlgID>C1</CtlgID><CtlgCode>KS1</CtlgCode></CtlgAssign>' +
      '</QtySplit>'), 'quantity split with catalogue assignment');
    Check(Contains(OutA, '<SubDescr><SubDNo>1</SubDNo>'), 'sub description');
    Check(Contains(OutA, '<MarkupSubQty><RefItem IDRef="I1"/></MarkupSubQty>'), 'markup item ListInSubQty');
    Check(Contains(OutA, '<NotApplBoQ>Yes</NotApplBoQ>'), 'category not applicable');
    Check(Contains(OutA, '<UPFracDig>3</UPFracDig>'), 'UPFracDig');
    { 35: labels of the unit price components as given, no fixed meaning }
    Check(Contains(OutA, '<NoUPComps>3</NoUPComps><LblUPComp1 Type="Wages">Lohn</LblUPComp1>' +
      '<LblUPComp2 Type="Materials">Stoffe</LblUPComp2>'), 'labels of the unit price components');
    Check(A.Award.BoQ.BoQInfo.LblUPComp3.Value = 'Geraete', 'label in the model');
    Check(Contains(OutB, '<UP>12.345</UP><UPComp1>10.000</UPComp1><UPComp2>2.345</UPComp2>' +
      '<DiscountPcnt>2.000000</DiscountPcnt><IT>120.98</IT>'), 'unit price components and discount');
    Check(Contains(OutB, '<Total>512.04</Total><DiscountPcnt>1.000000</DiscountPcnt><TotAfterDisc>506.92</TotAfterDisc>'),
      'totals with discount');
  finally
    Diags.Free;
    B.Free;
    A.Free;
  end;
end;

{ ---- 32: writer rules ---- }

procedure Test32Writer;
var
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  Output, Source: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
  Errs, Warns: Integer;
  Item: TLandrixGaebXmlItem;
begin
  { IT with two digits, VersDate of the target: XmlWriter.DecimalTooPrecise
    and XmlWriter.TargetValues; X86 and X84Z follow with their phases }
  Source := LegacyFile('26-no-category.x83');
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    G := ReadSource(Source, nil, T);
    Item := G.Award.BoQ.BoQBody.Itemlist.Children[0] as TLandrixGaebXmlItem;
    Item.ID := '1x';
    Item.QU := 'Stueck';
    Output := LandrixGaebXmlWriteCollect(G, T, LandrixGaebXmlDefaultWriteOptions, Diags, Errs, Warns);
    Check(Errs >= 2, 'ID that is no NCName and QU over its length are errors: ' + Diags.ToText);
    Check(Contains(Output, '<Item ID="1x"'), 'the ID is written as given, not repaired');
    Check(Contains(Output, '<QU>Stueck</QU>'), 'the unit is not cut');
    CheckNoFileValues(Output, Diags, '32');
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ ---- 34: 0.00 is a price, no price is none ---- }

procedure Test34Zero;
var
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebTarget;
  Output: TLandrixXmlUtf8;
  A, B: TLandrixGaebXmlItem;
begin
  G := ReadValid('34-zero.x84', T, Output);
  try
    A := ItemOf(FirstCategory(G), 0);
    B := ItemOf(FirstCategory(G), 1);
    Check(A.UP.HasValue, '0.00 is a value');
    CheckEquals(0, LandrixXmlDecimalCompare(A.UP.AsXmlDecimal, LandrixXmlDecimalZero), 'of zero');
    Check(not B.UP.HasValue, 'an item not offered has no price');
    CheckEquals(1, Occurrences(Output, '<UP>0.000</UP>'), '0.00 written (UP has three fraction digits)');
    CheckEquals(1, Occurrences(Output, '<IT>0.00</IT>'), 'total 0.00 written');
    CheckEquals(1, Occurrences(Output, '<UP>'), 'no price written for the item not offered');
  finally
    G.Free;
  end;
end;

{ ---- 37: the helper finds values in messages ---- }

procedure Test37Helper;
var
  Diags: TLandrixGaebDiagnostics;
  Values: TFileValues;
  First: string;
begin
  Values := FileValues('<?xml version="1.0"?><a xmlns="urn:x" ID="Kennung7"><b>Fassade</b>' +
    '<c>BoQLevel</c><d>ab</d></a>');
  CheckEquals(2, Integer(Length(Values)), 'text and attribute values, without vocabulary, namespace and short values');
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Diags.AddDiagnostic('X-1', gsError, 'item Fassade is wrong');
    Diags.AddDiagnostic('X-2', gsError, 'id Kennung7');
    Diags.AddDiagnostic('X-3', gsError, 'Fassaden, BoQLevel, urn:x, ab');
    CheckEquals(2, CountValueLeaks(Values, Diags, First), 'values found as whole words only');
    CheckEqualsStr('X-1 contains a value of 7 bytes', First, 'the report names rule and length, not the value');
    { decoded: character references, CDATA, entities in attributes }
    Values := FileValues('<a ID="Kenn&#117;ng7"><b>Fass&#97;de</b><c><![CDATA[Daemmung]]></c></a>');
    Diags.Clear;
    Diags.AddDiagnostic('X-4', gsError, 'Kennung7');
    Diags.AddDiagnostic('X-5', gsError, 'Fassade');
    Diags.AddDiagnostic('X-6', gsError, 'Daemmung');
    CheckEquals(3, CountValueLeaks(Values, Diags, First), 'values found after decoding');
    { text split by CDATA is one value }
    Values := FileValues('<a><b>Fas<![CDATA[sade]]></b></a>');
    CheckEquals(1, CountValueLeaks(Values, Diags, First), 'text and CDATA joined');
  finally
    Diags.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Legacy.24Namespaces', Test24Namespaces);
  RegisterTest('Legacy.25Vendor', Test25Vendor);
  RegisterTest('Legacy.26Structure', Test26Structure);
  RegisterTest('Legacy.27OZ', Test27OZ);
  RegisterTest('Legacy.28Encoding', Test28Encoding);
  RegisterTest('Legacy.29Complements', Test29Complements);
  RegisterTest('Legacy.30Format', Test30Format);
  RegisterTest('Legacy.31Elements', Test31Elements);
  RegisterTest('Legacy.32Writer', Test32Writer);
  RegisterTest('Legacy.34Zero', Test34Zero);
  RegisterTest('Legacy.37Helper', Test37Helper);
end;

end.

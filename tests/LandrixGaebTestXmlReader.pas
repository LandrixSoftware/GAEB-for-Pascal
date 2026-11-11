{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of the generated reader (LandrixGaebXmlReader): synthetic
  documents for every diagnostic, and the local corpus under
  tests/data/local (skipped when missing; prints counts only, never file
  content). }

unit LandrixGaebTestXmlReader;

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
  LandrixGaebXmlBase,
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebTestFramework;

const
  CRLF = #13#10;

{ A 3.3 document of phase APhase with ABody inside Award after DP. }
function DocFor(const APhase, ABody: AnsiString): AnsiString;
begin
  Result := '<?xml version="1.0" encoding="UTF-8"?>' + CRLF +
    '<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA' + APhase + '/3.3">' + CRLF +
    '  <GAEBInfo><Version>3.3</Version><VersDate>2021-05</VersDate>' +
    '<Date>2026-10-21</Date><ProgSystem>Test</ProgSystem></GAEBInfo>' + CRLF +
    '  <PrjInfo><NamePrj>P</NamePrj></PrjInfo>' + CRLF +
    '  <Award><DP>' + APhase + '</DP>' + ABody + '</Award>' + CRLF +
    '</GAEB>' + CRLF;
end;

{ An X83 3.3 document with ABody inside Award after DP. }
function Doc(const ABody: AnsiString): AnsiString;
begin
  Result := DocFor('83', ABody);
end;

function ReadDoc(const S: AnsiString; Diags: TLandrixGaebDiagnostics): TLandrixGaebXmlGAEB;
var
  Det: TLandrixGaebDetection;
begin
  Result := LandrixGaebXmlReadBuffer(Pointer(S), Length(S), Diags, Det);
end;

{ A bill of quantities with one item whose first paragraph holds AParagraph. }
function OneItemWith(const AParagraph: AnsiString): AnsiString;
begin
  Result := '<BoQ ID="B1"><BoQInfo><Name>LV</Name><LblBoQ>Test</LblBoQ><OutlCompl>AllTxt</OutlCompl>' +
    '<BoQBkdn><Type>Item</Type><Length>4</Length><Num>Yes</Num></BoQBkdn></BoQInfo>' +
    '<BoQBody><Itemlist><Item ID="I1" RNoPart="0010"><Qty>12.500</Qty><QU>m</QU>' +
    '<Description><CompleteText><DetailTxt><Text><p>' + AParagraph + '</p>' +
    '</Text></DetailTxt><OutlineText><OutlTxt><TextOutlTxt><p><span>Kurz</span></p></TextOutlTxt>' +
    '</OutlTxt></OutlineText></CompleteText></Description></Item></Itemlist></BoQBody></BoQ>';
end;

function OneItem: AnsiString;
begin
  Result := OneItemWith('<span>a</span><br/><span>b</span>');
end;

function FirstItem(G: TLandrixGaebXmlGAEB): TLandrixGaebXmlItem;
begin
  Result := G.Award.BoQ.BoQBody.Itemlist.Children[0] as TLandrixGaebXmlItem;
end;

procedure TestReadMinimal;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  Item: TLandrixGaebXmlItem;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    G := ReadDoc(Doc(OneItem), Diags);
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
    Check(G.Award.DP = '83', 'DP');
    Check(G.GAEBInfo.ProgSystem = 'Test', 'ProgSystem');
    Check(G.Award.BoQ.ID = 'B1', 'BoQ ID');
    Check(G.Award.BoQ.BoQInfo.BoQBkdn[0].LengthElement = '4', 'renamed element Length');
    Item := FirstItem(G);
    Check(Item.RNoPart = '0010', 'RNoPart keeps leading zeros');
    CheckEqualsUtf8('12.500', Item.Qty.Text, 'Qty with scale as read');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestTextTree;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  T: TLandrixGaebXmlFTextTC;
  P: TLandrixGaebXmlPTC;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    G := ReadDoc(Doc(OneItem), Diags);
    T := FirstItem(G).Description.CompleteText.DetailTxt.Children[0] as TLandrixGaebXmlFTextTC;
    CheckEqualsUtf8('Text', T.ElementName, 'Text element');
    P := T.Children[0] as TLandrixGaebXmlPTC;
    CheckEquals(3, Integer(P.Children.Count), 'span, br, span in order');
    Check((P.Children[0] as TLandrixGaebXmlSpan).Value = 'a', 'first span');
    CheckEqualsUtf8('br', P.Children[1].ElementName, 'br in the middle');
    Check(P.Children[1].IsPresent, 'empty br read is present');
    Check((P.Children[2] as TLandrixGaebXmlSpan).Value = 'b', 'second span');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestDiagnostics;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  S: AnsiString;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    { unknown element, vendor namespace (reported once), wrong order,
      repetition, invalid decimal, unknown attribute }
    S := '<AwardInfo Foo="1"><Cur>EUR</Cur><BoQID>X</BoQID>' +
      '<EvalEnd>2026-01-01</EvalEnd><EvalEnd>2026-01-02</EvalEnd><Unknown>u</Unknown>' +
      '<v:Ext xmlns:v="urn:vendor">1</v:Ext><v:Ext xmlns:v="urn:vendor">2</v:Ext>' +
      '<PerformPcnt>1,5</PerformPcnt></AwardInfo>';
    G := ReadDoc(Doc(S), Diags);
    CheckEquals(1, Diags.CountOf('GAEB-XML-001'), 'unknown element: ' + Diags.ToText);
    CheckEquals(1, Diags.CountOf('GAEB-XML-002'), 'vendor namespace once');
    CheckEquals(1, Diags.CountOf('GAEB-XML-003'), 'invalid decimal');
    CheckEquals(1, Diags.CountOf('GAEB-XML-004'), 'repetition');
    CheckEquals(1, Diags.CountOf('GAEB-XML-005'), 'BoQID after Cur is out of order');
    CheckEquals(1, Diags.CountOf('GAEB-XML-006'), 'unknown attribute');
    Check(G.Award.AwardInfo.BoQID = 'X', 'out-of-order element still read');
    Check(G.Award.AwardInfo.EvalEnd = '2026-01-01', 'first of a repetition kept');
    Check(not G.Award.AwardInfo.PerformPcnt.HasValue, 'invalid decimal dropped');
    Check(Diags[0].Line > 0, 'diagnostics have a position');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestMoreDiagnostics;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  S: AnsiString;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    { element inside a simple element, CDATA, single element repeated out
      of order, attribute on a simple element, vendor attribute }
    S := '<AwardInfo xmlns:v="urn:vendor" v:x="1"><Cur>E<b>x</b>UR</Cur>' +
      '<EvalEnd>2026-01-01</EvalEnd><SubmLoc><![CDATA[a<b]]></SubmLoc>' +
      '<Cur unit="x">USD</Cur></AwardInfo>';
    G := ReadDoc(Doc(S), Diags);
    CheckEquals(1, Diags.CountOf('GAEB-XML-008'), 'element inside a simple element: ' + Diags.ToText);
    Check(G.Award.AwardInfo.Cur = 'EUR', 'text around the skipped element kept');
    Check(G.Award.AwardInfo.SubmLoc = 'a<b', 'CDATA content');
    CheckEquals(1, Diags.CountOf('GAEB-XML-004'), 'repetition out of order is a repetition');
    CheckEquals(0, Diags.CountOf('GAEB-XML-005'), 'and not only an order problem');
    CheckEquals(0, Diags.CountOf('GAEB-XML-006'), 'the skipped repetition reports no attribute');
    CheckEquals(1, Diags.CountOf('GAEB-XML-002'), 'vendor attribute reported');
    Diags.Clear;
    G.Free;
    G := nil;
    S := '<AwardInfo><Cur unit="x">EUR</Cur></AwardInfo>';
    G := ReadDoc(Doc(S), Diags);
    CheckEquals(1, Diags.CountOf('GAEB-XML-006'), 'attribute on a simple element: ' + Diags.ToText);
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestTextInParagraph;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  S: AnsiString;
  P: TLandrixGaebXmlPTC;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    S := OneItemWith('raw<span>a</span><br/><span>b</span>');
    G := ReadDoc(Doc(S), Diags);
    CheckEquals(1, Diags.CountOf('GAEB-XML-007'), 'text in p reported');
    P := (FirstItem(G).Description.CompleteText.DetailTxt.Children[0] as TLandrixGaebXmlFTextTC).
      Children[0] as TLandrixGaebXmlPTC;
    Check(P.Children[0] is TLandrixGaebXmlTextNode, 'kept as text node, not repaired');
    Check(TLandrixGaebXmlTextNode(P.Children[0]).Text = 'raw', 'text node content');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestEmptyComplementBody;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  S: AnsiString;
  P: TLandrixGaebXmlPTC;
  TC: TLandrixGaebXmlTextComplement;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    S := OneItemWith('<span>a</span>' +
      '<TextComplement Kind="Bidder" MarkLbl="1"><ComplBodyDec/></TextComplement><span>b</span>');
    G := ReadDoc(Doc(S), Diags);
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
    P := (FirstItem(G).Description.CompleteText.DetailTxt.Children[0] as TLandrixGaebXmlFTextTC).
      Children[0] as TLandrixGaebXmlPTC;
    TC := P.Children[1] as TLandrixGaebXmlTextComplement;
    Check(TC.Kind = 'Bidder', 'complement kind');
    Check(TC.HasComplBodyDec, 'empty ComplBodyDec stays present');
    Check(not TC.ComplBodyDec.Value.HasValue, 'without value');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestGroups;
var
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  S: AnsiString;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    S := '<CnstSite><CnstSiteName>A</CnstSiteName></CnstSite><NotifSite/>' +
      '<CnstSite><CnstSiteName>B</CnstSiteName></CnstSite>' +
      '<CnstSite><CnstSiteName>C</CnstSiteName></CnstSite>';
    G := ReadDoc(Doc(S), Diags);
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
    CheckEquals(3, Integer(G.Award.CnstSiteGroup.Count), 'three sites');
    Check(G.Award.CnstSiteGroup[0].HasNotifSite, 'first site has its notification site');
    Check(not G.Award.CnstSiteGroup[1].HasNotifSite, 'second has none');
    Check(G.Award.CnstSiteGroup[2].CnstSite.CnstSiteName = 'C', 'third site');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestRejected;
var
  S: AnsiString;
  Raised: Boolean;
begin
  S := DocFor('89', '');
  Raised := False;
  try
    ReadDoc(S, nil).Free;
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'X89 is outside the model');
  S := '<?xml version="1.0"?><!DOCTYPE GAEB><GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA83/3.3"/>';
  Raised := False;
  try
    ReadDoc(S, nil).Free;
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'DOCTYPE rejected');
end;

{ ---- local corpus ---- }

var
  SweepRead, SweepSkipped, SweepFailed, SweepErrors, SweepWarnings: Integer;
  SweepFailures: TStringList;
  SweepRules: TStringList;

procedure CountRule(const ARuleId: string);
begin
  SweepRules.Add(ARuleId);
end;

procedure SweepFile(const FileName, RelName: string);
var
  Diags: TLandrixGaebDiagnostics;
  Det: TLandrixGaebDetection;
  G: TLandrixGaebXmlGAEB;
  I: TLandrixGaebListIndex;
begin
  Det := LandrixGaebDetectFile(FileName, nil, 0);
  if (Det.Format <> gfXml) or not Det.Accepted or
    not (Det.Target.Phase in [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]) or
    not ((Det.Target.Version = gv32) or (Det.Target.Version = gv33)) then
  begin
    Inc(SweepSkipped);
    Exit;
  end;
  Diags := TLandrixGaebDiagnostics.Create;
  try
    try
      G := LandrixGaebXmlReadFile(FileName, Diags, 0, Det);
      G.Free;
      Inc(SweepRead);
      for I := 0 to Diags.Count - 1 do
      begin
        CountRule(Diags[I].RuleId);
        if Diags[I].Severity >= gsError then
          Inc(SweepErrors)
        else if Diags[I].Severity = gsWarning then
          Inc(SweepWarnings);
      end;
    except
      on E: Exception do
      begin
        Inc(SweepFailed);
        SweepFailures.Add(RelName + ': ' + E.ClassName);
      end;
    end;
  finally
    Diags.Free;
  end;
end;

procedure SweepDir(const Dir, Rel: string);
var
  SR: TSearchRec;
begin
  if FindFirst(Dir + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        SweepDir(Dir + SR.Name + PathDelim, Rel + SR.Name + '/')
      else
        SweepFile(Dir + SR.Name, Rel + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TestLocalRead;
var
  Local, Rules: string;
  I, N: Integer;
begin
  Local := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim;
  if not DirectoryExists(Local) then
  begin
    Skip('tests/data/local not present');
    Exit;
  end;
  SweepRead := 0;
  SweepSkipped := 0;
  SweepFailed := 0;
  SweepErrors := 0;
  SweepWarnings := 0;
  SweepFailures := TStringList.Create;
  SweepRules := TStringList.Create;
  SweepRules.Sorted := True;
  SweepRules.Duplicates := dupAccept;
  try
    SweepDir(Local + 'xml' + PathDelim, 'xml/');
    SweepDir(Local + 'official' + PathDelim, 'official/');
    WriteLn('  Local.Read: ', SweepRead, ' file(s) read, ', SweepFailed, ' failed, ',
      SweepSkipped, ' outside the model; diagnostics: ', SweepErrors, ' error(s), ',
      SweepWarnings, ' warning(s)');
    Rules := '';
    I := 0;
    while I < SweepRules.Count do
    begin
      N := 1;
      while (I + N < SweepRules.Count) and (SweepRules[I + N] = SweepRules[I]) do
        Inc(N);
      Rules := Rules + ' ' + SweepRules[I] + '=' + IntToStr(N);
      Inc(I, N);
    end;
    if Rules <> '' then
      WriteLn('  Local.Read rules:', Rules);
    if SweepFailed > 0 then
      Fail(IntToStr(SweepFailed) + ' file(s) not read:' + sLineBreak + SweepFailures.Text);
    Check(SweepRead > 0, 'local files read');
  finally
    SweepRules.Free;
    SweepRules := nil;
    SweepFailures.Free;
    SweepFailures := nil;
  end;
end;

procedure Register;
begin
  RegisterTest('XmlReader.Minimal', TestReadMinimal);
  RegisterTest('XmlReader.TextTree', TestTextTree);
  RegisterTest('XmlReader.Diagnostics', TestDiagnostics);
  RegisterTest('XmlReader.MoreDiagnostics', TestMoreDiagnostics);
  RegisterTest('XmlReader.TextInParagraph', TestTextInParagraph);
  RegisterTest('XmlReader.EmptyComplementBody', TestEmptyComplementBody);
  RegisterTest('XmlReader.Groups', TestGroups);
  RegisterTest('XmlReader.Rejected', TestRejected);
  RegisterTest('Local.Read', TestLocalRead);
end;

end.

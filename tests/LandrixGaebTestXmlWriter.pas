{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of the generated writer (LandrixGaebXmlWriter): target values,
  decimals, modes, text blocks, read-write-read stability, and the local
  corpus (skipped when missing; prints counts only, never file content). }

unit LandrixGaebTestXmlWriter;

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
  LandrixGaebTestFramework;

const
  CRLF = #13#10;

function Doc33(const ABody: TLandrixXmlUtf8): TLandrixXmlUtf8;
begin
  Result := '<?xml version="1.0" encoding="UTF-8"?>' + CRLF +
    '<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA83/3.3">' + CRLF +
    '  <GAEBInfo><Version>3.3</Version><VersDate>2021-05</VersDate>' +
    '<Date>2026-10-21</Date><ProgSystem>Test</ProgSystem></GAEBInfo>' + CRLF +
    '  <PrjInfo><NamePrj>P</NamePrj></PrjInfo>' + CRLF +
    '  <Award><DP>83</DP>' + ABody + '</Award>' + CRLF +
    '</GAEB>' + CRLF;
end;

const
  Body =
    '<BoQ ID="B1"><BoQInfo><Name>LV</Name><LblBoQ>Test</LblBoQ><OutlCompl>AllTxt</OutlCompl>' +
    '<BoQBkdn><Type>Item</Type><Length>4</Length><Num>Yes</Num></BoQBkdn></BoQInfo>' +
    '<BoQBody><Itemlist><Item ID="I1" RNoPart="0010"><Qty>12.5</Qty><QU>m</QU>' +
    '<Description><CompleteText><DetailTxt><Text><p><span>a</span><br/><span>b</span></p>' +
    '</Text></DetailTxt><OutlineText><OutlTxt><TextOutlTxt><p><span>Kurz</span></p></TextOutlTxt>' +
    '</OutlTxt></OutlineText></CompleteText></Description></Item></Itemlist></BoQBody></BoQ>';

function Read(const S: TLandrixXmlUtf8): TLandrixGaebXmlGAEB;
var
  Det: TLandrixGaebDetection;
begin
  Result := LandrixGaebXmlReadBuffer(Pointer(S), Length(S), nil, Det);
end;

{ Default options without the check, for documents that are incomplete on
  purpose. }
function Unchecked: TLandrixGaebXmlWriteOptions;
begin
  Result := LandrixGaebXmlDefaultWriteOptions;
  Result.Check := False;
end;

function Contains(const S, Part: TLandrixXmlUtf8): Boolean;
begin
  Result := Pos(Part, S) > 0;
end;

procedure TestWriteBasics;
var
  G: TLandrixGaebXmlGAEB;
  Out1: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := Read(Doc33(Body));
  try
    Out1 := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp83),
      LandrixGaebXmlDefaultWriteOptions, Diags);
    CheckEquals(0, Integer(Diags.Count), 'no diagnostics: ' + Diags.ToText);
    Check(Contains(Out1, '<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA83/3.3">'), 'namespace of the target');
    Check(Contains(Out1, '<Qty>12.500</Qty>'), 'decimal normalized to three fraction digits');
    Check(Contains(Out1, '<p><span>a</span><br/><span>b</span></p>'), 'text block not indented');
    Check(Contains(Out1, '<Item ID="I1" RNoPart="0010">'), 'attributes');
    Check(Copy(Out1, 1, 5) = '<?xml', 'declaration, no BOM');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestStableRoundTrip;
var
  G, G2: TLandrixGaebXmlGAEB;
  Out1, Out2: TLandrixXmlUtf8;
  Target: TLandrixGaebTarget;
begin
  Target := LandrixGaebTarget(gv33, ge2021_05, gp83);
  G := Read(Doc33(Body));
  G2 := nil;
  try
    Out1 := LandrixGaebXmlWriteUtf8(G, Target, LandrixGaebXmlDefaultWriteOptions, nil);
    G2 := Read(Out1);
    Out2 := LandrixGaebXmlWriteUtf8(G2, Target, LandrixGaebXmlDefaultWriteOptions, nil);
    Check(Out1 = Out2, 'write - read - write gives the same bytes');
  finally
    G2.Free;
    G.Free;
  end;
end;

procedure TestTargetValues;
var
  G: TLandrixGaebXmlGAEB;
  S: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := TLandrixGaebXmlGAEB.Create;
  try
    G.GAEBInfo.Version := '3.1';
    G.GAEBInfo.ProgSystem := 'Test';
    G.Award.BoQ.ID := 'B1';
    S := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv32, ge2013_10, gp84),
      Unchecked, Diags);
    Check(Contains(S, 'DA84/3.2'), 'namespace of the target');
    Check(Contains(S, '<Version>3.2</Version>'), 'Version from the target');
    Check(Contains(S, '<VersDate>2013-10</VersDate>'), 'VersDate from the target');
    Check(Contains(S, '<DP>84</DP>'), 'DP from the target');
    CheckEquals(1, Diags.CountOf('GAEB-WRT-003'), 'replaced model version reported');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestDecimalTooPrecise;
var
  G: TLandrixGaebXmlGAEB;
  Diags: TLandrixGaebDiagnostics;
  Options: TLandrixGaebXmlWriteOptions;
  S: TLandrixXmlUtf8;
  Raised: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := Read(Doc33(Body));
  try
    Check((G.Award.BoQ.BoQBody.Itemlist.Children[0] as TLandrixGaebXmlItem).Qty.TrySetText('1.2345'),
      'four fraction digits');
    Raised := False;
    try
      LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp83),
        LandrixGaebXmlDefaultWriteOptions, Diags);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'never rounded: normal mode aborts');
    CheckEquals(1, Diags.CountOf('GAEB-WRT-002'), 'reported');
    Options := LandrixGaebXmlDefaultWriteOptions;
    Options.PreserveScale := True;
    { four fraction digits are invalid in the target: without the check }
    Options.Check := False;
    S := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp83), Options, nil);
    Check(Contains(S, '<Qty>1.2345</Qty>'), 'PreserveScale writes the value as it is');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestModes;
var
  G: TLandrixGaebXmlGAEB;
  Diags: TLandrixGaebDiagnostics;
  Options: TLandrixGaebXmlWriteOptions;
  S: TLandrixXmlUtf8;
  Raised: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := Read(Doc33(Body));
  try
    { AwardInfo/CtlgAssign exists in 3.3, not in 3.2 }
    with G.Award.AwardInfo.CtlgAssign.Add do
    begin
      CtlgID := 'K1';
      CtlgCode := 'C1';
    end;
    Options := LandrixGaebXmlDefaultWriteOptions;
    Raised := False;
    try
      LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv32, ge2013_10, gp83), Options, Diags);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'element not in the target aborts in normal mode');
    CheckEquals(1, Diags.CountOf('GAEB-WRT-001'), 'reported as error: ' + Diags.ToText);
    Diags.Clear;
    Options.Mode := gwmBestEffort;
    S := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv32, ge2013_10, gp83), Options, Diags);
    Check(not Contains(S, 'CtlgAssign'), 'best effort leaves it out');
    CheckEquals(1, Diags.CountOf('GAEB-WRT-001'), 'loss reported');
    Check(not Diags.HasErrors, 'as warning, not as error');
    S := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp83),
      LandrixGaebXmlDefaultWriteOptions, nil);
    Check(Contains(S, '<CtlgID>K1</CtlgID>'), 'written where allowed');
    Check(Pos('/GAEB[1]/Award[1]/AwardInfo[1]', string(Diags[Integer(Diags.Count) - 1].Path)) = 1,
      'loss reported with element path and index');
    Raised := False;
    try
      LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp81),
        LandrixGaebXmlDefaultWriteOptions, nil);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'X81 has no profile yet');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestEmptyValuesSurvive;
var
  G: TLandrixGaebXmlGAEB;
  S: TLandrixXmlUtf8;
begin
  G := Read(Doc33('<OWN><Address><Name1/><Street></Street><PCode/><City/></Address></OWN>'));
  try
    Check(G.Award.OWN.Address.Name1 = '', 'empty value reads as ''''');
    Check(G.Award.OWN.Address.IsMarkedEmpty('Name1'), 'but carries an empty mark');
    S := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp83),
      Unchecked, nil);
    Check(Contains(S, '<Name1/>') and Contains(S, '<Street/>') and Contains(S, '<City/>'),
      'empty mandatory elements written back');
    G.Award.OWN.Address.Name1 := 'Owner';
    S := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp83),
      Unchecked, nil);
    Check(Contains(S, '<Name1>Owner</Name1>'), 'a value wins over the mark');
    G.Award.OWN.Address.Clear;
    Check(not G.Award.OWN.Address.IsMarkedEmpty('Street'), 'Clear removes the marks');
  finally
    G.Free;
  end;
  G := TLandrixGaebXmlGAEB.Create;
  try
    G.Award.OWN.Address.City := 'X';
    S := LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, gp83),
      Unchecked, nil);
    Check(not Contains(S, '<Name1'), 'no placeholders for values never set');
  finally
    G.Free;
  end;
end;

{ ---- local corpus ---- }

var
  CorpusWritten, CorpusStable, CorpusFailed: Integer;
  CorpusFailures: TStringList;
  { when build/written exists, the written files are stored there for an
    external check (build/ is git-ignored; the files may hold customer data) }
  CorpusDumpDir: string;

procedure Dump(const RelName: string; const S: TLandrixXmlUtf8);
var
  Name: string;
  I: Integer;
  Stream: TFileStream;
begin
  if CorpusDumpDir = '' then
    Exit;
  Name := RelName;
  for I := 1 to Length(Name) do
    if Name[I] = '/' then
      Name[I] := '_';
  Stream := TFileStream.Create(CorpusDumpDir + Name, fmCreate);
  try
    if S <> '' then
      Stream.WriteBuffer(S[1], Length(S));
  finally
    Stream.Free;
  end;
end;

procedure CorpusFile(const FileName, RelName: string);
var
  Det: TLandrixGaebDetection;
  G, G2: TLandrixGaebXmlGAEB;
  Options: TLandrixGaebXmlWriteOptions;
  Out1, Out2: TLandrixXmlUtf8;
begin
  Det := LandrixGaebDetectFile(FileName, nil, 0);
  if (Det.Format <> gfXml) or not Det.Accepted or not (Det.Target.Phase in [gp83, gp84]) or
    not ((Det.Target.Version = gv32) or (Det.Target.Version = gv33)) or
    not LandrixGaebTargetIsSupported(Det.Target, True) then
    Exit;
  Options := LandrixGaebXmlDefaultWriteOptions;
  Options.Mode := gwmBestEffort;
  Options.PreserveScale := True;
  G := nil;
  G2 := nil;
  try
    try
      G := LandrixGaebXmlReadFile(FileName, nil, 0, Det);
      Out1 := LandrixGaebXmlWriteUtf8(G, Det.Target, Options, nil);
      Inc(CorpusWritten);
      Dump(RelName, Out1);
      G2 := LandrixGaebXmlReadBuffer(Pointer(Out1), Length(Out1), nil, Det);
      Out2 := LandrixGaebXmlWriteUtf8(G2, Det.Target, Options, nil);
      if Out1 = Out2 then
        Inc(CorpusStable)
      else
        CorpusFailures.Add(RelName + ': second write differs');
    except
      on E: Exception do
      begin
        Inc(CorpusFailed);
        CorpusFailures.Add(RelName + ': ' + E.ClassName);
      end;
    end;
  finally
    G2.Free;
    G.Free;
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

procedure TestLocalWrite;
var
  Local: string;
begin
  Local := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim;
  if not DirectoryExists(Local) then
  begin
    Skip('tests/data/local not present');
    Exit;
  end;
  CorpusWritten := 0;
  CorpusStable := 0;
  CorpusFailed := 0;
  CorpusDumpDir := RepositoryRoot + 'build' + PathDelim + 'written' + PathDelim;
  if not DirectoryExists(CorpusDumpDir) then
    CorpusDumpDir := '';
  CorpusFailures := TStringList.Create;
  try
    CorpusDir(Local + 'xml' + PathDelim, 'xml/');
    CorpusDir(Local + 'official' + PathDelim, 'official/');
    WriteLn('  Local.Write: ', CorpusWritten, ' file(s) written, ', CorpusStable, ' stable, ',
      CorpusFailed, ' failed');
    if CorpusFailures.Count > 0 then
      Fail(IntToStr(CorpusFailures.Count) + ' problem(s):' + sLineBreak + CorpusFailures.Text);
    Check(CorpusWritten > 0, 'local files written');
  finally
    CorpusFailures.Free;
    CorpusFailures := nil;
  end;
end;

procedure Register;
begin
  RegisterTest('XmlWriter.Basics', TestWriteBasics);
  RegisterTest('XmlWriter.StableRoundTrip', TestStableRoundTrip);
  RegisterTest('XmlWriter.TargetValues', TestTargetValues);
  RegisterTest('XmlWriter.DecimalTooPrecise', TestDecimalTooPrecise);
  RegisterTest('XmlWriter.Modes', TestModes);
  RegisterTest('XmlWriter.EmptyValuesSurvive', TestEmptyValuesSurvive);
  RegisterTest('Local.Write', TestLocalWrite);
end;

end.

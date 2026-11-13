{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Reading GAEB DA XML 3.0 and 3.1 into the model: the synthetic documents in
  tests/data/version3x (valid against their original schemas), the facade
  (OutputTarget 3.3/2021-05), the rejection by the check and the writer, and
  the local corpus (counts only). }

unit LandrixGaebTestXml3x;

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
  LandrixGaebRules,
  LandrixGaebBoQ,
  LandrixGaebProcess,
  LandrixGaebTestNoValues,
  LandrixGaebTestFramework;

function DataFile(const AName: string): string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'version3x' + PathDelim + AName;
end;

function ErrorCount(ADiags: TLandrixGaebDiagnostics): Integer;
var
  I: TLandrixGaebListIndex;
begin
  Result := 0;
  for I := 0 to ADiags.Count - 1 do
    if ADiags[I].Severity >= gsError then
      Inc(Result);
end;

{ Reads AName, checks its target and the diagnostics of the 3.x mapping. }
procedure CheckRead(const AName: string; AVersion: TLandrixGaebVersion; AEdition: TLandrixGaebEdition;
  APhase: TLandrixGaebPhase; ACommunication: Integer);
var
  Source: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
begin
  Source := ReadFileBytes(DataFile(AName));
  Diags := TLandrixGaebDiagnostics.Create;
  try
    G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), Diags, Det);
    try
      Check((Det.Target.Version = AVersion) and (Det.Target.Edition = AEdition) and (Det.Target.Phase = APhase),
        AName + ': detected target');
      CheckEquals(0, ErrorCount(Diags), AName + ': no reader error: ' + Diags.ToText);
      CheckEquals(1, Diags.CountOf('GAEB-XML-009'), AName + ': the list inside a list is reported');
      CheckEquals(ACommunication, Diags.CountOf('GAEB-XML-010'), AName + ': Communication is reported');
      CheckNoFileValues(Source, Diags, AName);
    finally
      G.Free;
    end;
  finally
    Diags.Free;
  end;
end;

procedure TestRead;
begin
  CheckRead('v31-2009-12.x83', gv31, ge2009_12, gp83, 1);
  CheckRead('v30.x81', gv30, ge2004_07, gp81, 0);
end;

{ Another VersDate than 2009-12 is the edition 2007-11. }
procedure TestEdition;
var
  Source: TLandrixXmlUtf8;
  P: Integer;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
begin
  Source := ReadFileBytes(DataFile('v31-2009-12.x83'));
  P := Pos(TLandrixXmlUtf8('<VersDate>2009-12</VersDate>'), Source);
  Check(P > 0, 'VersDate found');
  Source := Copy(Source, 1, P - 1) + '<VersDate>2007-06</VersDate>' + Copy(Source, P + 28, MaxInt);
  G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
  try
    Check((Det.Target.Version = gv31) and (Det.Target.Edition = ge2007_11), 'VersDate 2007-06: 3.1/2007-11');
  finally
    G.Free;
  end;
end;

{ The facade reads 3.1 and saves 3.3/2021-05; the nested list keeps its
  text. }
procedure TestFacade;
var
  Diags: TLandrixGaebDiagnostics;
  Bill: TLandrixGaebBillOfQuantities;
  Item: TLandrixGaebItem;
  Stream: TMemoryStream;
  Output: TLandrixXmlUtf8;
  Det: TLandrixGaebDetection;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := TMemoryStream.Create;
  try
    Bill := TLandrixGaebBillOfQuantities.LoadFromFile(DataFile('v31-2009-12.x83'), Diags, 0);
    try
      Check(Bill.Target.Version = gv31, 'Target is the source version');
      Check((Bill.OutputTarget.Version = gv33) and (Bill.OutputTarget.Edition = ge2021_05) and
        (Bill.OutputTarget.Phase = gp83), 'OutputTarget is 3.3/2021-05 X83');
      CheckEquals(1, Diags.CountOf('GAEB-BOQ-001'), 'the read-only source is noted');
      CheckEquals(2, Integer(Bill.AllItems.Count), 'two items');
      Item := Bill.AllItems[0] as TLandrixGaebItem;
      CheckEqualsGaebStr('01.0010', Item.OZ, 'OZ');
      CheckEqualsUtf8('12.500', Item.Qty.Text, 'quantity');
      Check(Pos('Soil class 3', string(Item.LongText)) > 0, 'text of the outer list');
      Check(Pos('Depth up to 1.25 m', string(Item.LongText)) > 0, 'text of the inner list');
      Diags.Clear;
      Bill.SaveToStream(Stream, Diags);
    finally
      Bill.Free;
    end;
    CheckEquals(0, ErrorCount(Diags), 'saved as 3.3 without error: ' + Diags.ToText);
    Output := '';
    SetLength(Output, Integer(Stream.Size));
    if Length(Output) > 0 then
      Move(Stream.Memory^, Output[1], Length(Output));
    Diags.Clear;
    Check(LandrixGaebXmlCheckBuffer(Pointer(Output), Integer(Length(Output)), Diags, Det),
      'the 3.3 output passes the check: ' + Diags.ToText);
    Check((Det.Target.Version = gv33) and (Det.Target.Edition = ge2021_05), 'the output is 3.3/2021-05');
    { the texts of both lists survive saving and reading again }
    Stream.Position := 0;
    Bill := TLandrixGaebBillOfQuantities.LoadFromStream(Stream, nil, 0);
    try
      Item := Bill.AllItems[0] as TLandrixGaebItem;
      Check(Pos('Soil class 3', string(Item.LongText)) > 0, 'saved: text of the outer list');
      Check(Pos('Depth up to 1.25 m', string(Item.LongText)) > 0, 'saved: text of the inner list');
    finally
      Bill.Free;
    end;
  finally
    Stream.Free;
    Diags.Free;
  end;
end;

{ Communication is only expected below PrjInfo; elsewhere it stays an
  unknown element. }
procedure TestCommunicationParent;
var
  Source: TLandrixXmlUtf8;
  P: Integer;
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
begin
  Source := ReadFileBytes(DataFile('v31-2009-12.x83'));
  P := Pos(TLandrixXmlUtf8('<DP>83</DP>'), Source);
  Check(P > 0, 'DP found');
  Source := Copy(Source, 1, P + 10) + '<Communication><Question>Q</Question></Communication>' +
    Copy(Source, P + 11, MaxInt);
  Diags := TLandrixGaebDiagnostics.Create;
  try
    G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), Diags, Det);
    G.Free;
    CheckEquals(1, Diags.CountOf('GAEB-XML-010'), 'below PrjInfo: GAEB-XML-010');
    CheckEquals(1, Diags.CountOf('GAEB-XML-001'), 'below Award: unknown element');
  finally
    Diags.Free;
  end;
end;

{ The award from a 3.1 request and a 3.1 bid is written in 3.3/2021-05. }
procedure TestBuildAward;
var
  Diags: TLandrixGaebDiagnostics;
  Request, Bid, Award: TLandrixGaebBillOfQuantities;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Request := nil;
  Bid := nil;
  Award := nil;
  try
    Request := TLandrixGaebBillOfQuantities.LoadFromFile(DataFile('v31-2009-12.x83'), nil, 0);
    Bid := TLandrixGaebBillOfQuantities.LoadFromFile(DataFile('v31-2009-12.x84'), nil, 0);
    Award := LandrixGaebBuildAward(Request, Bid, Diags);
    Check((Award.Target.Version = gv33) and (Award.Target.Edition = ge2021_05) and (Award.Target.Phase = gp86),
      'the award is 3.3/2021-05 X86');
    CheckEquals(2, Integer(Award.AllItems.Count), 'two items');
    CheckEqualsUtf8('2.50', (Award.AllItems[0] as TLandrixGaebItem).UP.Text, 'unit price from the bid');
    CheckEqualsUtf8('40.00', (Award.AllItems[1] as TLandrixGaebItem).UP.Text, 'second unit price');
  finally
    Award.Free;
    Bid.Free;
    Request.Free;
    Diags.Free;
  end;
end;

{ 3.x is read only and has no grammar for the check. }
procedure TestNotWrittenNotChecked;
var
  Source: TLandrixXmlUtf8;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  Raised: Boolean;
begin
  Source := ReadFileBytes(DataFile('v31-2009-12.x83'));
  Raised := False;
  try
    LandrixGaebXmlCheckBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'the check rejects 3.1');
  G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
  try
    Raised := False;
    try
      LandrixGaebXmlWriteUtf8(G, Det.Target, LandrixGaebXmlDefaultWriteOptions, nil);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'the writer rejects 3.1');
    Raised := False;
    try
      LandrixGaebCheckRules(G, Det.Target, nil);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'the business rules reject 3.1');
    Raised := False;
    try
      LandrixGaebCheckPair(G, Det.Target, G, LandrixGaebTarget(gv33, ge2021_05, gp84), nil);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'the pair rules reject 3.1 as first document');
    Raised := False;
    try
      LandrixGaebCheckPair(G, LandrixGaebTarget(gv33, ge2021_05, gp83), G, LandrixGaebTarget(gv31, ge2009_12, gp84), nil);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'the pair rules reject 3.1 as second document');
  finally
    G.Free;
  end;
end;

{ ---- local corpus: counts only ---- }

var
  LocalFiles, LocalRead, LocalTrade, LocalFailed, LocalReadErrors, LocalConverted, LocalClean: Integer;
  LocalFirstFailure: string;

procedure LocalFile(const AFileName: string);
var
  Source: TLandrixXmlUtf8;
  Det: TLandrixGaebDetection;
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  Options: TLandrixGaebXmlWriteOptions;
  Errors, Warnings: Integer;
begin
  Source := ReadFileBytes(AFileName);
  Det := LandrixGaebDetectBuffer(Pointer(Source), Integer(Length(Source)), False, nil);
  if not Det.Accepted or (Det.Format <> gfXml) or not (Det.Target.Version in [gv30, gv31]) then
    Exit;
  Inc(LocalFiles);
  if not LandrixGaebTargetIsSupported(Det.Target, False) then
  begin
    { trade phases of 3.1, DP 88: rejected on purpose }
    Inc(LocalTrade);
    Exit;
  end;
  Diags := TLandrixGaebDiagnostics.Create;
  try
    { messages of exceptions may quote the file: only the class is kept }
    try
      G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), Diags, Det);
    except
      on E: Exception do
      begin
        Inc(LocalFailed);
        if LocalFirstFailure = '' then
          LocalFirstFailure := E.ClassName;
        Exit;
      end;
    end;
    try
      Inc(LocalRead);
      Inc(LocalReadErrors, ErrorCount(Diags));
      Diags.Clear;
      Options := LandrixGaebXmlDefaultWriteOptions;
      Options.Mode := gwmBestEffort;
      LandrixGaebXmlWriteCollect(G, LandrixGaebTarget(gv33, ge2021_05, Det.Target.Phase), Options, Diags,
        Errors, Warnings);
      Inc(LocalConverted);
      if Errors = 0 then
        Inc(LocalClean);
    finally
      G.Free;
    end;
  finally
    Diags.Free;
  end;
end;

procedure LocalDir(const ADir: string);
var
  SR: TSearchRec;
begin
  if FindFirst(ADir + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        LocalDir(ADir + SR.Name + PathDelim)
      else
        LocalFile(ADir + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TestLocal;
begin
  if not DirectoryExists(LocalDataDir) then
  begin
    Skip('local corpus not present');
    Exit;
  end;
  LocalFiles := 0;
  LocalRead := 0;
  LocalTrade := 0;
  LocalFailed := 0;
  LocalReadErrors := 0;
  LocalConverted := 0;
  LocalClean := 0;
  LocalFirstFailure := '';
  LocalDir(LocalDataDir);
  WriteLn('  Local.Xml3x: ', LocalFiles, ' file(s) 3.0/3.1, ', LocalTrade, ' trade or DP 88 (not read), ',
    LocalRead, ' read with ', LocalReadErrors, ' reader error(s), ', LocalFailed, ' failed; ', LocalConverted,
    ' converted to 3.3/2021-05, ', LocalClean, ' of them without error');
  CheckEquals(0, LocalFailed, 'every readable 3.0/3.1 file is read (first failure: ' + LocalFirstFailure + ')');
  CheckEquals(LocalRead, LocalConverted, 'every file read is converted (best effort)');
end;

procedure Register;
begin
  RegisterTest('Xml3x.Read', TestRead);
  RegisterTest('Xml3x.Edition', TestEdition);
  RegisterTest('Xml3x.Facade', TestFacade);
  RegisterTest('Xml3x.NotWrittenNotChecked', TestNotWrittenNotChecked);
  RegisterTest('Xml3x.CommunicationParent', TestCommunicationParent);
  RegisterTest('Xml3x.BuildAward', TestBuildAward);
  RegisterTest('Local.Xml3x', TestLocal);
end;

end.

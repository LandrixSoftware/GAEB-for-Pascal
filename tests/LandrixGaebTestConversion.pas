{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of LandrixGaebCheckConversion with the synthetic 3.0/3.1 documents
  of tests/data/version3x. }

unit LandrixGaebTestConversion;

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
  LandrixGaebXmlCheck,
  LandrixGaebBoQ,
  LandrixGaebConversion,
  LandrixGaebTestNoValues,
  LandrixGaebTestFramework;

function DataFile(const AName: string): string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'version3x' + PathDelim + AName;
end;

function StateText(AState: TLandrixGaebConversionState): string;
begin
  case AState of
    gcrNotRun:
      Result := 'not run';
    gcrPassed:
      Result := 'passed';
  else
    Result := 'failed';
  end;
end;

procedure CheckState(AExpected, AActual: TLandrixGaebConversionState; const AWhat: string);
begin
  CheckEqualsStr(StateText(AExpected), StateText(AActual), AWhat);
end;

function StreamText(AStream: TMemoryStream): TLandrixXmlUtf8;
begin
  Result := '';
  SetLength(Result, Integer(AStream.Size));
  if Length(Result) > 0 then
    Move(AStream.Memory^, Result[1], Length(Result));
end;

{ A 3.1 request converts to 3.3 without loss; the output is handed out and
  passes the check; the bill and the reader's list stay as they were. }
procedure TestPassed;
var
  ReadDiags, Diags: TLandrixGaebDiagnostics;
  Bill: TLandrixGaebBillOfQuantities;
  Stream: TMemoryStream;
  R: TLandrixGaebConversionResult;
  Output: TLandrixXmlUtf8;
  Det: TLandrixGaebDetection;
  ReadCount: Integer;
begin
  ReadDiags := TLandrixGaebDiagnostics.Create;
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := TMemoryStream.Create;
  try
    Bill := TLandrixGaebBillOfQuantities.LoadFromFile(DataFile('v31-2009-12.x83'), ReadDiags, 0);
    try
      ReadCount := Integer(ReadDiags.Count);
      R := LandrixGaebCheckConversion(Bill, Bill.OutputTarget, Diags, Stream);
      Check((R.OutputTarget.Version = gv33) and (R.OutputTarget.Edition = ge2021_05) and
        (R.OutputTarget.Phase = gp83), 'the target checked');
      CheckState(gcrPassed, R.Writing, 'writing: ' + Diags.ToText);
      CheckState(gcrPassed, R.Structure, 'structure: ' + Diags.ToText);
      CheckState(gcrPassed, R.Rules, 'rules: ' + Diags.ToText);
      CheckEquals(0, Diags.CountOf('GAEB-CNV-002'), 'every check ran');
      CheckEquals(ReadCount, Integer(ReadDiags.Count), 'the reader''s list is not touched');
      Check(Bill.Target.Version = gv31, 'the bill keeps its target');
      CheckEquals(2, Integer(Bill.AllItems.Count), 'the bill keeps its items');
    finally
      Bill.Free;
    end;
    Output := StreamText(Stream);
    Check(Length(Output) > 0, 'the output is handed out');
    Diags.Clear;
    Check(LandrixGaebXmlCheckBuffer(Pointer(Output), Integer(Length(Output)), Diags, Det),
      'the handed out output passes the check: ' + Diags.ToText);
    Check((Det.Target.Version = gv33) and (Det.Target.Phase = gp83), 'the output is 3.3 X83');
  finally
    Stream.Free;
    Diags.Free;
    ReadDiags.Free;
  end;
end;

{ A bid saved as a request loses its prices and totals: writing fails. The
  slim bid also lacks the texts a request requires, so the content model
  check and the rules of the output fail as well: every check runs. }
procedure TestLoss;
var
  Diags: TLandrixGaebDiagnostics;
  Bill: TLandrixGaebBillOfQuantities;
  R: TLandrixGaebConversionResult;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Bill := TLandrixGaebBillOfQuantities.LoadFromFile(DataFile('v31-2009-12.x84'), nil, 0);
    try
      R := LandrixGaebCheckConversion(Bill, LandrixGaebTarget(gv33, ge2021_05, gp83), Diags, nil);
      CheckState(gcrFailed, R.Writing, 'writing');
      Check(Diags.CountOf('GAEB-WRT-001') > 0, 'the losses are reported: ' + Diags.ToText);
      CheckState(gcrFailed, R.Structure, 'structure: ' + Diags.ToText);
      Check(Diags.CountOf('GAEB-CHK-001') > 0, 'texts missing in the request');
      CheckState(gcrFailed, R.Rules, 'rules: ' + Diags.ToText);
      Check(Diags.CountOf('GAEB-BR-ITEM-001') > 0, 'items without description');
      Check(Bill.Target.Phase = gp84, 'the bill stays a bid');
      CheckNoFileValues(ReadFileBytes(DataFile('v31-2009-12.x84')), Diags, 'conversion findings');
    finally
      Bill.Free;
    end;
  finally
    Diags.Free;
  end;
end;

{ Two items with the same OZ: writing and structure pass, the rules fail. }
procedure TestRulesFail;
var
  Diags: TLandrixGaebDiagnostics;
  Bill: TLandrixGaebBillOfQuantities;
  Item: TLandrixGaebItem;
  R: TLandrixGaebConversionResult;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Bill := TLandrixGaebBillOfQuantities.LoadFromFile(DataFile('v30.x81'), nil, 0);
    try
      Item := Bill.AllItems[0] as TLandrixGaebItem;
      Bill.AddItem(Item.Parent, '0010');
      R := LandrixGaebCheckConversion(Bill, Bill.OutputTarget, Diags, nil);
      CheckState(gcrPassed, R.Writing, 'writing: ' + Diags.ToText);
      CheckState(gcrPassed, R.Structure, 'structure: ' + Diags.ToText);
      CheckState(gcrFailed, R.Rules, 'rules: ' + Diags.ToText);
      Check(Diags.CountOf('GAEB-BR-OZ-001') > 0, 'the duplicate OZ is found: ' + Diags.ToText);
    finally
      Bill.Free;
    end;
  finally
    Diags.Free;
  end;
end;

{ Lists nested directly in lists get a list item each when read, so the
  output nests twice as deep as the input: beyond the limit of the XML
  reader the content model check fails with GAEB-CNV-003 instead of
  raising, and the rules do not run. }
procedure TestTooDeep;
const
  Depth = 130;
var
  Source, Lists: TLandrixXmlUtf8;
  Input: TMemoryStream;
  Diags: TLandrixGaebDiagnostics;
  Bill: TLandrixGaebBillOfQuantities;
  R: TLandrixGaebConversionResult;
  I: Integer;
begin
  Source := ReadFileBytes(DataFile('v31-2009-12.x83'));
  Lists := '';
  for I := 1 to Depth do
    Lists := Lists + '<ul>';
  Lists := Lists + '<li><p><span>x</span></p></li>';
  for I := 1 to Depth do
    Lists := Lists + '</ul>';
  I := Pos(TLandrixXmlUtf8('<p><span>Dispose of the soil.</span></p>'), Source);
  Check(I > 0, 'marker found');
  Source := Copy(Source, 1, I - 1) + Lists +
    Copy(Source, I + Length('<p><span>Dispose of the soil.</span></p>'), MaxInt);
  Input := TMemoryStream.Create;
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Input.WriteBuffer(Source[1], Length(Source));
    Input.Position := 0;
    Bill := TLandrixGaebBillOfQuantities.LoadFromStream(Input, nil, 0);
    try
      R := LandrixGaebCheckConversion(Bill, Bill.OutputTarget, Diags, nil);
      CheckState(gcrPassed, R.Writing, 'writing: ' + Diags.ToText);
      CheckState(gcrFailed, R.Structure, 'structure');
      CheckEquals(1, Diags.CountOf('GAEB-CNV-003'), 'the output exceeds the reader: ' + Diags.ToText);
      CheckState(gcrNotRun, R.Rules, 'rules');
      CheckEquals(1, Diags.CountOf('GAEB-CNV-002'), 'the rules did not run');
    finally
      Bill.Free;
    end;
  finally
    Diags.Free;
    Input.Free;
  end;
end;

{ Without diagnostics; the output is appended at the position of the
  stream; nothing is appended when no output arises. }
procedure TestStream;
var
  Bill: TLandrixGaebBillOfQuantities;
  Stream: TMemoryStream;
  R: TLandrixGaebConversionResult;
  Text: TLandrixXmlUtf8;
  Before: TLandrixGaebXmlWriteOptions;
begin
  Stream := TMemoryStream.Create;
  try
    Stream.WriteBuffer(PAnsiChar('KEEP')^, 4);
    Bill := TLandrixGaebBillOfQuantities.LoadFromFile(DataFile('v31-2009-12.x83'), nil, 0);
    try
      Before := Bill.WriteOptions;
      R := LandrixGaebCheckConversion(Bill, Bill.OutputTarget, nil, Stream);
      CheckState(gcrPassed, R.Writing, 'writing without diagnostics');
      CheckState(gcrPassed, R.Rules, 'rules without diagnostics');
      Check(Bill.WriteOptions.Mode = Before.Mode, 'the write options of the bill stay');
      Check(Bill.WriteOptions.Check = Before.Check, 'the check option of the bill stays');
      Text := StreamText(Stream);
      CheckEqualsUtf8('KEEP', Copy(Text, 1, 4), 'the earlier content stays');
      Check(Pos(TLandrixXmlUtf8('<GAEB'), Text) > 4, 'the output follows it');
      (Bill.AllItems[0] as TLandrixGaebItem).SetShortText('A' + TLandrixGaebString(#1) + 'B');
      Stream.Clear;
      Stream.WriteBuffer(PAnsiChar('KEEP')^, 4);
      LandrixGaebCheckConversion(Bill, Bill.OutputTarget, nil, Stream);
      CheckEquals(4, Integer(Stream.Size), 'nothing appended without output');
    finally
      Bill.Free;
    end;
  finally
    Stream.Free;
  end;
end;

{ A character XML cannot carry: no output, the later checks do not run. }
procedure TestNotWritable;
var
  Diags: TLandrixGaebDiagnostics;
  Bill: TLandrixGaebBillOfQuantities;
  Stream: TMemoryStream;
  R: TLandrixGaebConversionResult;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := TMemoryStream.Create;
  try
    Bill := TLandrixGaebBillOfQuantities.LoadFromFile(DataFile('v31-2009-12.x83'), nil, 0);
    try
      (Bill.AllItems[0] as TLandrixGaebItem).SetShortText('A' + TLandrixGaebString(#1) + 'B');
      R := LandrixGaebCheckConversion(Bill, Bill.OutputTarget, Diags, Stream);
      CheckState(gcrFailed, R.Writing, 'writing');
      CheckState(gcrNotRun, R.Structure, 'structure');
      CheckState(gcrNotRun, R.Rules, 'rules');
      CheckEquals(1, Diags.CountOf('GAEB-CNV-001'), 'not written: ' + Diags.ToText);
      CheckEquals(2, Diags.CountOf('GAEB-CNV-002'), 'two checks did not run');
      CheckEquals(0, Integer(Stream.Size), 'nothing handed out');
      CheckNoFileValues(ReadFileBytes(DataFile('v31-2009-12.x83')), Diags, 'conversion findings');
    finally
      Bill.Free;
    end;
  finally
    Stream.Free;
    Diags.Free;
  end;
end;

procedure TestRaises;
var
  Bill: TLandrixGaebBillOfQuantities;
  Raised: Boolean;
begin
  Raised := False;
  try
    LandrixGaebCheckConversion(nil, LandrixGaebTarget(gv33, ge2021_05, gp83), nil, nil);
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'no bill');
  Bill := TLandrixGaebBillOfQuantities.LoadFromFile(DataFile('v31-2009-12.x83'), nil, 0);
  try
    Raised := False;
    try
      LandrixGaebCheckConversion(Bill, Bill.Target, nil, nil);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, '3.1 cannot be written');
  finally
    Bill.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Conversion.Passed', TestPassed);
  RegisterTest('Conversion.Loss', TestLoss);
  RegisterTest('Conversion.RulesFail', TestRulesFail);
  RegisterTest('Conversion.NotWritable', TestNotWritable);
  RegisterTest('Conversion.TooDeep', TestTooDeep);
  RegisterTest('Conversion.Stream', TestStream);
  RegisterTest('Conversion.Raises', TestRaises);
end;

end.

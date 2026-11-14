{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of LandrixGaebDA2000Reader and of loading GAEB DA 2000 into the
  bill of quantities (LoadFromFile/LoadFromStream, LoadFromDA2000File/
  Stream, LandrixGaebFillMissingTotals), and the local corpus loaded
  through the facade (skipped when missing; counts only, never values). }

unit LandrixGaebTestDA2000Reader;

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
  LandrixGaebXmlWriter,
  LandrixGaebXmlCheck,
  LandrixGaebBoQ,
  LandrixGaebProcess,
  LandrixGaebDA2000Reader,
  LandrixGaebTestFramework;

const
  CRLF = #13#10;

function Lines(const A: array of AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Integer(High(A)) do
    Result := Result + A[I] + CRLF;
end;

{ Header up to the owner; ACharset is the Zeichensatz line ('' for none),
  AName the project name. }
function Head(const DP, ACharset, AName: AnsiString): AnsiString;
begin
  Result := Lines(['#begin[GAEB]', '#begin[GAEBInfo]', '[Version]1.2[end]',
    '[Datum]14.11.2026[end]', '[Uhrzeit]10:30[end]', '[ProgSystem]Test[end]']);
  if ACharset <> '' then
    Result := Result + Lines(['[Zeichensatz]' + ACharset + '[end]']);
  Result := Result + Lines(['#end[GAEBInfo]', '#begin[PrjInfo]', '[Name]' + AName + '[end]',
    '[Bez]Projekt[end]', '[Wae]EUR[end]', '#end[PrjInfo]', '#begin[Vergabe]',
    '[DP]' + DP + '[end]', '#begin[VergabeInfo]', '[Wae]EUR[end]', '#end[VergabeInfo]',
    '#begin[AG]', '#begin[Adresse]', '[Name1]Bauherr[end]', '#end[Adresse]', '#end[AG]']);
end;

function Position(const AOZ, AGB: AnsiString): AnsiString;
begin
  Result := Lines(['#begin[Position]', '[OZ]' + AOZ + '[end]', '[Menge]1[end]', '[ME]St[end]',
    '[EP]' + AGB + '[end]', '[GB]' + AGB + '[end]', '#begin[Beschreibung]', '[Kurztext]Pos[end]',
    '#end[Beschreibung]', '#end[Position]']);
end;

{ An item for a provision only (Bedarf E): it does not count. }
function Provisional(const AOZ, AGB: AnsiString): AnsiString;
begin
  Result := Lines(['#begin[Position]', '[OZ]' + AOZ + '[end]', '[Menge]1[end]', '[ME]St[end]',
    '[Bedarf]E[end]', '[GB]' + AGB + '[end]', '#end[Position]']);
end;

{ Three categories: 01 without Summe (and a provisional item), 02 with an unusable Summe, 03 with
  a Summe that differs from its items; the LV has no Summe. }
function PricedWith(const DP, ASumme02: AnsiString): AnsiString;
begin
  Result := Head(DP, 'ANSI', 'P1') + Lines(['#begin[LV]', '#begin[LVInfo]', '[Name]LV1[end]',
    '#begin[LVGlied]', '[Typ]LVStufe[end]', '[Laenge]2[end]', '#end[LVGlied]',
    '#begin[LVGlied]', '[Typ]Position[end]', '[Laenge]4[end]', '#end[LVGlied]',
    '#end[LVInfo]', '#begin[LVBereich]', '[OZ]01[end]', '[Bez]Eins[end]']) +
    Position('010010', '100,00') + Position('010020', '50,50') + Provisional('010030', '1000,00') +
    Lines(['#end[LVBereich]', '#begin[LVBereich]', '[OZ]02[end]', '[Bez]Zwei[end]']) + ASumme02 +
    Position('020010', '10,00') +
    Lines(['#end[LVBereich]', '#begin[LVBereich]', '[OZ]03[end]', '[Bez]Drei[end]', '[Summe]999,00[end]']) +
    Position('030010', '5,00') +
    Lines(['#end[LVBereich]', '#end[LV]', '#end[Vergabe]', '#end[GAEB]']);
end;

function DataDir(const ASub: string): string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + ASub + PathDelim;
end;

{ 'A' followed by the character ACode. }
function AWith(ACode: Word): TLandrixGaebString;
begin
  Result := 'A';
  Result := Result + WideChar(ACode);
end;

function Priced(const DP: AnsiString): AnsiString;
begin
  Result := PricedWith(DP, Lines(['[Summe]abc[end]']));
end;

function StreamOf(const S: AnsiString): TMemoryStream;
begin
  Result := TMemoryStream.Create;
  if S <> '' then
    Result.WriteBuffer(S[1], Length(S));
  Result.Position := 0;
end;

function TotalText(ATotals: TLandrixGaebTotals): string;
begin
  Result := LandrixXmlUtf8ToString(ATotals.Value(gtfTotal).Text);
end;

procedure TestReadBuffer;
var
  S: AnsiString;
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  T: TLandrixGaebTarget;
begin
  S := Priced('83');
  Diags := TLandrixGaebDiagnostics.Create;
  try
    G := LandrixGaebDA2000ReadBuffer(Pointer(S), Length(S), LandrixGaebDA2000DefaultReadOptions, Diags, Det, T);
    try
      Check(Det.Format = gfDA2000, 'format of the input');
      Check(Det.Target.Version = gvUnknown, 'the detection keeps no target');
      CheckEqualsStr('1.2', Det.SourceVersion, 'version as found');
      CheckEqualsStr('83', Det.SourcePhase, 'phase as found');
      Check(Det.SourceCharset = gcsAnsi, 'declared character set');
      Check((T.Version = gv33) and (T.Edition = ge2021_05) and (T.Phase = gp83), 'mapped target');
      CheckEquals(3, Integer(G.Award.BoQ.BoQBody.Children.Count), 'categories mapped');
      { the reader maps only: no total is computed }
      CheckEquals(0, Diags.CountOf('GAEB-PRC-005'), 'nothing filled by the reader');
      CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-008'), 'unusable Summe reported');
    finally
      G.Free;
    end;
    { the character set is reported once, by the parser }
    Diags.Clear;
    S := Head('83', '', 'P1') + Lines(['#end[Vergabe]', '#end[GAEB]']);
    LandrixGaebDA2000ReadBuffer(Pointer(S), Length(S), LandrixGaebDA2000DefaultReadOptions, Diags, Det, T).Free;
    CheckEquals(0, Diags.CountOf('GAEB-DET-014'), 'no detection message on the character set');
    CheckEquals(1, Diags.CountOf('GAEB-BR-D2000-006'), 'parser message on the character set');
  finally
    Diags.Free;
  end;
end;

procedure TestCharsetOption;
var
  S: AnsiString;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  T: TLandrixGaebTarget;
  Options: TLandrixGaebDA2000ReadOptions;
begin
  { byte $84 is a lower case a umlaut in code page 850, a low double
    quotation mark in Windows-1252 }
  S := Head('83', 'ANSI', 'A' + #$84) + Lines(['#end[Vergabe]', '#end[GAEB]']);
  Options := LandrixGaebDA2000DefaultReadOptions;
  G := LandrixGaebDA2000ReadBuffer(Pointer(S), Length(S), Options, nil, Det, T);
  try
    CheckEqualsGaebStr(AWith($201E), G.PrjInfo.NamePrj, 'as declared: Windows-1252');
  finally
    G.Free;
  end;
  Options.Charset := gcsOem;
  G := LandrixGaebDA2000ReadBuffer(Pointer(S), Length(S), Options, nil, Det, T);
  try
    CheckEqualsGaebStr(AWith($00E4), G.PrjInfo.NamePrj, 'overridden: code page 850');
    Check(Det.SourceCharset = gcsAnsi, 'SourceCharset stays the declared one');
  finally
    G.Free;
  end;
end;

procedure TestRejected;
var
  S: AnsiString;
  Det: TLandrixGaebDetection;
  T: TLandrixGaebTarget;
  Options: TLandrixGaebDA2000ReadOptions;
  Stream: TMemoryStream;
  Raised: Boolean;
begin
  { XML is no GAEB DA 2000 }
  S := '<?xml version="1.0"?><GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA83/3.3"/>';
  Raised := False;
  try
    LandrixGaebDA2000ReadBuffer(Pointer(S), Length(S), LandrixGaebDA2000DefaultReadOptions, nil, Det, T).Free;
  except
    on E: ELandrixGaebError do
      Raised := Pos('GAEB DA 2000', E.Message) > 0;
  end;
  Check(Raised, 'XML rejected');
  { the message names no value of the input }
  S := '<?xml version="1.0"?><GAEB xmlns="urn:example:PRIVATE-123"/>';
  Raised := False;
  try
    LandrixGaebDA2000ReadBuffer(Pointer(S), Length(S), LandrixGaebDA2000DefaultReadOptions, nil, Det, T).Free;
  except
    on E: ELandrixGaebError do
    begin
      Raised := True;
      Check(Pos('PRIVATE', E.Message) = 0, 'no value in the message: ' + E.Message);
    end;
  end;
  Check(Raised, 'unknown namespace rejected');
  { the size limit holds for buffers and streams; a stream is not read }
  S := Priced('83');
  Options := LandrixGaebDA2000DefaultReadOptions;
  Options.MaxSize := 100;
  Raised := False;
  try
    LandrixGaebDA2000ReadBuffer(Pointer(S), Length(S), Options, nil, Det, T).Free;
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'buffer over the size limit');
  Stream := StreamOf(S);
  try
    Raised := False;
    try
      LandrixGaebDA2000ReadStream(Stream, Options, nil, Det, T).Free;
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'stream over the size limit');
    CheckEqualsInt64(0, Stream.Position, 'stream not read');
    Raised := False;
    try
      TLandrixGaebBillOfQuantities.LoadFromStream(Stream, nil, 100).Free;
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'the facade passes AMaxSize on');
  finally
    Stream.Free;
  end;
end;

procedure TestLoadBill;
var
  Stream: TMemoryStream;
  Diags: TLandrixGaebDiagnostics;
  B: TLandrixGaebBillOfQuantities;
  Options: TLandrixGaebDA2000ReadOptions;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := StreamOf(Priced('82'));
  try
    B := TLandrixGaebBillOfQuantities.LoadFromStream(Stream, Diags, 0);
    try
      Check(B.SourceFormat = gfDA2000, 'read from GAEB DA 2000');
      CheckEqualsStr('1.2', B.Source.SourceVersion, 'source version');
      Check((B.Target.Version = gv33) and (B.Target.Phase = gp82), 'target');
      Check((B.OutputTarget.Version = gv33) and (B.OutputTarget.Edition = ge2021_05), 'output target');
      CheckEquals(1, Diags.CountOf('GAEB-BOQ-002'), 'reading noted');
      CheckEqualsStr('150.5', TotalText(TLandrixGaebCategory(B.Root[0]).Totals), 'missing total computed');
      Check(not TLandrixGaebCategory(B.Root[1]).Totals.Value(gtfTotal).HasValue,
        'unusable Summe stays missing');
      CheckEqualsStr('999.00', TotalText(TLandrixGaebCategory(B.Root[2]).Totals), 'Summe of the file kept');
      { the bill: 150.50 + 10.00 + 5.00; categories add their items, never
        their Total }
      CheckEqualsStr('165.5', TotalText(B.Totals), 'total of the bill computed');
      CheckEquals(1, Diags.CountOf('GAEB-PRC-005'), 'filled totals reported');
      Check(Pos('2 missing', Diags.ToText) > 0, 'two totals filled: ' + Diags.ToText);
      CheckEquals(0, Diags.CountOf('GAEB-PRC-006'), 'nothing left missing');
    finally
      B.Free;
    end;
    { with options }
    Diags.Clear;
    Stream.Position := 0;
    Options := LandrixGaebDA2000DefaultReadOptions;
    Options.Charset := gcsOem;
    B := TLandrixGaebBillOfQuantities.LoadFromDA2000Stream(Stream, Options, Diags);
    try
      Check(B.SourceFormat = gfDA2000, 'LoadFromDA2000Stream: format');
      CheckEquals(3, B.Root.Count, 'LoadFromDA2000Stream: categories');
    finally
      B.Free;
    end;
  finally
    Stream.Free;
    Diags.Free;
  end;
  { a Summe written as an object is unusable as well }
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := StreamOf(PricedWith('82', Lines(['#begin[Summe]', '[Wert]1[end]', '#end[Summe]'])));
  try
    B := TLandrixGaebBillOfQuantities.LoadFromStream(Stream, Diags, 0);
    try
      Check(not TLandrixGaebCategory(B.Root[1]).Totals.Value(gtfTotal).HasValue,
        'Summe as an object stays missing');
    finally
      B.Free;
    end;
  finally
    Stream.Free;
    Diags.Free;
  end;
  { a request X83 has no totals: none is added }
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := StreamOf(Priced('83'));
  try
    B := TLandrixGaebBillOfQuantities.LoadFromStream(Stream, Diags, 0);
    try
      Check(not TLandrixGaebCategory(B.Root[0]).Totals.Value(gtfTotal).HasValue, 'X83: no total added');
      CheckEquals(0, Diags.CountOf('GAEB-PRC-005') + Diags.CountOf('GAEB-PRC-006'), 'X83: nothing reported');
    finally
      B.Free;
    end;
  finally
    Stream.Free;
    Diags.Free;
  end;
  { a bid counts by the kinds its GAEB DA 2000 file holds }
  Diags := TLandrixGaebDiagnostics.Create;
  Stream := StreamOf(Priced('84'));
  try
    B := TLandrixGaebBillOfQuantities.LoadFromStream(Stream, Diags, 0);
    try
      CheckEqualsStr('150.5', TotalText(TLandrixGaebCategory(B.Root[0]).Totals), 'bid: total computed');
      CheckEqualsStr('165.5', TotalText(B.Totals), 'bid: total of the bill computed');
      CheckEquals(0, Diags.CountOf('GAEB-PRC-006'), 'bid: nothing left missing');
      { without the kinds a bid has unknown count status }
      TLandrixGaebCategory(B.Root[0]).Totals.ClearValue(gtfTotal);
      CheckEquals(0, LandrixGaebFillMissingTotals(B, nil, Diags), 'bid without kinds: nothing written');
      CheckEquals(1, Diags.CountOf('GAEB-PRC-006'), 'bid without kinds: left missing reported');
    finally
      B.Free;
    end;
  finally
    Stream.Free;
    Diags.Free;
  end;
end;

procedure TestSourceOfOtherBills;
var
  B: TLandrixGaebBillOfQuantities;
begin
  B := TLandrixGaebBillOfQuantities.Create(TLandrixGaebXmlGAEB.Create,
    LandrixGaebTarget(gv33, ge2021_05, gp83), True);
  try
    Check(B.SourceFormat = gfUnknown, 'made with Create: unknown');
  finally
    B.Free;
  end;
  B := TLandrixGaebBillOfQuantities.LoadFromFile(DataDir('process') + 'request.x83', nil, 0);
  try
    Check(B.SourceFormat = gfXml, 'loaded from XML');
    Check(B.Source.Target.Phase = gp83, 'the detection of the XML file');
  finally
    B.Free;
  end;
end;

var
  LocalFiles, LocalLoaded, LocalValid, LocalFilled, LocalLeft: Integer;
  { with LANDRIX_CHECKPATHS set: rule and path (without indexes) of the
    findings of the check, counted }
  LocalPaths: TStringList;
  LocalPathCounts: array of Integer;

function StripIndexes(const APath: TLandrixGaebString): string;
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
      Result := Result + Char(Ord(APath[I]));
end;

procedure LoadLocalFile(const FileName: string);
var
  Diags, CheckDiags: TLandrixGaebDiagnostics;
  B: TLandrixGaebBillOfQuantities;
  Options: TLandrixGaebXmlWriteOptions;
  Xml: TLandrixXmlUtf8;
  Errors, Warnings, I, K: Integer;
  Key: string;
begin
  if LandrixGaebDetectFile(FileName, nil, 0).Format <> gfDA2000 then
    Exit;
  Inc(LocalFiles);
  Diags := TLandrixGaebDiagnostics.Create;
  CheckDiags := TLandrixGaebDiagnostics.Create;
  try
    try
      B := TLandrixGaebBillOfQuantities.LoadFromFile(FileName, Diags, 0);
    except
      on ELandrixGaebError do
        B := nil;
    end;
    if B = nil then
      Exit;
    try
      Inc(LocalLoaded);
      Inc(LocalFilled, Diags.CountOf('GAEB-PRC-005'));
      Inc(LocalLeft, Diags.CountOf('GAEB-PRC-006'));
      Options := LandrixGaebXmlDefaultWriteOptions;
      Options.Mode := gwmBestEffort;
      Options.Check := False;
      Xml := LandrixGaebXmlWriteCollect(B.Document, B.OutputTarget, Options, Diags, Errors, Warnings);
      if LandrixGaebXmlCheckTarget(Pointer(Xml), Length(Xml), B.OutputTarget, CheckDiags) then
        Inc(LocalValid);
      if LocalPaths <> nil then
        for I := 0 to Integer(CheckDiags.Count) - 1 do
        begin
          Key := CheckDiags[I].RuleId + ' DA' + LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(B.OutputTarget.Phase)) +
            ' ' + StripIndexes(CheckDiags[I].Path) + ': ' + Copy(CheckDiags[I].Message, 1, 50);
          K := LocalPaths.IndexOf(Key);
          if K < 0 then
          begin
            K := LocalPaths.Add(Key);
            SetLength(LocalPathCounts, K + 1);
            LocalPathCounts[K] := 0;
          end;
          Inc(LocalPathCounts[K]);
        end;
    finally
      B.Free;
    end;
  finally
    CheckDiags.Free;
    Diags.Free;
  end;
end;

procedure WalkLocal(const Dir: string);
var
  SR: TSearchRec;
begin
  if FindFirst(Dir + '*', faAnyFile, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        WalkLocal(Dir + SR.Name + PathDelim)
      else
        LoadLocalFile(Dir + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TestLocalLoad;
var
  I: Integer;
begin
  if not DirectoryExists(LocalDataDir) then
  begin
    Skip('local corpus not present');
    Exit;
  end;
  LocalFiles := 0;
  LocalLoaded := 0;
  LocalValid := 0;
  LocalFilled := 0;
  LocalLeft := 0;
  LocalPaths := nil;
  LocalPathCounts := nil;
  if GetEnvironmentVariable('LANDRIX_CHECKPATHS') <> '' then
    LocalPaths := TStringList.Create;
  try
    WalkLocal(LocalDataDir);
    if LocalPaths <> nil then
      for I := 0 to LocalPaths.Count - 1 do
        WriteLn('    ', LocalPathCounts[I]: 6, '  ', LocalPaths[I]);
  finally
    LocalPaths.Free;
    LocalPaths := nil;
  end;
  WriteLn('  Local.DA2000Load: ', LocalFiles, ' file(s), ', LocalLoaded, ' loaded into the bill, ',
    LocalValid, ' valid against the content model; ', LocalFilled, ' with totals filled, ',
    LocalLeft, ' with totals left missing');
  Check(LocalFiles > 0, 'GAEB DA 2000 files found');
end;

procedure Register;
begin
  RegisterTest('DA2000Reader.ReadBuffer', TestReadBuffer);
  RegisterTest('DA2000Reader.CharsetOption', TestCharsetOption);
  RegisterTest('DA2000Reader.Rejected', TestRejected);
  RegisterTest('DA2000Reader.LoadBill', TestLoadBill);
  RegisterTest('DA2000Reader.SourceOfOtherBills', TestSourceOfOtherBills);
  RegisterTest('Local.DA2000Load', TestLocalLoad);
end;

end.

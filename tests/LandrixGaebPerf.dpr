{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Performance and memory measurement (plan, phase 1 step 11): writes a
  synthetic X83 (3.3/2021-05) of about SizeMB megabytes in memory (two
  category levels, items with quantity, unit, a long text of three
  paragraphs and an outline text; all text invented), then measures

    read    LandrixGaebXmlReadBuffer, with the heap the model takes
    check   LandrixGaebXmlCheckBuffer (content models, stage 2)
    rules   LandrixGaebCheckRules (stage 3)
    write   LandrixGaebXmlWriteUtf8 without and with the check of the output,
            and LandrixGaebXmlWriteFile (next to the program, deleted again)
    xsd     the LandrixXml validator against the GAEB XSD, if Specification/
            is present under the repository root
    free    the heap after freeing the model (must be back where it was)

  Times in milliseconds. The peak working set is measured from outside
  (tools/perf.ps1). Exit code 1 if the document draws a diagnostic, so a
  measurement never runs on a path that real files do not take.

  Usage: LandrixGaebPerf [SizeMB] [repository-root] [-wait]
    -wait: print "done" at the end and wait for a line on standard input,
           so tools/perf.ps1 reads the peak working set of the whole run
           before the process exits }

program LandrixGaebPerf;

{$I LandrixGaeb.inc}

{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

{$IFNDEF FPC}
  { the heap counters of the memory manager are Windows-only in Delphi }
  {$WARN SYMBOL_PLATFORM OFF}
{$ENDIF}

uses
  SysUtils,
  LandrixXmlBase,
  LandrixXmlReader,
  LandrixXmlWriter,
  LandrixXmlXsdSchema,
  LandrixXmlXsdSchemaLoader,
  LandrixXmlXsdValidator,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebXmlWriteBase,
  LandrixGaebXmlWriter,
  LandrixGaebXmlCheck,
  LandrixGaebRules;

const
  GaebNs: TLandrixXmlUtf8 = 'http://www.gaeb.de/GAEB_DA_XML/DA83/3.3';
  ItemsPerCategory = 500;
  CategoriesPerTitle = 20;

var
  Failed: Boolean;

{ Bytes allocated on the heap. }
function HeapUsed: Int64;
{$IFNDEF FPC}
  {$IF CompilerVersion >= 18.0}
var
  S: TMemoryManagerState;
  I: Integer;
  {$IFEND}
{$ENDIF}
begin
{$IFDEF FPC}
  Result := GetFPCHeapStatus.CurrHeapUsed;
{$ELSE}
  {$IF CompilerVersion >= 18.0}
  GetMemoryManagerState(S);
  Result := Int64(S.TotalAllocatedMediumBlockSize) + Int64(S.TotalAllocatedLargeBlockSize);
  for I := Low(S.SmallBlockTypeStates) to High(S.SmallBlockTypeStates) do
    Result := Result + Int64(S.SmallBlockTypeStates[I].AllocatedBlockCount) *
      Int64(S.SmallBlockTypeStates[I].UseableBlockSize);
  {$ELSE}
  Result := GetHeapStatus.TotalAllocated;
  {$IFEND}
{$ENDIF}
end;

{$IFNDEF FPC}
  {$IF CompilerVersion < 18.0}
    {$DEFINE PRIVATE_BYTES}
  {$IFEND}
{$ENDIF}

{$IFDEF PRIVATE_BYTES}
{ Delphi 6/7: TLandrixGaebString is WideString, whose memory comes from the
  COM allocator, not from the Delphi heap; the committed private memory of
  the process covers both. Win32 only (SIZE_T fields as Cardinal). }
type
  TProcessMemoryCounters = record
    cb: Cardinal;
    PageFaultCount: Cardinal;
    PeakWorkingSetSize: Cardinal;
    WorkingSetSize: Cardinal;
    QuotaPeakPagedPoolUsage: Cardinal;
    QuotaPagedPoolUsage: Cardinal;
    QuotaPeakNonPagedPoolUsage: Cardinal;
    QuotaNonPagedPoolUsage: Cardinal;
    PagefileUsage: Cardinal;
    PeakPagefileUsage: Cardinal;
  end;

function GetCurrentProcess: Cardinal; stdcall; external 'kernel32.dll';
function GetProcessMemoryInfo(AProcess: Cardinal; var ACounters: TProcessMemoryCounters;
  ASize: Cardinal): LongBool; stdcall; external 'psapi.dll';

function PrivateBytes: Int64;
var
  C: TProcessMemoryCounters;
begin
  FillChar(C, SizeOf(C), 0);
  C.cb := SizeOf(C);
  Result := 0;
  if GetProcessMemoryInfo(GetCurrentProcess, C, SizeOf(C)) then
    Result := C.PagefileUsage;
end;
{$ENDIF}

function Ms(AStart: TDateTime): Integer;
begin
  Result := Integer(Round((Now - AStart) * 24 * 60 * 60 * 1000));
end;

function MB(ABytes: Int64): string;
begin
  Result := IntToStr(ABytes div (1024 * 1024)) + '.' + IntToStr((ABytes mod (1024 * 1024)) * 10 div (1024 * 1024)) +
    ' MB';
end;

function Num(N: Integer): TLandrixXmlUtf8;
begin
  Result := LandrixXmlStringToUtf8(IntToStr(N));
end;

function Pad(N, AWidth: Integer): TLandrixXmlUtf8;
begin
  Result := Num(N);
  while Integer(Length(Result)) < AWidth do
    Result := '0' + Result;
end;

procedure Fail(const AMsg: string);
begin
  WriteLn('FAILED: ', AMsg);
  Failed := True;
end;

procedure Paragraph(W: TLandrixXmlWriter; const AText: TLandrixXmlUtf8);
begin
  W.StartElement('p', True);
  W.StartElement('span');
  W.TextUtf8(AText);
  W.EndElement;
  W.EndElement;
end;

procedure Breakdown(W: TLandrixXmlWriter; const AType: TLandrixXmlUtf8; ALength: Integer);
begin
  W.StartElement('BoQBkdn');
  W.ElementUtf8('Type', AType);
  if AType <> 'Item' then
    W.ElementUtf8('LblBoQBkdn', 'Titel');
  W.ElementUtf8('Length', Num(ALength));
  W.ElementUtf8('Num', 'Yes');
  W.EndElement;
end;

procedure Item(W: TLandrixXmlWriter; AId, ANumber: Integer);
begin
  W.StartElement('Item');
  W.AttributeUtf8('ID', 'I' + Num(AId));
  W.AttributeUtf8('RNoPart', Pad(ANumber, 4));
  W.ElementUtf8('Qty', Num(ANumber mod 97 + 1) + '.250');
  W.ElementUtf8('QU', 'm2');
  W.StartElement('Description');
  W.StartElement('CompleteText');
  W.StartElement('DetailTxt');
  W.StartElement('Text');
  Paragraph(W, 'Mauerwerk der Innenwand aus Kalksandstein, Steinformat 2DF, Rohdichteklasse 1,8, ' +
    'Druckfestigkeitsklasse 12, im Duennbettmoertel versetzt.');
  Paragraph(W, 'Wanddicke 24 cm, Wandhoehe bis 3,00 m, einschliesslich Anschluessen an Decken und ' +
    'Waende sowie aller Aussparungen nach Plan.');
  Paragraph(W, 'Abrechnung nach Flaeche, Oeffnungen ueber 2,5 m2 werden abgezogen. Position ' + Num(AId) + '.');
  W.EndElement;
  W.EndElement;
  W.StartElement('OutlineText');
  W.StartElement('OutlTxt');
  W.StartElement('TextOutlTxt');
  Paragraph(W, 'Innenwand KS 24 cm');
  W.EndElement;
  W.EndElement;
  W.EndElement;
  W.EndElement;
  W.EndElement;
  W.EndElement;
end;

procedure Category(W: TLandrixXmlWriter; AId, ANumber: Integer; const ALabel: TLandrixXmlUtf8);
begin
  W.StartElement('BoQCtgy');
  W.AttributeUtf8('ID', 'C' + Num(AId));
  W.AttributeUtf8('RNoPart', Pad(ANumber, 2));
  W.StartElement('LblTx');
  Paragraph(W, ALabel);
  W.EndElement;
  W.StartElement('BoQBody');
end;

{ About 1.2 KB per item (indented). }
function Generate(ASizeMB: Integer; out AItems: Integer): TLandrixXmlUtf8;
var
  W: TLandrixXmlWriter;
  Total, T, C, I, CtgyId: Integer;
begin
  Total := Integer(Int64(ASizeMB) * 1024 * 1024 div 1220);
  if Total > 99 * CategoriesPerTitle * ItemsPerCategory then
    raise Exception.Create('size too large for two levels of two digits');
  AItems := 0;
  CtgyId := 0;
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    W.StartElementNs(GaebNs, '', 'GAEB');
    W.StartElement('GAEBInfo');
    W.ElementUtf8('Version', '3.3');
    W.ElementUtf8('VersDate', '2021-05');
    W.ElementUtf8('Date', '2026-11-11');
    W.ElementUtf8('ProgSystem', 'LandrixGaebPerf');
    W.EndElement;
    W.StartElement('PrjInfo');
    W.ElementUtf8('NamePrj', 'Messung');
    W.EndElement;
    W.StartElement('Award');
    W.ElementUtf8('DP', '83');
    W.StartElement('BoQ');
    W.AttributeUtf8('ID', 'B1');
    W.StartElement('BoQInfo');
    W.ElementUtf8('Name', 'LV');
    W.ElementUtf8('LblBoQ', 'Synthetisches LV');
    W.ElementUtf8('OutlCompl', 'AllTxt');
    Breakdown(W, 'BoQLevel', 2);
    Breakdown(W, 'BoQLevel', 2);
    Breakdown(W, 'Item', 4);
    W.EndElement;
    W.StartElement('BoQBody');
    T := 0;
    while AItems < Total do
    begin
      Inc(T);
      Inc(CtgyId);
      Category(W, CtgyId, T, 'Rohbau Abschnitt ' + Num(T));
      C := 0;
      while (C < CategoriesPerTitle) and (AItems < Total) do
      begin
        Inc(C);
        Inc(CtgyId);
        Category(W, CtgyId, C, 'Mauerarbeiten ' + Num(T) + '.' + Num(C));
        W.StartElement('Itemlist');
        I := 0;
        while (I < ItemsPerCategory) and (AItems < Total) do
        begin
          Inc(I);
          Inc(AItems);
          Item(W, AItems, I * 10);
        end;
        W.EndElement;
        W.EndElement;
        W.EndElement;
      end;
      W.EndElement;
      W.EndElement;
    end;
    W.EndElement;
    W.EndElement;
    W.EndElement;
    W.EndElement;
    W.EndDocument;
    Result := W.AsUtf8;
  finally
    W.Free;
  end;
end;

function Problems(ADiags: TLandrixGaebDiagnostics): Integer;
var
  I: TLandrixGaebListIndex;
begin
  Result := 0;
  for I := 0 to ADiags.Count - 1 do
    if ADiags[I].Severity >= gsWarning then
      Inc(Result);
end;

procedure Xsd(const ASource: TLandrixXmlUtf8; const ARoot: string);
var
  FileName: string;
  Schema: TLandrixXmlXsdSchemaSet;
  Validator: TLandrixXmlXsdValidator;
  Reader: TLandrixXmlReader;
  Start: TDateTime;
begin
  FileName := ARoot + 'Specification' + PathDelim + 'XML-3.3' + PathDelim + 'Schema' + PathDelim +
    'GAEB_DA_XML_83_3.3_2021-05.xsd';
  if not FileExists(FileName) then
  begin
    WriteLn('xsd: skipped (Specification/ not present)');
    Exit;
  end;
  Start := Now;
  Schema := LandrixXmlXsdLoadSchema(FileName);
  try
    WriteLn('xsd load: ', Ms(Start), ' ms');
    Validator := TLandrixXmlXsdValidator.Create(Schema);
    Reader := TLandrixXmlReader.Create;
    try
      Start := Now;
      Reader.LoadFromUtf8(ASource);
      if not Validator.ValidateReader(Reader) then
        Fail('xsd: ' + Validator.Errors[0].Code + ' ' + Validator.Errors[0].Message);
      WriteLn('xsd validate: ', Ms(Start), ' ms');
    finally
      Reader.Free;
      Validator.Free;
    end;
  finally
    Schema.Free;
  end;
end;

{ A file name next to the program that does not exist yet, so no file is
  overwritten and parallel runs do not share it. }
function FreshFileName: string;
var
  N: Integer;
begin
  N := Integer(Round(Frac(Now) * 24 * 60 * 60 * 1000));
  repeat
    Result := ChangeFileExt(ParamStr(0), '') + '-' + IntToStr(N) + '.x83';
    Inc(N);
  until not FileExists(Result);
end;

procedure Run(ASizeMB: Integer; const ARoot: string);
var
  Xml, Output: TLandrixXmlUtf8;
  Items: Integer;
  Start: TDateTime;
  Diags: TLandrixGaebDiagnostics;
  Det: TLandrixGaebDetection;
  G: TLandrixGaebXmlGAEB;
  Options: TLandrixGaebXmlWriteOptions;
  Before, Model: Int64;
  OutFile: string;
{$IFDEF PRIVATE_BYTES}
  Private: Int64;
{$ENDIF}
begin
  Start := Now;
  Xml := Generate(ASizeMB, Items);
  WriteLn('generate: ', MB(Length(Xml)), ', ', Items, ' items, ', Ms(Start), ' ms');
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
{$IFDEF PRIVATE_BYTES}
    Private := PrivateBytes;
{$ENDIF}
    Before := HeapUsed;
    Start := Now;
    G := LandrixGaebXmlReadBuffer(Pointer(Xml), Integer(Length(Xml)), Diags, Det);
    WriteLn('read: ', Ms(Start), ' ms');
    Model := HeapUsed - Before;
    WriteLn('model heap: ', MB(Model), ' (', Model * 10 div Length(Xml) div 10, '.', Model * 10 div Length(Xml) mod 10,
      ' x file size, ', Model div Items, ' bytes per item)');
{$IFDEF PRIVATE_BYTES}
    Private := PrivateBytes - Private;
    WriteLn('model private memory: ', MB(Private), ' (', Private * 10 div Length(Xml) div 10, '.',
      Private * 10 div Length(Xml) mod 10, ' x file size, ', Private div Items, ' bytes per item; heap and COM strings)');
{$ENDIF}
    if Diags.Count > 0 then
      Fail('read: ' + Diags.ToText);

    Diags.Clear;
    Start := Now;
    if not LandrixGaebXmlCheckBuffer(Pointer(Xml), Integer(Length(Xml)), Diags, Det) then
      Fail('check: ' + Diags.ToText);
    WriteLn('check: ', Ms(Start), ' ms');

    Diags.Clear;
    Start := Now;
    LandrixGaebCheckRules(G, Det.Target, Diags);
    WriteLn('rules: ', Ms(Start), ' ms');
    if Problems(Diags) > 0 then
      Fail('rules: ' + IntToStr(Problems(Diags)) + ' finding(s)');

    Options := LandrixGaebXmlDefaultWriteOptions;
    Options.Check := False;
    Diags.Clear;
    Start := Now;
    Output := LandrixGaebXmlWriteUtf8(G, Det.Target, Options, Diags);
    WriteLn('write: ', MB(Length(Output)), ' in ', Ms(Start), ' ms');
    Output := '';
    Options.Check := True;
    Start := Now;
    Output := LandrixGaebXmlWriteUtf8(G, Det.Target, Options, Diags);
    WriteLn('write with check: ', Ms(Start), ' ms');
    Output := '';
    if Problems(Diags) > 0 then
      Fail('write: ' + Diags.ToText);

    Options.Check := False;
    OutFile := FreshFileName;
    try
      Start := Now;
      LandrixGaebXmlWriteFile(G, Det.Target, OutFile, Options, Diags);
      WriteLn('write to file: ', Ms(Start), ' ms');
    finally
      DeleteFile(OutFile);
    end;
    if Problems(Diags) > 0 then
      Fail('write to file: ' + Diags.ToText);

    Xsd(Xml, ARoot);

    Diags.Clear;
    Before := HeapUsed;
    Start := Now;
    FreeAndNil(G);
    WriteLn('free: ', Ms(Start), ' ms, heap released ', MB(Before - HeapUsed), ' of ', MB(Model));
  finally
    G.Free;
    Diags.Free;
  end;
end;

var
  SizeMB: Integer;
  Root: string;

begin
  Failed := False;
  SizeMB := 50;
  Root := '';
  if ParamCount >= 1 then
    SizeMB := StrToInt(ParamStr(1));
  if ParamCount >= 2 then
    Root := IncludeTrailingPathDelimiter(ParamStr(2));
  try
    Run(SizeMB, Root);
  except
    on E: Exception do
      Fail(E.ClassName + ': ' + E.Message);
  end;
  if (ParamCount >= 3) and (ParamStr(3) = '-wait') then
  begin
    WriteLn('done');
    Flush(Output);
    ReadLn;
  end;
  if Failed then
    Halt(1);
end.

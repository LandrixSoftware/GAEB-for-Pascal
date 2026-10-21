{
  GAEB-for-pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Minimal test framework, adapted from the LandrixXml test framework. Works
  identically on Delphi 6 through Delphi 13 and Free Pascal: no RTTI, no
  anonymous methods, no generics.

  Usage:
    procedure TestSomething;
    begin
      CheckEquals(3, Length('abc'), 'length');
    end;
    ...
    RegisterTest('Unit.Something', TestSomething);
    ...
    ExitCode := RunAllTests(Filter);

  Expected exceptions are checked with try/except in the test itself:
    try
      DoSomething;
      FailNotRaised('ELandrixXmlError');
    except
      on E: ELandrixXmlError do ;
    end; }

unit LandrixGaebTestFramework;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  LandrixXmlBase,
  LandrixGaebTypes;

type
  TTestProc = procedure;

  ETestFailure = class(Exception);

procedure RegisterTest(const Name: string; Proc: TTestProc);

{ Runs all registered tests (optionally only those whose name starts with
  Filter) and returns the process exit code: 0 = all passed. }
function RunAllTests(const Filter: string): Integer;

procedure Fail(const Msg: string);
{ Marks the running test as skipped (it still passes): prints a SKIP line
  and counts it in the summary, so that a test whose checks cannot run on
  this platform does not pass silently. }
procedure Skip(const Msg: string);
procedure FailNotRaised(const ExceptionName: string);
procedure Check(Condition: Boolean; const Msg: string);
procedure CheckEquals(Expected, Actual: Integer; const Msg: string);
procedure CheckEqualsInt64(Expected, Actual: Int64; const Msg: string);
procedure CheckEqualsStr(const Expected, Actual: string; const Msg: string);
{ Compares two byte strings; on mismatch the message shows both values as
  hex. }
procedure CheckEqualsBytes(const Expected, Actual: AnsiString; const Msg: string);
procedure CheckEqualsWide(const Expected, Actual: TLandrixXmlWide; const Msg: string);
procedure CheckEqualsUtf8(const Expected, Actual: TLandrixXmlUtf8; const Msg: string);
{ Compares GAEB text code unit by code unit (never through a code page
  conversion); on mismatch the message shows both values as hex. }
procedure CheckEqualsGaebStr(const Expected, Actual: TLandrixGaebString;
  const Msg: string);

{ Hex dump helpers for messages. }
function BytesToHex(const S: AnsiString): string;
function WideToHex(const S: TLandrixXmlWide): string;
function Utf8ToHex(const S: TLandrixXmlUtf8): string;
{ Four hex digits per UTF-16 code unit. }
function GaebStrToHex(const S: TLandrixGaebString): string;

{ Builds an AnsiString from byte values, e.g. Bytes([$C3, $A4]). }
function Bytes(const Values: array of Byte): AnsiString;
{ Builds a TLandrixXmlUtf8 from byte values without any validation or
  code page conversion. }
function Utf8Bytes(const Values: array of Byte): TLandrixXmlUtf8;
{ Builds a TLandrixXmlWide from UTF-16 code units. }
function Wide(const Units: array of Word): TLandrixXmlWide;

{ Root directory of the repository (contains tests/data). Taken from the
  first command line parameter that is not a filter, else the current
  directory. }
function RepositoryRoot: string;

implementation

type
  TTestEntry = record
    Name: string;
    Proc: TTestProc;
  end;

var
  Tests: array of TTestEntry;
  TestCount: Integer = 0;
  CheckCount: Integer = 0;
  SkipCount: Integer = 0;
  CurrentTest: string = '';

procedure RegisterTest(const Name: string; Proc: TTestProc);
begin
  if TestCount = Length(Tests) then
  begin
    if TestCount = 0 then
      SetLength(Tests, 64)
    else
      SetLength(Tests, TestCount * 2);
  end;
  Tests[TestCount].Name := Name;
  Tests[TestCount].Proc := Proc;
  Inc(TestCount);
end;

procedure Fail(const Msg: string);
begin
  raise ETestFailure.Create(Msg);
end;

procedure Skip(const Msg: string);
begin
  Inc(SkipCount);
  WriteLn('SKIP ', CurrentTest, ': ', Msg);
end;

procedure FailNotRaised(const ExceptionName: string);
begin
  raise ETestFailure.Create('expected exception ' + ExceptionName + ' was not raised');
end;

procedure Check(Condition: Boolean; const Msg: string);
begin
  Inc(CheckCount);
  if not Condition then
    Fail(Msg);
end;

procedure CheckEquals(Expected, Actual: Integer; const Msg: string);
begin
  Inc(CheckCount);
  if Expected <> Actual then
    Fail(Msg + ': expected ' + IntToStr(Expected) + ', got ' + IntToStr(Actual));
end;

procedure CheckEqualsInt64(Expected, Actual: Int64; const Msg: string);
begin
  Inc(CheckCount);
  if Expected <> Actual then
    Fail(Msg + ': expected ' + IntToStr(Expected) + ', got ' + IntToStr(Actual));
end;

procedure CheckEqualsStr(const Expected, Actual: string; const Msg: string);
begin
  Inc(CheckCount);
  if Expected <> Actual then
    Fail(Msg + ': expected "' + Expected + '", got "' + Actual + '"');
end;

procedure CheckEqualsBytes(const Expected, Actual: AnsiString; const Msg: string);
begin
  Inc(CheckCount);
  if Expected <> Actual then
    Fail(Msg + ': expected [' + BytesToHex(Expected) + '], got [' + BytesToHex(Actual) + ']');
end;

procedure CheckEqualsWide(const Expected, Actual: TLandrixXmlWide; const Msg: string);
var
  Same: Boolean;
  I: Integer;
begin
  Inc(CheckCount);
  { compare code units, never through a code page conversion }
  Same := Length(Expected) = Length(Actual);
  I := 1;
  while Same and (I <= Length(Expected)) do
  begin
    Same := Ord(Expected[I]) = Ord(Actual[I]);
    Inc(I);
  end;
  if not Same then
    Fail(Msg + ': expected [' + WideToHex(Expected) + '], got [' + WideToHex(Actual) + ']');
end;

procedure CheckEqualsUtf8(const Expected, Actual: TLandrixXmlUtf8; const Msg: string);
var
  Same: Boolean;
  I: Integer;
begin
  Inc(CheckCount);
  { compare bytes, never through a code page conversion }
  Same := Length(Expected) = Length(Actual);
  I := 1;
  while Same and (I <= Length(Expected)) do
  begin
    Same := Ord(Expected[I]) = Ord(Actual[I]);
    Inc(I);
  end;
  if not Same then
    Fail(Msg + ': expected [' + Utf8ToHex(Expected) + '], got [' + Utf8ToHex(Actual) + ']');
end;

procedure CheckEqualsGaebStr(const Expected, Actual: TLandrixGaebString;
  const Msg: string);
var
  Same: Boolean;
  I: Integer;
begin
  Inc(CheckCount);
  { compare code units of the actual type, never through a code page
    conversion }
  Same := Length(Expected) = Length(Actual);
  I := 1;
  while Same and (I <= Length(Expected)) do
  begin
    Same := Ord(Expected[I]) = Ord(Actual[I]);
    Inc(I);
  end;
  if not Same then
    Fail(Msg + ': expected [' + GaebStrToHex(Expected) + '], got [' +
      GaebStrToHex(Actual) + ']');
end;

function Utf8ToHex(const S: TLandrixXmlUtf8): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if I > 1 then
      Result := Result + ' ';
    Result := Result + IntToHex(Ord(S[I]), 2);
  end;
end;

function BytesToHex(const S: AnsiString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if I > 1 then
      Result := Result + ' ';
    Result := Result + IntToHex(Ord(S[I]), 2);
  end;
end;

function WideToHex(const S: TLandrixXmlWide): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if I > 1 then
      Result := Result + ' ';
    Result := Result + IntToHex(Ord(S[I]), 4);
  end;
end;

function GaebStrToHex(const S: TLandrixGaebString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if I > 1 then
      Result := Result + ' ';
    Result := Result + IntToHex(Ord(S[I]), 2 * SizeOf(TLandrixGaebChar));
  end;
end;

function Bytes(const Values: array of Byte): AnsiString;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(Values));
  for I := 0 to Integer(High(Values)) do
    Result[I + 1] := AnsiChar(Values[I]);
end;

function Utf8Bytes(const Values: array of Byte): TLandrixXmlUtf8;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(Values));
  for I := 0 to Integer(High(Values)) do
    Result[I + 1] := AnsiChar(Values[I]);
end;

function Wide(const Units: array of Word): TLandrixXmlWide;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(Units));
  for I := 0 to Integer(High(Units)) do
    Result[I + 1] := WideChar(Units[I]);
end;

function RepositoryRoot: string;
var
  I: Integer;
  P: string;
begin
  Result := '';
  for I := 1 to ParamCount do
  begin
    P := ParamStr(I);
    if (Length(P) > 0) and (P[1] <> '-') and DirectoryExists(P) then
    begin
      Result := P;
      Break;
    end;
  end;
  if Result = '' then
    Result := GetCurrentDir;
  Result := IncludeTrailingPathDelimiter(Result);
end;

function StartsWith(const S, Prefix: string): Boolean;
begin
  Result := (Length(S) >= Length(Prefix)) and (Copy(S, 1, Length(Prefix)) = Prefix);
end;

function RunAllTests(const Filter: string): Integer;
var
  I, Passed, Failed: Integer;
begin
  Passed := 0;
  Failed := 0;
  for I := 0 to TestCount - 1 do
  begin
    if (Filter <> '') and not StartsWith(Tests[I].Name, Filter) then
      Continue;
    CurrentTest := Tests[I].Name;
    try
      Tests[I].Proc;
      Inc(Passed);
    except
      on E: ETestFailure do
      begin
        Inc(Failed);
        WriteLn('FAIL ', Tests[I].Name, ': ', E.Message);
      end;
      on E: Exception do
      begin
        Inc(Failed);
        WriteLn('ERROR ', Tests[I].Name, ': ', E.ClassName, ': ', E.Message);
      end;
    end;
  end;
  WriteLn(Passed + Failed, ' test(s), ', CheckCount, ' check(s), ',
    Failed, ' failure(s), ', SkipCount, ' skip(s)');
  if Passed + Failed = 0 then
  begin
    { a mistyped filter must not look like success }
    WriteLn('ERROR no test matches the filter "', Filter, '"');
    Result := 1;
  end
  else if Failed = 0 then
    Result := 0
  else
    Result := 1;
end;

end.

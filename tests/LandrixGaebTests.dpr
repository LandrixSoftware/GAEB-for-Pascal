{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Console test runner. Exit code 0 = all tests passed.

  Usage: LandrixGaebTests [repository-root] [-filter=Prefix] }

program LandrixGaebTests;

{$I LandrixGaeb.inc}

{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  SysUtils,
  LandrixGaebTestFramework,
  LandrixGaebTestSelf,
  LandrixGaebTestTypes,
  LandrixGaebTestDetect,
  LandrixGaebTestXmlModel,
  LandrixGaebTestXmlReader,
  LandrixGaebTestXmlWriter,
  LandrixGaebTestXmlCheck,
  LandrixGaebTestRules,
  LandrixGaebTestNoValues,
  LandrixGaebTestLegacy,
  LandrixGaebTestXsd,
  LandrixGaebTestCoverage,
  LandrixGaebTestRoundTrip;

function FilterParam: string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ParamCount do
    if Copy(ParamStr(I), 1, 8) = '-filter=' then
      Result := Copy(ParamStr(I), 9, MaxInt);
end;

begin
  LandrixGaebTestSelf.Register;
  LandrixGaebTestTypes.Register;
  LandrixGaebTestDetect.Register;
  LandrixGaebTestXmlModel.Register;
  LandrixGaebTestXmlReader.Register;
  LandrixGaebTestXmlWriter.Register;
  LandrixGaebTestXmlCheck.Register;
  LandrixGaebTestRules.Register;
  LandrixGaebTestLegacy.Register;
  LandrixGaebTestXsd.Register;
  LandrixGaebTestCoverage.Register;
  LandrixGaebTestRoundTrip.Register;
  ExitCode := RunAllTests(FilterParam);
end.

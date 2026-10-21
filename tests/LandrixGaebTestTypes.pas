{
  GAEB-for-pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of LandrixGaebTypes: decimal value types, commercial rounding and
  the target (version, edition, phase). }

unit LandrixGaebTestTypes;

{$I LandrixGaeb.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixXmlDecimal,
  LandrixGaebTypes,
  LandrixGaebTestFramework;

procedure TestObjectSizes;
begin
  { Delphi 13 Win64 passes 8-byte objects wrongly as value or const
    parameters (CONTRIBUTING.md) }
  Check(SizeOf(TLandrixGaebDecimal) <> 8, 'SizeOf(TLandrixGaebDecimal) <> 8');
  Check(SizeOf(TLandrixGaebDecimalText) <> 8, 'SizeOf(TLandrixGaebDecimalText) <> 8');
end;

procedure TestDecimalZeroedIsUnset;
var
  D: TLandrixGaebDecimal;
  T: TLandrixGaebDecimalText;
begin
  D.SetValue(1, 0);
  FillChar(D, SizeOf(D), 0);
  Check(not D.HasValue, 'zeroed decimal is not set');
  CheckEqualsUtf8('', D.Text, 'text of unset decimal');
  T.Clear;
  Check(not T.HasValue, 'cleared decimal text is not set');
  CheckEqualsUtf8('', T.Text, 'text of unset decimal text');
end;

procedure CheckParse(const S, Expected: TLandrixXmlUtf8; ExpectedScale: Integer);
var
  D: TLandrixGaebDecimal;
begin
  D.Clear;
  Check(D.TrySetText(S), 'parse "' + LandrixXmlUtf8ToString(S) + '"');
  CheckEqualsUtf8(Expected, D.Text, 'text of "' + LandrixXmlUtf8ToString(S) + '"');
  CheckEquals(ExpectedScale, D.Scale, 'scale of "' + LandrixXmlUtf8ToString(S) + '"');
end;

procedure CheckReject(const S: TLandrixXmlUtf8);
var
  D: TLandrixGaebDecimal;
begin
  D.Clear;
  D.SetValue(7, 0);
  Check(not D.TrySetText(S), 'reject "' + LandrixXmlUtf8ToString(S) + '"');
  CheckEqualsUtf8('7', D.Text, 'value unchanged after rejecting "' + LandrixXmlUtf8ToString(S) + '"');
end;

procedure TestDecimalParse;
begin
  CheckParse('12.500', '12.500', 3);
  CheckParse('12.5', '12.5', 1);
  CheckParse('-3', '-3', 0);
  CheckParse('+.5', '0.5', 1);
  CheckParse('5.', '5', 0);
  CheckParse('-0.05', '-0.05', 2);
  CheckParse('0.000', '0.000', 3);
  CheckParse('  42.10 ', '42.10', 2);
  CheckParse('000123.40', '123.40', 2);
  CheckParse('999999999999999.999', '999999999999999.999', 3);
  CheckReject('');
  CheckReject(' ');
  CheckReject('.');
  CheckReject('-');
  CheckReject('1,5');
  CheckReject('1.2.3');
  CheckReject('1e5');
  CheckReject('12 5');
  { 19 significant digits do not fit }
  CheckReject('1234567890123456789');
end;

procedure TestDecimalEquals;
var
  A, B: TLandrixGaebDecimal;
begin
  A.Clear;
  B.Clear;
  Check(A.Equals(B), 'two unset values are equal');
  A.TrySetText('12.5');
  Check(not A.Equals(B), 'set and unset differ');
  B.TrySetText('12.500');
  Check(A.Equals(B), '12.5 = 12.500');
  B.TrySetText('-12.5');
  Check(not A.Equals(B), '12.5 <> -12.5');
  A.TrySetText('0.00');
  B.TrySetText('0');
  Check(A.Equals(B), '0.00 = 0');
  { 0.00 is a value, not "not set" (X84: a price of 0.00 is a price) }
  Check(A.HasValue, '0.00 is set');
end;

procedure TestDecimalAsXmlDecimal;
var
  D: TLandrixGaebDecimal;
  Raised: Boolean;
begin
  D.Clear;
  D.SetValue(-1250, 3);
  CheckEqualsUtf8('-1.25', LandrixXmlFormatDecimal(D.AsXmlDecimal), 'AsXmlDecimal');
  D.Clear;
  Raised := False;
  try
    D.AsXmlDecimal;
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'AsXmlDecimal of an unset value raises');
  Raised := False;
  try
    D.SetValue(1, LandrixGaebDecimalMaxScale + 1);
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'scale above the maximum raises');
  D.SetValue(-LandrixGaebDecimalMaxCoefficient, 2);
  CheckEqualsUtf8('-9999999999999999.99', D.Text, '18 digits accepted');
  Raised := False;
  try
    D.SetValue(LandrixGaebDecimalMaxCoefficient + 1, 0);
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'coefficient with 19 digits raises');
  CheckEqualsUtf8('-9999999999999999.99', D.Text, 'value unchanged after rejection');
end;

procedure TestDecimalText;
var
  A, B: TLandrixGaebDecimalText;
begin
  A.Clear;
  B.Clear;
  { tgDecimal is unbounded: far more digits than Int64 }
  Check(A.TrySetText(' 123456789012345678901234567890.123456789 '), 'long decimal');
  CheckEqualsUtf8('123456789012345678901234567890.123456789', A.Text, 'text kept, white space removed');
  Check(B.TrySetText('123456789012345678901234567890.12345678900'), 'trailing zeros');
  Check(A.Equals(B), 'value comparison ignores trailing zeros');
  Check(not A.TrySetText('1,5'), 'comma rejected');
  CheckEqualsUtf8('123456789012345678901234567890.123456789', A.Text, 'value unchanged after rejection');
  A.SetXmlDecimal(LandrixXmlParseDecimal('-0.50'));
  CheckEqualsUtf8('-0.5', A.Text, 'SetXmlDecimal uses the shortest form');
end;

procedure CheckRound(const Value: TLandrixXmlUtf8; Precision: Integer;
  const Expected: TLandrixXmlUtf8);
begin
  CheckEqualsUtf8(Expected, LandrixXmlFormatDecimal(LandrixGaebRoundHalfAwayFromZero(
    LandrixXmlParseDecimal(Value), Precision)), 'round ' + LandrixXmlUtf8ToString(Value) + ' to ' +
    IntToStr(Precision));
end;

procedure TestRoundHalfAwayFromZero;
begin
  CheckRound('2.345', 2, '2.35');
  CheckRound('-2.345', 2, '-2.35');
  CheckRound('2.344', 2, '2.34');
  CheckRound('-2.344', 2, '-2.34');
  CheckRound('2.5', 0, '3');
  CheckRound('-2.5', 0, '-3');
  CheckRound('-0.5', 0, '-1');
  CheckRound('0.005', 2, '0.01');
  CheckRound('-0.005', 2, '-0.01');
  CheckRound('-0.004', 2, '0');
  CheckRound('1.2', 3, '1.2');
  CheckRound('0', 2, '0');
end;

procedure TestPhaseDP;
var
  P: TLandrixGaebPhase;
begin
  for P := Succ(gpUnknown) to High(TLandrixGaebPhase) do
    Check(LandrixGaebPhaseFromDP(LandrixGaebPhaseToDP(P)) = P,
      'DP round trip ' + LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(P)));
  Check(LandrixGaebPhaseFromDP(' 50.1 ') = gp50_1, 'DP with white space');
  Check(LandrixGaebPhaseFromDP('84z') = gpUnknown, 'DP is case-sensitive');
  Check(LandrixGaebPhaseFromDP('') = gpUnknown, 'empty DP');
  Check(LandrixGaebPhaseFromDP('50') = gpUnknown, '50 alone is no exchange phase');
  Check(LandrixGaebVersionFromText('3.3') = gv33, 'version 3.3');
  Check(LandrixGaebVersionFromText('3.5') = gvUnknown, 'unknown version');
  Check(LandrixGaebEditionFromText('2021-05') = ge2021_05, 'edition 2021-05');
  CheckEqualsUtf8('2019-11', LandrixGaebEditionToText(ge2019_11), 'edition text');
end;

procedure TestTargetNamespace;
begin
  CheckEqualsUtf8('http://www.gaeb.de/GAEB_DA_XML/DA83/3.3',
    LandrixGaebTargetNamespace(LandrixGaebTarget(gv33, ge2021_05, gp83)), '83/3.3');
  CheckEqualsUtf8('http://www.gaeb.de/GAEB_DA_XML/DA84Z/3.2',
    LandrixGaebTargetNamespace(LandrixGaebTarget(gv32, ge2014_03, gp84Z)), '84Z/3.2');
  CheckEqualsUtf8('http://www.gaeb.de/GAEB_DA_XML/DA50/3.3',
    LandrixGaebTargetNamespace(LandrixGaebTarget(gv33, ge2021_05, gp50_2)), '50.2 shares DA50');
  CheckEqualsUtf8('http://www.gaeb.de/GAEB_DA_XML/200407',
    LandrixGaebTargetNamespace(LandrixGaebTarget(gv31, ge2009_12, gp84)), '3.1');
  CheckEqualsUtf8('http://www.gaeb.de/GAEB_DA_XML/200706',
    LandrixGaebTargetNamespace(LandrixGaebTarget(gv31, ge2007_11, gp93)), '3.1 trade');
  CheckEqualsUtf8('', LandrixGaebTargetNamespace(LandrixGaebTarget(gv33, ge2021_05, gpUnknown)),
    'unknown phase');
  CheckEqualsUtf8('2021-05', LandrixGaebTargetVersDate(LandrixGaebTarget(gv33, ge2021_05, gp83)),
    'VersDate');
  CheckEqualsUtf8('2009-12', LandrixGaebTargetVersDate(LandrixGaebTarget(gv31, ge2009_12, gp83)),
    'VersDate 3.1/2009-12');
  CheckEqualsUtf8('', LandrixGaebTargetVersDate(LandrixGaebTarget(gv30, ge2004_07, gp83)),
    'VersDate of 3.0 is free');
end;

procedure TestTargetIsSupported;
begin
  Check(LandrixGaebTargetIsSupported(LandrixGaebTarget(gv33, ge2021_05, gp83), True), '3.3/2021-05 X83 write');
  Check(LandrixGaebTargetIsSupported(LandrixGaebTarget(gv33, ge2019_11, gp84), False), '3.3/2019-11 X84 read');
  Check(not LandrixGaebTargetIsSupported(LandrixGaebTarget(gv33, ge2019_11, gp84), True), '3.3/2019-11 not written');
  Check(not LandrixGaebTargetIsSupported(LandrixGaebTarget(gv33, ge2019_11, gp89B), False), '89B not in 2019-11');
  Check(LandrixGaebTargetIsSupported(LandrixGaebTarget(gv33, ge2021_05, gp84P), False), 'beta 84P read');
  Check(not LandrixGaebTargetIsSupported(LandrixGaebTarget(gv33, ge2021_05, gp84P), True), 'beta 84P not written');
  Check(LandrixGaebTargetIsSupported(LandrixGaebTarget(gv32, ge2013_10, gp81), True), '3.2 X81 write');
  Check(not LandrixGaebTargetIsSupported(LandrixGaebTarget(gv32, ge2013_10, gp50_1), False), 'no 50.1 in 3.2');
  Check(LandrixGaebTargetIsSupported(LandrixGaebTarget(gv32, ge2014_03, gp86ZE), True), '3.2 time contract');
  Check(not LandrixGaebTargetIsSupported(LandrixGaebTarget(gv32, ge2014_03, gp83), False), '2014-03 only time contract');
  Check(not LandrixGaebTargetIsSupported(LandrixGaebTarget(gv32, ge2013_10, gp83Z), False), 'no time contract in 2013-10');
  Check(LandrixGaebTargetIsSupported(LandrixGaebTarget(gv33, ge2023_01, gp31), True), '3.3/2023-01 X31');
  Check(not LandrixGaebTargetIsSupported(LandrixGaebTarget(gv33, ge2023_01, gp83), False), '2023-01 only X31');
  Check(not LandrixGaebTargetIsSupported(LandrixGaebTarget(gv34, ge2026_03, gp83), False), '3.4 beta not yet');
  Check(not LandrixGaebTargetIsSupported(LandrixGaebTarget(gv31, ge2009_12, gp83), False), '3.1 not yet');
  Check(not LandrixGaebTargetIsSupported(LandrixGaebTarget(gv33, geUnknown, gp83), False), 'edition required');
end;

procedure Register;
begin
  RegisterTest('Types.ObjectSizes', TestObjectSizes);
  RegisterTest('Types.DecimalZeroedIsUnset', TestDecimalZeroedIsUnset);
  RegisterTest('Types.DecimalParse', TestDecimalParse);
  RegisterTest('Types.DecimalEquals', TestDecimalEquals);
  RegisterTest('Types.DecimalAsXmlDecimal', TestDecimalAsXmlDecimal);
  RegisterTest('Types.DecimalText', TestDecimalText);
  RegisterTest('Types.RoundHalfAwayFromZero', TestRoundHalfAwayFromZero);
  RegisterTest('Types.PhaseDP', TestPhaseDP);
  RegisterTest('Types.TargetNamespace', TestTargetNamespace);
  RegisterTest('Types.TargetIsSupported', TestTargetIsSupported);
end;

end.

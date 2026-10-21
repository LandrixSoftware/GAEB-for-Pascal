{
  GAEB-for-pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of the generated syntax model (LandrixGaebXmlModel) and its codes
  (LandrixGaebXmlCodes): presence rules, lazy children, ordered child
  lists, group classes, code conversion. }

unit LandrixGaebTestXmlModel;

{$I LandrixGaeb.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  LandrixGaebTypes,
  LandrixGaebXmlBase,
  LandrixGaebXmlModel,
  LandrixGaebXmlCodes,
  LandrixGaebTestFramework;

procedure TestGetterDoesNotMarkPresent;
var
  G: TLandrixGaebXmlGAEB;
begin
  G := TLandrixGaebXmlGAEB.Create;
  try
    Check(G.IsEmpty, 'new document is empty');
    Check(not G.HasAward, 'no Award yet');
    Check(G.Award <> nil, 'getter creates');
    Check(not G.HasAward, 'reading the getter does not make Award present');
    Check(G.IsEmpty, 'still empty after reading a getter');
    G.Award.DP := '83';
    Check(G.HasAward, 'Award with DP is present');
    Check(not G.IsEmpty, 'document with DP is not empty');
    CheckEqualsUtf8('Award', G.Award.ElementName, 'element name set by the getter');
    G.Clear;
    Check(not G.HasAward and G.IsEmpty, 'Clear removes everything');
  finally
    G.Free;
  end;
end;

procedure TestPresentKeepsEmptyElements;
var
  T: TLandrixGaebXmlTextComplement;
begin
  T := TLandrixGaebXmlTextComplement.Create;
  try
    Check(not T.HasComplBodyDec, 'no body yet');
    T.ComplBodyDec.Present := True;
    Check(T.HasComplBodyDec, 'an empty but present body counts');
    Check(not T.IsEmpty, 'the parent is not empty because of a present child');
    T.ComplBodyDec.Clear;
    Check(not T.HasComplBodyDec, 'Clear resets Present');
    Check(T.ComplBodyDec.Value.TrySetText('12.5'), 'decimal attribute');
    Check(T.HasComplBodyDec, 'a value makes it present');
  finally
    T.Free;
  end;
end;

procedure TestDecimalFields;
var
  I: TLandrixGaebXmlItem;
begin
  I := TLandrixGaebXmlItem.Create;
  try
    Check(not I.Qty.HasValue, 'Qty not set');
    I.Qty.SetValue(0, 3);
    Check(I.Qty.HasValue, '0.000 is a value, not absent');
    CheckEqualsUtf8('0.000', I.Qty.Text, 'scale kept');
    Check(not I.IsEmpty, 'item with Qty 0 is not empty');
    I.Clear;
    Check(not I.Qty.HasValue and I.IsEmpty, 'Clear resets decimals');
  finally
    I.Free;
  end;
end;

procedure TestOrderedChildren;
var
  P: TLandrixGaebXmlP;
  S: TLandrixGaebXmlSpan;
begin
  P := TLandrixGaebXmlP.Create;
  try
    Check(not P.HasChildren, 'no children');
    S := P.AddSpan;
    S.Value := 'a';
    P.AddBr('');
    P.AddSpan.Value := 'b';
    CheckEquals(3, Integer(P.Children.Count), 'three children');
    CheckEqualsUtf8('span', P.Children[0].ElementName, 'first is span');
    CheckEqualsUtf8('br', P.Children[1].ElementName, 'second is br');
    Check(P.Children[1] is TLandrixGaebXmlValueNode, 'br is a value node');
    Check(P.Children[2] is TLandrixGaebXmlSpan, 'third is a span');
    Check(P.HasChildren, 'children present');
    P.ClassAttr := 'x';
    P.Clear;
    Check(not P.HasChildren and (P.ClassAttr = ''), 'Clear');
  finally
    P.Free;
  end;
end;

procedure TestAddedValueNodeIsPresent;
var
  P: TLandrixGaebXmlP;
begin
  P := TLandrixGaebXmlP.Create;
  try
    P.AddBr('');
    Check(P.HasChildren, 'an added empty br is present (it is written)');
    P.Children[0].Present := False;
    Check(not P.HasChildren, 'unless its presence is withdrawn');
  finally
    P.Free;
  end;
end;

procedure TestGroups;
var
  A: TLandrixGaebXmlAward;
  G: TLandrixGaebXmlAwardCnstSiteGroup;
begin
  A := TLandrixGaebXmlAward.Create;
  try
    Check(not A.HasCnstSiteGroup, 'no group');
    G := A.CnstSiteGroup.Add;
    Check(not A.HasCnstSiteGroup, 'an empty group is not present');
    G.CnstSite.Present := True;
    Check(A.HasCnstSiteGroup, 'group with a present site');
    Check(not G.HasNotifSite, 'notification site is optional');
  finally
    A.Free;
  end;
end;

procedure TestCodes;
begin
  Check(LandrixGaebXmlYesNoFromText('') = gxynNone, 'empty');
  Check(LandrixGaebXmlYesNoFromText('Yes') = gxynYes, 'Yes');
  Check(LandrixGaebXmlYesNoFromText('yes') = gxynUnrecognized, 'codes are case-sensitive');
  Check(LandrixGaebXmlYesNoToText(gxynNo) = 'No', 'to text');
  Check(LandrixGaebXmlYesNoToText(gxynUnrecognized) = '', 'unrecognized has no text');
  Check(LandrixGaebXmlUpCompTypeFromText('Unknown') = gxuctUnknown, 'code named Unknown');
  Check(LandrixGaebXmlCtlgTypeFromText('BIM') = gxctlBIM, '3.3 code of an open list');
  Check(LandrixGaebXmlCtlgTypeFromText('own catalogue') = gxctlUnrecognized, 'free text in an open list');
end;

procedure Register;
begin
  RegisterTest('XmlModel.GetterDoesNotMarkPresent', TestGetterDoesNotMarkPresent);
  RegisterTest('XmlModel.PresentKeepsEmptyElements', TestPresentKeepsEmptyElements);
  RegisterTest('XmlModel.DecimalFields', TestDecimalFields);
  RegisterTest('XmlModel.OrderedChildren', TestOrderedChildren);
  RegisterTest('XmlModel.AddedValueNodeIsPresent', TestAddedValueNodeIsPresent);
  RegisterTest('XmlModel.Groups', TestGroups);
  RegisterTest('XmlModel.Codes', TestCodes);
end;

end.

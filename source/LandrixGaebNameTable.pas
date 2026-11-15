{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ A table from names to integers with logarithmic lookups, for the readers
  of untrusted input.
  DE: Eine Tabelle von Namen auf Ganzzahlen mit logarithmischer Suche, fuer
  die Leser nicht vertrauenswuerdiger Eingaben. }

{ API: internal. May change in any release, also after 1.0; use the
  stable units instead (see README).
  DE: API: intern. Kann sich in jeder Version aendern, auch nach 1.0;
  stattdessen die stabilen Units verwenden (siehe README). }

unit LandrixGaebNameTable;

{$I LandrixGaeb.inc}

interface

uses
  LandrixGaebTypes;

type
  { Names with an integer each in a balanced search tree (AVL): input is
    untrusted, so no lookup may take more than logarithmic time, whatever
    the names are; the first value added for a name wins. Names compare
    as written (ordinal).
    DE: Namen mit je einer Ganzzahl in einem balancierten Suchbaum (AVL):
    Eingaben sind nicht vertrauenswuerdig, daher dauert keine Suche mehr
    als logarithmische Zeit, gleich welche Namen; der zuerst eingetragene
    Wert eines Namens gilt. Namen werden wie geschrieben verglichen. }
  TLandrixGaebNameTable = class(TObject)
  private
    FNames: array of TLandrixGaebString;
    FValues: array of Integer;
    FLeft, FRight, FHeight: array of Integer;
    FRoot: Integer;
    FCount: Integer;
    FAdded: Boolean;
    function Height(ANode: Integer): Integer;
    procedure Update(ANode: Integer);
    function RotateLeft(ANode: Integer): Integer;
    function RotateRight(ANode: Integer): Integer;
    function Balance(ANode: Integer): Integer;
    function Insert(ANode: Integer; const AName: TLandrixGaebString; AValue: Integer): Integer;
  public
    { An empty table. DE: Eine leere Tabelle. }
    constructor Create;
    { Value of AName, -1 if absent. DE: Wert von AName, -1 wenn nicht
      vorhanden. }
    function Find(const AName: TLandrixGaebString): Integer;
    { Adds AName with AValue unless present; False if it was present (its
      value stays). DE: Traegt AName mit AValue ein, wenn noch nicht
      vorhanden; False, wenn vorhanden (sein Wert bleibt). }
    function Add(const AName: TLandrixGaebString; AValue: Integer): Boolean;
    { Number of names. DE: Anzahl der Namen. }
    property Count: Integer read FCount;
  end;

implementation

{ Ordinal comparison of two names: < 0, 0 or > 0. }
function CompareNames(const A, B: TLandrixGaebString): Integer;
var
  I, N: Integer;
begin
  N := Length(A);
  if Length(B) < N then
    N := Length(B);
  for I := 1 to N do
    if A[I] <> B[I] then
    begin
      Result := Ord(A[I]) - Ord(B[I]);
      Exit;
    end;
  Result := Length(A) - Length(B);
end;

constructor TLandrixGaebNameTable.Create;
begin
  inherited Create;
  FRoot := -1;
end;

function TLandrixGaebNameTable.Height(ANode: Integer): Integer;
begin
  if ANode < 0 then
    Result := 0
  else
    Result := FHeight[ANode];
end;

procedure TLandrixGaebNameTable.Update(ANode: Integer);
var
  L, R: Integer;
begin
  L := Height(FLeft[ANode]);
  R := Height(FRight[ANode]);
  if L > R then
    FHeight[ANode] := L + 1
  else
    FHeight[ANode] := R + 1;
end;

function TLandrixGaebNameTable.RotateLeft(ANode: Integer): Integer;
begin
  Result := FRight[ANode];
  FRight[ANode] := FLeft[Result];
  FLeft[Result] := ANode;
  Update(ANode);
  Update(Result);
end;

function TLandrixGaebNameTable.RotateRight(ANode: Integer): Integer;
begin
  Result := FLeft[ANode];
  FLeft[ANode] := FRight[Result];
  FRight[Result] := ANode;
  Update(ANode);
  Update(Result);
end;

function TLandrixGaebNameTable.Balance(ANode: Integer): Integer;
var
  Diff, T: Integer;
begin
  Update(ANode);
  Diff := Height(FLeft[ANode]) - Height(FRight[ANode]);
  if Diff > 1 then
  begin
    if Height(FLeft[FLeft[ANode]]) < Height(FRight[FLeft[ANode]]) then
    begin
      T := RotateLeft(FLeft[ANode]);
      FLeft[ANode] := T;
    end;
    Result := RotateRight(ANode);
  end
  else if Diff < -1 then
  begin
    if Height(FRight[FRight[ANode]]) < Height(FLeft[FRight[ANode]]) then
    begin
      T := RotateRight(FRight[ANode]);
      FRight[ANode] := T;
    end;
    Result := RotateLeft(ANode);
  end
  else
    Result := ANode;
end;

{ The subtree ANode with AName added (the arrays have room for one more
  name; recursion depth is the height of the tree, logarithmic). }
function TLandrixGaebNameTable.Insert(ANode: Integer; const AName: TLandrixGaebString; AValue: Integer): Integer;
var
  C, T: Integer;
begin
  if ANode < 0 then
  begin
    Result := FCount;
    FNames[Result] := AName;
    FValues[Result] := AValue;
    FLeft[Result] := -1;
    FRight[Result] := -1;
    FHeight[Result] := 1;
    Inc(FCount);
    FAdded := True;
    Exit;
  end;
  C := CompareNames(AName, FNames[ANode]);
  if C = 0 then
  begin
    Result := ANode;
    Exit;
  end;
  if C < 0 then
  begin
    T := Insert(FLeft[ANode], AName, AValue);
    FLeft[ANode] := T;
  end
  else
  begin
    T := Insert(FRight[ANode], AName, AValue);
    FRight[ANode] := T;
  end;
  Result := Balance(ANode);
end;

function TLandrixGaebNameTable.Find(const AName: TLandrixGaebString): Integer;
var
  N, C: Integer;
begin
  N := FRoot;
  while N >= 0 do
  begin
    C := CompareNames(AName, FNames[N]);
    if C = 0 then
    begin
      Result := FValues[N];
      Exit;
    end;
    if C < 0 then
      N := FLeft[N]
    else
      N := FRight[N];
  end;
  Result := -1;
end;

function TLandrixGaebNameTable.Add(const AName: TLandrixGaebString; AValue: Integer): Boolean;
var
  T: Integer;
begin
  if FCount >= Length(FNames) then
  begin
    SetLength(FNames, 2 * FCount + 16);
    SetLength(FValues, 2 * FCount + 16);
    SetLength(FLeft, 2 * FCount + 16);
    SetLength(FRight, 2 * FCount + 16);
    SetLength(FHeight, 2 * FCount + 16);
  end;
  FAdded := False;
  T := Insert(FRoot, AName, AValue);
  FRoot := T;
  Result := FAdded;
end;

end.

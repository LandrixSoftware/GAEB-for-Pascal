{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Diagnostics: what reading, checking or writing found, with rule
  identifier, severity and position. Messages describe the finding in
  English and never contain content of the input file (it may hold prices,
  addresses or other confidential data).

  DE: Meldungen: was Lesen, Pruefen oder Schreiben gefunden hat, mit
  Regelkennung, Schwere und Position. Die Texte beschreiben den Befund auf
  Englisch und enthalten nie Inhalt der Eingabedatei (sie kann Preise,
  Adressen oder andere vertrauliche Daten enthalten). }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixGaebDiagnostics;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixGaebTypes;

type
  { How serious a diagnostic is.
    DE: Wie schwer eine Meldung wiegt. }
  TLandrixGaebSeverity = (
    { Information only, nothing is lost. DE: Nur zur Information, nichts
      geht verloren. }
    gsInformation,
    { Formally allowed or tolerated, but probably a problem.
      DE: Formal erlaubt oder toleriert, aber wahrscheinlich ein Problem. }
    gsWarning,
    { A GAEB rule is violated, or data was lost.
      DE: Eine GAEB-Regel ist verletzt oder Daten gingen verloren. }
    gsError,
    { The input cannot be processed at all (not readable, format unknown).
      DE: Die Eingabe laesst sich gar nicht verarbeiten (nicht lesbar,
      Format unbekannt). }
    gsFatal
  );

  { One diagnostic. Line, Column are 1-based, 0 = no position; Offset is a
    0-based byte offset, -1 = unknown.
    DE: Eine Meldung. Line und Column zaehlen ab 1, 0 = keine Position;
    Offset ist ein Byte-Versatz ab 0, -1 = unbekannt. }
  TLandrixGaebDiagnostic = class(TObject)
  public
    { Stable rule identifier, e.g. GAEB-DET-002 or GAEB-BR-X84-003.
      DE: Stabile Regelkennung, z. B. GAEB-DET-002 oder GAEB-BR-X84-003. }
    RuleId: string;
    Severity: TLandrixGaebSeverity;
    { Element path or record/block reference; '' if none.
      DE: Elementpfad oder Satz-/Blockangabe; '' wenn keine. }
    Path: TLandrixGaebString;
    Line: Integer;
    Column: Integer;
    Offset: Int64;
    { English message without file content. DE: Englischer Text ohne
      Dateiinhalt. }
    Message: string;
  end;

  { List of diagnostics (owns its entries).
    DE: Liste von Meldungen (besitzt ihre Eintraege). }
  TLandrixGaebDiagnostics = class(TObjectList)
  protected
    function GetItem(Index: TLandrixGaebListIndex): TLandrixGaebDiagnostic;
  public
    property Items[Index: TLandrixGaebListIndex]: TLandrixGaebDiagnostic read GetItem; default;
    { Adds an entry without position and returns it.
      DE: Fuegt einen Eintrag ohne Position hinzu und liefert ihn. }
    function AddDiagnostic(const ARuleId: string; ASeverity: TLandrixGaebSeverity;
      const AMessage: string): TLandrixGaebDiagnostic;
    { Adds an entry with position and returns it.
      DE: Fuegt einen Eintrag mit Position hinzu und liefert ihn. }
    function AddAt(const ARuleId: string; ASeverity: TLandrixGaebSeverity;
      const APath: TLandrixGaebString; ALine, AColumn: Integer; AOffset: Int64;
      const AMessage: string): TLandrixGaebDiagnostic;
    { Number of entries with this rule identifier.
      DE: Anzahl der Eintraege mit dieser Regelkennung. }
    function CountOf(const ARuleId: string): Integer;
    { True if an entry has at least severity gsError.
      DE: True, wenn ein Eintrag mindestens die Schwere gsError hat. }
    function HasErrors: Boolean;
    { All entries, one per line: "line:column severity [rule] path: message".
      For display in the string type of the compiler: where string is not
      Unicode (Delphi 6 to 2007, Free Pascal), characters of a path outside
      the code page of the system are lost; ToWideText keeps them.
      DE: Alle Eintraege, einer je Zeile: "Zeile:Spalte Schwere [Regel]
      Pfad: Text". Zur Anzeige im String-Typ des Compilers: wo string nicht
      Unicode ist (Delphi 6 bis 2007, Free Pascal), gehen Zeichen eines
      Pfads ausserhalb der Codepage des Systems verloren; ToWideText
      behaelt sie. }
    function ToText: string;
    { As ToText, as TLandrixGaebString without loss.
      DE: Wie ToText, als TLandrixGaebString ohne Verlust. }
    function ToWideText: TLandrixGaebString;
  end;

{ Name of a severity ('information', 'warning', 'error', 'fatal').
  DE: Name einer Schwere ('information', 'warning', 'error', 'fatal'). }
function LandrixGaebSeverityToStr(ASeverity: TLandrixGaebSeverity): string;

implementation

function LandrixGaebSeverityToStr(ASeverity: TLandrixGaebSeverity): string;
begin
  case ASeverity of
    gsInformation: Result := 'information';
    gsWarning: Result := 'warning';
    gsError: Result := 'error';
  else
    Result := 'fatal';
  end;
end;

function TLandrixGaebDiagnostics.GetItem(Index: TLandrixGaebListIndex): TLandrixGaebDiagnostic;
begin
  Result := TLandrixGaebDiagnostic(inherited Items[Index]);
end;

function TLandrixGaebDiagnostics.AddDiagnostic(const ARuleId: string;
  ASeverity: TLandrixGaebSeverity; const AMessage: string): TLandrixGaebDiagnostic;
begin
  Result := AddAt(ARuleId, ASeverity, '', 0, 0, -1, AMessage);
end;

function TLandrixGaebDiagnostics.AddAt(const ARuleId: string;
  ASeverity: TLandrixGaebSeverity; const APath: TLandrixGaebString;
  ALine, AColumn: Integer; AOffset: Int64; const AMessage: string): TLandrixGaebDiagnostic;
begin
  Result := TLandrixGaebDiagnostic.Create;
  Result.RuleId := ARuleId;
  Result.Severity := ASeverity;
  Result.Path := APath;
  Result.Line := ALine;
  Result.Column := AColumn;
  Result.Offset := AOffset;
  Result.Message := AMessage;
  inherited Add(Result);
end;

function TLandrixGaebDiagnostics.CountOf(const ARuleId: string): Integer;
var
  I: TLandrixGaebListIndex;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    if Items[I].RuleId = ARuleId then
      Inc(Result);
end;

function TLandrixGaebDiagnostics.HasErrors: Boolean;
var
  I: TLandrixGaebListIndex;
begin
  Result := False;
  for I := 0 to Count - 1 do
    if Items[I].Severity >= gsError then
    begin
      Result := True;
      Exit;
    end;
end;

function TLandrixGaebDiagnostics.ToText: string;
var
  I: TLandrixGaebListIndex;
  D: TLandrixGaebDiagnostic;
  Line: string;
begin
  Result := '';
  for I := 0 to Count - 1 do
  begin
    D := Items[I];
    Line := IntToStr(D.Line) + ':' + IntToStr(D.Column) + ' ' +
      LandrixGaebSeverityToStr(D.Severity) + ' [' + D.RuleId + ']';
    if D.Path <> '' then
      Line := Line + ' ' + string(D.Path);
    Result := Result + Line + ': ' + D.Message + sLineBreak;
  end;
end;

function TLandrixGaebDiagnostics.ToWideText: TLandrixGaebString;
var
  I: TLandrixGaebListIndex;
  D: TLandrixGaebDiagnostic;
  Line: TLandrixGaebString;
begin
  Result := '';
  for I := 0 to Count - 1 do
  begin
    D := Items[I];
    { rule identifiers, severities and messages are ASCII }
    Line := TLandrixGaebString(IntToStr(D.Line) + ':' + IntToStr(D.Column) + ' ' +
      LandrixGaebSeverityToStr(D.Severity) + ' [' + D.RuleId + ']');
    if D.Path <> '' then
      Line := Line + ' ' + D.Path;
    Result := Result + Line + ': ' + TLandrixGaebString(D.Message + sLineBreak);
  end;
end;

end.

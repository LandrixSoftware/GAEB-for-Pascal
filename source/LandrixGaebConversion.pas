{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Checks a conversion: what a bill of quantities becomes when it is saved
  for another target, for example a file of GAEB DA XML 3.0 or 3.1 (read
  only) saved as 3.3. Nothing is repaired and the bill is not changed; the
  result says for each check whether it passed, failed or did not run.
  Rule identifiers (messages never contain values of the document):
    GAEB-CNV-001  error        the output was not written: a value holds
                               characters XML cannot carry
    GAEB-CNV-002  information  a check did not run; the message says which
                               and why
    GAEB-CNV-003  error        the content model check could not parse the
                               output (a limit of the XML reader, e.g. the
                               nesting depth, with its position)
  The XSD validation against the original schemas is a separate step
  (LandrixGaebXmlXsdValidateTarget on the output of
  LandrixGaebCheckConversion).
  DE: Prueft eine Konvertierung: was aus einem LV wird, wenn es fuer ein
  anderes Ziel gespeichert wird, etwa eine Datei in GAEB DA XML 3.0 oder
  3.1 (nur gelesen), gespeichert als 3.3. Nichts wird repariert und das LV
  nicht geaendert; das Ergebnis sagt fuer jede Pruefung, ob sie bestanden
  hat, gescheitert ist oder nicht lief. Regelkennungen (Meldungen enthalten
  nie Werte des Dokuments):
    GAEB-CNV-001  Fehler   die Ausgabe wurde nicht geschrieben: ein Wert
                           enthaelt Zeichen, die XML nicht tragen kann
    GAEB-CNV-002  Hinweis  eine Pruefung lief nicht; der Text sagt welche
                           und warum
    GAEB-CNV-003  Fehler   die Inhaltsmodellpruefung konnte die Ausgabe
                           nicht parsen (eine Grenze des XML-Lesers, etwa
                           die Schachtelungstiefe, mit ihrer Position)
  Die XSD-Pruefung gegen die originalen Schemas ist ein eigener Schritt
  (LandrixGaebXmlXsdValidateTarget auf der Ausgabe von
  LandrixGaebCheckConversion). }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixGaebConversion;

{$I LandrixGaeb.inc}

interface

uses
  Classes,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebBoQ;

type
  { State of one check of a conversion.
    DE: Zustand einer Pruefung einer Konvertierung. }
  TLandrixGaebConversionState = (
    { The check did not run (GAEB-CNV-002 says why).
      DE: Die Pruefung lief nicht (GAEB-CNV-002 sagt warum). }
    gcrNotRun,
    { The check ran and found nothing that fails it.
      DE: Die Pruefung lief und fand nichts, woran sie scheitert. }
    gcrPassed,
    { The check ran and failed.
      DE: Die Pruefung lief und ist gescheitert. }
    gcrFailed
  );

  { Result of LandrixGaebCheckConversion. A record without methods
    (Delphi 6); later releases may add fields.
    DE: Ergebnis von LandrixGaebCheckConversion. Record ohne Methoden
    (Delphi 6); spaetere Versionen koennen Felder ergaenzen. }
  TLandrixGaebConversionResult = record
    { The target checked. DE: Das gepruefte Ziel. }
    OutputTarget: TLandrixGaebTarget;
    { Writing: passed if nothing was lost (no GAEB-WRT-001, -002, -004;
      the information GAEB-WRT-003 does not count), failed if something
      was left out or the output could not be written (GAEB-CNV-001).
      DE: Schreiben: bestanden, wenn nichts verloren ging (kein
      GAEB-WRT-001, -002, -004; der Hinweis GAEB-WRT-003 zaehlt nicht),
      gescheitert, wenn etwas weggelassen wurde oder die Ausgabe nicht
      geschrieben werden konnte (GAEB-CNV-001). }
    Writing: TLandrixGaebConversionState;
    { Content model check of the output (LandrixGaebXmlCheck, stage 2);
      failed also if the output cannot be parsed (GAEB-CNV-003).
      DE: Inhaltsmodellpruefung der Ausgabe (LandrixGaebXmlCheck, Stufe 2);
      gescheitert auch, wenn die Ausgabe nicht geparst werden kann
      (GAEB-CNV-003). }
    Structure: TLandrixGaebConversionState;
    { Business rules of the output phase (LandrixGaebRules) on the output
      as this library reads it back; warnings do not fail it. Not run if
      the output cannot be read back or its phase has no rules.
      DE: Geschaeftsregeln der Ausgabephase (LandrixGaebRules) an der
      Ausgabe, wie diese Bibliothek sie zuruecklies; Warnungen lassen
      sie nicht scheitern. Laeuft nicht, wenn die Ausgabe nicht
      zurueckgelesen werden kann oder ihre Phase keine Regeln hat. }
    Rules: TLandrixGaebConversionState;
  end;

{ Writes ABill for AOutputTarget in memory (with ABill.WriteOptions, but
  mode gwmBestEffort and without the check while writing), checks the
  output against the content models of AOutputTarget, reads it back and
  checks the business rules of its phase. All three run, also when an
  earlier one failed (a passed later check never makes up for a failed
  earlier one). ABill is not changed; its OutputTarget is not used.
  ADiagnostics (may be nil) gets, in this order, the findings of the
  writer (paths of the output, no position), of the content model check,
  of reading the output back and of the rules (line and column of the
  output), and a GAEB-CNV-002 information for each check that did not run.
  The diagnostics of reading ABill stay where the caller has them. With
  AOutput <> nil the output is written to it (at its position), also when
  a check failed; nothing is written if the output could not be produced.
  Raises ELandrixGaebError if AOutputTarget cannot be written or ABill is
  nil.
  DE: Schreibt ABill im Speicher fuer AOutputTarget (mit
  ABill.WriteOptions, aber Modus gwmBestEffort und ohne Pruefung beim
  Schreiben), prueft die Ausgabe gegen die Inhaltsmodelle von
  AOutputTarget, liest sie zurueck und prueft die Geschaeftsregeln ihrer
  Phase. Alle drei laufen, auch wenn eine fruehere gescheitert ist (eine
  bestandene spaetere Pruefung gleicht eine gescheiterte fruehere nie
  aus). ABill wird nicht geaendert; sein OutputTarget wird nicht
  verwendet. ADiagnostics (darf nil sein) erhaelt in dieser Reihenfolge
  die Befunde des Schreibers (Pfade der Ausgabe, keine Position), der
  Inhaltsmodellpruefung, des Zuruecklesens der Ausgabe und der Regeln
  (Zeile und Spalte der Ausgabe) sowie einen Hinweis GAEB-CNV-002 fuer
  jede Pruefung, die nicht lief. Die Meldungen des Lesens von ABill
  bleiben, wo der Aufrufer sie hat. Mit AOutput <> nil wird die Ausgabe
  dorthin geschrieben (an seiner Position), auch wenn eine Pruefung
  gescheitert ist; nichts wird geschrieben, wenn die Ausgabe nicht
  entstehen konnte. Loest ELandrixGaebError aus, wenn AOutputTarget nicht
  geschrieben werden kann oder ABill nil ist. }
function LandrixGaebCheckConversion(ABill: TLandrixGaebBillOfQuantities;
  const AOutputTarget: TLandrixGaebTarget; ADiagnostics: TLandrixGaebDiagnostics;
  AOutput: TStream): TLandrixGaebConversionResult;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebXmlWriter,
  LandrixGaebXmlCheck,
  LandrixGaebRules;

procedure NotRun(ADiagnostics: TLandrixGaebDiagnostics; const AMessage: string);
begin
  if ADiagnostics <> nil then
    ADiagnostics.AddDiagnostic('GAEB-CNV-002', gsInformation, AMessage);
end;

{ True if the catalogue has a single-document rule for APhase. }
function PhaseHasRules(APhase: TLandrixGaebPhase): Boolean;
var
  I: Integer;
  Rule: TLandrixGaebRule;
begin
  Result := False;
  for I := 0 to LandrixGaebRuleCount - 1 do
  begin
    Rule := LandrixGaebRuleAt(I);
    if not Rule.Pair and (APhase in Rule.Phases) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function SameTarget(const A, B: TLandrixGaebTarget): Boolean;
begin
  Result := (A.Version = B.Version) and (A.Edition = B.Edition) and (A.Phase = B.Phase);
end;

{ Reads the output back and checks the rules of its phase. }
function CheckRules(const AOutput: TLandrixXmlUtf8; const ATarget: TLandrixGaebTarget;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebConversionState;
var
  Document: TLandrixGaebXmlGAEB;
  Detection: TLandrixGaebDetection;
begin
  Result := gcrNotRun;
  if not PhaseHasRules(ATarget.Phase) then
  begin
    NotRun(ADiagnostics, 'business rules not run: the phase of the output has no business rules');
    Exit;
  end;
  try
    Document := LandrixGaebXmlReadBuffer(Pointer(AOutput), Length(AOutput), ADiagnostics, Detection);
  except
    on ELandrixGaebError do
    begin
      NotRun(ADiagnostics, 'business rules not run: the output cannot be read back');
      Exit;
    end;
    on ELandrixXmlError do
    begin
      NotRun(ADiagnostics, 'business rules not run: the output cannot be read back');
      Exit;
    end;
  end;
  try
    if not SameTarget(Detection.Target, ATarget) then
      NotRun(ADiagnostics, 'business rules not run: the output is read back as another target')
    else if LandrixGaebCheckRules(Document, ATarget, ADiagnostics) then
      Result := gcrPassed
    else
      Result := gcrFailed;
  finally
    Document.Free;
  end;
end;

function LandrixGaebCheckConversion(ABill: TLandrixGaebBillOfQuantities;
  const AOutputTarget: TLandrixGaebTarget; ADiagnostics: TLandrixGaebDiagnostics;
  AOutput: TStream): TLandrixGaebConversionResult;
var
  Options: TLandrixGaebXmlWriteOptions;
  Output: TLandrixXmlUtf8;
  Errors, Warnings: Integer;
  Written: Boolean;
begin
  if ABill = nil then
    raise ELandrixGaebError.Create('no bill of quantities to check');
  if not LandrixGaebTargetIsSupported(AOutputTarget, True) then
    raise ELandrixGaebError.Create('GAEB DA XML ' +
      LandrixXmlUtf8ToString(LandrixGaebVersionToText(AOutputTarget.Version)) + ' ' +
      LandrixXmlUtf8ToString(LandrixGaebEditionToText(AOutputTarget.Edition)) + ' DA' +
      LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(AOutputTarget.Phase)) +
      ' is not supported for writing');
  Result.OutputTarget := AOutputTarget;
  Result.Writing := gcrNotRun;
  Result.Structure := gcrNotRun;
  Result.Rules := gcrNotRun;
  Options := ABill.WriteOptions;
  Options.Mode := gwmBestEffort;
  Options.Check := False;
  Output := '';
  Written := False;
  try
    Output := LandrixGaebXmlWriteCollect(ABill.Document, AOutputTarget, Options, ADiagnostics,
      Errors, Warnings);
    Written := True;
    if (Errors > 0) or (Warnings > 0) then
      Result.Writing := gcrFailed
    else
      Result.Writing := gcrPassed;
  except
    on ELandrixXmlError do
    begin
      Result.Writing := gcrFailed;
      if ADiagnostics <> nil then
        ADiagnostics.AddDiagnostic('GAEB-CNV-001', gsError,
          'output not written: a value holds characters XML cannot carry');
    end;
  end;
  if not Written then
  begin
    NotRun(ADiagnostics, 'content model check not run: no output');
    NotRun(ADiagnostics, 'business rules not run: no output');
    Exit;
  end;
  if AOutput <> nil then
    if Length(Output) > 0 then
      AOutput.WriteBuffer(Output[1], Length(Output));
  try
    if LandrixGaebXmlCheckTarget(Pointer(Output), Length(Output), AOutputTarget, ADiagnostics) then
      Result.Structure := gcrPassed
    else
      Result.Structure := gcrFailed;
  except
    on E: ELandrixXmlError do
    begin
      Result.Structure := gcrFailed;
      if ADiagnostics <> nil then
        ADiagnostics.AddAt('GAEB-CNV-003', gsError, '', E.Line, E.Column, E.Offset,
          'content model check stopped: the output exceeds a limit of the XML reader');
    end;
  end;
  Result.Rules := CheckRules(Output, AOutputTarget, ADiagnostics);
end;

end.

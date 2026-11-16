{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Mapping of the records of a GAEB 90 file (LandrixGaebDA90Parser) into
  the syntax model of GAEB DA XML 3.3 (2021-05), record by record; what has
  no counterpart, or is not mapped yet, is reported once per record type
  or field with a count.

  Mapped (exchange phases 81 to 86):
  - 00: DP -> Award/DP, KURZLANG L/K -> BoQInfo/OutlCompl AllTxt/OutTxt,
    VERGAG -> OWN/AwardNo, DVNRAG -> OWN/DPNo, BIETERAG -> CTR/BidderNo,
    VERGAN -> CTR/AwardNo, DVNRAN -> CTR/DPNo, OZMASKE -> BoQBkdn;
  - 01: LVBEZ -> BoQInfo/LblBoQ, LVDATUM -> BoQInfo/Date and
    GAEBInfo/Date, DATANG and
    DATUHR -> AwardInfo/OpenDate and OpenTime, DATZUS -> AwardInfo/EvalEnd;
  - 02: the first line -> PrjInfo/LblPrj, all lines -> PrjInfo/Descrip;
    03 -> OWN, 04 -> CTR (Address/Name1, beyond 40 characters Name2);
    06: ANZEP -> NoUPComps, BEZEITAN -> LblTime, BEZEPAN1 to 4 ->
    LblUPComp1 to 4 (type Unknown); 08: WAEKU and WAEBEZ -> Cur and CurLbl
    of PrjInfo and AwardInfo;
  - the hierarchy from the ordinal numbers and the mask: each level of the
    mask is a BoQBkdn level (KENNWORT of 11 -> LblBoQBkdn, Alignment right,
    Num Yes when every part of the level is written with digits only, zeros
    in front included, No otherwise and for a level without values); an
    item belongs to the category of the deepest level its number fills
    (lower levels may stay empty); categories without record 11 are
    derived from the numbers. 11 -> BoQCtgy (RNoPart, LVGRART G/A with ZZV
    -> ALNBGroupNo and ALNBSerNo), 12 -> LblTx (a paragraph per line), 31
    closes nothing (the numbers decide), 32 -> Totals (SUMME -> Total,
    PAUSCH -> TotalLSUM);
  - 20 with 26 -> Remark; 21 (or, in phase 84, a 23 without 21) -> Item:
    RNoPart and RNoIndex from the mask, POSART1 G/A with ZZ -> ALNGroupNo
    and ALNSerNo, S -> HourIt, POSART2 E/M -> Provis WithoutTotal/
    WithTotal, POSTYP L -> SumDescr, EPAUFGL -> UPBkdn, ZUSCHLAG E ->
    MarkupIt, WIEVOR B/W -> RefDescr Ref/Rep, KZFRMENG -> QtyTBD, MENGE ->
    Qty, EINHEIT -> QU (psch -> LumpSumItem; ---- for no unit as written),
    POSSTAT R -> NotAppl (NACHTRKZ is not mapped: CONo needs a COStatus
    GAEB 90 does not have); ZUSCHLAG Z -> MarkupItem (IdentAsMark);
    POSART1/2/POSTYP NNH (edition 1985, a note text) -> Remark;
  - 22 (phase 82) and 23: VEP/EP with VEPZPF/EPZPF (third decimal) -> UP,
    VGB/GB -> IT, the free quantity -> Qty of an item with QtyTBD or
    without MENGE, VZUSCHP/ZUSCHPR -> Markup and VZUSCHSU/ZUSCHSU ->
    ITMarkup of a markup item; 30: ZEITANS -> TimeQu, EPANTEL1 to 4 ->
    UPComp1 to 4;
  - texts: 25 -> OutlTxt and 26 -> DetailTxt, a paragraph per line
    (spaces on the right removed); consecutive lines with the same KNR and
    TEKZ A/B (25: KNR only, owner) are a TextComplement when they hold
    exactly two apostrophes: text before -> ComplCaption, between ->
    ComplBody (dots, underscores or nothing -> Empty), after -> ComplTail;
    TA/TB -> ComplTSA/ComplTSB;
  - 99: LVSUMME -> BoQInfo/Totals/Total, UST -> VAT, ANGEBOTS ->
    TotalGross, PAUSCH -> TotalLSUM;
  - 24 -> SubDescr of the item (UB -> SubDNo, UBMENGE -> Qty, EINHEIT ->
    QU, KZFRMENG -> QtyTBD, its 28/25/26/79 -> Description); 27 -> QtySplit
    (TEILMENG -> Qty); 28: OZ -> RefRNo, AUSNR -> RefPerfNo (IDRef of the
    item or execution description with that number), KURZAN -> the short
    text when the item has no 25 (a different one is counted);
  - 41 with its blocks 42 (25/26) -> PerfDescr (AUSNR -> PerfNo, AUSBEZ ->
    PerfLbl, each block -> Description), placed as a remark;
  - STLNR with TEXTSYST 1/2 (20, 21, 24, 42) -> StLNo (Type StLB/StLK);
    79 -> STLBBau (STLPAR -> CtlgName, VJ/VM -> VersDate, LB -> WCtg, TLG ->
    Group, each BM/BMI/AP -> STLBBauID ArtChrIdent/ArtChIdx/ChVIdent), which
    takes the place of StLNo;
  - T0/T1/T9 (contract terms) -> Award/AddText, one per block, a paragraph
    per T1 line (DetailAddText);
  - lots, which GAEB 90 keeps outside the ordinal number: with records 10
    the breakdown gets a level Lot (length 2) above the levels of the mask;
    10 opens the lot category (LOSNR -> RNoPart, LOSBEZ -> LblTx), what
    follows up to its 33 belongs to it, 33 -> its Totals; the numbers of a
    lot (also those 28 refers to) are taken within it; 34 -> BoQ/LotGrp
    (LOSGRNR -> LotGrNo, Totals), each LOSNR of 35 -> RefLotNo;
  - wage changes: 46 -> Award/WgChange/LblRefWage (lines joined), 47 ->
    RefGroup with RefBoQ, 45 with LOSNR or LOSGRNR -> RefGroup with RefLotNo
    or RefLotGrNo (the amounts and rates are not mapped);
  - AUFABFAK (factor f, 32/33/34/99) -> DiscountPcnt (1 - f) x 100 and
    TotAfterDisc (total x f, rounded commercially), AUFABDM -> DiscountAmt
    (minus: a discount) and TotAfterDisc, unless the totals carry a lump
    sum (GAEB DA XML takes one of them); f of 23 -> DiscountPcnt of the
    item; f 0 or 1 is no discount (0 stands for an empty field in the
    files seen, never for a discount of 100 percent); SKONTO with ZAFRIST
    of 99 -> AwardInfo/CashDiscount;
  - a second record of totals (32, 33) for the same group or lot is not
    mapped (the first one counts); a wage change without LblRefWage (46)
    or without any reference it can carry is left out.
  Numbers carry an implied decimal point; spaces instead of leading zeros
  are read, spaces behind are not. Dates TT.MM.JJ become YYYY-MM-DD (JJ
  below 70: 20JJ, else 19JJ; days checked against the calendar), times HH:MM become HH:MM:SS. IDs are generated (LGB, LGC, LGI, LGR
  plus a number).

  Diagnostics (rule identifiers):
    GAEB-BR-D90-001 error        OZMASKE missing or not readable (items
                                 without hierarchy)
    GAEB-BR-D90-003 warning      ANZTEIL of 99 other than the positions
    GAEB-BR-D90-005 warning      OZMASKE with spaces as fill
    GAEB-BR-D90-006 error        ZUSCHLAG other than space, E or Z (item
                                 kept)
    GAEB-BR-D90-007 error/warning  POSART1/POSART2/POSTYP not one of the
                                 16 combinations (NNH: warning, read as a
                                 note text)
    GAEB-BR-D90-008 warning      POSSTAT other than R or space
    GAEB-BR-D90-009 error        WIEVOR W without the OZ of its 28, A without
                                 its AUSNR, or a 28 with a reference its
                                 WIEVOR does not name
    GAEB-BR-D90-011 warning      text complement lines with TEKZ other
                                 than A or B, or KNR without TEKZ (text
                                 kept)
    GAEB-BR-D90-013 warning      contract terms (T0 to T9) inside the bill
    GAEB-BR-D90-017 error        LOSKZ X without lots, or lots without LOSKZ
                                 X; records outside any lot in a file with
                                 lots; lot or lot group numbers used a
                                 second time (references go to the first)
    GAEB-BR-D90-014 information  record types GAEB 90 does not define
                                 (free range 70 to 89, vendor records,
                                 others) skipped
    GAEB-BR-D90-016 warning      more than 9 lines of 02, 12 or 25, or more
                                 than 999 of 26
    GAEB-D90-MAP-001 information record types not mapped (yet)
    GAEB-D90-MAP-002 information fields with a value not mapped
    GAEB-D90-MAP-003 warning     text complements without exactly two
                                 apostrophes (text kept)
    GAEB-D90-MAP-004 warning     codes outside the values of GAEB 90
    GAEB-D90-MAP-005 information categories derived from the ordinal
                                 numbers (without record 11)
    GAEB-D90-MAP-006 warning     control characters removed
    GAEB-D90-MAP-007 information breakdown levels without any value
    GAEB-D90-MAP-008 warning     numbers that are no digits (left out);
                                 information: numbers with spaces instead
                                 of leading zeros (read)
    GAEB-D90-MAP-009 warning     records without the record they belong to
                                 (left out)
    GAEB-D90-MAP-010 warning     dates and times in another form (left
                                 out)
    GAEB-D90-MAP-011 error       categories and items on one level
    GAEB-D90-MAP-012 warning     a further bill (00) in the file, not read
    GAEB-D90-MAP-013 warning     ordinal numbers with an empty level above
                                 a filled one, or without an item number
    GAEB-D90-MAP-014 information required parts of GAEB DA XML GAEB 90 has
                                 no source for, filled: BoQInfo/Name from
                                 VERGAG or the first 20 characters of LVBEZ,
                                 PrjInfo/NamePrj from the first line of
                                 PROBEZ, else VERGAG, else LVBEZ (owner
                                 decisions 15.11.2026), GAEBInfo/Date
                                 from LVDATUM (owner decision 16.11.2026;
                                 without a usable LVDATUM it stays
                                 missing, reported), an empty LblTx for
                                 categories without record 12; reported
                                 too: Street, PCode and City of the
                                 address of 03/04, which GAEB 90 does not
                                 have (owner decision 16.11.2026: not
                                 split from the name line)
    GAEB-D90-MAP-015 information KURZAN of 28 other than the first line of
                                 the short text (the short text kept)
    GAEB-D90-MAP-016 warning     references (28, 35, 45) to a number that no
                                 item, execution description, lot or lot
                                 group has (left out)
    GAEB-D90-MAP-017 warning     discounts and surcharges the totals cannot
                                 carry (no total, or a lump sum beside
                                 them), wage change texts over 120
                                 characters (cut), cash discounts without
                                 days
  Messages name record types and fields, never values.

  DE: Abbildung der Saetze einer GAEB-90-Datei in das Syntaxmodell von
  GAEB DA XML 3.3 (2021-05), Satz fuer Satz; was kein Gegenstueck hat oder
  noch nicht abgebildet ist, wird je Satzart oder Feld einmal mit Anzahl
  gemeldet. Meldungen nennen Satzarten und Felder, nie Werte. }

{ API: internal. May change in any release, also after 1.0; use the
  stable units instead (see README).
  DE: API: intern. Kann sich in jeder Version aendern, auch nach 1.0;
  stattdessen die stabilen Units verwenden (siehe README). }

unit LandrixGaebDA90Mapping;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebXmlModel,
  LandrixGaebCharsets,
  LandrixGaebDetect,
  LandrixGaebDA90Parser;

{ Maps ADocument into a new GAEB DA XML 3.3 document. ATarget is
  3.3/2021-05 with the phase of the file. Raises ELandrixGaebError when
  the file holds no record 00 or a phase other than 81 to 86. ADiagnostics
  and AInvalidTotals may be nil; AInvalidTotals (not owning) receives the
  TLandrixGaebXmlTotals whose total the source holds in an unusable form.
  DE: Bildet ADocument in ein neues Dokument GAEB DA XML 3.3 ab. ATarget
  ist 3.3/2021-05 mit der Phase der Datei. Loest ELandrixGaebError aus,
  wenn die Datei keinen Satz 00 oder eine andere Phase als 81 bis 86
  enthaelt. ADiagnostics und AInvalidTotals duerfen nil sein;
  AInvalidTotals erhaelt die TLandrixGaebXmlTotals, deren Summe die Quelle
  in unbrauchbarer Form enthaelt. }
function LandrixGaebDA90Map(ADocument: TLandrixGaebDA90Document;
  ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

{ Reads a GAEB 90 file held in Buffer: detection, record reader and
  mapping. AMaxSize <= 0 means LandrixGaebDefaultMaxSize; ACharset and
  AOemCodePage as in LandrixGaebDA90Parse. ADetection describes the input,
  ATarget the returned document. AItemsWithoutKind receives the number of
  items and markup items made from a 23 without 21 (phase 84), which carry
  no kind (basic, alternative, contingency). Raises ELandrixGaebError for input larger
  than AMaxSize, input that is no GAEB 90 and the errors of the record
  reader and the mapping. The caller owns the result.
  DE: Liest eine GAEB-90-Datei aus Buffer: Erkennung, Satzleser und
  Abbildung. AMaxSize <= 0 bedeutet LandrixGaebDefaultMaxSize; ACharset und
  AOemCodePage wie bei LandrixGaebDA90Parse. ADetection beschreibt die
  Eingabe, ATarget das gelieferte Dokument. AItemsWithoutKind erhaelt die
  Zahl der Positionen und Zuschlagspositionen aus einem 23 ohne 21 (Phase
  84), die keine Art
  (Grund-, Alternativ-, Eventualposition) tragen. Loest ELandrixGaebError
  aus fuer Eingaben ueber AMaxSize, Eingaben, die kein GAEB 90 sind, und
  die Fehler von Satzleser und Abbildung. Das Ergebnis gehoert dem
  Aufrufer. }
function LandrixGaebDA90ReadMapped(Buffer: Pointer; Size: Integer; AMaxSize: Int64;
  ACharset: TLandrixGaebCharset; AOemCodePage: TLandrixGaebCodePage;
  ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out AItemsWithoutKind: Integer; out ADetection: TLandrixGaebDetection;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

{ The same for a stream from its current position to its end (it must
  know its Size); the size limit is checked before anything is read.
  DE: Dasselbe fuer einen Stream ab der aktuellen Position bis zum Ende
  (er muss seine Groesse kennen); die Groessengrenze wird geprueft, bevor
  etwas gelesen wird. }
function LandrixGaebDA90ReadMappedStream(AStream: TStream; AMaxSize: Int64;
  ACharset: TLandrixGaebCharset; AOemCodePage: TLandrixGaebCodePage;
  ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out AItemsWithoutKind: Integer; out ADetection: TLandrixGaebDetection;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

implementation

uses
  LandrixXmlBase,
  LandrixXmlDecimal,
  LandrixGaebNameTable;

const
  RuleMask = 'GAEB-BR-D90-001';
  RuleCount = 'GAEB-BR-D90-003';
  RuleMaskSpaces = 'GAEB-BR-D90-005';
  RuleMarkup = 'GAEB-BR-D90-006';
  RuleKind = 'GAEB-BR-D90-007';
  RuleStatus = 'GAEB-BR-D90-008';
  RuleTekz = 'GAEB-BR-D90-011';
  RuleSkipped = 'GAEB-BR-D90-014';
  RuleLimits = 'GAEB-BR-D90-016';
  RuleNotMapped = 'GAEB-D90-MAP-001';
  RuleFields = 'GAEB-D90-MAP-002';
  RuleMarks = 'GAEB-D90-MAP-003';
  RuleValue = 'GAEB-D90-MAP-004';
  RuleDerived = 'GAEB-D90-MAP-005';
  RuleControl = 'GAEB-D90-MAP-006';
  RuleUnusedLevel = 'GAEB-D90-MAP-007';
  RuleNumber = 'GAEB-D90-MAP-008';
  RuleOrphan = 'GAEB-D90-MAP-009';
  RuleDate = 'GAEB-D90-MAP-010';
  RuleLevels = 'GAEB-D90-MAP-011';
  RuleSecondBill = 'GAEB-D90-MAP-012';
  RuleNumbers = 'GAEB-D90-MAP-013';
  RuleFilled = 'GAEB-D90-MAP-014';
  RuleKurzan = 'GAEB-D90-MAP-015';
  RuleReference = 'GAEB-D90-MAP-016';
  RuleRefKind = 'GAEB-BR-D90-009';
  RuleContractInside = 'GAEB-BR-D90-013';
  RuleLots = 'GAEB-BR-D90-017';
  RuleDiscount = 'GAEB-D90-MAP-017';

  { the 16 combinations of POSART1, POSART2 and POSTYP }
  PositionKinds = '|NNN|NNL|NEN|NEL|NMN|NML|ANN|ANL|GNN|GNL|AEN|AEL|GMN|GML|SNN|SNL|';
  { record types of GAEB 90 that are not mapped yet }
  NotMappedKinds = '|07|';

type
  { counts per name, reported in the order the names first occurred }
  TCounts = class(TObject)
  private
    FTable: TLandrixGaebNameTable;
    FNames: array of string;
    FCounts: array of Integer;
    FCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const AName: string);
    property Count: Integer read FCount;
  end;

  { lines of a text: the line, KNR and TEKZ (26) as written }
  TLines = class(TObject)
  public
    Text: array of TLandrixGaebString;
    Knr: array of string;
    Tekz: array of Char;
    Count: Integer;
    procedure Add(const AText: TLandrixGaebString; const AKnr: string; ATekz: Char);
    procedure Clear;
  end;

  TPartArray = array of TLandrixGaebString;

  { a level of the mask }
  TLevel = record
    Kind: string;
    Start: Integer;
    Length: Integer;
  end;

  TMapper = class(TObject)
  private
    FDoc: TLandrixGaebDA90Document;
    FDiags: TLandrixGaebDiagnostics;
    FInvalidTotals: TObjectList;
    FNextId: Integer;
    FG: TLandrixGaebXmlGAEB;
    FPhase: string;
    FUsed: array of Boolean;
    { mask }
    FLevels: array of TLevel;
    FCategoryLevels: Integer;
    FItemLevel, FIndexLevel: Integer;
    FLevelLabels: array of TLandrixGaebString;
    FLevelSeen, FLevelOther: array of Boolean;
    { open categories by level }
    FRootBody: TLandrixGaebXmlBoQBody;
    FOpenPart: array of TLandrixGaebString;
    FOpenCtgy: array of TLandrixGaebXmlBoQCtgy;
    FOpenImplicit, FOpenHasCtgy, FOpenHasItem: array of Boolean;
    FOpenDepth: Integer;
    FRootHasCtgy, FRootHasItem: Boolean;
    { every category by its path (the parts joined), first one wins }
    FCtgyTable: TLandrixGaebNameTable;
    FCtgys: array of TLandrixGaebXmlBoQCtgy;
    FCtgyCount: Integer;
    { counters }
    FNotMapped, FSkipped, FFields, FValues, FBadNumbers, FOrphans, FDates, FLimits: TCounts;
    FPadded, FControl, FDerived, FMixed, FMarkProblems, FTekz, FNumberProblems: Integer;
    FMarkupValues, FBadKinds, FOldNotes, FStatus, FItems, FNoKind: Integer;
    FMaskSpaces: Boolean;
    FVergag: TLandrixGaebString;
    { items and execution descriptions by number, and the references to
      resolve at the end }
    FItemTable, FPerfTable: TLandrixGaebNameTable;
    FItemIds, FPerfIds: array of TLandrixGaebString;
    { with lots: items by number without the lot (an empty ID: the number
      is in more than one lot) }
    FOzTable: TLandrixGaebNameTable;
    FOzIds: array of TLandrixGaebString;
    FOzCount: Integer;
    FItemCount, FPerfCount: Integer;
    FRefs: array of TLandrixGaebXmlRefItem;
    FRefKeys: array of TLandrixGaebString;
    FRefIsPerf: array of Boolean;
    FRefCount, FUnresolved, FRefKind, FKurzan, FIncompleteStlb, FIncompletePerf: Integer;
    FInBill: Boolean;
    FContractInside: Integer;
    { lots: the current lot number ('' outside), lot groups by number }
    FHasLots: Boolean;
    FCurLot: TLandrixGaebString;
    FLotGrpTable: TLandrixGaebNameTable;
    FLotGrps: array of TLandrixGaebXmlLotGrp;
    FLotGrpCount: Integer;
    FLotRefs: array of TLandrixGaebXmlRefBoQCtgy;
    FLotRefKeys: array of TLandrixGaebString;
    FLotRefCount: Integer;
    FGrpRefs: array of TLandrixGaebXmlRefLotGrp;
    FGrpRefKeys: array of TLandrixGaebString;
    FGrpRefCount: Integer;
    FOutsideLot, FDiscountLost, FLotTwice: Integer;
    FWgLines: TLandrixGaebString;
    { the last lot group (34), for its 35 }
    FLastGrp: TLandrixGaebXmlLotGrp;
    FLastGrpNo: TLandrixGaebString;
    { set while ItemlistFor looks ahead: nothing is counted twice }
    FQuiet: Boolean;
    { the look-ahead of ItemlistFor: from FLookFrom on, the next record
      that places a remark is FLookAt (Count: none) }
    FLookFrom, FLookAt: Integer;
    FDescrShort, FDescrLong: TLines;
    procedure Report(AIndex: Integer; const ARuleId: string; ASeverity: TLandrixGaebSeverity;
      const AMessage: string);
    procedure ReportCounts(ACounts: TCounts; const ARuleId: string; ASeverity: TLandrixGaebSeverity;
      const AText: string);
    function NewId(const APrefix: string): TLandrixGaebString;
    { fields }
    function Raw(AIndex, AFrom, ATo: Integer): TLandrixGaebString;
    function Str(AIndex, AFrom, ATo: Integer): TLandrixGaebString;
    function Code(AIndex, ACol: Integer; const AName, AAllowed: string): Char;
    function NumField(AIndex, AFrom, ATo, AFraction, ASign: Integer; const AName: string;
      var ADecimal: TLandrixGaebDecimal): Boolean;
    procedure Price(AIndex, AFrom, ATo, ASign, AThird: Integer; const AName: string;
      var ADecimal: TLandrixGaebDecimal);
    function DateField(AIndex, AFrom: Integer; const AName: string): TLandrixGaebString;
    function TimeField(AIndex, AFrom: Integer; const AName: string): TLandrixGaebString;
    procedure Unmapped(AIndex, AFrom, ATo: Integer; const AName: string);
    { structure }
    procedure ReadMask(AIndex: Integer);
    procedure PartsOf(const AOZ: TLandrixGaebString; out AParts: TPartArray;
      out ADepth: Integer; out AItem, AIndex: TLandrixGaebString; out ABad: Boolean);
    function PathKey(const AParts: TPartArray; ADepth: Integer): TLandrixGaebString;
    procedure OpenPath(const AParts: TPartArray; ADepth, AExplicitLevel: Integer);
    function BodyAt(ADepth: Integer): TLandrixGaebXmlBoQBody;
    procedure NoteItem(ADepth: Integer);
    function ItemlistFor(AIndex: Integer): TLandrixGaebXmlItemlist;
    { texts }
    procedure CollectText(var AIndex: Integer; ALines: TLines; const AKind: string);
    procedure AddLinesTo(const AText: TLandrixGaebString; P: TLandrixGaebXmlPMLText);
    function IsPlaceholder(const S: TLandrixGaebString): Boolean;
    function SplitComplement(ALines: TLines; AFirst, ALast: Integer;
      out ACaption, ABody, ATail: TLandrixGaebString): Boolean;
    procedure FillComplement(AComplement: TLandrixGaebXmlTextComplement; ABidder: Boolean;
      const AKnr, ACaption, ABody, ATail: TLandrixGaebString);
    procedure MapLong(ALines: TLines; ADetail: TLandrixGaebXmlBoQText);
    procedure MapShort(ALines: TLines; AOutline: TLandrixGaebXmlOutlTxt);
    function MapTextParts(AShort, ALong: TLines; ATA, ATB: Boolean; AComplete: TLandrixGaebXmlCompleteText;
      AOutline: TLandrixGaebXmlOutlineText): Boolean;
    procedure MapTexts(AShort, ALong: TLines; ATA, ATB: Boolean; ADescription: TLandrixGaebXmlDescription);
    function MapStLNo(AIndex, ASystem, AFrom, ATo: Integer; AStLNo: TLandrixGaebXmlStLNo): Boolean;
    function MapStlbBau(const ACatalog, AText: TLandrixGaebString; AStlb: TLandrixGaebXmlSTLBBau): Boolean;
    function NumberKey(const AOZ: TLandrixGaebString): TLandrixGaebString;
    procedure AddOz(const AKey, AId: TLandrixGaebString);
    function PerfKey(const ANo: TLandrixGaebString): TLandrixGaebString;
    procedure AddRef(ARef: TLandrixGaebXmlRefItem; const AKey: TLandrixGaebString; AIsPerf: Boolean);
    procedure ResolveRefs;
    procedure MapSub(var AIndex: Integer; AItem: TLandrixGaebXmlItem);
    procedure MapPerf(var AIndex: Integer);
    procedure MapContract(var AIndex: Integer);
    procedure MapDiscount(AIndex, AFactor, ASign, AAmount: Integer; ATotals: TLandrixGaebXmlTotals);
    procedure MapLot(AIndex: Integer);
    procedure MapLotEnd(AIndex: Integer);
    procedure MapLotGroup(AIndex: Integer);
    procedure MapLotGroupLots(AIndex: Integer);
    procedure MapWage(AIndex: Integer);
    procedure FinishWage;
    procedure AddLotRef(ARef: TLandrixGaebXmlRefBoQCtgy; const ALot: TLandrixGaebString);
    procedure AddGroupRef(ARef: TLandrixGaebXmlRefLotGrp; const AGroup: TLandrixGaebString);
    { records }
    procedure MapHeader00(AIndex: Integer);
    procedure MapHeader01(AIndex: Integer);
    procedure MapProject(var AIndex: Integer);
    procedure MapParty(AIndex: Integer; AAddress: TLandrixGaebXmlAddress; const AWhat: string);
    procedure MapComponents(AIndex: Integer);
    procedure MapCurrency(AIndex: Integer);
    procedure MapGroup(var AIndex: Integer);
    procedure MapGroupTotals(AIndex: Integer);
    procedure MapRemark(var AIndex: Integer);
    procedure MapItem(var AIndex: Integer);
    procedure MapClosing(AIndex: Integer);
    procedure SkipBlock(var AIndex: Integer; const AFollowers: string);
    procedure AddBreakdown;
    procedure FillRequired;
  public
    constructor Create;
    destructor Destroy; override;
    function Map(ADocument: TLandrixGaebDA90Document; ADiagnostics: TLandrixGaebDiagnostics;
      AInvalidTotals: TObjectList; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
    { Items and markup items made from a 23 without 21. }
    property ItemsWithoutKind: Integer read FNoKind;
  end;

function W(const S: string): TLandrixGaebString;
begin
  Result := LandrixXmlUtf8ToWide(LandrixXmlStringToUtf8(S));
end;

function TrimW(const S: TLandrixGaebString): TLandrixGaebString;
var
  A, B: Integer;
begin
  A := 1;
  B := Length(S);
  while (A <= B) and (S[A] = ' ') do
    Inc(A);
  while (B >= A) and (S[B] = ' ') do
    Dec(B);
  Result := Copy(S, A, B - A + 1);
end;

function TrimRightW(const S: TLandrixGaebString): TLandrixGaebString;
var
  B: Integer;
begin
  B := Length(S);
  while (B >= 1) and (S[B] = ' ') do
    Dec(B);
  Result := Copy(S, 1, B);
end;

{ An ASCII value as string; characters outside ASCII as '?'. }
function AsciiOf(const S: TLandrixGaebString): string;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    if Ord(S[I]) < 128 then
      Result[I] := Char(Ord(S[I]))
    else
      Result[I] := '?';
end;

function IsDigits(const S: TLandrixGaebString): Boolean;
var
  I: Integer;
begin
  Result := S <> '';
  for I := 1 to Length(S) do
    if (S[I] < '0') or (S[I] > '9') then
    begin
      Result := False;
      Exit;
    end;
end;

function BadXmlChar(const S: TLandrixGaebString; I: Integer): Boolean;
var
  C: Word;
begin
  C := Ord(S[I]);
  if (C >= $D800) and (C <= $DBFF) then
    Result := (I >= Length(S)) or (Ord(S[I + 1]) < $DC00) or (Ord(S[I + 1]) > $DFFF)
  else if (C >= $DC00) and (C <= $DFFF) then
    Result := (I <= 1) or (Ord(S[I - 1]) < $D800) or (Ord(S[I - 1]) > $DBFF)
  else
    Result := ((C < 32) and (C <> 9) and (C <> 10) and (C <> 13)) or (C = $FFFE) or (C = $FFFF);
end;

{ S without the characters XML 1.0 cannot carry; ACount is increased by
  their number. }
function XmlSafe(const S: TLandrixGaebString; var ACount: Integer): TLandrixGaebString;
var
  I, N: Integer;
begin
  N := 0;
  for I := 1 to Length(S) do
    if BadXmlChar(S, I) then
      Inc(N);
  if N = 0 then
  begin
    Result := S;
    Exit;
  end;
  Inc(ACount, N);
  Result := '';
  SetLength(Result, Length(S) - N);
  N := 0;
  for I := 1 to Length(S) do
    if not BadXmlChar(S, I) then
    begin
      Inc(N);
      Result[N] := S[I];
    end;
end;

{ True if AKey is one of the |-separated names of AList. }
function InList(const AKey, AList: string): Boolean;
begin
  Result := Pos('|' + AKey + '|', AList) > 0;
end;

function ToDecimal(const A: TLandrixXmlDecimal; out AValue: TLandrixGaebDecimal): Boolean;
begin
  AValue.Clear;
  Result := AValue.TrySetText(LandrixXmlFormatDecimal(A));
end;

{ ---- TCounts ---- }

constructor TCounts.Create;
begin
  inherited Create;
  FTable := TLandrixGaebNameTable.Create;
end;

destructor TCounts.Destroy;
begin
  FTable.Free;
  inherited Destroy;
end;

procedure TCounts.Add(const AName: string);
var
  K: Integer;
begin
  K := FTable.Find(W(AName));
  if K < 0 then
  begin
    K := FCount;
    FTable.Add(W(AName), K);
    if K >= Length(FNames) then
    begin
      SetLength(FNames, 2 * K + 16);
      SetLength(FCounts, 2 * K + 16);
    end;
    FNames[K] := AName;
    FCounts[K] := 0;
    Inc(FCount);
  end;
  Inc(FCounts[K]);
end;

{ ---- TLines ---- }

procedure TLines.Add(const AText: TLandrixGaebString; const AKnr: string; ATekz: Char);
begin
  if Count >= Length(Text) then
  begin
    SetLength(Text, 2 * Count + 16);
    SetLength(Knr, 2 * Count + 16);
    SetLength(Tekz, 2 * Count + 16);
  end;
  Text[Count] := AText;
  Knr[Count] := AKnr;
  Tekz[Count] := ATekz;
  Inc(Count);
end;

procedure TLines.Clear;
begin
  Count := 0;
end;

{ ---- TMapper: basics ---- }

constructor TMapper.Create;
begin
  inherited Create;
  FNotMapped := TCounts.Create;
  FSkipped := TCounts.Create;
  FFields := TCounts.Create;
  FValues := TCounts.Create;
  FBadNumbers := TCounts.Create;
  FOrphans := TCounts.Create;
  FDates := TCounts.Create;
  FLimits := TCounts.Create;
  FDescrShort := TLines.Create;
  FDescrLong := TLines.Create;
  FItemLevel := -1;
  FIndexLevel := -1;
  FCtgyTable := TLandrixGaebNameTable.Create;
  FItemTable := TLandrixGaebNameTable.Create;
  FOzTable := TLandrixGaebNameTable.Create;
  FPerfTable := TLandrixGaebNameTable.Create;
  FLotGrpTable := TLandrixGaebNameTable.Create;
end;

destructor TMapper.Destroy;
begin
  FLotGrpTable.Free;
  FPerfTable.Free;
  FOzTable.Free;
  FItemTable.Free;
  FCtgyTable.Free;
  FDescrLong.Free;
  FDescrShort.Free;
  FLimits.Free;
  FDates.Free;
  FOrphans.Free;
  FBadNumbers.Free;
  FValues.Free;
  FFields.Free;
  FSkipped.Free;
  FNotMapped.Free;
  inherited Destroy;
end;

procedure TMapper.Report(AIndex: Integer; const ARuleId: string; ASeverity: TLandrixGaebSeverity;
  const AMessage: string);
var
  Line: Integer;
begin
  if FDiags = nil then
    Exit;
  Line := 0;
  if AIndex >= 0 then
    Line := FDoc.Line(AIndex);
  FDiags.AddAt(ARuleId, ASeverity, '', Line, 0, -1, AMessage);
end;

procedure TMapper.ReportCounts(ACounts: TCounts; const ARuleId: string; ASeverity: TLandrixGaebSeverity;
  const AText: string);
var
  I: Integer;
begin
  for I := 0 to ACounts.Count - 1 do
    Report(-1, ARuleId, ASeverity, ACounts.FNames[I] + ': ' + IntToStr(ACounts.FCounts[I]) + ' ' + AText);
end;

function TMapper.NewId(const APrefix: string): TLandrixGaebString;
begin
  Inc(FNextId);
  Result := W(APrefix + IntToStr(FNextId));
end;

{ ---- TMapper: fields ---- }

function TMapper.Raw(AIndex, AFrom, ATo: Integer): TLandrixGaebString;
begin
  Result := XmlSafe(FDoc.Field(AIndex, AFrom, ATo), FControl);
end;

function TMapper.Str(AIndex, AFrom, ATo: Integer): TLandrixGaebString;
begin
  Result := TrimW(Raw(AIndex, AFrom, ATo));
end;

{ The code in column ACol: one of AAllowed or a space; another value is
  counted (GAEB-D90-MAP-004) and read as a space. }
function TMapper.Code(AIndex, ACol: Integer; const AName, AAllowed: string): Char;
var
  F: TLandrixGaebString;
begin
  Result := ' ';
  F := FDoc.Field(AIndex, ACol, ACol);
  if (Length(F) <> 1) or (F[1] = ' ') then
    Exit;
  if (Ord(F[1]) < 128) and (Pos(Char(Ord(F[1])), AAllowed) > 0) then
    Result := Char(Ord(F[1]))
  else
    FValues.Add(FDoc.Kind(AIndex) + '/' + AName);
end;

{ A number with an implied decimal point (AFraction digits) in columns
  AFrom to ATo, its sign in column ASign (0: none). Spaces instead of
  leading zeros are read (counted); anything else that is no digit is
  counted and the value left unset. False when unset. }
function TMapper.NumField(AIndex, AFrom, ATo, AFraction, ASign: Integer; const AName: string;
  var ADecimal: TLandrixGaebDecimal): Boolean;
var
  F, T: TLandrixGaebString;
  V: Int64;
  I: Integer;
  S: TLandrixGaebString;
begin
  Result := False;
  F := FDoc.Field(AIndex, AFrom, ATo);
  if TrimW(F) = '' then
    Exit;
  { spaces in front stand for zeros (right-aligned); spaces behind or
    inside are no number }
  I := 1;
  while (I <= Length(F)) and (F[I] = ' ') do
    Inc(I);
  T := Copy(F, I, MaxInt);
  if not IsDigits(T) then
  begin
    FBadNumbers.Add(FDoc.Kind(AIndex) + '/' + AName);
    Exit;
  end;
  if Length(T) <> Length(F) then
    Inc(FPadded);
  V := 0;
  for I := 1 to Length(T) do
    V := V * 10 + (Ord(T[I]) - Ord('0'));
  if ASign > 0 then
  begin
    S := FDoc.Field(AIndex, ASign, ASign);
    if S = '-' then
      V := -V
    else if S <> ' ' then
      FValues.Add(FDoc.Kind(AIndex) + '/sign of ' + AName);
  end;
  ADecimal.SetValue(V, AFraction);
  Result := True;
end;

{ A price of two decimals with a third one in column AThird (EPZPF,
  VEPZPF), which only counts when the price is set. }
procedure TMapper.Price(AIndex, AFrom, ATo, ASign, AThird: Integer; const AName: string;
  var ADecimal: TLandrixGaebDecimal);
var
  D: TLandrixGaebString;
  V: Int64;
begin
  D := FDoc.Field(AIndex, AThird, AThird);
  { the amount first, the sign once all three decimals are known }
  if not NumField(AIndex, AFrom, ATo, 2, 0, AName, ADecimal) then
  begin
    if D <> ' ' then
      FFields.Add(FDoc.Kind(AIndex) + '/third decimal without ' + AName);
    Exit;
  end;
  V := ADecimal.Coefficient;
  if D <> ' ' then
  begin
    if IsDigits(D) then
    begin
      V := V * 10 + (Ord(D[1]) - Ord('0'));
      ADecimal.SetValue(V, 3);
    end
    else
      FBadNumbers.Add(FDoc.Kind(AIndex) + '/third decimal of ' + AName);
  end;
  D := FDoc.Field(AIndex, ASign, ASign);
  if D = '-' then
    ADecimal.SetValue(-ADecimal.Coefficient, ADecimal.Scale)
  else if D <> ' ' then
    FValues.Add(FDoc.Kind(AIndex) + '/sign of ' + AName);
end;

{ Days of AMonth (1 to 12) in AYear. }
function DaysOf(AMonth, AYear: Integer): Integer;
begin
  case AMonth of
    2:
      if ((AYear mod 4 = 0) and (AYear mod 100 <> 0)) or (AYear mod 400 = 0) then
        Result := 29
      else
        Result := 28;
    4, 6, 9, 11:
      Result := 30;
  else
    Result := 31;
  end;
end;

function TMapper.DateField(AIndex, AFrom: Integer; const AName: string): TLandrixGaebString;
var
  F: TLandrixGaebString;
  Day, Month, Year: Integer;
  Century: string;
begin
  Result := '';
  F := FDoc.Field(AIndex, AFrom, AFrom + 7);
  if TrimW(F) = '' then
    Exit;
  if not (IsDigits(Copy(F, 1, 2)) and (F[3] = '.') and IsDigits(Copy(F, 4, 2)) and (F[6] = '.') and
    IsDigits(Copy(F, 7, 2))) then
  begin
    FDates.Add(FDoc.Kind(AIndex) + '/' + AName);
    Exit;
  end;
  Day := StrToInt(AsciiOf(Copy(F, 1, 2)));
  Month := StrToInt(AsciiOf(Copy(F, 4, 2)));
  { two-digit years: 00 to 69 are 20JJ, 70 to 99 19JJ (GAEB 90 dates from
    1985 on) }
  if F[7] < '7' then
    Century := '20'
  else
    Century := '19';
  Year := StrToInt(Century + AsciiOf(Copy(F, 7, 2)));
  if (Month < 1) or (Month > 12) or (Day < 1) or (Day > DaysOf(Month, Year)) then
  begin
    FDates.Add(FDoc.Kind(AIndex) + '/' + AName);
    Exit;
  end;
  Result := W(Century) + Copy(F, 7, 2) + '-' + Copy(F, 4, 2) + '-' + Copy(F, 1, 2);
end;

function TMapper.TimeField(AIndex, AFrom: Integer; const AName: string): TLandrixGaebString;
var
  F: TLandrixGaebString;
begin
  Result := '';
  F := FDoc.Field(AIndex, AFrom, AFrom + 4);
  if TrimW(F) = '' then
    Exit;
  if not (IsDigits(Copy(F, 1, 2)) and (F[3] = ':') and IsDigits(Copy(F, 4, 2))) or
    (StrToInt(AsciiOf(Copy(F, 1, 2))) > 23) or (StrToInt(AsciiOf(Copy(F, 4, 2))) > 59) then
  begin
    FDates.Add(FDoc.Kind(AIndex) + '/' + AName);
    Exit;
  end;
  Result := F + ':00';
end;

{ A field the mapping does not take: counted when it holds a value. }
procedure TMapper.Unmapped(AIndex, AFrom, ATo: Integer; const AName: string);
begin
  if TrimW(FDoc.Field(AIndex, AFrom, ATo)) <> '' then
    FFields.Add(FDoc.Kind(AIndex) + '/' + AName);
end;

{ ---- TMapper: mask and hierarchy ---- }

{ OZMASKE: runs of 1 to 4 (one level each, ascending from 1), a run of P
  (item), a run of I (index), then fill 0 (spaces are read as fill and
  reported). Without a readable mask the whole number is the item. }
procedure TMapper.ReadMask(AIndex: Integer);
var
  M: TLandrixGaebString;
  I, State, N: Integer;
  C, Last: Char;
  Ok: Boolean;

  procedure NewLevel(const AKind: string; AStart: Integer);
  begin
    SetLength(FLevels, N + 1);
    FLevels[N].Kind := AKind;
    FLevels[N].Start := AStart;
    FLevels[N].Length := 1;
    Inc(N);
  end;

begin
  FLevels := nil;
  N := 0;
  Ok := True;
  State := 0;
  Last := '0';
  M := FDoc.Field(AIndex, 63, 71);
  for I := 1 to 9 do
  begin
    if Ord(M[I]) < 128 then
      C := Char(Ord(M[I]))
    else
      C := '?';
    if C = ' ' then
    begin
      FMaskSpaces := True;
      C := '0';
    end;
    case State of
      0:
        if (C >= '1') and (C <= '4') then
        begin
          if C = Last then
            Inc(FLevels[N - 1].Length)
          else if Ord(C) = Ord(Last) + 1 then
            NewLevel('BoQLevel', I)
          else
            Ok := False;
          Last := C;
        end
        else if C = 'P' then
        begin
          NewLevel('Item', I);
          State := 1;
        end
        else
          Ok := False;
      1:
        if C = 'P' then
          Inc(FLevels[N - 1].Length)
        else if C = 'I' then
        begin
          NewLevel('Index', I);
          State := 2;
        end
        else if C = '0' then
          State := 3
        else
          Ok := False;
      2:
        if C = 'I' then
          Inc(FLevels[N - 1].Length)
        else if C = '0' then
          State := 3
        else
          Ok := False;
    else
      if C <> '0' then
        Ok := False;
    end;
    if not Ok then
      Break;
  end;
  if Ok and (State = 0) then
    Ok := False;
  if not Ok then
  begin
    Report(AIndex, RuleMask, gsError, 'OZMASKE missing or not readable: the ordinal numbers are read as item ' +
      'numbers without hierarchy');
    FLevels := nil;
    N := 0;
    NewLevel('Item', 1);
    FLevels[0].Length := 9;
    FMaskSpaces := False;
  end
  else if FMaskSpaces then
    Report(AIndex, RuleMaskSpaces, gsWarning, 'OZMASKE with spaces as fill; read as 0');
  { lots stand outside the ordinal number: a level of its own on top }
  if FHasLots then
  begin
    SetLength(FLevels, N + 1);
    for I := N downto 1 do
      FLevels[I] := FLevels[I - 1];
    FLevels[0].Kind := 'Lot';
    FLevels[0].Start := 0;
    FLevels[0].Length := 2;
    Inc(N);
  end;
  FCategoryLevels := 0;
  FItemLevel := -1;
  FIndexLevel := -1;
  for I := 0 to N - 1 do
    if (FLevels[I].Kind = 'BoQLevel') or (FLevels[I].Kind = 'Lot') then
      Inc(FCategoryLevels)
    else if FLevels[I].Kind = 'Item' then
      FItemLevel := I
    else
      FIndexLevel := I;
  SetLength(FLevelLabels, N);
  SetLength(FLevelSeen, N);
  SetLength(FLevelOther, N);
  for I := 0 to N - 1 do
  begin
    FLevelLabels[I] := '';
    FLevelSeen[I] := False;
    FLevelOther[I] := False;
  end;
  SetLength(FOpenPart, FCategoryLevels);
  SetLength(FOpenCtgy, FCategoryLevels);
  SetLength(FOpenImplicit, FCategoryLevels);
  SetLength(FOpenHasCtgy, FCategoryLevels);
  SetLength(FOpenHasItem, FCategoryLevels);
  FOpenDepth := 0;
end;

{ The category parts of AOZ (trimmed, without characters XML cannot
  carry), the number of leading filled levels, and the item and index
  parts. ABad is set for a filled level below an empty one (not taken);
  the caller counts it once per number (GAEB-D90-MAP-013). }
procedure TMapper.PartsOf(const AOZ: TLandrixGaebString; out AParts: TPartArray;
  out ADepth: Integer; out AItem, AIndex: TLandrixGaebString; out ABad: Boolean);
var
  I, Dummy: Integer;
  Raw: TLandrixGaebString;
  Gap: Boolean;

  function Clean(const S: TLandrixGaebString): TLandrixGaebString;
  begin
    if FQuiet then
      Result := TrimW(XmlSafe(S, Dummy))
    else
      Result := TrimW(XmlSafe(S, FControl));
  end;

  procedure Note(ALevel: Integer; const ARaw: TLandrixGaebString);
  begin
    if FQuiet or (TrimW(ARaw) = '') then
      Exit;
    FLevelSeen[ALevel] := True;
    { Num Yes only for digits written in full (zeros in front) }
    if not IsDigits(ARaw) then
      FLevelOther[ALevel] := True;
  end;

begin
  AParts := nil;
  SetLength(AParts, FCategoryLevels);
  ADepth := 0;
  AItem := '';
  AIndex := '';
  ABad := False;
  Gap := False;
  Dummy := 0;
  for I := 0 to Integer(Length(FLevels)) - 1 do
  begin
    if FLevels[I].Kind = 'Lot' then
      Raw := FCurLot
    else
      Raw := Copy(AOZ, FLevels[I].Start, FLevels[I].Length);
    Note(I, Raw);
    if (FLevels[I].Kind = 'BoQLevel') or (FLevels[I].Kind = 'Lot') then
    begin
      AParts[I] := Clean(Raw);
      if AParts[I] = '' then
        Gap := True
      else if Gap then
        ABad := True
      else
        Inc(ADepth);
    end
    else if FLevels[I].Kind = 'Item' then
      AItem := Clean(Raw)
    else
      AIndex := Clean(Raw);
  end;
end;

function TMapper.BodyAt(ADepth: Integer): TLandrixGaebXmlBoQBody;
begin
  if ADepth = 0 then
    Result := FRootBody
  else
    Result := FOpenCtgy[ADepth - 1].BoQBody;
end;

{ The parts of the first ADepth levels as one key. }
function TMapper.PathKey(const AParts: TPartArray; ADepth: Integer): TLandrixGaebString;
var
  L: Integer;
begin
  Result := '';
  for L := 0 to ADepth - 1 do
    Result := Result + AParts[L] + #10;
end;

{ Makes the open categories equal AParts[0 .. ADepth - 1]: the matching
  ones stay, the others are closed and new ones opened (derived from the
  numbers, except the one of level AExplicitLevel). }
procedure TMapper.OpenPath(const AParts: TPartArray; ADepth, AExplicitLevel: Integer);
var
  L, Keep: Integer;
  Ctgy: TLandrixGaebXmlBoQCtgy;
  Body: TLandrixGaebXmlBoQBody;
begin
  Keep := 0;
  while (Keep < ADepth) and (Keep < FOpenDepth) and (FOpenPart[Keep] = AParts[Keep]) do
    Inc(Keep);
  { a category kept as derived becomes the one of its record 11 }
  if (AExplicitLevel >= 0) and (AExplicitLevel < Keep) and FOpenImplicit[AExplicitLevel] then
  begin
    FOpenImplicit[AExplicitLevel] := False;
    Dec(FDerived);
  end;
  FOpenDepth := Keep;
  for L := Keep to ADepth - 1 do
  begin
    Body := BodyAt(L);
    if L = 0 then
    begin
      FRootHasCtgy := True;
      if FRootHasItem then
        Inc(FMixed);
    end
    else
    begin
      FOpenHasCtgy[L - 1] := True;
      if FOpenHasItem[L - 1] then
        Inc(FMixed);
    end;
    Ctgy := Body.AddBoQCtgy;
    Ctgy.Present := True;
    Ctgy.ID := NewId('LGC');
    Ctgy.RNoPart := AParts[L];
    Ctgy.BoQBody.Present := True;
    FOpenPart[L] := AParts[L];
    FOpenCtgy[L] := Ctgy;
    FOpenImplicit[L] := L <> AExplicitLevel;
    if FOpenImplicit[L] then
      Inc(FDerived);
    FOpenHasCtgy[L] := False;
    FOpenHasItem[L] := False;
    FOpenDepth := L + 1;
    { every category (FillRequired visits all), the table names the first
      one of a path }
    if FCtgyCount >= Length(FCtgys) then
      SetLength(FCtgys, 2 * FCtgyCount + 16);
    FCtgys[FCtgyCount] := Ctgy;
    FCtgyTable.Add(PathKey(AParts, L + 1), FCtgyCount);
    Inc(FCtgyCount);
  end;
end;

procedure TMapper.NoteItem(ADepth: Integer);
begin
  if ADepth = 0 then
  begin
    FRootHasItem := True;
    if FRootHasCtgy then
      Inc(FMixed);
  end
  else
  begin
    FOpenHasItem[ADepth - 1] := True;
    if FOpenHasCtgy[ADepth - 1] then
      Inc(FMixed);
  end;
end;

{ The item list a record without ordinal number (20) belongs to: that of
  the next item; before a record 11, the body of its parent (as remarks of
  the body, see MapRemark). }
function TMapper.ItemlistFor(AIndex: Integer): TLandrixGaebXmlItemlist;
var
  J, Depth: Integer;
  K: string;
  Parts: TPartArray;
  ItemPart, IndexPart: TLandrixGaebString;
  Bad: Boolean;
begin
  Result := nil;
  Parts := nil;
  { remarks in a row share one look-ahead (linear time) }
  if not ((FLookFrom <= AIndex) and (AIndex < FLookAt)) then
  begin
    FLookFrom := AIndex;
    FLookAt := FDoc.Count;
    for J := AIndex + 1 to FDoc.Count - 1 do
    begin
      K := FDoc.Kind(J);
      if (K = '21') or (K = '23') or (K = '11') or (K = '10') or (K = '33') or (K = '00') or
        (K = '99') then
      begin
        FLookAt := J;
        Break;
      end;
    end;
  end;
  for J := FLookAt to FLookAt do
  begin
    if J >= FDoc.Count then
      Break;
    K := FDoc.Kind(J);
    if (K = '21') or (K = '23') or (K = '11') then
    begin
      FQuiet := True;
      try
        PartsOf(FDoc.Field(J, 3, 11), Parts, Depth, ItemPart, IndexPart, Bad);
      finally
        FQuiet := False;
      end;
      if K = '11' then
      begin
        { an 11 in a lot without a group number (MapGroup leaves it out):
          the open path stays }
        if FHasLots and (Depth = 1) then
          Break;
        if Depth > 0 then
          Dec(Depth);
        OpenPath(Parts, Depth, -1);
        Exit;
      end;
      OpenPath(Parts, Depth, -1);
      NoteItem(Depth);
      Result := BodyAt(Depth).Itemlist;
      Exit;
    end;
    if K = '10' then
    begin
      { before a lot: on top, beside the lots }
      FOpenDepth := 0;
      Exit;
    end;
    if (K = '00') or (K = '99') then
      Break;
  end;
  if FOpenDepth = 0 then
  begin
    if not FRootHasCtgy then
    begin
      NoteItem(0);
      Result := FRootBody.Itemlist;
    end;
  end
  else if not FOpenHasCtgy[FOpenDepth - 1] then
  begin
    NoteItem(FOpenDepth);
    Result := BodyAt(FOpenDepth).Itemlist;
  end;
end;

{ ---- TMapper: texts ---- }

{ The lines of 25 or 26 records from AIndex on (AKind), AIndex ends after
  the last one. }
procedure TMapper.CollectText(var AIndex: Integer; ALines: TLines; const AKind: string);
var
  T: TLandrixGaebString;
  Knr: string;
  Tekz: Char;
  F: TLandrixGaebString;
begin
  while (AIndex < FDoc.Count) and (FDoc.Kind(AIndex) = AKind) do
  begin
    FUsed[AIndex] := True;
    if AKind = '25' then
    begin
      T := TrimRightW(Raw(AIndex, 3, 72));
      Knr := AsciiOf(Str(AIndex, 73, 74));
      Tekz := ' ';
      if (Knr <> '') and not IsDigits(W(Knr)) then
        Inc(FTekz);
    end
    else
    begin
      T := TrimRightW(Raw(AIndex, 6, 60));
      Knr := AsciiOf(Str(AIndex, 3, 4));
      F := FDoc.Field(AIndex, 5, 5);
      if Ord(F[1]) < 128 then
        Tekz := Char(Ord(F[1]))
      else
        Tekz := '?';
      { KNR and TEKZ A/B belong together, KNR of two digits }
      if (Tekz = ' ') <> (Knr = '') then
        Inc(FTekz)
      else if (Tekz <> ' ') and not (((Tekz = 'A') or (Tekz = 'B')) and IsDigits(W(Knr))) then
        Inc(FTekz);
      Unmapped(AIndex, 61, 74, 'FILLER');
    end;
    ALines.Add(T, Knr, Tekz);
    Inc(AIndex);
  end;
end;

procedure TMapper.AddLinesTo(const AText: TLandrixGaebString; P: TLandrixGaebXmlPMLText);
var
  I, Start: Integer;
begin
  P.Present := True;
  Start := 1;
  for I := 1 to Length(AText) + 1 do
    if (I > Length(AText)) or (AText[I] = #10) then
    begin
      if I > Start then
        P.AddSpan.Value := Copy(AText, Start, I - Start);
      if I <= Length(AText) then
        P.AddBr('');
      Start := I + 1;
    end;
end;

{ Dots, underscores, ellipses, spaces and line breaks only: a placeholder
  for a complement still to be filled in. }
function TMapper.IsPlaceholder(const S: TLandrixGaebString): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 1 to Length(S) do
    if not ((S[I] = '.') or (S[I] = '_') or (S[I] = ' ') or (S[I] = #10) or (S[I] = TLandrixGaebChar($2026))) then
    begin
      Result := False;
      Exit;
    end;
end;

{ The lines AFirst to ALast as caption, body and tail: False unless they
  hold exactly two apostrophes. }
function TMapper.SplitComplement(ALines: TLines; AFirst, ALast: Integer;
  out ACaption, ABody, ATail: TLandrixGaebString): Boolean;
var
  S: TLandrixGaebString;
  I, Q1, Q2, N: Integer;
begin
  ACaption := '';
  ABody := '';
  ATail := '';
  { the lines joined by line feeds, sized once (linear time) }
  N := 0;
  for I := AFirst to ALast do
    Inc(N, Length(ALines.Text[I]) + 1);
  S := '';
  SetLength(S, N - 1);
  N := 0;
  for I := AFirst to ALast do
  begin
    if I > AFirst then
    begin
      Inc(N);
      S[N] := #10;
    end;
    for Q1 := 1 to Length(ALines.Text[I]) do
    begin
      Inc(N);
      S[N] := ALines.Text[I][Q1];
    end;
  end;
  N := 0;
  Q1 := 0;
  Q2 := 0;
  for I := 1 to Length(S) do
    if S[I] = '''' then
    begin
      Inc(N);
      if N = 1 then
        Q1 := I
      else
        Q2 := I;
    end;
  Result := N = 2;
  if not Result then
    Exit;
  ACaption := TrimRightW(Copy(S, 1, Q1 - 1));
  ABody := Copy(S, Q1 + 1, Q2 - Q1 - 1);
  ATail := TrimRightW(Copy(S, Q2 + 1, MaxInt));
  if TrimW(ATail) = '' then
    ATail := '';
end;

procedure TMapper.FillComplement(AComplement: TLandrixGaebXmlTextComplement; ABidder: Boolean;
  const AKnr, ACaption, ABody, ATail: TLandrixGaebString);
begin
  AComplement.Present := True;
  if ABidder then
    AComplement.Kind := 'Bidder'
  else
    AComplement.Kind := 'Owner';
  AComplement.MarkLbl := AKnr;
  if ACaption <> '' then
    AddLinesTo(ACaption, AComplement.ComplCaption.AddP);
  if IsPlaceholder(ABody) then
  begin
    AComplement.Empty := 'Yes';
    AComplement.ComplBody.Present := True;
  end
  else
    AddLinesTo(ABody, AComplement.ComplBody.AddP);
  if ATail <> '' then
    AddLinesTo(ATail, AComplement.ComplTail.AddP);
end;

{ Long text: a paragraph per line, a complement (lines with the same KNR
  and TEKZ A/B and two apostrophes) as a paragraph of its own. }
procedure TMapper.MapLong(ALines: TLines; ADetail: TLandrixGaebXmlBoQText);
var
  F: TLandrixGaebXmlFTextTC;
  P: TLandrixGaebXmlPTC;
  I, J, K: Integer;
  Caption, Body, Tail: TLandrixGaebString;
  Knr: string;

  procedure Plain(ALine: Integer);
  begin
    P := F.AddP;
    P.Present := True;
    if ALines.Text[ALine] <> '' then
      P.AddSpan.Value := ALines.Text[ALine];
  end;

begin
  F := ADetail.AddText;
  F.Present := True;
  I := 0;
  while I < ALines.Count do
  begin
    Knr := ALines.Knr[I];
    if (ALines.Tekz[I] = 'A') or (ALines.Tekz[I] = 'B') then
    begin
      J := I;
      while (J + 1 < ALines.Count) and (ALines.Knr[J + 1] = Knr) and (ALines.Tekz[J + 1] = ALines.Tekz[I]) do
        Inc(J);
      if IsDigits(W(Knr)) and SplitComplement(ALines, I, J, Caption, Body, Tail) then
      begin
        P := F.AddP;
        P.Present := True;
        FillComplement(P.AddTextComplement, ALines.Tekz[I] = 'B', W(Knr), Caption, Body, Tail);
      end
      else
      begin
        { a wrong KNR is counted per line when collected }
        if IsDigits(W(Knr)) then
          Inc(FMarkProblems);
        for K := I to J do
          Plain(K);
      end;
      I := J + 1;
      Continue;
    end;
    Plain(I);
    Inc(I);
  end;
end;

{ Short text: plain lines as paragraphs of TextOutlTxt, lines with a KNR
  (owner complements) as TextComplement between them. }
procedure TMapper.MapShort(ALines: TLines; AOutline: TLandrixGaebXmlOutlTxt);
var
  M: TLandrixGaebXmlMLText;
  I, J, K: Integer;
  Caption, Body, Tail: TLandrixGaebString;
  Knr: string;
  P: TLandrixGaebXmlPMLText;

  procedure Plain(ALine: Integer);
  begin
    if M = nil then
    begin
      M := AOutline.AddTextOutlTxt;
      M.Present := True;
    end;
    P := M.AddP;
    P.Present := True;
    if ALines.Text[ALine] <> '' then
      P.AddSpan.Value := ALines.Text[ALine];
  end;

begin
  AOutline.Present := True;
  M := nil;
  I := 0;
  while I < ALines.Count do
  begin
    Knr := ALines.Knr[I];
    if Knr <> '' then
    begin
      J := I;
      while (J + 1 < ALines.Count) and (ALines.Knr[J + 1] = Knr) do
        Inc(J);
      if IsDigits(W(Knr)) and SplitComplement(ALines, I, J, Caption, Body, Tail) then
      begin
        FillComplement(AOutline.AddTextComplement, False, W(Knr), Caption, Body, Tail);
        M := nil;
      end
      else
      begin
        if IsDigits(W(Knr)) then
          Inc(FMarkProblems);
        for K := I to J do
          Plain(K);
      end;
      I := J + 1;
      Continue;
    end;
    Plain(I);
    Inc(I);
  end;
end;

{ True if the lines hold any text or a complement mark. }
function HasContent(ALines: TLines): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if (ALines.Text[I] <> '') or (ALines.Knr[I] <> '') then
      Exit;
  Result := False;
end;

{ The texts into AComplete (with a long text) or AOutline (short text
  only) of a description; False when there is no text. }
function TMapper.MapTextParts(AShort, ALong: TLines; ATA, ATB: Boolean; AComplete: TLandrixGaebXmlCompleteText;
  AOutline: TLandrixGaebXmlOutlineText): Boolean;
var
  HasShort, HasLong: Boolean;
begin
  HasShort := HasContent(AShort);
  HasLong := HasContent(ALong);
  if AShort.Count > 9 then
    FLimits.Add('25');
  if ALong.Count > 999 then
    FLimits.Add('26');
  Result := HasShort or HasLong;
  if HasLong then
  begin
    MapLong(ALong, AComplete.DetailTxt);
    if ATA then
      AComplete.ComplTSA := 'Yes';
    if ATB then
      AComplete.ComplTSB := 'Yes';
    if HasShort then
    begin
      MapShort(AShort, AComplete.OutlineText.OutlTxt);
      if ATA then
        AComplete.OutlineText.OutlTSA := 'Yes';
    end;
  end
  else if HasShort then
  begin
    MapShort(AShort, AOutline.OutlTxt);
    if ATA then
      AOutline.OutlTSA := 'Yes';
  end;
end;

procedure TMapper.MapTexts(AShort, ALong: TLines; ATA, ATB: Boolean; ADescription: TLandrixGaebXmlDescription);
begin
  if MapTextParts(AShort, ALong, ATA, ATB, ADescription.CompleteText, ADescription.OutlineText) then
    ADescription.Present := True;
end;

{ STLNR (columns AFrom to ATo, 17 digits, spaces around tolerated) with
  TEXTSYST in column ASystem -> StLNo (1 StLB, 2 StLK); False when unset. }
function TMapper.MapStLNo(AIndex, ASystem, AFrom, ATo: Integer; AStLNo: TLandrixGaebXmlStLNo): Boolean;
var
  S: TLandrixGaebString;
  Sys: Char;
begin
  Result := False;
  Sys := Code(AIndex, ASystem, 'TEXTSYST', '12');
  S := Str(AIndex, AFrom, ATo);
  if S = '' then
    Exit;
  if not IsDigits(S) then
  begin
    FValues.Add(FDoc.Kind(AIndex) + '/STLNR');
    Exit;
  end;
  AStLNo.Present := True;
  AStLNo.Value := S;
  if Sys = '1' then
    AStLNo.TypeAttr := 'StLB'
  else if Sys = '2' then
    AStLNo.TypeAttr := 'StLK';
  Result := True;
end;

{ 79: ACatalog (STLPAR) and the tokens of AText (STLWERT of all 79 of the
  description): VJ year, VM month, LB, TLG, then any number of BM, BMI,
  AP. False (and AStlb cleared) without catalogue name or group. }
function TMapper.MapStlbBau(const ACatalog, AText: TLandrixGaebString; AStlb: TLandrixGaebXmlSTLBBau): Boolean;
var
  Tokens: array of TLandrixGaebString;
  N, I, Start, M: Integer;
  Key: string;
  Year, Month: TLandrixGaebString;
  Ctlg: TLandrixGaebXmlSTLBBauCtlg;
  Id: TLandrixGaebXmlSTLBBauID;
  Bad: Boolean;
begin
  Tokens := nil;
  N := 0;
  I := 1;
  while I <= Length(AText) do
  begin
    while (I <= Length(AText)) and (AText[I] = ' ') do
      Inc(I);
    Start := I;
    while (I <= Length(AText)) and (AText[I] <> ' ') do
      Inc(I);
    if I > Start then
    begin
      if N >= Length(Tokens) then
        SetLength(Tokens, 2 * N + 16);
      Tokens[N] := Copy(AText, Start, I - Start);
      Inc(N);
    end;
  end;
  Ctlg := AStlb.STLBBauCtlg;
  Ctlg.CtlgName := ACatalog;
  Year := '';
  Month := '';
  Id := nil;
  Bad := False;
  I := 0;
  while I < N do
  begin
    Key := UpperCase(AsciiOf(Tokens[I]));
    if I + 1 >= N then
    begin
      Bad := True;
      Break;
    end;
    if Key = 'VJ' then
      Year := Tokens[I + 1]
    else if Key = 'VM' then
      Month := Tokens[I + 1]
    else if Key = 'LB' then
      Ctlg.WCtg := Tokens[I + 1]
    else if Key = 'TLG' then
    begin
      if IsDigits(Tokens[I + 1]) then
        Ctlg.Group := Tokens[I + 1]
      else
        Bad := True;
    end
    else if Key = 'BM' then
    begin
      if IsDigits(Tokens[I + 1]) then
      begin
        Id := AStlb.STLBBauID.Add;
        Id.Present := True;
        Id.ArtChrIdent := Tokens[I + 1];
      end
      else
      begin
        Id := nil;
        Bad := True;
      end;
    end
    else if (Key = 'BMI') and (Id <> nil) and IsDigits(Tokens[I + 1]) then
      Id.ArtChIdx := Tokens[I + 1]
    else if (Key = 'AP') and (Id <> nil) and IsDigits(Tokens[I + 1]) then
      Id.ChVIdent := Tokens[I + 1]
    else
      Bad := True;
    Inc(I, 2);
  end;
  if (Year <> '') or (Month <> '') then
  begin
    M := StrToIntDef(AsciiOf(Month), 0);
    if (Length(Year) = 4) and IsDigits(Year) and (M >= 1) and (M <= 12) then
      Ctlg.VersDate := Year + W('-' + Copy(IntToStr(100 + M), 2, 2))
    else
      Bad := True;
  end;
  if Bad then
    FValues.Add('79/STLWERT');
  Result := (Ctlg.CtlgName <> '') and (Ctlg.Group <> '');
  if Result then
  begin
    AStlb.Present := True;
    Ctlg.Present := True;
  end
  else
  begin
    Inc(FIncompleteStlb);
    AStlb.Clear;
  end;
end;

{ The key of an ordinal number: its cleaned parts, as items are kept. }
function TMapper.NumberKey(const AOZ: TLandrixGaebString): TLandrixGaebString;
var
  Parts: TPartArray;
  Depth: Integer;
  ItemPart, IndexPart: TLandrixGaebString;
  Bad: Boolean;
begin
  Parts := nil;
  FQuiet := True;
  try
    PartsOf(AOZ, Parts, Depth, ItemPart, IndexPart, Bad);
  finally
    FQuiet := False;
  end;
  Result := PathKey(Parts, Depth) + #10 + ItemPart + #10 + IndexPart;
end;

{ A key of NumberKey without its lot part (the first one). }
function WithoutLot(const AKey: TLandrixGaebString): TLandrixGaebString;
var
  I: Integer;
begin
  I := 1;
  while (I <= Length(AKey)) and (AKey[I] <> #10) do
    Inc(I);
  Result := Copy(AKey, I + 1, MaxInt);
end;

procedure TMapper.AddOz(const AKey, AId: TLandrixGaebString);
var
  K: Integer;
begin
  if FOzTable.Add(AKey, FOzCount) then
  begin
    if FOzCount >= Length(FOzIds) then
      SetLength(FOzIds, 2 * FOzCount + 16);
    FOzIds[FOzCount] := AId;
    Inc(FOzCount);
  end
  else
  begin
    { the number again: ambiguous across lots }
    K := FOzTable.Find(AKey);
    if K >= 0 then
      FOzIds[K] := '';
  end;
end;

{ The key of AUSNR: digits without leading zeros, else as written. }
function TMapper.PerfKey(const ANo: TLandrixGaebString): TLandrixGaebString;
var
  I: Integer;
begin
  Result := TrimW(ANo);
  if not IsDigits(Result) then
    Exit;
  I := 1;
  while (I < Length(Result)) and (Result[I] = '0') do
    Inc(I);
  Result := Copy(Result, I, MaxInt);
end;

procedure TMapper.AddRef(ARef: TLandrixGaebXmlRefItem; const AKey: TLandrixGaebString; AIsPerf: Boolean);
begin
  if FRefCount >= Length(FRefs) then
  begin
    SetLength(FRefs, 2 * FRefCount + 16);
    SetLength(FRefKeys, 2 * FRefCount + 16);
    SetLength(FRefIsPerf, 2 * FRefCount + 16);
  end;
  FRefs[FRefCount] := ARef;
  FRefKeys[FRefCount] := AKey;
  FRefIsPerf[FRefCount] := AIsPerf;
  Inc(FRefCount);
end;

{ References of 28 to the IDs of items and execution descriptions, which
  may come later in the file; one to a number not in the file is left
  out and counted (GAEB-D90-MAP-016). }
function GroupHasLot(AGroup: TLandrixGaebXmlLotGrp): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Integer(AGroup.RefLotNo.Count) - 1 do
    if AGroup.RefLotNo[I].IsPresent then
    begin
      Result := True;
      Exit;
    end;
end;

procedure TMapper.ResolveRefs;
var
  I, K: Integer;
  Parts: TPartArray;
  Groups: TLandrixGaebXmlLotGrpList;
  Group: TLandrixGaebXmlLotGrp;
begin
  Parts := nil;
  SetLength(Parts, FCategoryLevels);
  for I := 0 to FLotRefCount - 1 do
  begin
    K := -1;
    if FHasLots and (FCategoryLevels > 0) then
    begin
      Parts[0] := FLotRefKeys[I];
      K := FCtgyTable.Find(PathKey(Parts, 1));
    end;
    if K >= 0 then
    begin
      FLotRefs[I].IDRef := FCtgys[K].ID;
      FLotRefs[I].Present := True;
    end
    else
      Inc(FUnresolved);
  end;
  { phase 83 needs a lot in each lot group: one without (no 35, or none of
    its lots in the file) is left out (84 takes groups without lots)
    DE: Phase 83 verlangt in jeder Losgruppe ein Los: eine ohne (kein 35
    oder keines ihrer Lose in der Datei) entfaellt (84 nimmt Gruppen ohne
    Lose) }
  if FPhase = '83' then
  begin
    for I := 0 to FLotGrpCount - 1 do
      if not GroupHasLot(FLotGrps[I]) then
        FLotGrps[I] := nil;
    { freed and packed in linear time }
    Groups := FG.Award.BoQ.LotGrp;
    Groups.OwnsObjects := False;
    try
      for I := 0 to Integer(Groups.Count) - 1 do
        if not GroupHasLot(Groups[I]) then
        begin
          FOrphans.Add('34 without a lot (35)');
          Group := Groups[I];
          TObjectList(Groups)[I] := nil;
          Group.Free;
        end;
      Groups.Pack;
    finally
      Groups.OwnsObjects := True;
    end;
  end;
  for I := 0 to FGrpRefCount - 1 do
  begin
    K := FLotGrpTable.Find(FGrpRefKeys[I]);
    if (K >= 0) and (FLotGrps[K] <> nil) then
    begin
      FGrpRefs[I].IDRef := FLotGrps[K].ID;
      FGrpRefs[I].Present := True;
    end
    else
      Inc(FUnresolved);
  end;
  for I := 0 to FRefCount - 1 do
  begin
    if FRefIsPerf[I] then
    begin
      K := FPerfTable.Find(FRefKeys[I]);
      if K >= 0 then
        FRefs[I].IDRef := FPerfIds[K];
    end
    else
    begin
      K := FItemTable.Find(FRefKeys[I]);
      if K >= 0 then
        FRefs[I].IDRef := FItemIds[K]
      else if FHasLots then
      begin
        { the number in another lot: GAEB 90 numbers are unique in the
          bill, the lot lies outside them (a number in more lots stays
          unresolved) }
        K := FOzTable.Find(WithoutLot(FRefKeys[I]));
        if (K >= 0) and (FOzIds[K] <> '') then
          FRefs[I].IDRef := FOzIds[K]
        else
          K := -1;
      end;
    end;
    if K >= 0 then
      FRefs[I].Present := True
    else
      Inc(FUnresolved);
  end;
end;

{ ---- TMapper: records ---- }

procedure TMapper.MapHeader00(AIndex: Integer);
var
  S: TLandrixGaebString;
  K: Char;
begin
  K := Code(AIndex, 13, 'KURZLANG', 'KL');
  if K = 'L' then
    FG.Award.BoQ.BoQInfo.OutlCompl := 'AllTxt'
  else if K = 'K' then
    FG.Award.BoQ.BoQInfo.OutlCompl := 'OutTxt';
  S := Str(AIndex, 14, 28);
  FVergag := S;
  if S <> '' then
  begin
    FG.Award.OWN.Present := True;
    FG.Award.OWN.AwardNo := S;
  end;
  S := Str(AIndex, 29, 36);
  if S <> '' then
  begin
    FG.Award.OWN.Present := True;
    FG.Award.OWN.DPNo := S;
  end;
  S := Str(AIndex, 37, 39);
  if S <> '' then
  begin
    FG.Award.CTR.Present := True;
    FG.Award.CTR.BidderNo := S;
  end;
  S := Str(AIndex, 40, 54);
  if S <> '' then
  begin
    FG.Award.CTR.Present := True;
    FG.Award.CTR.AwardNo := S;
  end;
  S := Str(AIndex, 55, 62);
  if S <> '' then
  begin
    FG.Award.CTR.Present := True;
    FG.Award.CTR.DPNo := S;
  end;
  ReadMask(AIndex);
  { the edition of GAEB 90 has no counterpart }
  S := FDoc.Field(AIndex, 72, 73);
  if (S <> '90') and (S <> '  ') then
    FValues.Add('00/VERSDTA');
  { LOSKZ is checked against the records 10 }
  Code(AIndex, 74, 'LOSKZ', 'X');
  Unmapped(AIndex, 3, 10, 'FILLER');
end;

procedure TMapper.MapHeader01(AIndex: Integer);
var
  Info: TLandrixGaebXmlAwardInfo;
  S: TLandrixGaebString;
begin
  FG.Award.BoQ.BoQInfo.LblBoQ := Str(AIndex, 3, 42);
  FG.Award.BoQ.BoQInfo.Date := DateField(AIndex, 43, 'LVDATUM');
  Info := FG.Award.AwardInfo;
  S := DateField(AIndex, 51, 'DATANG');
  if S <> '' then
  begin
    Info.Present := True;
    Info.OpenDate := S;
  end;
  S := TimeField(AIndex, 59, 'DATUHR');
  if (S <> '') and (Info.OpenDate <> '') then
  begin
    Info.Present := True;
    Info.OpenTime := S;
  end
  else if S <> '' then
    FFields.Add('01/DATUHR without DATANG');
  S := DateField(AIndex, 64, 'DATZUS');
  if S <> '' then
  begin
    Info.Present := True;
    Info.EvalEnd := S;
  end;
  { KZPREIS describes the file (prices or not) and has no counterpart }
  Code(AIndex, 72, 'KZPREIS', 'X');
  Unmapped(AIndex, 73, 73, 'KZLOHN');
  Unmapped(AIndex, 74, 74, 'FILLER');
end;

procedure TMapper.MapProject(var AIndex: Integer);
var
  N: Integer;
  S: TLandrixGaebString;
  P: TLandrixGaebXmlP;
begin
  N := 0;
  while (AIndex < FDoc.Count) and (FDoc.Kind(AIndex) = '02') do
  begin
    FUsed[AIndex] := True;
    S := Str(AIndex, 3, 62);
    if N = 0 then
      FG.PrjInfo.LblPrj := S;
    P := FG.PrjInfo.Descrip.AddP;
    P.Present := True;
    if S <> '' then
      P.AddSpan.Value := S;
    Unmapped(AIndex, 63, 74, 'FILLER');
    Inc(N);
    Inc(AIndex);
  end;
  if N > 9 then
    FLimits.Add('02');
end;

{ 03/04: the name, up to 40 characters to Name1, the rest (cut at the
  last space before) to Name2. }
{ 03 and 04: the name of the party, a free line of 60 characters. GAEB DA
  XML requires Street, PCode and City in the address of OWN (X83) and CTR
  (X84); GAEB 90 has none, and the line is not split by guessing (owner
  decision 16.11.2026): the caller completes them, which is reported.
  DE: 03 und 04: der Name der Partei, eine freie Zeile mit 60 Zeichen.
  GAEB DA XML verlangt Street, PCode und City in der Adresse von OWN (X83)
  und CTR (X84); GAEB 90 hat sie nicht, und die Zeile wird nicht durch
  Raten zerlegt (Entscheidung Nutzer 16.11.2026): der Aufrufer ergaenzt
  sie, das wird gemeldet. }
procedure TMapper.MapParty(AIndex: Integer; AAddress: TLandrixGaebXmlAddress; const AWhat: string);
var
  S: TLandrixGaebString;
  Cut: Integer;
begin
  S := Str(AIndex, 3, 62);
  Unmapped(AIndex, 63, 74, 'FILLER');
  if S = '' then
    Exit;
  if not AAddress.Present then
    Report(AIndex, RuleFilled, gsInformation, AWhat + '/Address: Street, PCode and City (required) ' +
      'stay missing, GAEB 90 has only the name; the caller completes them');
  AAddress.Present := True;
  if Length(S) <= 40 then
  begin
    AAddress.Name1 := S;
    Exit;
  end;
  Cut := 41;
  while (Cut > 1) and (S[Cut] <> ' ') do
    Dec(Cut);
  if Cut <= 1 then
    Cut := 41;
  AAddress.Name1 := TrimW(Copy(S, 1, Cut - 1));
  AAddress.Name2 := TrimW(Copy(S, Cut, MaxInt));
end;

procedure TMapper.MapComponents(AIndex: Integer);
var
  Info: TLandrixGaebXmlBoQInfo;
  S: TLandrixGaebString;

  procedure Lbl(AFrom: Integer; ALabel: TLandrixGaebXmlLblUpComp);
  var
    L: TLandrixGaebString;
  begin
    L := Str(AIndex, AFrom, AFrom + 13);
    if L = '' then
      Exit;
    ALabel.Value := L;
    ALabel.TypeAttr := 'Unknown';
  end;

begin
  Info := FG.Award.BoQ.BoQInfo;
  S := Str(AIndex, 3, 3);
  if IsDigits(S) and (S <> '0') then
    Info.NoUPComps := S
  else if S <> '' then
    FValues.Add('06/ANZEP');
  Info.LblTime := Str(AIndex, 4, 17);
  Lbl(18, Info.LblUPComp1);
  Lbl(32, Info.LblUPComp2);
  Lbl(46, Info.LblUPComp3);
  Lbl(60, Info.LblUPComp4);
end;

procedure TMapper.MapCurrency(AIndex: Integer);
var
  Cur, Lbl: TLandrixGaebString;
begin
  Cur := Str(AIndex, 3, 8);
  Lbl := Str(AIndex, 9, 58);
  FG.PrjInfo.Cur := Cur;
  FG.PrjInfo.CurLbl := Lbl;
  if (Cur <> '') or (Lbl <> '') then
  begin
    FG.Award.AwardInfo.Present := True;
    FG.Award.AwardInfo.Cur := Cur;
    FG.Award.AwardInfo.CurLbl := Lbl;
  end;
  Unmapped(AIndex, 59, 74, 'FILLER');
end;

{ 11 and its 12: the category of the deepest level the number fills. }
procedure TMapper.MapGroup(var AIndex: Integer);
var
  Parts: TPartArray;
  Depth, Level, N: Integer;
  ItemPart, IndexPart, S, Zzv: TLandrixGaebString;
  Ctgy: TLandrixGaebXmlBoQCtgy;
  Art: Char;
  P: TLandrixGaebXmlPMLText;
  First: Integer;
  Bad: Boolean;
begin
  First := AIndex;
  FUsed[AIndex] := True;
  Parts := nil;
  PartsOf(FDoc.Field(AIndex, 3, 11), Parts, Depth, ItemPart, IndexPart, Bad);
  if Bad then
    Inc(FNumberProblems);
  Inc(AIndex);
  { the level Lot comes from the 10, not from the number }
  if (Depth = 0) or (FHasLots and (Depth = 1)) then
  begin
    FOrphans.Add('11 without a group number');
    while (AIndex < FDoc.Count) and (FDoc.Kind(AIndex) = '12') do
    begin
      FUsed[AIndex] := True;
      FOrphans.Add('12');
      Inc(AIndex);
    end;
    Exit;
  end;
  Level := Depth - 1;
  OpenPath(Parts, Depth, Level);
  Ctgy := FOpenCtgy[Level];
  Art := Code(First, 12, 'LVGRART', 'NGA');
  Zzv := FDoc.Field(First, 13, 16);
  if (Art = 'G') or (Art = 'A') then
  begin
    if IsDigits(Copy(Zzv, 1, 3)) then
    begin
      { the group number only with a serial number (both or none) }
      if Art = 'G' then
        Ctgy.ALNBSerNo := '0'
      else if IsDigits(Copy(Zzv, 4, 1)) and (Zzv[4] <> '0') then
        { an alternative is numbered 1 to 9 (0 is the basic one) }
        Ctgy.ALNBSerNo := Copy(Zzv, 4, 1)
      else
        FValues.Add('11/ZZV');
      if Ctgy.ALNBSerNo <> '' then
        Ctgy.ALNBGroupNo := Copy(Zzv, 1, 3);
    end
    else
      FValues.Add('11/ZZV');
  end
  else if TrimW(Zzv) <> '' then
    FFields.Add('11/ZZV');
  S := Str(First, 17, 30);
  if (S <> '') and (FLevelLabels[Level] = '') then
    FLevelLabels[Level] := S;
  N := 0;
  while (AIndex < FDoc.Count) and (FDoc.Kind(AIndex) = '12') do
  begin
    FUsed[AIndex] := True;
    S := TrimRightW(Raw(AIndex, 3, 42));
    P := Ctgy.LblTx.AddP;
    P.Present := True;
    Ctgy.LblTx.Present := True;
    if S <> '' then
      P.AddSpan.Value := S;
    Unmapped(AIndex, 43, 74, 'FILLER');
    Inc(N);
    Inc(AIndex);
  end;
  if N > 9 then
    FLimits.Add('12');
end;

procedure TMapper.MapGroupTotals(AIndex: Integer);
var
  Parts: TPartArray;
  Depth, K, L: Integer;
  ItemPart, IndexPart: TLandrixGaebString;
  T: TLandrixGaebXmlTotals;
  Ctgy: TLandrixGaebXmlBoQCtgy;
  Bad, Open: Boolean;
begin
  FUsed[AIndex] := True;
  Parts := nil;
  PartsOf(FDoc.Field(AIndex, 3, 11), Parts, Depth, ItemPart, IndexPart, Bad);
  Ctgy := nil;
  { a number with a gap names no group: counted, the totals left out }
  if Bad then
    Inc(FNumberProblems)
  else if (Depth > 1) or ((Depth = 1) and not FHasLots) then
  begin
    { the open group, else the first one of the number (the level Lot
      comes from the 10, not from the number) }
    Open := Depth <= FOpenDepth;
    for L := 0 to Depth - 1 do
      if Open and (FOpenPart[L] <> Parts[L]) then
        Open := False;
    if Open then
      Ctgy := FOpenCtgy[Depth - 1]
    else
    begin
      K := FCtgyTable.Find(PathKey(Parts, Depth));
      if K >= 0 then
        Ctgy := FCtgys[K];
    end;
  end;
  if Ctgy = nil then
  begin
    FOrphans.Add('32 without its group');
    Exit;
  end;
  T := Ctgy.Totals;
  if T.IsPresent then
  begin
    { the first totals count (a second set could mix exclusive parts) }
    FFields.Add('32 a second time for its group');
    Exit;
  end;
  if not NumField(AIndex, 13, 24, 2, 12, 'SUMME', T.Total) then
    if (TrimW(FDoc.Field(AIndex, 13, 24)) <> '') and (FInvalidTotals <> nil) then
      FInvalidTotals.Add(T);
  NumField(AIndex, 46, 57, 2, 45, 'PAUSCH', T.TotalLSUM);
  MapDiscount(AIndex, 25, 32, 33, T);
  if T.Total.HasValue or T.TotalLSUM.HasValue then
    T.Present := True;
end;

{ 20 and its 26: a remark in the item list of the next item, or before a
  group in the body of its parent. }
procedure TMapper.MapRemark(var AIndex: Integer);
var
  First: Integer;
  List: TLandrixGaebXmlItemlist;
  R: TLandrixGaebXmlRemark;
  Body: TLandrixGaebXmlBoQBody;
begin
  First := AIndex;
  FUsed[AIndex] := True;
  Inc(AIndex);
  FDescrShort.Clear;
  FDescrLong.Clear;
  CollectText(AIndex, FDescrLong, '26');
  if not HasContent(FDescrLong) then
  begin
    { GAEB DA XML needs the description of a remark }
    FOrphans.Add('20 without text');
    Exit;
  end;
  List := ItemlistFor(AIndex - 1);
  if List <> nil then
  begin
    List.Present := True;
    R := List.AddRemark;
  end
  else
  begin
    Body := BodyAt(FOpenDepth);
    R := Body.AddRemark;
  end;
  R.Present := True;
  R.ID := NewId('LGR');
  MapTexts(FDescrShort, FDescrLong, Code(First, 3, 'TA', 'X') = 'X', False, R.Description);
  MapStLNo(First, 5, 6, 22, R.Description.StLNo);
end;

{ 24 and its 28/25/26/79: a sub description of AItem. }
procedure TMapper.MapSub(var AIndex: Integer; AItem: TLandrixGaebXmlItem);
var
  First, N: Integer;
  Sub: TLandrixGaebXmlSubDescr;
  S, Kurzan, StlbName, StlbText: TLandrixGaebString;
  K: string;
  Short, Long: TLines;
  Stlb: Boolean;
begin
  First := AIndex;
  FUsed[AIndex] := True;
  Sub := AItem.SubDescr.Add;
  Sub.Present := True;
  S := Str(AIndex, 3, 4);
  { SubDNo is 1 to 99 }
  if IsDigits(S) and (StrToInt(AsciiOf(S)) >= 1) then
    Sub.SubDNo := S
  else
    FValues.Add('24/UB');
  { GAEB DA XML takes a unit only with a quantity }
  if NumField(AIndex, 6, 16, 3, 5, 'UBMENGE', Sub.Qty) then
    Sub.QU := Str(AIndex, 17, 20)
  else
    Unmapped(AIndex, 17, 20, 'EINHEIT without UBMENGE');
  { a free quantity is a quantity to be stated (QtySpec comes first) }
  if Code(AIndex, 41, 'KZFRMENG', 'X') = 'X' then
  begin
    Sub.QtySpec := 'Yes';
    Sub.QtyTBD := 'Yes';
  end;
  Inc(AIndex);
  Kurzan := '';
  StlbName := '';
  StlbText := '';
  N := 0;
  Short := TLines.Create;
  Long := TLines.Create;
  try
    while AIndex < FDoc.Count do
    begin
      K := FDoc.Kind(AIndex);
      if K = '28' then
      begin
        FUsed[AIndex] := True;
        Kurzan := TrimRightW(Raw(AIndex, 3, 57));
        { a shortened sub description names no reference }
        Unmapped(AIndex, 58, 70, 'OZ/AUSNR of a sub description');
        Inc(AIndex);
      end
      else if K = '25' then
        CollectText(AIndex, Short, '25')
      else if K = '26' then
        CollectText(AIndex, Long, '26')
      else if K = '79' then
      begin
        FUsed[AIndex] := True;
        if N = 0 then
          StlbName := Str(AIndex, 3, 12);
        if N < 99 then
          StlbText := StlbText + ' ' + Raw(AIndex, 13, 74);
        Inc(N);
        Inc(AIndex);
      end
      else
        Break;
    end;
    if N > 9 then
      FLimits.Add('79');
    if (Short.Count = 0) and (TrimW(Kurzan) <> '') then
      Short.Add(Kurzan, '', ' ');
    if MapTextParts(Short, Long, Code(First, 21, 'TA', 'X') = 'X', Code(First, 22, 'TB', 'X') = 'X',
      Sub.Description.CompleteText, Sub.Description.OutlineText) then
      Sub.Description.Present := True;
    Stlb := (N > 0) and MapStlbBau(StlbName, StlbText, Sub.Description.STLBBau);
    if Stlb then
    begin
      Sub.Description.Present := True;
      Unmapped(First, 23, 40, 'TEXTSYST/STLNR beside STLB-Bau');
    end
    else if MapStLNo(First, 23, 24, 40, Sub.Description.StLNo) then
      Sub.Description.Present := True;
  finally
    Long.Free;
    Short.Free;
  end;
  Unmapped(First, 42, 74, 'FILLER');
end;

{ 41 and its blocks (42 with 25/26): an execution description, placed as
  a remark. }
procedure TMapper.MapPerf(var AIndex: Integer);
var
  First, Block, J: Integer;
  List: TLandrixGaebXmlItemlist;
  Perf: TLandrixGaebXmlPerfDescr;
  D: TLandrixGaebXmlPerfDescription;
  No: TLandrixGaebString;
  Short, Long: TLines;
  Has: Boolean;
begin
  First := AIndex;
  FUsed[AIndex] := True;
  Inc(AIndex);
  { the place: that of a remark before the next item or group }
  J := AIndex;
  while (J < FDoc.Count) and InList(FDoc.Kind(J), '|42|25|26|') do
    Inc(J);
  List := ItemlistFor(J - 1);
  if List <> nil then
  begin
    List.Present := True;
    Perf := List.AddPerfDescr;
  end
  else
    Perf := BodyAt(FOpenDepth).AddPerfDescr;
  Perf.Present := True;
  Perf.ID := NewId('LGP');
  No := Str(First, 3, 6);
  if IsDigits(No) then
  begin
    Perf.PerfNo := No;
    if FPerfTable.Add(PerfKey(No), FPerfCount) then
    begin
      if FPerfCount >= Length(FPerfIds) then
        SetLength(FPerfIds, 2 * FPerfCount + 16);
      FPerfIds[FPerfCount] := Perf.ID;
      Inc(FPerfCount);
    end;
  end
  else if No <> '' then
    FValues.Add('41/AUSNR');
  Perf.PerfLbl := Str(First, 7, 61);
  Has := False;
  Short := TLines.Create;
  Long := TLines.Create;
  try
    while (AIndex < FDoc.Count) and InList(FDoc.Kind(AIndex), '|42|25|26|') do
    begin
      { a block: its 42 (or the texts right after 41) and its texts }
      Block := -1;
      if FDoc.Kind(AIndex) = '42' then
      begin
        Block := AIndex;
        FUsed[AIndex] := True;
        Inc(AIndex);
      end;
      Short.Clear;
      Long.Clear;
      while (AIndex < FDoc.Count) and ((FDoc.Kind(AIndex) = '25') or (FDoc.Kind(AIndex) = '26')) do
        if FDoc.Kind(AIndex) = '25' then
          CollectText(AIndex, Short, '25')
        else
          CollectText(AIndex, Long, '26');
      D := Perf.Description.Add;
      D.Present := True;
      if Block >= 0 then
      begin
        MapTextParts(Short, Long, Code(Block, 3, 'TA', 'X') = 'X', Code(Block, 4, 'TB', 'X') = 'X',
          D.CompleteText, D.OutlineText);
        MapStLNo(Block, 5, 6, 22, D.StLNo);
      end
      else
        MapTextParts(Short, Long, False, False, D.CompleteText, D.OutlineText);
      Has := True;
    end;
  finally
    Long.Free;
    Short.Free;
  end;
  if (Perf.PerfNo = '') or (Perf.PerfLbl = '') or not Has then
    Inc(FIncompletePerf);
end;

{ A block of contract terms (T0, T1 lines, T9; the block also ends at the
  next other record): one Award/AddText, a paragraph per T1 line. }
procedure TMapper.MapContract(var AIndex: Integer);
var
  A: TLandrixGaebXmlAddText;
  P: TLandrixGaebXmlP;
  S: TLandrixGaebString;
  K: string;
begin
  A := nil;
  if FInBill then
    Inc(FContractInside);
  if FDoc.Kind(AIndex) = 'T0' then
  begin
    FUsed[AIndex] := True;
    Unmapped(AIndex, 3, 74, 'FILLER');
    Inc(AIndex);
  end;
  while AIndex < FDoc.Count do
  begin
    K := FDoc.Kind(AIndex);
    if K = 'T1' then
    begin
      FUsed[AIndex] := True;
      if A = nil then
      begin
        A := FG.Award.AddText.Add;
        A.Present := True;
        A.DetailAddText.Present := True;
      end;
      S := TrimRightW(Raw(AIndex, 3, 74));
      P := A.DetailAddText.AddP;
      P.Present := True;
      if S <> '' then
        P.AddSpan.Value := S;
      Inc(AIndex);
    end
    else if K = 'T9' then
    begin
      FUsed[AIndex] := True;
      Unmapped(AIndex, 3, 74, 'FILLER');
      Inc(AIndex);
      Break;
    end
    else
      Break;
  end;
end;

{ 21 (or a 23 without 21) and the records of the item. }
procedure TMapper.MapItem(var AIndex: Integer);
var
  First, Depth, J: Integer;
  OZ, ItemPart, IndexPart, QU, Zz, Zzv90: TLandrixGaebString;
  Parts: TPartArray;
  Kind, K: string;
  Has21, IsMarkup, IsNote, QtyTBD, TA, TB, Bad, Stlb: Boolean;
  Kurzan, RefOZ, RefNo, StlbName, StlbText, ItemId: TLandrixGaebString;
  NStlb: Integer;
  Split: TLandrixGaebXmlQtySplit;
  SplitQty, ItemF: TLandrixGaebDecimal;
  Item: TLandrixGaebXmlItem;
  Markup: TLandrixGaebXmlMarkupItem;
  Descr: TLandrixGaebXmlDescription;
  List: TLandrixGaebXmlItemlist;
  P1, P2, Typ, Z, Wv, St: Char;
  FreeQty: TLandrixGaebDecimal;
  R: TLandrixGaebXmlRemark;
begin
  First := AIndex;
  Has21 := FDoc.Kind(AIndex) = '21';
  OZ := FDoc.Field(AIndex, 3, 11);
  Parts := nil;
  PartsOf(OZ, Parts, Depth, ItemPart, IndexPart, Bad);
  if Bad or (ItemPart = '') then
    Inc(FNumberProblems);
  IsNote := False;
  Wv := ' ';
  P1 := ' ';
  P2 := ' ';
  Typ := ' ';
  if Has21 then
  begin
    Kind := AsciiOf(FDoc.Field(AIndex, 12, 14));
    IsNote := Kind = 'NNH';
    if IsNote then
      Inc(FOldNotes)
    else if not InList(Kind, PositionKinds) then
      Inc(FBadKinds);
    P1 := Code(AIndex, 12, 'POSART1', 'NGAS');
    P2 := Code(AIndex, 13, 'POSART2', 'NEM');
    if not IsNote then
      Typ := Code(AIndex, 14, 'POSTYP', 'NL');
    Z := Code(AIndex, 20, 'ZUSCHLAG', 'EZ');
    if (Z = ' ') and (FDoc.Field(AIndex, 20, 20) <> ' ') then
      Inc(FMarkupValues);
    IsMarkup := Z = 'Z';
  end
  else
  begin
    Z := ' ';
    { a 23 without 21 (phase 84) with ZUSCHPR or ZUSCHSU is a markup item }
    IsMarkup := TrimW(FDoc.Field(AIndex, 56, 74)) <> '';
  end;
  OpenPath(Parts, Depth, -1);
  NoteItem(Depth);
  List := BodyAt(Depth).Itemlist;
  List.Present := True;
  Item := nil;
  Markup := nil;
  if IsNote then
  begin
    R := List.AddRemark;
    R.Present := True;
    R.ID := NewId('LGR');
    Descr := R.Description;
  end
  else if IsMarkup then
  begin
    Markup := List.AddMarkupItem;
    Markup.Present := True;
    Markup.ID := NewId('LGI');
    Markup.RNoPart := ItemPart;
    if IndexPart <> '' then
      Markup.RNoIndex := IndexPart;
    Markup.MarkupType := 'IdentAsMark';
    Descr := Markup.Description;
    if not Has21 then
      Inc(FNoKind);
  end
  else
  begin
    Item := List.AddItem;
    Item.Present := True;
    Item.ID := NewId('LGI');
    Item.RNoPart := ItemPart;
    if IndexPart <> '' then
      Item.RNoIndex := IndexPart;
    Descr := Item.Description;
    if not Has21 then
      Inc(FNoKind);
  end;
  if not IsNote then
  begin
    Inc(FItems);
    { the number for the references of 28 (first one wins) }
    if Item <> nil then
      ItemId := Item.ID
    else
      ItemId := Markup.ID;
    if FItemTable.Add(PathKey(Parts, Depth) + #10 + ItemPart + #10 + IndexPart, FItemCount) then
    begin
      if FItemCount >= Length(FItemIds) then
        SetLength(FItemIds, 2 * FItemCount + 16);
      FItemIds[FItemCount] := ItemId;
      Inc(FItemCount);
      { a number again in the same lot stays with the first one; only
        other lots make it ambiguous }
      if FHasLots then
        AddOz(WithoutLot(PathKey(Parts, Depth) + #10 + ItemPart + #10 + IndexPart), ItemId);
    end;
  end;
  QtyTBD := False;
  TA := False;
  TB := False;
  if Has21 then
  begin
    FUsed[AIndex] := True;
    Zz := FDoc.Field(AIndex, 15, 18);
    if (P1 = 'G') or (P1 = 'A') then
    begin
      if IsDigits(Copy(Zz, 1, 3)) then
      begin
        { the group number only with a serial number (both or none) }
        Zzv90 := Copy(Zz, 1, 3);
        if P1 = 'G' then
          Zz := '0'
        else if IsDigits(Copy(Zz, 4, 1)) and (Zz[4] <> '0') then
          { an alternative is numbered 1 to 9 (0 is the basic one) }
          Zz := Copy(Zz, 4, 1)
        else
        begin
          Zz := '';
          FValues.Add('21/ZZ');
        end;
        if (Item <> nil) and (Zz <> '') then
        begin
          Item.ALNGroupNo := Zzv90;
          Item.ALNSerNo := Zz;
        end
        else if (Markup <> nil) and (Zz <> '') then
        begin
          Markup.ALNGroupNo := Zzv90;
          Markup.ALNSerNo := Zz;
        end;
      end
      else
        FValues.Add('21/ZZ');
    end
    else if TrimW(Zz) <> '' then
      FFields.Add('21/ZZ');
    if Item <> nil then
    begin
      if P1 = 'S' then
        Item.HourIt := 'Yes';
      if P2 = 'E' then
        Item.Provis := 'WithoutTotal'
      else if P2 = 'M' then
        Item.Provis := 'WithTotal';
      if Typ = 'L' then
        Item.SumDescr := 'Yes';
      if Code(AIndex, 19, 'EPAUFGL', 'X') = 'X' then
        Item.UPBkdn := 'Yes';
      if Z = 'E' then
        Item.MarkupIt := 'Yes';
      QtyTBD := Code(AIndex, 22, 'KZFRMENG', 'X') = 'X';
      if QtyTBD then
        Item.QtyTBD := 'Yes';
      NumField(AIndex, 24, 34, 3, 23, 'MENGE', Item.Qty);
      { ---- (no unit) stays as written: GAEB DA XML needs a QU with a
        quantity }
      QU := Str(AIndex, 35, 38);
      Item.QU := QU;
      if CompareText(AsciiOf(QU), 'psch') = 0 then
        Item.LumpSumItem := 'Yes';
      Unmapped(AIndex, 39, 41, 'NACHTRKZ');
      St := Code(AIndex, 62, 'POSSTAT', 'R');
      if St = 'R' then
        Item.NotAppl := 'Yes'
      else if FDoc.Field(AIndex, 62, 62) <> ' ' then
        Inc(FStatus);
    end
    else
    begin
      if Markup <> nil then
      begin
        if P1 = 'S' then
          Markup.HourIt := 'Yes';
        if P2 = 'E' then
          Markup.Provis := 'WithoutTotal'
        else if P2 = 'M' then
          Markup.Provis := 'WithTotal';
        Unmapped(AIndex, 39, 41, 'NACHTRKZ');
        St := Code(AIndex, 62, 'POSSTAT', 'R');
        if St = 'R' then
          Markup.NotAppl := 'Yes'
        else if FDoc.Field(AIndex, 62, 62) <> ' ' then
          Inc(FStatus);
      end;
      Unmapped(AIndex, 19, 19, 'EPAUFGL');
      Unmapped(AIndex, 22, 38, 'MENGE/EINHEIT');
    end;
    Wv := Code(AIndex, 21, 'WIEVOR', 'BWA');
    if (Wv = 'B') or (Wv = 'W') then
    begin
      if Wv = 'B' then
        K := 'Ref'
      else
        K := 'Rep';
      if Item <> nil then
        Item.RefDescr := W(K)
      else if Markup <> nil then
        Markup.RefDescr := W(K);
    end;
    { A: the reference is the AUSNR of the 28 (RefPerfNo) }
    TA :=Code(AIndex, 42, 'TA', 'X') = 'X';
    TB := Code(AIndex, 43, 'TB', 'X') = 'X';
    Unmapped(AIndex, 63, 63, 'KZBELO');
    Unmapped(AIndex, 64, 74, 'FILLER');
    Inc(AIndex);
  end;
  FDescrShort.Clear;
  FDescrLong.Clear;
  Kurzan := '';
  RefOZ := '';
  RefNo := '';
  StlbName := '';
  StlbText := '';
  NStlb := 0;
  { the records of the item; a sub description (24) and what follows it
    belong to the sub description }
  while AIndex < FDoc.Count do
  begin
    K := FDoc.Kind(AIndex);
    if (K = '22') or (K = '23') then
    begin
      { another number: the next item }
      if TrimW(FDoc.Field(AIndex, 3, 11)) <> TrimW(OZ) then
        Break;
      if (K = '23') and (AIndex > First) and (FDoc.Kind(First) = '23') and (AIndex <> First) then
        Break;
      FUsed[AIndex] := True;
      FreeQty.Clear;
      if Item <> nil then
      begin
        if K = '22' then
        begin
          Price(AIndex, 13, 22, 12, 23, 'VEP', Item.UP);
          NumField(AIndex, 25, 36, 2, 24, 'VGB', Item.IT);
          NumField(AIndex, 38, 48, 3, 37, 'VFREIEME', FreeQty);
          Unmapped(AIndex, 56, 74, 'VZUSCHP/VZUSCHSU');
        end
        else
        begin
          Price(AIndex, 13, 22, 12, 23, 'EP', Item.UP);
          NumField(AIndex, 25, 36, 2, 24, 'GB', Item.IT);
          NumField(AIndex, 38, 48, 3, 37, 'FREIEMEN', FreeQty);
          { the factor of the item: f 0 or 1 is none }
          ItemF.Clear;
          if NumField(AIndex, 49, 55, 6, 0, 'AUFABFAK', ItemF) and (ItemF.Coefficient <> 0) and
            (ItemF.Coefficient <> 1000000) then
            Item.DiscountPcnt.SetValue((1000000 - ItemF.Coefficient) * 100, 6);
          Unmapped(AIndex, 56, 74, 'ZUSCHPR/ZUSCHSU');
        end;
        if FreeQty.HasValue and (QtyTBD or not Item.Qty.HasValue) then
          Item.Qty := FreeQty;
      end
      else if Markup <> nil then
      begin
        if K = '22' then
        begin
          NumField(AIndex, 25, 36, 2, 24, 'VGB', Markup.IT);
          NumField(AIndex, 57, 61, 2, 56, 'VZUSCHP', Markup.Markup);
          NumField(AIndex, 63, 74, 2, 62, 'VZUSCHSU', Markup.ITMarkup);
          Unmapped(AIndex, 12, 23, 'VEP');
        end
        else
        begin
          NumField(AIndex, 25, 36, 2, 24, 'GB', Markup.IT);
          NumField(AIndex, 57, 61, 2, 56, 'ZUSCHPR', Markup.Markup);
          NumField(AIndex, 63, 74, 2, 62, 'ZUSCHSU', Markup.ITMarkup);
          Unmapped(AIndex, 12, 23, 'EP');
          Unmapped(AIndex, 49, 55, 'AUFABFAK');
        end;
      end
      else
        Unmapped(AIndex, 12, 74, 'prices of a note text');
      Inc(AIndex);
    end
    else if K = '30' then
    begin
      FUsed[AIndex] := True;
      if Item <> nil then
      begin
        NumField(AIndex, 3, 12, 4, 0, 'ZEITANS', Item.TimeQu);
        NumField(AIndex, 13, 22, 2, 0, 'EPANTEL1', Item.UPComp1);
        NumField(AIndex, 23, 32, 2, 0, 'EPANTEL2', Item.UPComp2);
        NumField(AIndex, 33, 42, 2, 0, 'EPANTEL3', Item.UPComp3);
        NumField(AIndex, 43, 52, 2, 0, 'EPANTEL4', Item.UPComp4);
      end
      else
        Unmapped(AIndex, 3, 52, 'ZEITANS/EPANTEL');
      Inc(AIndex);
    end
    else if K = '25' then
      CollectText(AIndex, FDescrShort, '25')
    else if K = '26' then
      CollectText(AIndex, FDescrLong, '26')
    else if K = '27' then
    begin
      FUsed[AIndex] := True;
      if Item <> nil then
      begin
        { a split needs its quantity: only then it is added }
        SplitQty.Clear;
        if NumField(AIndex, 33, 43, 3, 32, 'TEILMENG', SplitQty) then
        begin
          Split := Item.QtySplit.Add;
          Split.Present := True;
          Split.Qty := SplitQty;
        end
        else
          FOrphans.Add('27 without TEILMENG');
        Unmapped(AIndex, 3, 31, 'KOSTENNR/LOKALIT');
        Unmapped(AIndex, 44, 66, 'LOKALNR/DATUM/LBKE');
      end
      else
        FOrphans.Add('27 of a markup item or note text');
      Inc(AIndex);
    end
    else if K = '28' then
    begin
      FUsed[AIndex] := True;
      Kurzan := TrimRightW(Raw(AIndex, 3, 57));
      RefOZ := FDoc.Field(AIndex, 58, 66);
      RefNo := Str(AIndex, 67, 70);
      Inc(AIndex);
    end
    else if K = '79' then
    begin
      FUsed[AIndex] := True;
      if NStlb = 0 then
        StlbName := Str(AIndex, 3, 12);
      if NStlb < 99 then
        StlbText := StlbText + ' ' + Raw(AIndex, 13, 74);
      Inc(NStlb);
      Inc(AIndex);
    end
    else if K = '24' then
    begin
      if Item <> nil then
        MapSub(AIndex, Item)
      else
      begin
        { a markup item or note text has no sub descriptions }
        J := AIndex;
        while (J < FDoc.Count) and InList(FDoc.Kind(J), '|24|25|26|28|79|') do
        begin
          FOrphans.Add(FDoc.Kind(J) + ' of a sub description without item');
          FUsed[J] := True;
          Inc(J);
        end;
        AIndex := J;
      end;
    end
    else
      Break;
  end;
  { KURZAN: the short text when there is none, else only compared }
  if TrimW(Kurzan) <> '' then
  begin
    if FDescrShort.Count = 0 then
      FDescrShort.Add(Kurzan, '', ' ')
    else if TrimW(Kurzan) <> TrimW(FDescrShort.Text[0]) then
      Inc(FKurzan);
  end;
  MapTexts(FDescrShort, FDescrLong, TA, TB, Descr);
  if NStlb > 9 then
    FLimits.Add('79');
  Stlb := (NStlb > 0) and MapStlbBau(StlbName, StlbText, Descr.STLBBau);
  if Stlb then
  begin
    Descr.Present := True;
    if Has21 then
      Unmapped(First, 44, 61, 'TEXTSYST/STLNR beside STLB-Bau');
  end
  else if Has21 and MapStLNo(First, 44, 45, 61, Descr.StLNo) then
    Descr.Present := True;
  { references: OZ (W) and AUSNR (A) of the 28 }
  if TrimW(RefOZ) <> '' then
  begin
    if Item <> nil then
      AddRef(Item.RefRNo, NumberKey(RefOZ), False)
    else if Markup <> nil then
      AddRef(Markup.RefRNo, NumberKey(RefOZ), False);
  end;
  if RefNo <> '' then
  begin
    if Item <> nil then
      AddRef(Item.RefPerfNo, PerfKey(RefNo), True)
    else if Markup <> nil then
      AddRef(Markup.RefPerfNo, PerfKey(RefNo), True);
  end;
  if Has21 then
  begin
    { Wv as read from the 21 above (read once: Code counts) }
    if ((Wv = 'W') and (TrimW(RefOZ) = '')) or ((Wv = 'A') and (RefNo = '')) or
      ((TrimW(RefOZ) <> '') and (Wv <> 'W')) or ((RefNo <> '') and (Wv <> 'A')) then
      Inc(FRefKind);
  end
  else if (TrimW(RefOZ) <> '') or (RefNo <> '') then
    Inc(FRefKind);
end;

procedure TMapper.MapClosing(AIndex: Integer);
var
  T: TLandrixGaebXmlTotals;
  N, Skonto: TLandrixGaebDecimal;
  Days: TLandrixGaebString;
  C: TLandrixGaebXmlCashDiscount;
begin
  FUsed[AIndex] := True;
  T := FG.Award.BoQ.BoQInfo.Totals;
  if not NumField(AIndex, 3, 14, 2, 0, 'LVSUMME', T.Total) then
    if (TrimW(FDoc.Field(AIndex, 3, 14)) <> '') and (FInvalidTotals <> nil) then
      FInvalidTotals.Add(T);
  NumField(AIndex, 22, 25, 2, 0, 'UST', T.VAT);
  NumField(AIndex, 26, 37, 2, 0, 'ANGEBOTS', T.TotalGross);
  NumField(AIndex, 52, 63, 2, 51, 'PAUSCH', T.TotalLSUM);
  MapDiscount(AIndex, 15, 38, 39, T);
  if T.Total.HasValue or T.VAT.HasValue or T.TotalGross.HasValue or T.TotalLSUM.HasValue then
    T.Present := True;
  { cash discount: SKONTO with the days of ZAFRIST }
  Skonto.Clear;
  if NumField(AIndex, 64, 67, 2, 0, 'SKONTO', Skonto) then
  begin
    Days := Str(AIndex, 68, 69);
    if IsDigits(Days) and (StrToInt(AsciiOf(Days)) > 0) then
    begin
      C := FG.Award.AwardInfo.CashDiscount.Add;
      C.Present := True;
      C.DiscountPcnt := Skonto;
      C.CashDiscDays.Present := True;
      C.CashDiscDays.Days := Days;
      FG.Award.AwardInfo.Present := True;
    end
    else
      Inc(FDiscountLost);
  end;
  N.Clear;
  if NumField(AIndex, 70, 74, 0, 0, 'ANZTEIL', N) and (N.Coefficient <> FItems) then
    Report(AIndex, RuleCount, gsWarning, 'ANZTEIL of 99 differs from the number of positions (' +
      IntToStr(FItems) + ')');
end;

{ A block that is not mapped yet: the record at AIndex and the following
  ones of the kinds AFollowers. }
procedure TMapper.SkipBlock(var AIndex: Integer; const AFollowers: string);
begin
  FNotMapped.Add(FDoc.Kind(AIndex));
  FUsed[AIndex] := True;
  Inc(AIndex);
  while (AIndex < FDoc.Count) and InList(FDoc.Kind(AIndex), AFollowers) do
  begin
    FNotMapped.Add(FDoc.Kind(AIndex));
    FUsed[AIndex] := True;
    Inc(AIndex);
  end;
end;

{ AUFABFAK in column AFactor (1,6) or AUFABDM in AAmount (10,2, its sign
  in ASign) into ATotals: a discount or surcharge with the total after it
  (GAEB DA XML needs both, and has no room for them beside a lump sum).
  A factor of 0 or 1 is none: 0 stands for an empty field in the files
  seen, never for a discount of 100 percent. }
procedure TMapper.MapDiscount(AIndex, AFactor, ASign, AAmount: Integer; ATotals: TLandrixGaebXmlTotals);
var
  F, A: TLandrixGaebDecimal;
  R: TLandrixGaebDecimal;
  HasF, HasA: Boolean;
begin
  F.Clear;
  A.Clear;
  HasF := NumField(AIndex, AFactor, AFactor + 6, 6, 0, 'AUFABFAK', F) and (F.Coefficient <> 0) and
    (F.Coefficient <> 1000000);
  HasA := NumField(AIndex, AAmount, AAmount + 11, 2, ASign, 'AUFABDM', A) and (A.Coefficient <> 0);
  if not (HasF or HasA) then
    Exit;
  if not ATotals.Total.HasValue or ATotals.TotalLSUM.HasValue then
  begin
    Inc(FDiscountLost);
    Exit;
  end;
  R.Clear;
  if HasF then
  begin
    { (1 - f) x 100 with six decimals: f has six }
    ATotals.DiscountPcnt.SetValue((1000000 - F.Coefficient) * 100, 6);
    if not ToDecimal(LandrixGaebRoundHalfAwayFromZero(LandrixXmlDecimalMultiply(ATotals.Total.AsXmlDecimal,
      F.AsXmlDecimal), 2), R) then
      Inc(FDiscountLost);
  end
  else
  begin
    { a minus marks a discount (Abschlag), else a surcharge }
    ATotals.DiscountAmt.SetValue(-A.Coefficient, 2);
    if not ToDecimal(LandrixGaebRoundHalfAwayFromZero(LandrixXmlDecimalSubtract(ATotals.Total.AsXmlDecimal,
      ATotals.DiscountAmt.AsXmlDecimal), 2), R) then
      Inc(FDiscountLost);
  end;
  { two decimals, as the total (an exact difference may have fewer) }
  while R.HasValue and (R.Scale < 2) do
    R.SetValue(R.Coefficient * 10, R.Scale + 1);
  if R.HasValue then
    ATotals.TotAfterDisc := R;
  if HasF and HasA then
    FFields.Add(FDoc.Kind(AIndex) + '/AUFABDM beside AUFABFAK');
end;

{ 10: the lot from here on, a category of the level Lot. }
procedure TMapper.MapLot(AIndex: Integer);
var
  Parts: TPartArray;
  Lbl: TLandrixGaebString;
  Ctgy: TLandrixGaebXmlBoQCtgy;
  P: TLandrixGaebXmlPMLText;
begin
  FUsed[AIndex] := True;
  FCurLot := Str(AIndex, 3, 4);
  if (FCurLot = '') or not FHasLots then
  begin
    FOrphans.Add('10 without LOSNR');
    Exit;
  end;
  Parts := nil;
  SetLength(Parts, FCategoryLevels);
  Parts[0] := FCurLot;
  { a lot number used before, not the open lot: a new category (its
    references go to the first) }
  if not ((FOpenDepth > 0) and (FOpenPart[0] = FCurLot)) and (FCtgyTable.Find(PathKey(Parts, 1)) >= 0) then
    Inc(FLotTwice);
  FLevelSeen[0] := True;
  if not IsDigits(FCurLot) then
    FLevelOther[0] := True;
  OpenPath(Parts, 1, 0);
  Ctgy := FOpenCtgy[0];
  Lbl := Str(AIndex, 5, 44);
  if (Lbl <> '') and (Ctgy.LblTx.Children.Count = 0) then
  begin
    Ctgy.LblTx.Present := True;
    P := Ctgy.LblTx.AddP;
    P.Present := True;
    P.AddSpan.Value := Lbl;
  end;
  Unmapped(AIndex, 45, 74, 'FILLER');
end;

{ 33: the totals of the lot; the lot ends. }
procedure TMapper.MapLotEnd(AIndex: Integer);
var
  Parts: TPartArray;
  K: Integer;
  T: TLandrixGaebXmlTotals;
  Ctgy: TLandrixGaebXmlBoQCtgy;
begin
  FUsed[AIndex] := True;
  Parts := nil;
  SetLength(Parts, FCategoryLevels);
  Ctgy := nil;
  if FHasLots and (FCategoryLevels > 0) then
  begin
    Parts[0] := Str(AIndex, 3, 4);
    { the open lot, else the first one of the number }
    if (FOpenDepth > 0) and (FOpenPart[0] = Parts[0]) then
      Ctgy := FOpenCtgy[0]
    else
    begin
      K := FCtgyTable.Find(PathKey(Parts, 1));
      if K >= 0 then
        Ctgy := FCtgys[K];
    end;
  end;
  { the lot ends: what follows is outside it }
  FCurLot := '';
  FOpenDepth := 0;
  if Ctgy = nil then
  begin
    FOrphans.Add('33 without its lot');
    Exit;
  end;
  T := Ctgy.Totals;
  if T.IsPresent then
  begin
    FFields.Add('33 a second time for its lot');
    Exit;
  end;
  if not NumField(AIndex, 5, 16, 2, 0, 'LOSUMME', T.Total) then
    if (TrimW(FDoc.Field(AIndex, 5, 16)) <> '') and (FInvalidTotals <> nil) then
      FInvalidTotals.Add(T);
  NumField(AIndex, 24, 27, 2, 0, 'UST', T.VAT);
  NumField(AIndex, 28, 39, 2, 0, 'ANGLOS', T.TotalGross);
  NumField(AIndex, 54, 65, 2, 53, 'PAUSCH', T.TotalLSUM);
  MapDiscount(AIndex, 17, 40, 41, T);
  if T.Total.HasValue or T.TotalGross.HasValue or T.TotalLSUM.HasValue or T.VAT.HasValue then
    T.Present := True;
  Unmapped(AIndex, 66, 71, 'SKONTO/ZAFRIST');
end;

{ 34: a lot group with its totals. }
procedure TMapper.MapLotGroup(AIndex: Integer);
var
  G: TLandrixGaebXmlLotGrp;
  No: TLandrixGaebString;
  T: TLandrixGaebXmlTotals;
begin
  FUsed[AIndex] := True;
  No := Str(AIndex, 3, 4);
  if No = '' then
  begin
    FOrphans.Add('34 without LOSGRNR');
    Exit;
  end;
  G := FG.Award.BoQ.LotGrp.Add;
  G.Present := True;
  G.ID := NewId('LGG');
  G.LotGrNo := No;
  FLastGrp := G;
  FLastGrpNo := No;
  if FLotGrpTable.Add(No, FLotGrpCount) then
  begin
    if FLotGrpCount >= Length(FLotGrps) then
      SetLength(FLotGrps, 2 * FLotGrpCount + 16);
    FLotGrps[FLotGrpCount] := G;
    Inc(FLotGrpCount);
  end
  else
    { references go to the first group of the number }
    Inc(FLotTwice);
  T := G.Totals;
  NumField(AIndex, 5, 16, 2, 0, 'LOSGRSUM', T.Total);
  NumField(AIndex, 24, 27, 2, 0, 'UST', T.VAT);
  NumField(AIndex, 28, 39, 2, 0, 'ANGGRLOS', T.TotalGross);
  NumField(AIndex, 54, 65, 2, 53, 'PAUSCH', T.TotalLSUM);
  MapDiscount(AIndex, 17, 40, 41, T);
  if T.Total.HasValue or T.TotalGross.HasValue or T.TotalLSUM.HasValue or T.VAT.HasValue then
    T.Present := True;
  Unmapped(AIndex, 66, 71, 'SKONTO/ZAFRIST');
end;

{ 35: the lots of a lot group (35 numbers of two columns from column 5). }
procedure TMapper.MapLotGroupLots(AIndex: Integer);
var
  K, I: Integer;
  Lot: TLandrixGaebString;
  Ref: TLandrixGaebXmlRefBoQCtgy;
  G: TLandrixGaebXmlLotGrp;
begin
  FUsed[AIndex] := True;
  { the last 34 of the number, else the first one }
  G := nil;
  if (FLastGrp <> nil) and (FLastGrpNo = Str(AIndex, 3, 4)) then
    G := FLastGrp
  else
  begin
    K := FLotGrpTable.Find(Str(AIndex, 3, 4));
    if K >= 0 then
      G := FLotGrps[K];
  end;
  if G = nil then
  begin
    FOrphans.Add('35 without its 34');
    Exit;
  end;
  for I := 0 to 34 do
  begin
    Lot := Str(AIndex, 5 + 2 * I, 6 + 2 * I);
    if Lot = '' then
      Continue;
    Ref := G.RefLotNo.Add;
    AddLotRef(Ref, Lot);
  end;
end;

{ 45/46/47: the wage change of the award. }
procedure TMapper.MapWage(AIndex: Integer);
var
  W90: TLandrixGaebXmlWgChange;
  R: TLandrixGaebXmlWgChangeRefGroup;
  S: TLandrixGaebString;
  K: string;
begin
  FUsed[AIndex] := True;
  K := FDoc.Kind(AIndex);
  W90 := FG.Award.WgChange;
  W90.Present := True;
  if K = '46' then
  begin
    S := Str(AIndex, 3, 57);
    { bounded: beyond 120 characters the text is cut anyway }
    if (S <> '') and (Length(FWgLines) < 200) then
    begin
      if FWgLines <> '' then
        FWgLines := FWgLines + ' ';
      FWgLines := FWgLines + S;
    end;
    Exit;
  end;
  R := W90.RefGroup.Add;
  R.Present := True;
  if K = '47' then
  begin
    R.AddRefBoQ.IDRef := FG.Award.BoQ.ID;
    Unmapped(AIndex, 3, 45, 'FILOAEND/AENDSATZ/AUFLOHN/SEBETEIL/ERSTLOHN');
    Exit;
  end;
  if Str(AIndex, 12, 13) <> '' then
    AddLotRef(R.AddRefLotNo, Str(AIndex, 12, 13))
  else if Str(AIndex, 14, 15) <> '' then
    AddGroupRef(R.AddRefLotGrNo, Str(AIndex, 14, 15))
  else
    { a group of the bill: GAEB DA XML refers to lots, groups of lots and
      items only }
    Unmapped(AIndex, 3, 11, 'OZ of a wage change');
  Unmapped(AIndex, 16, 34, 'FILOAEND/AENDSATZ/AUFLOHN');
end;

{ The wage change after the references are resolved: GAEB DA XML needs
  LblRefWage and at least one reference; without them it is left out.
  DE: Die Lohnaenderung nach dem Aufloesen der Verweise: GAEB DA XML
  verlangt LblRefWage und mindestens einen Verweis; ohne sie entfaellt
  sie. }
procedure TMapper.FinishWage;
var
  W90: TLandrixGaebXmlWgChange;
  I, J: Integer;
  HasRef: Boolean;
begin
  W90 := FG.Award.WgChange;
  HasRef := False;
  for I := 0 to Integer(W90.RefGroup.Count) - 1 do
    if W90.RefGroup[I].HasChildren then
      for J := 0 to Integer(W90.RefGroup[I].Children.Count) - 1 do
        if W90.RefGroup[I].Children[J].IsPresent then
          HasRef := True;
  if (FWgLines = '') or not HasRef then
  begin
    W90.Clear;
    W90.Present := False;
    FOrphans.Add('wage change without LblRefWage (46) or a reference');
    Exit;
  end;
  if Length(FWgLines) > 120 then
  begin
    Inc(FDiscountLost);
    FWgLines := TrimW(Copy(FWgLines, 1, 120));
  end;
  W90.LblRefWage := FWgLines;
end;

procedure TMapper.AddLotRef(ARef: TLandrixGaebXmlRefBoQCtgy; const ALot: TLandrixGaebString);
begin
  if FLotRefCount >= Length(FLotRefs) then
  begin
    SetLength(FLotRefs, 2 * FLotRefCount + 16);
    SetLength(FLotRefKeys, 2 * FLotRefCount + 16);
  end;
  FLotRefs[FLotRefCount] := ARef;
  FLotRefKeys[FLotRefCount] := ALot;
  Inc(FLotRefCount);
end;

procedure TMapper.AddGroupRef(ARef: TLandrixGaebXmlRefLotGrp; const AGroup: TLandrixGaebString);
begin
  if FGrpRefCount >= Length(FGrpRefs) then
  begin
    SetLength(FGrpRefs, 2 * FGrpRefCount + 16);
    SetLength(FGrpRefKeys, 2 * FGrpRefCount + 16);
  end;
  FGrpRefs[FGrpRefCount] := ARef;
  FGrpRefKeys[FGrpRefCount] := AGroup;
  Inc(FGrpRefCount);
end;

{ Required parts of GAEB DA XML without a source in GAEB 90 (owner
  decisions 15.11.2026): BoQInfo/Name from VERGAG, else from the first 20
  characters of LVBEZ; an empty LblTx for a category without record 12.
  GAEBInfo/Date (the date of the file) from LVDATUM, the date of the bill
  (owner decision 16.11.2026); without a usable LVDATUM it stays missing.
  DE: Pflichtteile von GAEB DA XML ohne Quelle in GAEB 90 (Entscheidungen
  Nutzer 15.11.2026): BoQInfo/Name aus VERGAG, sonst aus den ersten 20
  Zeichen von LVBEZ; ein leeres LblTx fuer einen Bereich ohne Satz 12.
  GAEBInfo/Date (Datum der Datei) aus LVDATUM, dem Datum des LV
  (Entscheidung Nutzer 16.11.2026); ohne brauchbares LVDATUM bleibt es
  fehlend. }
procedure TMapper.FillRequired;
var
  Info: TLandrixGaebXmlBoQInfo;
  I, Empty: Integer;
  From: string;
  P: TLandrixGaebXmlPMLText;
begin
  Info := FG.Award.BoQ.BoQInfo;
  if Info.Date <> '' then
  begin
    FG.GAEBInfo.Date := Info.Date;
    Report(-1, RuleFilled, gsInformation, 'GAEBInfo/Date (required, GAEB 90 has none) taken from LVDATUM');
  end
  else
    Report(-1, RuleFilled, gsInformation, 'GAEBInfo/Date (required) stays missing: no usable LVDATUM');
  From := '';
  if Info.Name = '' then
  begin
    if FVergag <> '' then
    begin
      Info.Name := TrimW(Copy(FVergag, 1, 20));
      From := 'VERGAG';
    end
    else if Info.LblBoQ <> '' then
    begin
      Info.Name := TrimW(Copy(Info.LblBoQ, 1, 20));
      From := 'LVBEZ';
    end;
  end;
  if From <> '' then
    Report(-1, RuleFilled, gsInformation, 'BoQInfo/Name (required, GAEB 90 has none) taken from ' + From);
  { PrjInfo/NamePrj (required once PrjInfo holds anything): the first line
    of PROBEZ, else VERGAG, else LVBEZ (owner decision 15.11.2026) }
  From := '';
  if (FG.PrjInfo.NamePrj = '') and not FG.PrjInfo.IsEmpty then
  begin
    if FG.PrjInfo.LblPrj <> '' then
    begin
      FG.PrjInfo.NamePrj := TrimW(Copy(FG.PrjInfo.LblPrj, 1, 60));
      From := 'PROBEZ';
    end
    else if FVergag <> '' then
    begin
      FG.PrjInfo.NamePrj := FVergag;
      From := 'VERGAG';
    end
    else if Info.LblBoQ <> '' then
    begin
      FG.PrjInfo.NamePrj := TrimW(Copy(Info.LblBoQ, 1, 60));
      From := 'LVBEZ';
    end;
  end;
  if From <> '' then
    Report(-1, RuleFilled, gsInformation, 'PrjInfo/NamePrj (required, GAEB 90 has none) taken from ' + From)
  else if (FG.PrjInfo.NamePrj = '') and FG.PrjInfo.IsEmpty then
    { nothing for the project: PrjInfo (optional) is left out }
    FG.PrjInfo.Present := False;
  Empty := 0;
  for I := 0 to FCtgyCount - 1 do
    if FCtgys[I].LblTx.Children.Count = 0 then
    begin
      FCtgys[I].LblTx.Present := True;
      P := FCtgys[I].LblTx.AddP;
      P.Present := True;
      Inc(Empty);
    end;
  if Empty > 0 then
    Report(-1, RuleFilled, gsInformation, IntToStr(Empty) +
      ' categor(y/ies) without label (record 12): LblTx (required) left empty');
end;

procedure TMapper.AddBreakdown;
var
  I, Unused: Integer;
  B: TLandrixGaebXmlBoQBkdn;
begin
  Unused := 0;
  for I := 0 to Integer(Length(FLevels)) - 1 do
  begin
    B := FG.Award.BoQ.BoQInfo.BoQBkdn.Add;
    B.Present := True;
    B.TypeElement := W(FLevels[I].Kind);
    B.LengthElement := W(IntToStr(FLevels[I].Length));
    B.LblBoQBkdn := FLevelLabels[I];
    B.Alignment := 'right';
    if FLevelSeen[I] and not FLevelOther[I] then
      B.Num := 'Yes'
    else
      B.Num := 'No';
    if not FLevelSeen[I] then
      Inc(Unused);
  end;
  if Unused > 0 then
    Report(-1, RuleUnusedLevel, gsInformation, IntToStr(Unused) +
      ' breakdown level(s) without any value: Num set to No');
end;

function TMapper.Map(ADocument: TLandrixGaebDA90Document; ADiagnostics: TLandrixGaebDiagnostics;
  AInvalidTotals: TObjectList; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  I, Header, Bills: Integer;
  K: string;
  Phase: TLandrixGaebPhase;
  BoQ: TLandrixGaebXmlBoQ;
  Lo: Integer;
begin
  FDoc := ADocument;
  FDiags := ADiagnostics;
  FInvalidTotals := AInvalidTotals;
  SetLength(FUsed, FDoc.Count);
  for I := 0 to FDoc.Count - 1 do
    FUsed[I] := False;
  Header := -1;
  for I := 0 to FDoc.Count - 1 do
    if FDoc.Kind(I) = '00' then
    begin
      Header := I;
      Break;
    end;
  if Header < 0 then
    raise ELandrixGaebError.Create('GAEB 90: no record 00 (opening record)');
  FPhase := AsciiOf(FDoc.Field(Header, 11, 12));
  Phase := LandrixGaebPhaseFromDP(LandrixXmlStringToUtf8(FPhase));
  if not (Phase in [gp81, gp82, gp83, gp84, gp85, gp86]) then
  begin
    if IsDigits(W(FPhase)) then
      raise ELandrixGaebError.Create('GAEB 90, line ' + IntToStr(FDoc.Line(Header)) + ': exchange phase ' +
        FPhase + ' is not read (81 to 86)')
    else
      raise ELandrixGaebError.Create('GAEB 90, line ' + IntToStr(FDoc.Line(Header)) +
        ': DP is no exchange phase; only 81 to 86 are read');
  end;
  ATarget := LandrixGaebTarget(gv33, ge2021_05, Phase);
  FG := TLandrixGaebXmlGAEB.Create;
  try
    FG.GAEBInfo.Present := True;
    FG.GAEBInfo.Version := '3.3';
    FG.GAEBInfo.VersDate := '2021-05';
    FG.PrjInfo.Present := True;
    FG.Award.Present := True;
    FG.Award.DP := W(FPhase);
    BoQ := FG.Award.BoQ;
    BoQ.Present := True;
    BoQ.ID := NewId('LGB');
    BoQ.BoQInfo.Present := True;
    BoQ.BoQBody.Present := True;
    FRootBody := BoQ.BoQBody;
    FUsed[Header] := True;
    for I := Header + 1 to FDoc.Count - 1 do
      if FDoc.Kind(I) = '10' then
      begin
        FHasLots := True;
        Break;
      end
      else if FDoc.Kind(I) = '00' then
        Break;
    MapHeader00(Header);
    if (FDoc.Field(Header, 74, 74) = 'X') <> FHasLots then
      Report(Header, RuleLots, gsError, 'LOSKZ and the lots (10) of the file do not agree');
    { contract terms before the bill }
    I := 0;
    while I < Header do
    begin
      K := FDoc.Kind(I);
      if (K = 'T0') or (K = 'T1') then
        MapContract(I)
      else
        Inc(I);
    end;
    FInBill := True;
    Bills := 0;
    I := Header + 1;
    while I < FDoc.Count do
    begin
      K := FDoc.Kind(I);
      if K = '00' then
      begin
        { further bills: not read }
        while I < FDoc.Count do
        begin
          if FDoc.Kind(I) = '00' then
            Inc(Bills);
          FUsed[I] := True;
          Inc(I);
        end;
        Break;
      end;
      if K = '01' then
      begin
        FUsed[I] := True;
        MapHeader01(I);
        Inc(I);
      end
      else if K = '02' then
        MapProject(I)
      else if (K = '03') or (K = '04') then
      begin
        FUsed[I] := True;
        if K = '03' then
        begin
          FG.Award.OWN.Present := True;
          MapParty(I, FG.Award.OWN.Address, 'OWN');
        end
        else
        begin
          FG.Award.CTR.Present := True;
          MapParty(I, FG.Award.CTR.Address, 'CTR');
        end;
        Inc(I);
      end
      else if K = '06' then
      begin
        FUsed[I] := True;
        MapComponents(I);
        Inc(I);
      end
      else if K = '08' then
      begin
        FUsed[I] := True;
        MapCurrency(I);
        Inc(I);
      end
      else if K = '11' then
      begin
        if FHasLots and (FCurLot = '') then
          Inc(FOutsideLot);
        MapGroup(I);
      end
      else if K = '31' then
      begin
        FUsed[I] := True;
        Inc(I);
      end
      else if K = '32' then
      begin
        MapGroupTotals(I);
        Inc(I);
      end
      else if K = '20' then
        MapRemark(I)
      else if (K = '21') or (K = '23') then
      begin
        if FHasLots and (FCurLot = '') then
          Inc(FOutsideLot);
        MapItem(I);
      end
      else if K = '99' then
      begin
        MapClosing(I);
        FInBill := False;
        Inc(I);
      end
      else if K = '41' then
        MapPerf(I)
      else if K = '10' then
      begin
        MapLot(I);
        Inc(I);
      end
      else if K = '33' then
      begin
        MapLotEnd(I);
        Inc(I);
      end
      else if K = '34' then
      begin
        MapLotGroup(I);
        Inc(I);
      end
      else if K = '35' then
      begin
        MapLotGroupLots(I);
        Inc(I);
      end
      else if (K = '45') or (K = '46') or (K = '47') then
      begin
        MapWage(I);
        Inc(I);
      end
      else if (K = 'T0') or (K = 'T1') or (K = 'T9') then
      begin
        if K = 'T9' then
        begin
          { a T9 without its block }
          FUsed[I] := True;
          Inc(I);
        end
        else
          MapContract(I);
      end
      else if InList(K, NotMappedKinds) then
        SkipBlock(I, '|')
      else if InList(K, '|12|22|24|25|26|27|28|30|42|79|') then
      begin
        FOrphans.Add(K);
        FUsed[I] := True;
        Inc(I);
      end
      else
      begin
        { vendor (75/76 of WEKA), free (70 to 89) and undefined record types }
        if IsDigits(W(K)) then
        begin
          Lo := StrToInt(K);
          if (Lo >= 70) and (Lo <= 89) then
            FSkipped.Add(K + ' (free record type)')
          else
            FSkipped.Add(K);
        end
        else
          FSkipped.Add('record type that is no number');
        FUsed[I] := True;
        Inc(I);
      end;
    end;
    { other records before the opening record }
    for I := 0 to Header - 1 do
      if not FUsed[I] then
      begin
        FOrphans.Add(FDoc.Kind(I) + ' before 00');
        FUsed[I] := True;
      end;
    ResolveRefs;
    if FG.Award.WgChange.Present then
      FinishWage;
    AddBreakdown;
    FillRequired;

    if Bills > 0 then
      Report(-1, RuleSecondBill, gsWarning, IntToStr(Bills) + ' further bill(s) (00) in the file; not read');
    ReportCounts(FNotMapped, RuleNotMapped, gsInformation, 'record(s) not mapped');
    ReportCounts(FSkipped, RuleSkipped, gsInformation, 'record(s) skipped (not defined by GAEB 90)');
    ReportCounts(FFields, RuleFields, gsInformation, 'value(s) not mapped');
    ReportCounts(FValues, RuleValue, gsWarning, 'value(s) outside GAEB 90; not mapped');
    ReportCounts(FBadNumbers, RuleNumber, gsWarning, 'number(s) that are no digits; left out');
    ReportCounts(FOrphans, RuleOrphan, gsWarning, 'record(s) without the record they belong to; left out');
    ReportCounts(FDates, RuleDate, gsWarning, 'date(s) or time(s) in another form; left out');
    ReportCounts(FLimits, RuleLimits, gsWarning, 'text(s) with more lines than GAEB 90 allows; kept');
    if FPadded > 0 then
      Report(-1, RuleNumber, gsInformation, IntToStr(FPadded) +
        ' number(s) with spaces instead of leading zeros; read');
    if FDerived > 0 then
      Report(-1, RuleDerived, gsInformation, IntToStr(FDerived) +
        ' categor(y/ies) without record 11, derived from the ordinal numbers');
    if FMixed > 0 then
      Report(-1, RuleLevels, gsError, IntToStr(FMixed) + ' time(s) categories and items on one level');
    if FNumberProblems > 0 then
      Report(-1, RuleNumbers, gsWarning, IntToStr(FNumberProblems) +
        ' ordinal number(s) with an empty level above a filled one or without an item number');
    if FMarkProblems > 0 then
      Report(-1, RuleMarks, gsWarning, IntToStr(FMarkProblems) +
        ' text complement(s) without exactly two apostrophes; their text is kept as text');
    if FTekz > 0 then
      Report(-1, RuleTekz, gsWarning, IntToStr(FTekz) +
        ' text line(s) with TEKZ other than A or B, or KNR and TEKZ not set together; kept as text');
    if FMarkupValues > 0 then
      Report(-1, RuleMarkup, gsError, IntToStr(FMarkupValues) +
        ' position(s) with ZUSCHLAG other than space, E or Z; read as space');
    if FBadKinds > 0 then
      Report(-1, RuleKind, gsError, IntToStr(FBadKinds) +
        ' position(s) whose POSART1/POSART2/POSTYP is none of the 16 combinations');
    if FOldNotes > 0 then
      Report(-1, RuleKind, gsWarning, IntToStr(FOldNotes) +
        ' position(s) NNH (edition 1985: a note text); read as remark');
    if FStatus > 0 then
      Report(-1, RuleStatus, gsWarning, IntToStr(FStatus) +
        ' position(s) with POSSTAT other than R or space; not mapped');
    if FControl > 0 then
      Report(-1, RuleControl, gsWarning, IntToStr(FControl) + ' control character(s) removed (not allowed in XML)');
    if FUnresolved > 0 then
      Report(-1, RuleReference, gsWarning, IntToStr(FUnresolved) +
        ' reference(s) (28, 35, 45) to a number not in the file; left out');
    if FRefKind > 0 then
      Report(-1, RuleRefKind, gsError, IntToStr(FRefKind) +
        ' position(s) whose WIEVOR does not fit the reference of their 28');
    if FKurzan > 0 then
      Report(-1, RuleKurzan, gsInformation, IntToStr(FKurzan) +
        ' KURZAN of 28 other than the first line of the short text; the short text kept');
    if FIncompleteStlb > 0 then
      Report(-1, RuleValue, gsWarning, IntToStr(FIncompleteStlb) +
        ' STLB-Bau key(s) (79) without catalogue name or TLG; left out');
    if FIncompletePerf > 0 then
      Report(-1, RuleOrphan, gsWarning, IntToStr(FIncompletePerf) +
        ' execution description(s) (41) without AUSNR, AUSBEZ or text, which PerfDescr requires; kept');
    if FOutsideLot > 0 then
      Report(-1, RuleLots, gsError, IntToStr(FOutsideLot) +
        ' group(s) or position(s) outside any lot in a file with lots');
    if FLotTwice > 0 then
      Report(-1, RuleLots, gsError, IntToStr(FLotTwice) +
        ' lot or lot group number(s) used a second time; references go to the first');
    if FDiscountLost > 0 then
      Report(-1, RuleDiscount, gsWarning, IntToStr(FDiscountLost) +
        ' discount(s), cash discount(s) or wage change text(s) the model cannot carry as they are; ' +
        'left out or cut');
    if FContractInside > 0 then
      Report(-1, RuleContractInside, gsWarning, IntToStr(FContractInside) +
        ' block(s) of contract terms (T0 to T9) inside the bill; read as Award/AddText');
  except
    FG.Free;
    raise;
  end;
  Result := FG;
end;

function LandrixGaebDA90Map(ADocument: TLandrixGaebDA90Document;
  ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  M: TMapper;
begin
  M := TMapper.Create;
  try
    Result := M.Map(ADocument, ADiagnostics, AInvalidTotals, ATarget);
  finally
    M.Free;
  end;
end;

function SizeLimit(AMaxSize: Int64): Int64;
begin
  Result := AMaxSize;
  if Result <= 0 then
    Result := LandrixGaebDefaultMaxSize;
  if Result > MaxInt then
    Result := MaxInt;
end;

procedure CheckSize(ASize, AMaxSize: Int64);
begin
  if ASize > SizeLimit(AMaxSize) then
    raise ELandrixGaebError.Create('input of ' + IntToStr(ASize) +
      ' bytes exceeds the size limit of ' + IntToStr(SizeLimit(AMaxSize)) + ' bytes');
end;

function LandrixGaebDA90ReadMapped(Buffer: Pointer; Size: Integer; AMaxSize: Int64;
  ACharset: TLandrixGaebCharset; AOemCodePage: TLandrixGaebCodePage;
  ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out AItemsWithoutKind: Integer; out ADetection: TLandrixGaebDetection;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Own: TLandrixGaebDiagnostics;
  I: TLandrixGaebListIndex;
  D: TLandrixGaebDiagnostic;
  Msg: string;
  Doc: TLandrixGaebDA90Document;
  M: TMapper;
  K: Integer;

  function TwoDigits(const S: TLandrixGaebString): string;
  begin
    Result := '';
    if (Length(S) = 2) and IsDigits(S) then
      Result := AsciiOf(S);
  end;

begin
  AItemsWithoutKind := 0;
  CheckSize(Size, AMaxSize);
  Own := TLandrixGaebDiagnostics.Create;
  try
    ADetection := LandrixGaebDetectBuffer(Buffer, Size, False, Own);
    if not ADetection.Accepted or (ADetection.Format <> gfDA90) then
    begin
      { the rule only: messages of the detection may name values of the
        input }
      Msg := 'input is not a readable GAEB 90 file';
      for I := 0 to Own.Count - 1 do
        if Own[I].Severity >= gsError then
        begin
          Msg := Msg + ' (' + Own[I].RuleId + ')';
          Break;
        end;
      raise ELandrixGaebError.Create(Msg);
    end;
    { record 00 is taken from the records below, as the mapping takes it:
      the detection only looks at the bytes }
    if ADiagnostics <> nil then
      for I := 0 to Own.Count - 1 do
      begin
        D := Own[I];
        if D.RuleId <> 'GAEB-DET-016' then
          ADiagnostics.AddAt(D.RuleId, D.Severity, D.Path, D.Line, D.Column, D.Offset, D.Message);
      end;
  finally
    Own.Free;
  end;
  Doc := LandrixGaebDA90Parse(Buffer, Size, ACharset, AOemCodePage, ADiagnostics);
  try
    ADetection.SourcePhase := '';
    ADetection.SourceVersion := '';
    for K := 0 to Doc.Count - 1 do
      if Doc.Kind(K) = '00' then
      begin
        ADetection.SourcePhase := TwoDigits(Doc.Field(K, 11, 12));
        ADetection.SourceVersion := TwoDigits(Doc.Field(K, 72, 73));
        Break;
      end;
    M := TMapper.Create;
    try
      Result := M.Map(Doc, ADiagnostics, AInvalidTotals, ATarget);
      AItemsWithoutKind := M.ItemsWithoutKind;
    finally
      M.Free;
    end;
  finally
    Doc.Free;
  end;
end;

function LandrixGaebDA90ReadMappedStream(AStream: TStream; AMaxSize: Int64;
  ACharset: TLandrixGaebCharset; AOemCodePage: TLandrixGaebCodePage;
  ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out AItemsWithoutKind: Integer; out ADetection: TLandrixGaebDetection;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Remaining: Int64;
  Buffer: AnsiString;
  Count: Integer;
begin
  Remaining := AStream.Size - AStream.Position;
  CheckSize(Remaining, AMaxSize);
  Count := Integer(Remaining);
  Buffer := '';
  SetLength(Buffer, Count);
  if Count > 0 then
    AStream.ReadBuffer(Buffer[1], Count);
  Result := LandrixGaebDA90ReadMapped(Pointer(Buffer), Count, AMaxSize, ACharset, AOemCodePage,
    ADiagnostics, AInvalidTotals, AItemsWithoutKind, ADetection, ATarget);
end;

end.

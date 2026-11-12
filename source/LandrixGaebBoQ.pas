{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Business facade over the syntax model of a GAEB DA XML document: the bill
  of quantities as a tree of categories, items, markup items, remarks and
  execution descriptions, with ordinal numbers (OZ), quantities, prices,
  kinds of items, parties and texts. The facade keeps no copy of the data:
  every value is read from and written into the syntax model
  (LandrixGaebXmlModel), which stays the complete source. Reading through
  the facade changes nothing the writer writes or a HasX function of the
  model reports; a setter changes only the value it names.

  LoadFromFile and LoadFromStream read a document into a new bill;
  SaveToFile and SaveToStream write it for Target with WriteOptions.

  The views are built by the constructor and by Refresh. AddCategory,
  AddItem and Remove change model and views together; all other views stay
  valid. A structural change made in the syntax model behind the facade
  needs Refresh, which frees all earlier views.

  DE: Fachliche Fassade ueber dem Syntaxmodell eines GAEB-DA-XML-Dokuments:
  das Leistungsverzeichnis als Baum aus Bereichen, Positionen,
  Zuschlagspositionen, Bemerkungen und Ausfuehrungsbeschreibungen mit
  Ordnungszahlen (OZ), Mengen, Preisen, Positionsarten, Parteien und Texten.
  Die Fassade haelt keine Kopie der Daten: jeder Wert wird aus dem
  Syntaxmodell (LandrixGaebXmlModel) gelesen und in es geschrieben, das die
  vollstaendige Quelle bleibt. Lesen ueber die Fassade aendert nichts von
  dem, was der Schreiber schreibt oder eine HasX-Funktion des Modells
  meldet; ein Setter aendert nur den Wert, den er nennt.

  LoadFromFile und LoadFromStream lesen ein Dokument in ein neues LV;
  SaveToFile und SaveToStream schreiben es fuer Target mit WriteOptions.

  Die Sichten entstehen im Konstruktor und durch Refresh. AddCategory,
  AddItem und Remove aendern Modell und Sichten zusammen; alle anderen
  Sichten bleiben gueltig. Eine Strukturaenderung im Syntaxmodell an der
  Fassade vorbei braucht Refresh; Refresh gibt alle frueheren Sichten
  frei. }

{ API: internal. May change in any release before 1.0 (becomes stable with
  the API review of phase 4).
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern (wird
  mit dem API-Review der Phase 4 stabil). }

unit LandrixGaebBoQ;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebXmlBase,
  LandrixGaebXmlModel,
  LandrixGaebXmlWriteBase;

type
  { Kind of a node of the bill. DE: Art eines Knotens des LV. }
  TLandrixGaebNodeKind = (gnkCategory, gnkItem, gnkMarkupItem, gnkRemark, gnkPerfDescr);

  { A set of node kinds. DE: Eine Menge von Knotenarten. }
  TLandrixGaebNodeKinds = set of TLandrixGaebNodeKind;

  { Whether a node enters the totals of its parent. gcsUnknown: the
    document does not say (a bid X84 does not carry the kinds of the
    request; a node with Accepted, for which the documentation gives no
    rule).
    DE: Ob ein Knoten in die Summe seines Elternknotens eingeht.
    gcsUnknown: das Dokument sagt es nicht (ein Angebot X84 traegt die
    Kennzeichen der Anfrage nicht; ein Knoten mit Accepted, fuer den die
    Dokumentation keine Regel gibt). }
  TLandrixGaebCountStatus = (gcsCounts, gcsNotCounted, gcsUnknown);

  { Eventual item (Provis). gpvUnrecognized: a value the schema does not
    know (faulty file). DE: Bedarfsposition (Provis). gpvUnrecognized: ein
    Wert, den das Schema nicht kennt (fehlerhafte Datei). }
  TLandrixGaebProvisional = (gpvNone, gpvWithTotal, gpvWithoutTotal, gpvUnrecognized);

  { Kind of a text complement (Kind). DE: Art einer Textergaenzung (Kind). }
  TLandrixGaebComplementKind = (gckOwner, gckBidder, gckUnrecognized);

  { Result of a search by OZ. DE: Ergebnis einer Suche nach OZ. }
  TLandrixGaebFindResult = (gfrNotFound, gfrFound, gfrAmbiguous);

  { Role of the description of an item (RefDescr): a reference description
    that other items repeat, a repetition of one, or neither.
    gdrUnrecognized: a value the schema does not know.
    DE: Rolle der Beschreibung einer Position (RefDescr): eine
    Bezugsbeschreibung, die andere Positionen wiederholen, eine
    Wiederholung davon oder keines von beiden. gdrUnrecognized: ein Wert,
    den das Schema nicht kennt. }
  TLandrixGaebDescriptionRole = (gdrNormal, gdrReference, gdrRepetition, gdrUnrecognized);

  { Resolution of a reference by IDRef: no reference, resolved, no element
    of the bill (BoQ and everything in it) has that ID, the element has
    another kind than the reference asks for, or several elements have the
    ID (a faulty file).
    DE: Aufloesung eines Bezugs ueber IDRef: kein Bezug, aufgeloest, kein
    Element des LV (BoQ und alles darin) hat diese ID, das Element hat eine
    andere Art, als der Bezug verlangt, oder mehrere Elemente haben die ID
    (eine fehlerhafte Datei). }
  TLandrixGaebRefStatus = (grsAbsent, grsResolved, grsNotFound, grsWrongKind, grsAmbiguous);

  { Kind of a breakdown level (BoQBkdn/Type): lot, category level, item,
    index. DE: Art einer Gliederungsstufe (BoQBkdn/Type): Los,
    Bereichsstufe, Position, Index. }
  TLandrixGaebBreakdownKind = (gbkLot, gbkLevel, gbkItem, gbkIndex, gbkUnrecognized);

  { A value of a totals block (Totals), named as the element.
    DE: Ein Wert eines Summenblocks (Totals), benannt wie das Element. }
  TLandrixGaebTotalField = (gtfTotal, gtfDiscountPcnt, gtfDiscountAmt, gtfTotAfterDisc, gtfTotalLSUM, gtfVAT,
    gtfTotalNet, gtfVATAmount, gtfTotalGross);

  { Role of a party: owner (OWN), contractor (CTR), requester (Requester).
    DE: Rolle einer Partei: Auftraggeber (OWN), Auftragnehmer (CTR),
    Bedarfstraeger (Requester). }
  TLandrixGaebPartyRole = (gprOwner, gprContractor, gprRequester);

  TLandrixGaebBillOfQuantities = class;
  TLandrixGaebCategory = class;
  TLandrixGaebNode = class;
  TLandrixGaebItem = class;

  { A reference: status, the IDRef as written and the node it resolves to
    (nil unless Status is grsResolved).
    DE: Ein Bezug: Status, die IDRef wie geschrieben und der Knoten, auf
    den sie verweist (nil, ausser Status ist grsResolved). }
  TLandrixGaebReference = record
    { Resolution. DE: Aufloesung. }
    Status: TLandrixGaebRefStatus;
    { The IDRef as written. DE: Die IDRef wie geschrieben. }
    IDRef: TLandrixGaebString;
    { The node referred to. DE: Der Knoten, auf den verwiesen wird. }
    Node: TLandrixGaebNode;
  end;

  { A breakdown level (BoQBkdn). DE: Eine Gliederungsstufe (BoQBkdn). }
  TLandrixGaebBreakdown = record
    { Kind (Type). DE: Art (Type). }
    Kind: TLandrixGaebBreakdownKind;
    { Label (LblBoQBkdn). DE: Bezeichnung (LblBoQBkdn). }
    Lbl: TLandrixGaebString;
    { Number of characters (Length), -1 if not a number. DE: Anzahl der
      Zeichen (Length), -1, wenn keine Zahl. }
    Length: Integer;
    { Num = Yes: the parts are numbers. DE: Num = Yes: die Teile sind
      Zahlen. }
    Numeric: Boolean;
    { Alignment ('Left', 'Right' or ''). DE: Ausrichtung ('Left', 'Right'
      oder ''). }
    Alignment: TLandrixGaebString;
  end;

  { An assignment to a catalogue (CtlgAssign). DE: Eine Zuordnung zu einem
    Katalog (CtlgAssign). }
  TLandrixGaebCatalogRef = record
    { CtlgID. DE: CtlgID. }
    CatalogID: TLandrixGaebString;
    { CtlgCode. DE: CtlgCode. }
    Code: TLandrixGaebString;
  end;

  { A VAT part of a totals block (VATPart). DE: Ein Umsatzsteueranteil
    eines Summenblocks (VATPart). }
  TLandrixGaebVATPart = record
    { TotalNetPart. DE: TotalNetPart. }
    TotalNet: TLandrixGaebDecimal;
    { VATAmount. DE: VATAmount. }
    VATAmount: TLandrixGaebDecimal;
    { VATPcnt. DE: VATPcnt. }
    VATPcnt: TLandrixGaebDecimal;
  end;

  { A partial quantity of an item (QtySplit): a quantity or a percentage.
    DE: Eine Teilmenge einer Position (QtySplit): eine Menge oder ein
    Prozentsatz. }
  TLandrixGaebQtySplit = record
    { Qty. DE: Qty. }
    Qty: TLandrixGaebDecimal;
    { QtyPcnt. DE: QtyPcnt. }
    QtyPcnt: TLandrixGaebDecimal;
  end;

  { Kind of a text event. Later releases may add kinds: handle unknown
    kinds in an else branch.
    DE: Art eines Textereignisses. Spaetere Versionen koennen Arten
    ergaenzen: unbekannte Arten in einem else-Zweig behandeln. }
  TLandrixGaebTextEventKind = (gteText, gteBeginParagraph, gteEndParagraph, gteLineBreak, gteBeginList,
    gteBeginListItem, gteEndListItem, gteEndList, gteBeginTable, gteBeginRow, gteBeginCell, gteEndCell,
    gteEndRow, gteEndTable, gteImage, gteComplement);

  { One part of a text: character data (gteText, Text), the start or end of
    a paragraph or block (p, div), a line break (br), a list (ul, ol;
    Ordered) and its entries (li), a table, its rows and cells (td, th;
    Header), an image or a text complement (Node: TLandrixGaebXmlImage or
    TLandrixGaebXmlTextComplement; the parts of a complement are not
    visited).
    DE: Ein Teil eines Textes: Zeichendaten (gteText, Text), Anfang oder
    Ende eines Absatzes oder Blocks (p, div), ein Zeilenumbruch (br), eine
    Liste (ul, ol; Ordered) und ihre Eintraege (li), eine Tabelle, ihre
    Zeilen und Zellen (td, th; Header), ein Bild oder eine Textergaenzung
    (Node: TLandrixGaebXmlImage oder TLandrixGaebXmlTextComplement; die
    Teile einer Ergaenzung werden nicht besucht). }
  TLandrixGaebTextEvent = record
    { Kind of the event. DE: Art des Ereignisses. }
    Kind: TLandrixGaebTextEventKind;
    { Character data (gteText). DE: Zeichendaten (gteText). }
    Text: TLandrixGaebString;
    { gteBeginList: ordered list (ol). DE: gteBeginList: nummerierte Liste
      (ol). }
    Ordered: Boolean;
    { gteBeginCell: header cell (th). DE: gteBeginCell: Kopfzelle (th). }
    Header: Boolean;
    { The element of the syntax model the event stands for. DE: Das Element
      des Syntaxmodells, fuer das das Ereignis steht. }
    Node: TLandrixGaebXmlNode;
  end;

  { Receives the parts of a text in document order
    (LandrixGaebVisitText). DE: Erhaelt die Teile eines Textes in
    Dokumentreihenfolge (LandrixGaebVisitText). }
  TLandrixGaebTextVisitor = class(TObject)
  public
    { One part of the text. DE: Ein Teil des Textes. }
    procedure Visit(const AEvent: TLandrixGaebTextEvent); virtual; abstract;
  end;

  { A text complement of a long or outline text: number (MarkLbl), kind,
    caption, body and tail.
    DE: Eine Textergaenzung eines Lang- oder Kurztextes: Nummer (MarkLbl),
    Art, Ueberschrift, Inhalt und Abschluss. }
  TLandrixGaebTextComplement = class(TObject)
  private
    FSyntaxNode: TLandrixGaebXmlTextComplement;
    function GetKind: TLandrixGaebComplementKind;
  public
    { A view of ASyntaxNode. DE: Eine Sicht auf ASyntaxNode. }
    constructor Create(ASyntaxNode: TLandrixGaebXmlTextComplement);
    { The element of the syntax model. DE: Das Element des Syntaxmodells. }
    property SyntaxNode: TLandrixGaebXmlTextComplement read FSyntaxNode;
    { MarkLbl. DE: MarkLbl. }
    function MarkLbl: TLandrixGaebString;
    { Owner or bidder. DE: Auftraggeber oder Bieter. }
    property Kind: TLandrixGaebComplementKind read GetKind;
    { True if marked Empty="Yes" (to be filled in). DE: True, wenn mit
      Empty="Yes" markiert (auszufuellen). }
    function IsEmptyMarked: Boolean;
    { The body asks for a decimal (ComplBodyDec) or an integer
      (ComplBodyInt). DE: Der Inhalt verlangt eine Dezimalzahl
      (ComplBodyDec) oder eine Ganzzahl (ComplBodyInt). }
    function WantsDecimal: Boolean;
    function WantsInteger: Boolean;
    { Plain texts of caption, body and tail ('' if absent).
      DE: Klartexte von Ueberschrift, Inhalt und Abschluss ('' wenn nicht
      vorhanden). }
    function CaptionText: TLandrixGaebString;
    function BodyText: TLandrixGaebString;
    function TailText: TLandrixGaebString;
    { Replaces the body by one paragraph with AText and removes Empty;
      caption and tail stay. Only for a bidder's complement without a
      numeric body (else ELandrixGaebError; see SetBodyNumber).
      DE: Ersetzt den Inhalt durch einen Absatz mit AText und entfernt
      Empty; Ueberschrift und Abschluss bleiben. Nur fuer eine
      Bieterergaenzung ohne Zahlenwert (sonst ELandrixGaebError; siehe
      SetBodyNumber). }
    procedure SetBodyText(const AText: TLandrixGaebString);
    { Sets the number of a bidder's complement with ComplBodyDec or
      ComplBodyInt and repeats it as the body text; removes Empty.
      ELandrixGaebError if the complement asks for no number, is no
      bidder's complement or AText is no decimal (no integer).
      DE: Setzt die Zahl einer Bieterergaenzung mit ComplBodyDec oder
      ComplBodyInt und wiederholt sie als Inhaltstext; entfernt Empty.
      ELandrixGaebError, wenn die Ergaenzung keine Zahl verlangt, keine
      Bieterergaenzung ist oder AText keine Dezimalzahl (Ganzzahl) ist. }
    procedure SetBodyNumber(const AText: TLandrixGaebString);
  end;

  { A totals block (Totals) of the bill, a category or a lot group. Reading
    an absent block gives no values; SetValue creates it.
    DE: Ein Summenblock (Totals) des LV, eines Bereichs oder einer
    Losgruppe. Lesen eines fehlenden Blocks liefert keine Werte; SetValue
    legt ihn an. }
  TLandrixGaebTotals = class(TObject)
  private
    FBill: TLandrixGaebBillOfQuantities;
    FOwner: TLandrixGaebXmlNode;
    function Ensure: TLandrixGaebXmlTotals;
  public
    { The totals of AOwner (TLandrixGaebXmlBoQCtgy or
      TLandrixGaebXmlLotGrp), with nil those of the bill (BoQInfo).
      DE: Die Summen von AOwner (TLandrixGaebXmlBoQCtgy oder
      TLandrixGaebXmlLotGrp), mit nil die des LV (BoQInfo). }
    constructor Create(ABill: TLandrixGaebBillOfQuantities; AOwner: TLandrixGaebXmlNode);
    { The element of the syntax model, nil if absent. DE: Das Element des
      Syntaxmodells, nil, wenn nicht vorhanden. }
    function SyntaxNode: TLandrixGaebXmlTotals;
    { True if the block is in the document. DE: True, wenn der Block im
      Dokument steht. }
    function Exists: Boolean;
    { Value AField; no value if absent. DE: Wert AField; ohne Wert, wenn
      nicht vorhanden. }
    function Value(AField: TLandrixGaebTotalField): TLandrixGaebDecimal;
    { Sets value AField (creates the block). DE: Setzt Wert AField (legt
      den Block an). }
    procedure SetValue(AField: TLandrixGaebTotalField; const AValue: TLandrixGaebDecimal);
    { Removes value AField (an absent block stays absent). DE: Entfernt
      Wert AField (ein fehlender Block bleibt fehlend). }
    procedure ClearValue(AField: TLandrixGaebTotalField);
    { The amount that counts: TotAfterDisc, else TotalLSUM, else Total.
      DE: Der Betrag, der zaehlt: TotAfterDisc, sonst TotalLSUM, sonst
      Total. }
    function Amount: TLandrixGaebDecimal;
    { Net total of unit price component 1 to 6 (TotalNetUpComp).
      DE: Nettosumme des EP-Anteils 1 bis 6 (TotalNetUpComp). }
    function UPCompTotal(ANumber: Integer): TLandrixGaebDecimal;
    { VAT parts (VATPart) in document order. DE: Umsatzsteueranteile
      (VATPart) in Dokumentreihenfolge. }
    function VATPartCount: Integer;
    function VATParts(AIndex: Integer): TLandrixGaebVATPart;
  end;

  { A node of the bill (category, item, markup item, remark, execution
    description). Owned by the bill; valid until Refresh or the bill is
    freed.
    DE: Ein Knoten des LV (Bereich, Position, Zuschlagsposition,
    Bemerkung, Ausfuehrungsbeschreibung). Im Besitz des LV; gueltig bis
    Refresh oder bis das LV freigegeben wird. }
  TLandrixGaebNode = class(TObject)
  private
    FBill: TLandrixGaebBillOfQuantities;
    FKind: TLandrixGaebNodeKind;
    FParent: TLandrixGaebCategory;
    FSyntaxNode: TLandrixGaebXmlNode;
    FTreeNode: TObject;
    FComplements: TObjectList;
    function GetPath: TLandrixGaebString;
    function GetOZ: TLandrixGaebString;
    function GetIndex: TLandrixGaebString;
  protected
    { The complete text and the outline text of the node (nil if absent).
      DE: Vollstaendiger Text und Kurztext des Knotens (nil, wenn nicht
      vorhanden). }
    procedure GetTexts(out AComplete: TLandrixGaebXmlCompleteText; out AOutline: TLandrixGaebXmlOutlineText); virtual;
  public
    { Created by the bill only. DE: Nur vom LV angelegt. }
    constructor Create(ABill: TLandrixGaebBillOfQuantities; AKind: TLandrixGaebNodeKind;
      AParent: TLandrixGaebCategory; ASyntaxNode: TLandrixGaebXmlNode; ATreeNode: TObject);
    { Frees the view, never the element of the model. DE: Gibt die Sicht
      frei, nie das Element des Modells. }
    destructor Destroy; override;
    { The bill. DE: Das LV. }
    property Bill: TLandrixGaebBillOfQuantities read FBill;
    { Kind of the node. DE: Art des Knotens. }
    property Kind: TLandrixGaebNodeKind read FKind;
    { Enclosing category, nil at top level. DE: Umgebender Bereich, nil auf
      oberster Ebene. }
    property Parent: TLandrixGaebCategory read FParent;
    { The element of the syntax model. DE: Das Element des Syntaxmodells. }
    property SyntaxNode: TLandrixGaebXmlNode read FSyntaxNode;
    { Path of the element (as in diagnostics). DE: Pfad des Elements (wie in
      Meldungen). }
    property Path: TLandrixGaebString read GetPath;
    { OZ: the RNoPart of every enclosing category and the own one joined
      with '.', as written in the document ('' for remarks and execution
      descriptions). DE: OZ: RNoPart aller umgebenden Bereiche und der
      eigene mit '.' verbunden, wie im Dokument geschrieben ('' bei
      Bemerkungen und Ausfuehrungsbeschreibungen). }
    property OZ: TLandrixGaebString read GetOZ;
    { RNoIndex of an item or markup item. DE: RNoIndex einer Position oder
      Zuschlagsposition. }
    property Index: TLandrixGaebString read GetIndex;
    { Plain text of the outline text (short text) and of the detail text
      (long text); for display only, not a format to parse.
      DE: Klartext des Kurztextes und des Langtextes; nur zur Anzeige, kein
      Format zum Einlesen. }
    function ShortText: TLandrixGaebString;
    function LongText: TLandrixGaebString;
    { The text elements to visit (nil if absent). DE: Die Textelemente zum
      Besuchen (nil, wenn nicht vorhanden). }
    function DetailTextNode: TLandrixGaebXmlNode;
    function OutlineTextNode: TLandrixGaebXmlNode;
    { Text complements of long and outline text in document order.
      DE: Textergaenzungen von Lang- und Kurztext in Dokumentreihenfolge. }
    function ComplementCount: Integer;
    function Complements(AIndex: Integer): TLandrixGaebTextComplement;
    { Reference to the reference description an item or markup item
      repeats (RefRNo, to an item) and to an execution description
      (RefPerfNo); grsAbsent for other nodes.
      DE: Bezug auf die Bezugsbeschreibung, die eine Position oder
      Zuschlagsposition wiederholt (RefRNo, auf eine Position), und auf
      eine Ausfuehrungsbeschreibung (RefPerfNo); grsAbsent bei anderen
      Knoten. }
    function RefRNo: TLandrixGaebReference;
    function RefPerfNo: TLandrixGaebReference;
    { Catalogue assignments (CtlgAssign) in document order. DE:
      Katalogzuordnungen (CtlgAssign) in Dokumentreihenfolge. }
    function CatalogCount: Integer;
    function Catalogs(AIndex: Integer): TLandrixGaebCatalogRef;
  end;

  { Nodes in document order (not owning). DE: Knoten in
    Dokumentreihenfolge (ohne Besitz). }
  TLandrixGaebNodeList = class(TObject)
  private
    FList: TObjectList;
    function GetItem(AIndex: Integer): TLandrixGaebNode;
  public
    { An empty list. DE: Eine leere Liste. }
    constructor Create;
    { Frees the list, not the nodes. DE: Gibt die Liste frei, nicht die
      Knoten. }
    destructor Destroy; override;
    { Appends ANode (used by the bill). DE: Haengt ANode an (vom LV
      benutzt). }
    procedure Add(ANode: TLandrixGaebNode);
    { Number of nodes. DE: Anzahl der Knoten. }
    function Count: Integer;
    { Node AIndex (0-based). DE: Knoten AIndex (ab 0). }
    property Items[AIndex: Integer]: TLandrixGaebNode read GetItem; default;
  end;

  { A category (BoQCtgy): label, alternative and applicability marks,
    children in document order.
    DE: Ein Bereich (BoQCtgy): Bezeichnung, Kennzeichen fuer Alternative
    und Entfall, Kinder in Dokumentreihenfolge. }
  TLandrixGaebCategory = class(TLandrixGaebNode)
  private
    FChildren: TLandrixGaebNodeList;
    FTotals: TLandrixGaebTotals;
    function Ctgy: TLandrixGaebXmlBoQCtgy;
  public
    { Created by the bill only. DE: Nur vom LV angelegt. }
    constructor Create(ABill: TLandrixGaebBillOfQuantities; AParent: TLandrixGaebCategory;
      ASyntaxNode: TLandrixGaebXmlBoQCtgy; ATreeNode: TObject);
    { Frees the view, its child list and its totals view. DE: Gibt die
      Sicht, ihre Kinderliste und ihre Summensicht frei. }
    destructor Destroy; override;
    { Children: categories, execution descriptions, remarks, then items and
      markup items. DE: Kinder: Bereiche, Ausfuehrungsbeschreibungen,
      Bemerkungen, dann Positionen und Zuschlagspositionen. }
    property Children: TLandrixGaebNodeList read FChildren;
    { Plain text of the label (LblTx). DE: Klartext der Bezeichnung
      (LblTx). }
    function Lbl: TLandrixGaebString;
    { Replaces the label by one paragraph with AText. DE: Ersetzt die
      Bezeichnung durch einen Absatz mit AText. }
    procedure SetLbl(const AText: TLandrixGaebString);
    { Alternative category (ALNBGroupNo, ALNBSerNo other than 0).
      DE: Alternativbereich (ALNBGroupNo, ALNBSerNo ungleich 0). }
    function AlternativeGroup: TLandrixGaebString;
    function AlternativeSerial: TLandrixGaebString;
    function IsAlternative: Boolean;
    { NotApplBoQ. DE: NotApplBoQ. }
    function NotApplicable: Boolean;
    { Accepted (award). DE: Accepted (Auftrag). }
    function Accepted: TLandrixGaebString;
    { Total of the category (Totals.Amount: TotAfterDisc, else TotalLSUM,
      else Total); no value if absent. DE: Summe des Bereichs
      (Totals.Amount: TotAfterDisc, sonst TotalLSUM, sonst Total); ohne
      Wert, wenn nicht vorhanden. }
    function Total: TLandrixGaebDecimal;
    { The totals block of the category. DE: Der Summenblock des Bereichs. }
    property Totals: TLandrixGaebTotals read FTotals;
    { True for a lot: a top level category of a bill whose first breakdown
      level is Lot. DE: True fuer ein Los: ein Bereich der obersten Ebene
      eines LV, dessen erste Gliederungsstufe Lot ist. }
    function IsLot: Boolean;
    { Whether the category enters the totals of its parent. DE: Ob der
      Bereich in die Summe seines Elternknotens eingeht. }
    function CountStatus: TLandrixGaebCountStatus;
  end;

  { A sub description of an item (SubDescr): number, quantity, unit,
    prices and texts. Owned by its item.
    DE: Eine Unterbeschreibung einer Position (SubDescr): Nummer, Menge,
    Einheit, Preise und Texte. Im Besitz ihrer Position. }
  TLandrixGaebSubDescription = class(TObject)
  private
    FItem: TLandrixGaebItem;
    FSyntaxNode: TLandrixGaebXmlSubDescr;
    FPosition: Integer;
    function GetQU: TLandrixGaebString;
    procedure SetQU(const AValue: TLandrixGaebString);
  public
    { Created by the item only. DE: Nur von der Position angelegt. }
    constructor Create(AItem: TLandrixGaebItem; ASyntaxNode: TLandrixGaebXmlSubDescr; APosition: Integer);
    { The item. DE: Die Position. }
    property Item: TLandrixGaebItem read FItem;
    { The element of the syntax model. DE: Das Element des Syntaxmodells. }
    property SyntaxNode: TLandrixGaebXmlSubDescr read FSyntaxNode;
    { Path of the element. DE: Pfad des Elements. }
    function Path: TLandrixGaebString;
    { SubDNo. DE: SubDNo. }
    function Number: TLandrixGaebString;
    { QtyTBD = Yes. DE: QtyTBD = Yes. }
    function QtyTBD: Boolean;
    { Quantity. DE: Menge. }
    function Qty: TLandrixGaebDecimal;
    procedure SetQty(const AValue: TLandrixGaebDecimal);
    procedure ClearQty;
    { Unit. DE: Einheit. }
    property QU: TLandrixGaebString read GetQU write SetQU;
    { Unit price and its components 1 to 6. DE: Einheitspreis und seine
      Anteile 1 bis 6. }
    function UP: TLandrixGaebDecimal;
    procedure SetUP(const AValue: TLandrixGaebDecimal);
    procedure ClearUP;
    function UPComp(ANumber: Integer): TLandrixGaebDecimal;
    procedure SetUPComp(ANumber: Integer; const AValue: TLandrixGaebDecimal);
    procedure ClearUPComp(ANumber: Integer);
    { Texts as at TLandrixGaebNode. DE: Texte wie bei TLandrixGaebNode. }
    function ShortText: TLandrixGaebString;
    function LongText: TLandrixGaebString;
    function DetailTextNode: TLandrixGaebXmlNode;
    function OutlineTextNode: TLandrixGaebXmlNode;
  end;

  { An item: quantities, prices, kinds and texts. Decimal values are read
    by the functions and written by SetX/ClearX (a value of the function
    is a copy). Values are never rounded.
    DE: Eine Position: Mengen, Preise, Arten und Texte. Dezimalwerte
    werden ueber die Funktionen gelesen und mit SetX/ClearX geschrieben
    (ein Wert der Funktion ist eine Kopie). Werte werden nie gerundet. }
  TLandrixGaebItem = class(TLandrixGaebNode)
  private
    FSubDescriptions: TObjectList;
    function Item: TLandrixGaebXmlItem;
    function GetQU: TLandrixGaebString;
    procedure SetQU(const AValue: TLandrixGaebString);
  protected
    procedure GetTexts(out AComplete: TLandrixGaebXmlCompleteText; out AOutline: TLandrixGaebXmlOutlineText); override;
  public
    { Frees the view and its sub description views. DE: Gibt die Sicht und
      die Sichten ihrer Unterbeschreibungen frei. }
    destructor Destroy; override;
    { Quantity. DE: Menge. }
    function Qty: TLandrixGaebDecimal;
    procedure SetQty(const AValue: TLandrixGaebDecimal);
    procedure ClearQty;
    { Unit. DE: Einheit. }
    property QU: TLandrixGaebString read GetQU write SetQU;
    { Unit price. DE: Einheitspreis. }
    function UP: TLandrixGaebDecimal;
    procedure SetUP(const AValue: TLandrixGaebDecimal);
    procedure ClearUP;
    { Unit price components 1 to 6 (labels at the bill). DE: EP-Anteile 1
      bis 6 (Bezeichnungen am LV). }
    function UPComp(ANumber: Integer): TLandrixGaebDecimal;
    procedure SetUPComp(ANumber: Integer; const AValue: TLandrixGaebDecimal);
    procedure ClearUPComp(ANumber: Integer);
    { Discount in percent. DE: Nachlass in Prozent. }
    function DiscountPcnt: TLandrixGaebDecimal;
    procedure SetDiscountPcnt(const AValue: TLandrixGaebDecimal);
    procedure ClearDiscountPcnt;
    { Total of the item. DE: Gesamtbetrag der Position. }
    function IT: TLandrixGaebDecimal;
    procedure SetIT(const AValue: TLandrixGaebDecimal);
    procedure ClearIT;
    { Kinds: alternative (ALNGroupNo, ALNSerNo; base with serial 0),
      eventual (Provis), lump sum, hourly work, not applicable, not offered
      (X84), quantity to be determined by the bidder.
      DE: Arten: Alternative (ALNGroupNo, ALNSerNo; Grundposition mit
      Nummer 0), Bedarf (Provis), Pauschal, Stundenlohn, entfaellt, nicht
      angeboten (X84), Menge vom Bieter einzutragen. }
    function AlternativeGroup: TLandrixGaebString;
    function AlternativeSerial: TLandrixGaebString;
    function IsBase: Boolean;
    function IsAlternative: Boolean;
    function Provisional: TLandrixGaebProvisional;
    function IsLumpSum: Boolean;
    function HourIt: TLandrixGaebString;
    function NotApplicable: Boolean;
    function NotOffered: Boolean;
    procedure SetNotOffered(AValue: Boolean);
    function QtyTBD: Boolean;
    { Accepted (award), change order number and status, status in a variant
      bid. DE: Accepted (Auftrag), Nachtragsnummer und -status, Status im
      Nebenangebot. }
    function Accepted: TLandrixGaebString;
    function ChangeOrderNo: TLandrixGaebString;
    function ChangeOrderStatus: TLandrixGaebString;
    function AlterBidStatus: TLandrixGaebString;
    { Whether the item enters the totals of its category.
      DE: Ob die Position in die Summe ihres Bereichs eingeht. }
    function CountStatus: TLandrixGaebCountStatus;
    { Role of the description (RefDescr). DE: Rolle der Beschreibung
      (RefDescr). }
    function DescriptionRole: TLandrixGaebDescriptionRole;
    { Kind of a hold-out item (HoldOutType, '' if none) and the base items
      it refers to (RefBaseItem, to items).
      DE: Art einer Vorhalteposition (HoldOutType, '' wenn keine) und die
      Grundpositionen, auf die sie verweist (RefBaseItem, auf Positionen). }
    function HoldOutType: TLandrixGaebString;
    function RefBaseItemCount: Integer;
    function RefBaseItem(AIndex: Integer): TLandrixGaebReference;
    { Partial quantities (QtySplit) in document order. DE: Teilmengen
      (QtySplit) in Dokumentreihenfolge. }
    function QtySplitCount: Integer;
    function QtySplits(AIndex: Integer): TLandrixGaebQtySplit;
    { Comments of the bidder (BidComm) as text elements to visit.
      DE: Kommentare des Bieters (BidComm) als Textelemente zum Besuchen. }
    function BidCommentCount: Integer;
    function BidCommentNode(AIndex: Integer): TLandrixGaebXmlNode;
    { SumDescr = Yes: the sub descriptions carry the quantities.
      DE: SumDescr = Yes: die Unterbeschreibungen tragen die Mengen. }
    function IsSumDescription: Boolean;
    { Sub descriptions (SubDescr) in document order. DE:
      Unterbeschreibungen (SubDescr) in Dokumentreihenfolge. }
    function SubDescriptionCount: Integer;
    function SubDescriptions(AIndex: Integer): TLandrixGaebSubDescription;
  end;

  { A markup item: markup type, markup, base amount and total.
    DE: Eine Zuschlagsposition: Zuschlagsart, Zuschlag, Grundbetrag und
    Gesamtbetrag. }
  TLandrixGaebMarkupItem = class(TLandrixGaebNode)
  private
    function Markup: TLandrixGaebXmlMarkupItem;
  protected
    procedure GetTexts(out AComplete: TLandrixGaebXmlCompleteText; out AOutline: TLandrixGaebXmlOutlineText); override;
  public
    { MarkupType. DE: MarkupType. }
    function MarkupType: TLandrixGaebString;
    { Markup in percent, amount the markup applies to (ITMarkup), total.
      DE: Zuschlag in Prozent, Betrag, auf den er wirkt (ITMarkup),
      Gesamtbetrag. }
    function MarkupPcnt: TLandrixGaebDecimal;
    function ITMarkup: TLandrixGaebDecimal;
    function IT: TLandrixGaebDecimal;
    procedure SetMarkupPcnt(const AValue: TLandrixGaebDecimal);
    procedure SetITMarkup(const AValue: TLandrixGaebDecimal);
    procedure SetIT(const AValue: TLandrixGaebDecimal);
    { As at TLandrixGaebItem. DE: Wie bei TLandrixGaebItem. }
    function AlternativeSerial: TLandrixGaebString;
    function IsAlternative: Boolean;
    function NotApplicable: Boolean;
    function CountStatus: TLandrixGaebCountStatus;
  end;

  { A remark. DE: Eine Bemerkung. }
  TLandrixGaebRemark = class(TLandrixGaebNode)
  protected
    procedure GetTexts(out AComplete: TLandrixGaebXmlCompleteText; out AOutline: TLandrixGaebXmlOutlineText); override;
  end;

  { An execution description; texts of its first Description.
    DE: Eine Ausfuehrungsbeschreibung; Texte ihrer ersten Description. }
  TLandrixGaebPerfDescr = class(TLandrixGaebNode)
  protected
    procedure GetTexts(out AComplete: TLandrixGaebXmlCompleteText; out AOutline: TLandrixGaebXmlOutlineText); override;
  public
    { PerfNo and PerfLbl. DE: PerfNo und PerfLbl. }
    function PerfNo: TLandrixGaebString;
    function PerfLbl: TLandrixGaebString;
  end;

  { A lot group (LotGrp): number, the lots it groups and its totals.
    DE: Eine Losgruppe (LotGrp): Nummer, die Lose, die sie zusammenfasst,
    und ihre Summen. }
  TLandrixGaebLotGroup = class(TObject)
  private
    FBill: TLandrixGaebBillOfQuantities;
    FSyntaxNode: TLandrixGaebXmlLotGrp;
    FTotals: TLandrixGaebTotals;
  public
    { Created by the bill only. DE: Nur vom LV angelegt. }
    constructor Create(ABill: TLandrixGaebBillOfQuantities; ASyntaxNode: TLandrixGaebXmlLotGrp);
    { Frees the view and its totals view. DE: Gibt die Sicht und ihre
      Summensicht frei. }
    destructor Destroy; override;
    { The element of the syntax model. DE: Das Element des Syntaxmodells. }
    property SyntaxNode: TLandrixGaebXmlLotGrp read FSyntaxNode;
    { LotGrNo. DE: LotGrNo. }
    function Number: TLandrixGaebString;
    { The lots (RefLotNo, to categories). DE: Die Lose (RefLotNo, auf
      Bereiche). }
    function LotCount: Integer;
    function Lots(AIndex: Integer): TLandrixGaebReference;
    { The totals block. DE: Der Summenblock. }
    property Totals: TLandrixGaebTotals read FTotals;
  end;

  { A party (owner OWN, contractor CTR, requester Requester): its address
    and, for a requester, number and name. Reading an absent party gives
    ''; writing creates the owner or the contractor (a requester must
    exist).
    DE: Eine Partei (Auftraggeber OWN, Auftragnehmer CTR, Bedarfstraeger
    Requester): ihre Anschrift und bei einem Bedarfstraeger Nummer und
    Name. Lesen einer fehlenden Partei liefert ''; Schreiben legt
    Auftraggeber oder Auftragnehmer an (ein Bedarfstraeger muss
    existieren). }
  TLandrixGaebParty = class(TObject)
  private
    FBill: TLandrixGaebBillOfQuantities;
    FRole: TLandrixGaebPartyRole;
    FIndex: Integer;
    function Requester: TLandrixGaebXmlRequester;
    function Address(ACreate: Boolean): TLandrixGaebXmlAddress;
    function GetField(AIndex: Integer): TLandrixGaebString;
    procedure SetField(AIndex: Integer; const AValue: TLandrixGaebString);
  public
    { Party ARole of ABill; AIndex counts the requesters (from 0).
      DE: Partei ARole von ABill; AIndex zaehlt die Bedarfstraeger (ab
      0). }
    constructor Create(ABill: TLandrixGaebBillOfQuantities; ARole: TLandrixGaebPartyRole; AIndex: Integer);
    { Role. DE: Rolle. }
    property Role: TLandrixGaebPartyRole read FRole;
    { True if the party is in the document (for a requester: its
      address). DE: True, wenn die Partei im Dokument steht (bei einem
      Bedarfstraeger: seine Anschrift). }
    function Exists: Boolean;
    { Fields of the address (Address/Name1 ... VATID). DE: Felder der
      Anschrift (Address/Name1 ... VATID). }
    property Name1: TLandrixGaebString index 0 read GetField write SetField;
    property Name2: TLandrixGaebString index 1 read GetField write SetField;
    property Name3: TLandrixGaebString index 2 read GetField write SetField;
    property Name4: TLandrixGaebString index 3 read GetField write SetField;
    property Street: TLandrixGaebString index 4 read GetField write SetField;
    property PCode: TLandrixGaebString index 5 read GetField write SetField;
    property City: TLandrixGaebString index 6 read GetField write SetField;
    property Country: TLandrixGaebString index 7 read GetField write SetField;
    property Contact: TLandrixGaebString index 8 read GetField write SetField;
    property Phone: TLandrixGaebString index 9 read GetField write SetField;
    property Fax: TLandrixGaebString index 10 read GetField write SetField;
    property Email: TLandrixGaebString index 11 read GetField write SetField;
    property VATID: TLandrixGaebString index 12 read GetField write SetField;
    { Requester only: RequestIDNo and RequestName ('' for other roles,
      writing raises ELandrixGaebError).
      DE: Nur Bedarfstraeger: RequestIDNo und RequestName ('' bei anderen
      Rollen, Schreiben loest ELandrixGaebError aus). }
    property RequestIDNo: TLandrixGaebString index 13 read GetField write SetField;
    property RequestName: TLandrixGaebString index 14 read GetField write SetField;
  end;

  { The bill of quantities of a document (Award/BoQ) as a tree of views.
    DE: Das Leistungsverzeichnis eines Dokuments (Award/BoQ) als Baum von
    Sichten. }
  TLandrixGaebBillOfQuantities = class(TObject)
  private
    FDocument: TLandrixGaebXmlGAEB;
    FTarget: TLandrixGaebTarget;
    FOwnsDocument: Boolean;
    FTree: TObject;
    FNodes: TObjectList;
    FRoot: TLandrixGaebNodeList;
    FAllItems: TLandrixGaebNodeList;
    FOwner: TLandrixGaebParty;
    FContractor: TLandrixGaebParty;
    FTotals: TLandrixGaebTotals;
    FRequesters: TObjectList;
    FLotGroups: TObjectList;
    FIds: TObject;
    FOtherId: TObject;
    FWriteOptions: TLandrixGaebXmlWriteOptions;
    FNextId: Integer;
    procedure Build(ATree: TObject; AOld: TObjectList);
    procedure Rebuild;
    procedure ClearViews;
    function Body(AParent: TLandrixGaebCategory): TLandrixGaebXmlBoQBody;
    function NewId(const APrefix: TLandrixGaebString): TLandrixGaebString;
    function ViewOf(ASyntaxNode: TLandrixGaebXmlNode): TLandrixGaebNode;
    function GetProjectName: TLandrixGaebString;
    procedure SetProjectName(const AValue: TLandrixGaebString);
    function GetAwardField(AIndex: Integer): TLandrixGaebString;
    procedure SetAwardField(AIndex: Integer; const AValue: TLandrixGaebString);
    function Info: TLandrixGaebXmlBoQInfo;
    function Resolve(const AIDRef: TLandrixGaebString; AKinds: TLandrixGaebNodeKinds): TLandrixGaebReference;
  public
    { Wraps ADocument, read or written for ATarget. With AOwnsDocument the
      bill frees the document (also if the constructor fails).
      DE: Umhuellt ADocument, gelesen oder zu schreiben fuer ATarget. Mit
      AOwnsDocument gibt das LV das Dokument frei (auch wenn der
      Konstruktor scheitert). }
    constructor Create(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget;
      AOwnsDocument: Boolean);
    { Frees the views and, with AOwnsDocument, the document. DE: Gibt die
      Sichten und mit AOwnsDocument das Dokument frei. }
    destructor Destroy; override;
    { Rebuilds all views after a structural change in the syntax model;
      earlier views are freed. DE: Baut alle Sichten nach einer
      Strukturaenderung im Syntaxmodell neu auf; fruehere Sichten werden
      freigegeben. }
    procedure Refresh;
    { Appends a category with ARNoPart and the label ALbl to AParent (nil:
      top level) and gives it a new ID. ELandrixGaebError if AParent holds
      items (a category body holds categories or an item list, not both).
      DE: Haengt einen Bereich mit ARNoPart und der Bezeichnung ALbl an
      AParent an (nil: oberste Ebene) und gibt ihm eine neue ID.
      ELandrixGaebError, wenn AParent Positionen enthaelt (ein
      Bereichsinhalt hat Bereiche oder eine Positionsliste, nicht beides). }
    function AddCategory(AParent: TLandrixGaebCategory;
      const ARNoPart, ALbl: TLandrixGaebString): TLandrixGaebCategory;
    { Appends an item with ARNoPart to AParent (nil: top level) and gives it
      a new ID; values and texts are set afterwards. ELandrixGaebError if
      AParent holds categories, remarks or execution descriptions outside
      an item list.
      DE: Haengt eine Position mit ARNoPart an AParent an (nil: oberste
      Ebene) und gibt ihr eine neue ID; Werte und Texte werden danach
      gesetzt. ELandrixGaebError, wenn AParent Bereiche, Bemerkungen oder
      Ausfuehrungsbeschreibungen ausserhalb einer Positionsliste enthaelt. }
    function AddItem(AParent: TLandrixGaebCategory; const ARNoPart: TLandrixGaebString): TLandrixGaebItem;
    { Removes ANode with everything in it from the model and frees its
      views (and those of its children); references to them are invalid
      afterwards. A category or item list that becomes empty stays. If
      rebuilding fails (memory), all views are freed as by Refresh.
      DE: Entfernt ANode mit allem darin aus dem Modell und gibt seine
      Sichten (und die seiner Kinder) frei; Verweise darauf sind danach
      ungueltig. Ein Bereich oder eine Positionsliste, die leer wird,
      bleibt. Scheitert der Neuaufbau (Speicher), sind wie nach Refresh
      alle Sichten freigegeben. }
    procedure Remove(ANode: TLandrixGaebNode);
    { Reads a GAEB DA XML file (LandrixGaebXmlReadFile; AMaxSize <= 0: the
      default limit) into a new bill that owns the document. ADiagnostics
      may be nil. Raises ELandrixGaebError for input that cannot be read.
      DE: Liest eine GAEB-DA-XML-Datei (LandrixGaebXmlReadFile; AMaxSize
      <= 0: die Standardgrenze) in ein neues LV, das das Dokument besitzt.
      ADiagnostics darf nil sein. Loest ELandrixGaebError fuer Eingaben
      aus, die nicht gelesen werden koennen. }
    class function LoadFromFile(const AFileName: string; ADiagnostics: TLandrixGaebDiagnostics;
      AMaxSize: Int64): TLandrixGaebBillOfQuantities;
    { As LoadFromFile, from the position of AStream to its end. DE: Wie
      LoadFromFile, ab der Position von AStream bis zu seinem Ende. }
    class function LoadFromStream(AStream: TStream; ADiagnostics: TLandrixGaebDiagnostics;
      AMaxSize: Int64): TLandrixGaebBillOfQuantities;
    { Writes the document for Target with WriteOptions
      (LandrixGaebXmlWriteFile, LandrixGaebXmlWriteStream). ADiagnostics
      may be nil.
      DE: Schreibt das Dokument fuer Target mit WriteOptions
      (LandrixGaebXmlWriteFile, LandrixGaebXmlWriteStream). ADiagnostics
      darf nil sein. }
    procedure SaveToFile(const AFileName: string; ADiagnostics: TLandrixGaebDiagnostics);
    procedure SaveToStream(AStream: TStream; ADiagnostics: TLandrixGaebDiagnostics);
    { Options of SaveToFile and SaveToStream (default:
      LandrixGaebXmlDefaultWriteOptions). DE: Optionen von SaveToFile und
      SaveToStream (Standard: LandrixGaebXmlDefaultWriteOptions). }
    property WriteOptions: TLandrixGaebXmlWriteOptions read FWriteOptions write FWriteOptions;
    { The document and the target it was read for or is to be written for;
      another target converts on saving (a bid X84 has unknown count
      status, see TLandrixGaebCountStatus).
      DE: Das Dokument und das Ziel, fuer das es gelesen wurde oder
      geschrieben werden soll; ein anderes Ziel konvertiert beim Speichern
      (ein Angebot X84 hat unbestimmten Zaehlstatus, siehe
      TLandrixGaebCountStatus). }
    property Document: TLandrixGaebXmlGAEB read FDocument;
    property Target: TLandrixGaebTarget read FTarget write FTarget;
    { Top level nodes and all items and markup items in document order.
      DE: Knoten der obersten Ebene und alle Positionen und
      Zuschlagspositionen in Dokumentreihenfolge. }
    property Root: TLandrixGaebNodeList read FRoot;
    property AllItems: TLandrixGaebNodeList read FAllItems;
    { Finds a category (ACategory) or an item or markup item by OZ and
      index; numeric parts by value ('10' finds '0010'). gfrAmbiguous if
      the document has the OZ twice (ANode is then the first).
      DE: Sucht einen Bereich (ACategory) oder eine Position bzw.
      Zuschlagsposition nach OZ und Index; Ziffernteile nach Wert ('10'
      findet '0010'). gfrAmbiguous, wenn das Dokument die OZ doppelt hat
      (ANode ist dann die erste). }
    function FindByOZ(const AOZ, AIndex: TLandrixGaebString; ACategory: Boolean;
      out ANode: TLandrixGaebNode): TLandrixGaebFindResult;
    { Project name (PrjInfo/NamePrj). DE: Projektname (PrjInfo/NamePrj). }
    property ProjectName: TLandrixGaebString read GetProjectName write SetProjectName;
    { Name of the bill (BoQInfo/Name). DE: Name des LV (BoQInfo/Name). }
    function BoQName: TLandrixGaebString;
    { Currency: Award/AwardInfo/Cur, else PrjInfo/Cur. DE: Waehrung:
      Award/AwardInfo/Cur, sonst PrjInfo/Cur. }
    function Currency: TLandrixGaebString;
    { UPFracDig of the request (-1 if absent), NoUPComps (-1 if absent) and
      the labels of the unit price components 1 to 6.
      DE: UPFracDig der Anfrage (-1, wenn nicht vorhanden), NoUPComps (-1,
      wenn nicht vorhanden) und die Bezeichnungen der EP-Anteile 1 bis 6. }
    function UPFracDig: Integer;
    function NoUPComps: Integer;
    function UPCompLabel(ANumber: Integer): TLandrixGaebString;
    { Owner and contractor. DE: Auftraggeber und Auftragnehmer. }
    property Owner: TLandrixGaebParty read FOwner;
    property Contractor: TLandrixGaebParty read FContractor;
    { Requesters (Award/Requester) in document order. DE: Bedarfstraeger
      (Award/Requester) in Dokumentreihenfolge. }
    function RequesterCount: Integer;
    function Requesters(AIndex: Integer): TLandrixGaebParty;
    { Award data (Award/AwardInfo): contract number and date, date of the
      bid, start and end of construction. Reading an absent value gives
      ''; writing creates AwardInfo.
      DE: Vergabedaten (Award/AwardInfo): Vertragsnummer und -datum,
      Angebotstermin, Baubeginn und -ende. Lesen eines fehlenden Wertes
      liefert ''; Schreiben legt AwardInfo an. }
    property ContractNo: TLandrixGaebString index 0 read GetAwardField write SetAwardField;
    property ContractDate: TLandrixGaebString index 1 read GetAwardField write SetAwardField;
    property BidDate: TLandrixGaebString index 2 read GetAwardField write SetAwardField;
    property ConstructionStart: TLandrixGaebString index 3 read GetAwardField write SetAwardField;
    property ConstructionEnd: TLandrixGaebString index 4 read GetAwardField write SetAwardField;
    { Total of the bill (Totals.Amount: TotAfterDisc, else TotalLSUM, else
      Total). DE: Summe des LV (Totals.Amount: TotAfterDisc, sonst
      TotalLSUM, sonst Total). }
    function Total: TLandrixGaebDecimal;
    { The totals block of the bill (BoQInfo/Totals). DE: Der Summenblock
      des LV (BoQInfo/Totals). }
    property Totals: TLandrixGaebTotals read FTotals;
    { Breakdown levels (BoQInfo/BoQBkdn) from the top. DE:
      Gliederungsstufen (BoQInfo/BoQBkdn) von oben. }
    function BreakdownCount: Integer;
    function Breakdowns(AIndex: Integer): TLandrixGaebBreakdown;
    { True if the first breakdown level is Lot. DE: True, wenn die erste
      Gliederungsstufe Lot ist. }
    function HasLots: Boolean;
    { Lot groups (BoQ/LotGrp) in document order. DE: Losgruppen
      (BoQ/LotGrp) in Dokumentreihenfolge. }
    function LotGroupCount: Integer;
    function LotGroups(AIndex: Integer): TLandrixGaebLotGroup;
  end;

{ Visits the text parts of ANode (a text container of the syntax model:
  DetailTxt, OutlTxt, LblTx, p, div, ... or a TLandrixGaebXmlTextComplement
  body) in document order.
  DE: Besucht die Textteile von ANode (ein Textcontainer des
  Syntaxmodells: DetailTxt, OutlTxt, LblTx, p, div, ... oder der Inhalt
  einer TLandrixGaebXmlTextComplement) in Dokumentreihenfolge. }
procedure LandrixGaebVisitText(ANode: TLandrixGaebXmlNode; AVisitor: TLandrixGaebTextVisitor);

{ Plain text of ANode for display: paragraphs, list entries and table rows
  on lines of their own (LF), cells separated by TAB, a complement as
  '[' MarkLbl ': ' body ']'. Not a format to parse.
  DE: Klartext von ANode zur Anzeige: Absaetze, Listeneintraege und
  Tabellenzeilen auf eigenen Zeilen (LF), Zellen durch TAB getrennt, eine
  Ergaenzung als '[' MarkLbl ': ' Inhalt ']'. Kein Format zum Einlesen. }
function LandrixGaebPlainText(ANode: TLandrixGaebXmlNode): TLandrixGaebString;

implementation

uses
  LandrixGaebDetect,
  LandrixGaebXmlReader,
  LandrixGaebXmlWriter,
  LandrixGaebBoQTree;

function YesOf(const S: TLandrixGaebString): Boolean;
begin
  Result := S = 'Yes';
end;

function NoValue: TLandrixGaebDecimal;
begin
  Result.Clear;
end;

function IsAlternativeSerial(const S: TLandrixGaebString): Boolean;
begin
  Result := LandrixGaebIsAlternative(S);
end;

function TreeNodeOf(AObject: TObject): TLandrixGaebTreeNode;
begin
  Result := TLandrixGaebTreeNode(AObject);
end;

{ ---- text ---- }

procedure Emit(AVisitor: TLandrixGaebTextVisitor; AKind: TLandrixGaebTextEventKind;
  const AText: TLandrixGaebString; AFlag: Boolean; ANode: TLandrixGaebXmlNode);
var
  E: TLandrixGaebTextEvent;
begin
  E.Kind := AKind;
  E.Text := AText;
  E.Ordered := AFlag and (AKind = gteBeginList);
  E.Header := AFlag and (AKind = gteBeginCell);
  E.Node := ANode;
  AVisitor.Visit(E);
end;

{ Ordered children of a text container, nil if the node has none. }
function TextChildren(ANode: TLandrixGaebXmlNode): TLandrixGaebXmlNodeList;
begin
  Result := nil;
  if ANode is TLandrixGaebXmlBoQText then
    Result := TLandrixGaebXmlBoQText(ANode).Children
  else if ANode is TLandrixGaebXmlOutlTxt then
    Result := TLandrixGaebXmlOutlTxt(ANode).Children
  else if ANode is TLandrixGaebXmlFText then
    Result := TLandrixGaebXmlFText(ANode).Children
  else if ANode is TLandrixGaebXmlFTextTC then
    Result := TLandrixGaebXmlFTextTC(ANode).Children
  else if ANode is TLandrixGaebXmlMLText then
    Result := TLandrixGaebXmlMLText(ANode).Children
  else if ANode is TLandrixGaebXmlPMLText then
    Result := TLandrixGaebXmlPMLText(ANode).Children
  else if ANode is TLandrixGaebXmlP then
    Result := TLandrixGaebXmlP(ANode).Children
  else if ANode is TLandrixGaebXmlPTC then
    Result := TLandrixGaebXmlPTC(ANode).Children
  else if ANode is TLandrixGaebXmlDiv then
    Result := TLandrixGaebXmlDiv(ANode).Children
  else if ANode is TLandrixGaebXmlDivTC then
    Result := TLandrixGaebXmlDivTC(ANode).Children
  else if ANode is TLandrixGaebXmlLi then
    Result := TLandrixGaebXmlLi(ANode).Children
  else if ANode is TLandrixGaebXmlLiTC then
    Result := TLandrixGaebXmlLiTC(ANode).Children
  else if ANode is TLandrixGaebXmlTr then
    Result := TLandrixGaebXmlTr(ANode).Children
  else if ANode is TLandrixGaebXmlTrTC then
    Result := TLandrixGaebXmlTrTC(ANode).Children
  else if ANode is TLandrixGaebXmlTd then
    Result := TLandrixGaebXmlTd(ANode).Children
  else if ANode is TLandrixGaebXmlTdTC then
    Result := TLandrixGaebXmlTdTC(ANode).Children
  else if ANode is TLandrixGaebXmlTh then
    Result := TLandrixGaebXmlTh(ANode).Children;
end;

procedure VisitList(AList: TObjectList; AVisitor: TLandrixGaebTextVisitor); forward;

procedure VisitNode(ANode: TLandrixGaebXmlNode; AVisitor: TLandrixGaebTextVisitor);
var
  Children: TLandrixGaebXmlNodeList;
begin
  if ANode = nil then
    Exit;
  if ANode is TLandrixGaebXmlTextComplement then
    Emit(AVisitor, gteComplement, '', False, ANode)
  else if ANode is TLandrixGaebXmlSpan then
    Emit(AVisitor, gteText, TLandrixGaebXmlSpan(ANode).Value, False, ANode)
  else if ANode is TLandrixGaebXmlTextNode then
    Emit(AVisitor, gteText, TLandrixGaebXmlTextNode(ANode).Text, False, ANode)
  else if ANode is TLandrixGaebXmlImage then
    Emit(AVisitor, gteImage, '', False, ANode)
  else if ANode is TLandrixGaebXmlValueNode then
  begin
    if ANode.ElementName = 'br' then
      Emit(AVisitor, gteLineBreak, '', False, ANode);
  end
  else if (ANode is TLandrixGaebXmlUl) or (ANode is TLandrixGaebXmlOl) then
  begin
    Emit(AVisitor, gteBeginList, '', ANode is TLandrixGaebXmlOl, ANode);
    if ANode is TLandrixGaebXmlUl then
      VisitList(TLandrixGaebXmlUl(ANode).Li, AVisitor)
    else
      VisitList(TLandrixGaebXmlOl(ANode).Li, AVisitor);
    Emit(AVisitor, gteEndList, '', False, ANode);
  end
  else if (ANode is TLandrixGaebXmlUlTC) or (ANode is TLandrixGaebXmlOlTC) then
  begin
    Emit(AVisitor, gteBeginList, '', ANode is TLandrixGaebXmlOlTC, ANode);
    if ANode is TLandrixGaebXmlUlTC then
      VisitList(TLandrixGaebXmlUlTC(ANode).Li, AVisitor)
    else
      VisitList(TLandrixGaebXmlOlTC(ANode).Li, AVisitor);
    Emit(AVisitor, gteEndList, '', False, ANode);
  end
  else if ANode is TLandrixGaebXmlTable then
  begin
    Emit(AVisitor, gteBeginTable, '', False, ANode);
    VisitList(TLandrixGaebXmlTable(ANode).Tr, AVisitor);
    Emit(AVisitor, gteEndTable, '', False, ANode);
  end
  else if ANode is TLandrixGaebXmlTableTC then
  begin
    Emit(AVisitor, gteBeginTable, '', False, ANode);
    VisitList(TLandrixGaebXmlTableTC(ANode).Tr, AVisitor);
    Emit(AVisitor, gteEndTable, '', False, ANode);
  end
  else
  begin
    Children := TextChildren(ANode);
    if (ANode is TLandrixGaebXmlLi) or (ANode is TLandrixGaebXmlLiTC) then
    begin
      Emit(AVisitor, gteBeginListItem, '', False, ANode);
      VisitList(Children, AVisitor);
      Emit(AVisitor, gteEndListItem, '', False, ANode);
    end
    else if (ANode is TLandrixGaebXmlTr) or (ANode is TLandrixGaebXmlTrTC) then
    begin
      Emit(AVisitor, gteBeginRow, '', False, ANode);
      VisitList(Children, AVisitor);
      Emit(AVisitor, gteEndRow, '', False, ANode);
    end
    else if (ANode is TLandrixGaebXmlTd) or (ANode is TLandrixGaebXmlTdTC) or (ANode is TLandrixGaebXmlTh) then
    begin
      Emit(AVisitor, gteBeginCell, '', ANode is TLandrixGaebXmlTh, ANode);
      VisitList(Children, AVisitor);
      Emit(AVisitor, gteEndCell, '', False, ANode);
    end
    else if (ANode is TLandrixGaebXmlP) or (ANode is TLandrixGaebXmlPTC) or (ANode is TLandrixGaebXmlPMLText) or
      (ANode is TLandrixGaebXmlDiv) or (ANode is TLandrixGaebXmlDivTC) then
    begin
      Emit(AVisitor, gteBeginParagraph, '', False, ANode);
      VisitList(Children, AVisitor);
      Emit(AVisitor, gteEndParagraph, '', False, ANode);
    end
    else
      VisitList(Children, AVisitor);
  end;
end;

procedure VisitList(AList: TObjectList; AVisitor: TLandrixGaebTextVisitor);
var
  I: Integer;
begin
  if AList = nil then
    Exit;
  for I := 0 to Integer(AList.Count) - 1 do
    VisitNode(TLandrixGaebXmlNode(AList[I]), AVisitor);
end;

procedure LandrixGaebVisitText(ANode: TLandrixGaebXmlNode; AVisitor: TLandrixGaebTextVisitor);
begin
  VisitNode(ANode, AVisitor);
end;

type
  { Plain text renderer (LandrixGaebPlainText). }
  TPlainText = class(TLandrixGaebTextVisitor)
  private
    FText: TLandrixGaebString;
    FCellInRow: Integer;
    procedure NewLine;
  public
    procedure Visit(const AEvent: TLandrixGaebTextEvent); override;
  end;

procedure TPlainText.NewLine;
begin
  if (FText <> '') and (FText[Length(FText)] <> #10) then
    FText := FText + #10;
end;

procedure TPlainText.Visit(const AEvent: TLandrixGaebTextEvent);
var
  C: TLandrixGaebXmlTextComplement;
  Body: TLandrixGaebString;
begin
  case AEvent.Kind of
    gteText:
      FText := FText + AEvent.Text;
    gteBeginParagraph, gteEndParagraph, gteBeginListItem, gteEndListItem, gteEndRow:
      NewLine;
    gteLineBreak:
      FText := FText + #10;
    gteBeginRow:
      begin
        NewLine;
        FCellInRow := 0;
      end;
    gteBeginCell:
      begin
        if FCellInRow > 0 then
          FText := FText + #9;
        Inc(FCellInRow);
      end;
    gteComplement:
      begin
        C := TLandrixGaebXmlTextComplement(AEvent.Node);
        Body := '';
        if C.HasComplBody then
          Body := LandrixGaebPlainText(C.ComplBody);
        FText := FText + '[' + C.MarkLbl + ': ' + Body + ']';
      end;
  else
    ;
  end;
end;

function LandrixGaebPlainText(ANode: TLandrixGaebXmlNode): TLandrixGaebString;
var
  R: TPlainText;
begin
  R := TPlainText.Create;
  try
    VisitNode(ANode, R);
    Result := R.FText;
  finally
    R.Free;
  end;
  while (Result <> '') and (Result[Length(Result)] = #10) do
    SetLength(Result, Length(Result) - 1);
end;

{ Collects the text complements of a text in document order. }
type
  TComplementCollector = class(TLandrixGaebTextVisitor)
  private
    FList: TObjectList;
  public
    procedure Visit(const AEvent: TLandrixGaebTextEvent); override;
  end;

procedure TComplementCollector.Visit(const AEvent: TLandrixGaebTextEvent);
begin
  if AEvent.Kind = gteComplement then
    FList.Add(TLandrixGaebTextComplement.Create(TLandrixGaebXmlTextComplement(AEvent.Node)));
end;

{ TLandrixGaebTextComplement }

constructor TLandrixGaebTextComplement.Create(ASyntaxNode: TLandrixGaebXmlTextComplement);
begin
  inherited Create;
  FSyntaxNode := ASyntaxNode;
end;

function TLandrixGaebTextComplement.GetKind: TLandrixGaebComplementKind;
begin
  if FSyntaxNode.Kind = 'Owner' then
    Result := gckOwner
  else if FSyntaxNode.Kind = 'Bidder' then
    Result := gckBidder
  else
    Result := gckUnrecognized;
end;

function TLandrixGaebTextComplement.MarkLbl: TLandrixGaebString;
begin
  Result := FSyntaxNode.MarkLbl;
end;

function TLandrixGaebTextComplement.IsEmptyMarked: Boolean;
begin
  Result := YesOf(FSyntaxNode.Empty);
end;

function TLandrixGaebTextComplement.WantsDecimal: Boolean;
begin
  Result := FSyntaxNode.HasComplBodyDec;
end;

function TLandrixGaebTextComplement.WantsInteger: Boolean;
begin
  Result := FSyntaxNode.HasComplBodyInt;
end;

function TLandrixGaebTextComplement.CaptionText: TLandrixGaebString;
begin
  Result := '';
  if FSyntaxNode.HasComplCaption then
    Result := LandrixGaebPlainText(FSyntaxNode.ComplCaption);
end;

function TLandrixGaebTextComplement.BodyText: TLandrixGaebString;
begin
  Result := '';
  if FSyntaxNode.HasComplBody then
    Result := LandrixGaebPlainText(FSyntaxNode.ComplBody);
end;

function TLandrixGaebTextComplement.TailText: TLandrixGaebString;
begin
  Result := '';
  if FSyntaxNode.HasComplTail then
    Result := LandrixGaebPlainText(FSyntaxNode.ComplTail);
end;

procedure ReplaceBody(AComplement: TLandrixGaebXmlTextComplement; const AText: TLandrixGaebString);
var
  Body: TLandrixGaebXmlMLText;
  P: TLandrixGaebXmlPMLText;
begin
  Body := AComplement.ComplBody;
  Body.Children.Clear;
  P := Body.AddP;
  P.AddSpan.Value := AText;
  AComplement.Empty := '';
end;

procedure TLandrixGaebTextComplement.SetBodyText(const AText: TLandrixGaebString);
begin
  if Kind <> gckBidder then
    raise ELandrixGaebError.Create('only a bidder''s text complement can be filled in');
  if WantsDecimal or WantsInteger then
    raise ELandrixGaebError.Create('the text complement asks for a number (SetBodyNumber)');
  ReplaceBody(FSyntaxNode, AText);
end;

function IsIntegerText(const S: TLandrixGaebString): Boolean;
var
  I, First: Integer;
begin
  Result := False;
  First := 1;
  if (S <> '') and ((S[1] = '-') or (S[1] = '+')) then
    First := 2;
  if First > Length(S) then
    Exit;
  for I := First to Length(S) do
    if (S[I] < '0') or (S[I] > '9') then
      Exit;
  Result := True;
end;

procedure TLandrixGaebTextComplement.SetBodyNumber(const AText: TLandrixGaebString);
var
  D: TLandrixGaebDecimalText;
begin
  if Kind <> gckBidder then
    raise ELandrixGaebError.Create('only a bidder''s text complement can be filled in');
  if WantsDecimal then
  begin
    D.Clear;
    if not D.TrySetText(LandrixXmlWideToUtf8(AText)) then
      raise ELandrixGaebError.Create('no decimal for the text complement');
    FSyntaxNode.ComplBodyDec.Value := D;
  end
  else if WantsInteger then
  begin
    if not IsIntegerText(AText) then
      raise ELandrixGaebError.Create('no integer for the text complement');
    FSyntaxNode.ComplBodyInt.Value := AText;
  end
  else
    raise ELandrixGaebError.Create('the text complement asks for no number (SetBodyText)');
  ReplaceBody(FSyntaxNode, AText);
end;

{ TLandrixGaebNodeList }

constructor TLandrixGaebNodeList.Create;
begin
  inherited Create;
  FList := TObjectList.Create(False);
end;

destructor TLandrixGaebNodeList.Destroy;
begin
  FList.Free;
  inherited Destroy;
end;

procedure TLandrixGaebNodeList.Add(ANode: TLandrixGaebNode);
begin
  FList.Add(ANode);
end;

function TLandrixGaebNodeList.Count: Integer;
begin
  Result := Integer(FList.Count);
end;

function TLandrixGaebNodeList.GetItem(AIndex: Integer): TLandrixGaebNode;
begin
  Result := TLandrixGaebNode(FList[AIndex]);
end;

{ TLandrixGaebNode }

constructor TLandrixGaebNode.Create(ABill: TLandrixGaebBillOfQuantities; AKind: TLandrixGaebNodeKind;
  AParent: TLandrixGaebCategory; ASyntaxNode: TLandrixGaebXmlNode; ATreeNode: TObject);
begin
  inherited Create;
  FBill := ABill;
  FKind := AKind;
  FParent := AParent;
  FSyntaxNode := ASyntaxNode;
  FTreeNode := ATreeNode;
end;

destructor TLandrixGaebNode.Destroy;
begin
  FComplements.Free;
  inherited Destroy;
end;

function TLandrixGaebNode.GetPath: TLandrixGaebString;
begin
  Result := LandrixXmlUtf8ToWide(TreeNodeOf(FTreeNode).Path);
end;

function TLandrixGaebNode.GetOZ: TLandrixGaebString;
var
  T: TLandrixGaebTreeNode;
  I: Integer;
begin
  T := TreeNodeOf(FTreeNode);
  Result := '';
  for I := 0 to Integer(High(T.Parts)) do
  begin
    if I > 0 then
      Result := Result + '.';
    Result := Result + T.Parts[I];
  end;
end;

function TLandrixGaebNode.GetIndex: TLandrixGaebString;
begin
  Result := TreeNodeOf(FTreeNode).Index;
end;

procedure TLandrixGaebNode.GetTexts(out AComplete: TLandrixGaebXmlCompleteText;
  out AOutline: TLandrixGaebXmlOutlineText);
begin
  AComplete := nil;
  AOutline := nil;
end;

procedure DescriptionTexts(D: TLandrixGaebXmlDescription; out AComplete: TLandrixGaebXmlCompleteText;
  out AOutline: TLandrixGaebXmlOutlineText);
begin
  AComplete := nil;
  AOutline := nil;
  if D.HasCompleteText then
    AComplete := D.CompleteText;
  if D.HasOutlineText then
    AOutline := D.OutlineText;
end;

function DetailOf(C: TLandrixGaebXmlCompleteText): TLandrixGaebXmlNode;
begin
  Result := nil;
  if (C <> nil) and C.HasDetailTxt then
    Result := C.DetailTxt;
end;

function OutlineOf(C: TLandrixGaebXmlCompleteText; O: TLandrixGaebXmlOutlineText): TLandrixGaebXmlNode;
begin
  Result := nil;
  if (C <> nil) and C.HasOutlineText and C.OutlineText.HasOutlTxt then
    Result := C.OutlineText.OutlTxt
  else if (O <> nil) and O.HasOutlTxt then
    Result := O.OutlTxt;
end;

function PlainOrEmpty(ANode: TLandrixGaebXmlNode): TLandrixGaebString;
begin
  Result := '';
  if ANode <> nil then
    Result := LandrixGaebPlainText(ANode);
end;

function TLandrixGaebNode.DetailTextNode: TLandrixGaebXmlNode;
var
  C: TLandrixGaebXmlCompleteText;
  O: TLandrixGaebXmlOutlineText;
begin
  GetTexts(C, O);
  Result := DetailOf(C);
end;

function TLandrixGaebNode.OutlineTextNode: TLandrixGaebXmlNode;
var
  C: TLandrixGaebXmlCompleteText;
  O: TLandrixGaebXmlOutlineText;
begin
  GetTexts(C, O);
  Result := OutlineOf(C, O);
end;

function TLandrixGaebNode.ShortText: TLandrixGaebString;
begin
  Result := '';
  if OutlineTextNode <> nil then
    Result := LandrixGaebPlainText(OutlineTextNode);
end;

function TLandrixGaebNode.LongText: TLandrixGaebString;
begin
  Result := '';
  if DetailTextNode <> nil then
    Result := LandrixGaebPlainText(DetailTextNode);
end;

function TLandrixGaebNode.ComplementCount: Integer;
var
  C: TComplementCollector;
begin
  if FComplements = nil then
  begin
    FComplements := TObjectList.Create;
    C := TComplementCollector.Create;
    try
      C.FList := FComplements;
      VisitNode(DetailTextNode, C);
      VisitNode(OutlineTextNode, C);
    finally
      C.Free;
    end;
  end;
  Result := Integer(FComplements.Count);
end;

function TLandrixGaebNode.Complements(AIndex: Integer): TLandrixGaebTextComplement;
begin
  if (AIndex < 0) or (AIndex >= ComplementCount) then
    raise ELandrixGaebError.Create('complement index out of range');
  Result := TLandrixGaebTextComplement(FComplements[AIndex]);
end;

procedure CheckIndex(AIndex, ACount: Integer);
begin
  if (AIndex < 0) or (AIndex >= ACount) then
    raise ELandrixGaebError.Create('index out of range');
end;

function NoReference: TLandrixGaebReference;
begin
  Result.Status := grsAbsent;
  Result.IDRef := '';
  Result.Node := nil;
end;

function TLandrixGaebNode.RefRNo: TLandrixGaebReference;
begin
  Result := NoReference;
  if (FSyntaxNode is TLandrixGaebXmlItem) and TLandrixGaebXmlItem(FSyntaxNode).HasRefRNo then
    Result := FBill.Resolve(TLandrixGaebXmlItem(FSyntaxNode).RefRNo.IDRef, [gnkItem])
  else if (FSyntaxNode is TLandrixGaebXmlMarkupItem) and TLandrixGaebXmlMarkupItem(FSyntaxNode).HasRefRNo then
    Result := FBill.Resolve(TLandrixGaebXmlMarkupItem(FSyntaxNode).RefRNo.IDRef, [gnkItem]);
end;

function TLandrixGaebNode.RefPerfNo: TLandrixGaebReference;
begin
  Result := NoReference;
  if (FSyntaxNode is TLandrixGaebXmlItem) and TLandrixGaebXmlItem(FSyntaxNode).HasRefPerfNo then
    Result := FBill.Resolve(TLandrixGaebXmlItem(FSyntaxNode).RefPerfNo.IDRef, [gnkPerfDescr])
  else if (FSyntaxNode is TLandrixGaebXmlMarkupItem) and TLandrixGaebXmlMarkupItem(FSyntaxNode).HasRefPerfNo then
    Result := FBill.Resolve(TLandrixGaebXmlMarkupItem(FSyntaxNode).RefPerfNo.IDRef, [gnkPerfDescr]);
end;

{ Catalogue assignments of a node, nil if it has none. }
function CatalogList(ANode: TLandrixGaebXmlNode): TLandrixGaebXmlCtlgAssignList;
begin
  Result := nil;
  if ANode is TLandrixGaebXmlItem then
  begin
    if TLandrixGaebXmlItem(ANode).HasCtlgAssign then
      Result := TLandrixGaebXmlItem(ANode).CtlgAssign;
  end
  else if ANode is TLandrixGaebXmlMarkupItem then
  begin
    if TLandrixGaebXmlMarkupItem(ANode).HasCtlgAssign then
      Result := TLandrixGaebXmlMarkupItem(ANode).CtlgAssign;
  end
  else if ANode is TLandrixGaebXmlBoQCtgy then
  begin
    if TLandrixGaebXmlBoQCtgy(ANode).HasCtlgAssign then
      Result := TLandrixGaebXmlBoQCtgy(ANode).CtlgAssign;
  end
  else if ANode is TLandrixGaebXmlRemark then
  begin
    if TLandrixGaebXmlRemark(ANode).HasCtlgAssign then
      Result := TLandrixGaebXmlRemark(ANode).CtlgAssign;
  end
  else if ANode is TLandrixGaebXmlPerfDescr then
  begin
    if TLandrixGaebXmlPerfDescr(ANode).HasCtlgAssign then
      Result := TLandrixGaebXmlPerfDescr(ANode).CtlgAssign;
  end;
end;

function TLandrixGaebNode.CatalogCount: Integer;
var
  L: TLandrixGaebXmlCtlgAssignList;
begin
  L := CatalogList(FSyntaxNode);
  Result := 0;
  if L <> nil then
    Result := Integer(L.Count);
end;

function TLandrixGaebNode.Catalogs(AIndex: Integer): TLandrixGaebCatalogRef;
var
  A: TLandrixGaebXmlCtlgAssign;
begin
  CheckIndex(AIndex, CatalogCount);
  A := CatalogList(FSyntaxNode)[AIndex];
  Result.CatalogID := A.CtlgID;
  Result.Code := A.CtlgCode;
end;

{ TLandrixGaebCategory }

constructor TLandrixGaebCategory.Create(ABill: TLandrixGaebBillOfQuantities; AParent: TLandrixGaebCategory;
  ASyntaxNode: TLandrixGaebXmlBoQCtgy; ATreeNode: TObject);
begin
  inherited Create(ABill, gnkCategory, AParent, ASyntaxNode, ATreeNode);
  FChildren := TLandrixGaebNodeList.Create;
  FTotals := TLandrixGaebTotals.Create(ABill, ASyntaxNode);
end;

destructor TLandrixGaebCategory.Destroy;
begin
  FTotals.Free;
  FChildren.Free;
  inherited Destroy;
end;

function TLandrixGaebCategory.Ctgy: TLandrixGaebXmlBoQCtgy;
begin
  Result := TLandrixGaebXmlBoQCtgy(SyntaxNode);
end;

function TLandrixGaebCategory.Lbl: TLandrixGaebString;
begin
  Result := '';
  if Ctgy.HasLblTx then
    Result := LandrixGaebPlainText(Ctgy.LblTx);
end;

procedure SetMLText(AText: TLandrixGaebXmlMLText; const AValue: TLandrixGaebString);
begin
  AText.Children.Clear;
  AText.AddP.AddSpan.Value := AValue;
end;

procedure TLandrixGaebCategory.SetLbl(const AText: TLandrixGaebString);
begin
  SetMLText(Ctgy.LblTx, AText);
end;

function TLandrixGaebCategory.AlternativeGroup: TLandrixGaebString;
begin
  Result := Ctgy.ALNBGroupNo;
end;

function TLandrixGaebCategory.AlternativeSerial: TLandrixGaebString;
begin
  Result := Ctgy.ALNBSerNo;
end;

function TLandrixGaebCategory.IsAlternative: Boolean;
begin
  Result := IsAlternativeSerial(Ctgy.ALNBSerNo);
end;

function TLandrixGaebCategory.NotApplicable: Boolean;
begin
  Result := YesOf(Ctgy.NotApplBoQ);
end;

function TLandrixGaebCategory.Accepted: TLandrixGaebString;
begin
  Result := Ctgy.Accepted;
end;

function TLandrixGaebCategory.Total: TLandrixGaebDecimal;
begin
  Result := FTotals.Amount;
end;

function TLandrixGaebCategory.IsLot: Boolean;
begin
  Result := (Parent = nil) and Bill.HasLots;
end;

function NodeCountStatus(ABill: TLandrixGaebBillOfQuantities; ATreeNode: TObject): TLandrixGaebCountStatus;
var
  T: TLandrixGaebTreeNode;
begin
  T := TreeNodeOf(ATreeNode);
  if (ABill.Target.Phase = gp84) or LandrixGaebHasAccepted(T) then
    Result := gcsUnknown
  else if LandrixGaebNotCounted(T) then
    Result := gcsNotCounted
  else
    Result := gcsCounts;
end;

function TLandrixGaebCategory.CountStatus: TLandrixGaebCountStatus;
begin
  Result := NodeCountStatus(Bill, FTreeNode);
end;

{ TLandrixGaebItem }

function TLandrixGaebItem.Item: TLandrixGaebXmlItem;
begin
  Result := TLandrixGaebXmlItem(SyntaxNode);
end;

procedure TLandrixGaebItem.GetTexts(out AComplete: TLandrixGaebXmlCompleteText;
  out AOutline: TLandrixGaebXmlOutlineText);
begin
  AComplete := nil;
  AOutline := nil;
  if Item.HasDescription then
    DescriptionTexts(Item.Description, AComplete, AOutline);
end;

function TLandrixGaebItem.Qty: TLandrixGaebDecimal;
begin
  Result := Item.Qty;
end;

procedure TLandrixGaebItem.SetQty(const AValue: TLandrixGaebDecimal);
begin
  Item.Qty := AValue;
end;

procedure TLandrixGaebItem.ClearQty;
begin
  Item.Qty.Clear;
end;

function TLandrixGaebItem.GetQU: TLandrixGaebString;
begin
  Result := Item.QU;
end;

procedure TLandrixGaebItem.SetQU(const AValue: TLandrixGaebString);
begin
  Item.QU := AValue;
end;

function TLandrixGaebItem.UP: TLandrixGaebDecimal;
begin
  Result := Item.UP;
end;

procedure TLandrixGaebItem.SetUP(const AValue: TLandrixGaebDecimal);
begin
  Item.UP := AValue;
end;

procedure TLandrixGaebItem.ClearUP;
begin
  Item.UP.Clear;
end;

procedure CheckComp(ANumber: Integer);
begin
  if (ANumber < 1) or (ANumber > 6) then
    raise ELandrixGaebError.Create('unit price component number out of range (1 to 6)');
end;

function TLandrixGaebItem.UPComp(ANumber: Integer): TLandrixGaebDecimal;
begin
  CheckComp(ANumber);
  case ANumber of
    1: Result := Item.UPComp1;
    2: Result := Item.UPComp2;
    3: Result := Item.UPComp3;
    4: Result := Item.UPComp4;
    5: Result := Item.UPComp5;
  else
    Result := Item.UPComp6;
  end;
end;

procedure TLandrixGaebItem.SetUPComp(ANumber: Integer; const AValue: TLandrixGaebDecimal);
begin
  CheckComp(ANumber);
  case ANumber of
    1: Item.UPComp1 := AValue;
    2: Item.UPComp2 := AValue;
    3: Item.UPComp3 := AValue;
    4: Item.UPComp4 := AValue;
    5: Item.UPComp5 := AValue;
  else
    Item.UPComp6 := AValue;
  end;
end;

procedure TLandrixGaebItem.ClearUPComp(ANumber: Integer);
begin
  SetUPComp(ANumber, NoValue);
end;

function TLandrixGaebItem.DiscountPcnt: TLandrixGaebDecimal;
begin
  Result := Item.DiscountPcnt;
end;

procedure TLandrixGaebItem.SetDiscountPcnt(const AValue: TLandrixGaebDecimal);
begin
  Item.DiscountPcnt := AValue;
end;

procedure TLandrixGaebItem.ClearDiscountPcnt;
begin
  Item.DiscountPcnt.Clear;
end;

function TLandrixGaebItem.IT: TLandrixGaebDecimal;
begin
  Result := Item.IT;
end;

procedure TLandrixGaebItem.SetIT(const AValue: TLandrixGaebDecimal);
begin
  Item.IT := AValue;
end;

procedure TLandrixGaebItem.ClearIT;
begin
  Item.IT.Clear;
end;

function TLandrixGaebItem.AlternativeGroup: TLandrixGaebString;
begin
  Result := Item.ALNGroupNo;
end;

function TLandrixGaebItem.AlternativeSerial: TLandrixGaebString;
begin
  Result := Item.ALNSerNo;
end;

function TLandrixGaebItem.IsBase: Boolean;
begin
  Result := (Item.ALNGroupNo <> '') and not IsAlternativeSerial(Item.ALNSerNo);
end;

function TLandrixGaebItem.IsAlternative: Boolean;
begin
  Result := IsAlternativeSerial(Item.ALNSerNo);
end;

function TLandrixGaebItem.Provisional: TLandrixGaebProvisional;
begin
  if Item.Provis = '' then
    Result := gpvNone
  else if Item.Provis = 'WithTotal' then
    Result := gpvWithTotal
  else if Item.Provis = 'WithoutTotal' then
    Result := gpvWithoutTotal
  else
    Result := gpvUnrecognized;
end;

function TLandrixGaebItem.IsLumpSum: Boolean;
begin
  Result := YesOf(Item.LumpSumItem);
end;

function TLandrixGaebItem.HourIt: TLandrixGaebString;
begin
  Result := Item.HourIt;
end;

function TLandrixGaebItem.NotApplicable: Boolean;
begin
  Result := YesOf(Item.NotAppl);
end;

function TLandrixGaebItem.NotOffered: Boolean;
begin
  Result := YesOf(Item.NotOffered);
end;

procedure TLandrixGaebItem.SetNotOffered(AValue: Boolean);
begin
  if AValue then
    Item.NotOffered := 'Yes'
  else
    Item.NotOffered := '';
end;

function TLandrixGaebItem.QtyTBD: Boolean;
begin
  Result := YesOf(Item.QtyTBD);
end;

function TLandrixGaebItem.Accepted: TLandrixGaebString;
begin
  Result := Item.Accepted;
end;

function TLandrixGaebItem.ChangeOrderNo: TLandrixGaebString;
begin
  Result := Item.CONo;
end;

function TLandrixGaebItem.ChangeOrderStatus: TLandrixGaebString;
begin
  Result := Item.COStatus;
end;

function TLandrixGaebItem.AlterBidStatus: TLandrixGaebString;
begin
  Result := Item.AlterBidStatus;
end;

function TLandrixGaebItem.CountStatus: TLandrixGaebCountStatus;
begin
  Result := NodeCountStatus(Bill, FTreeNode);
end;

destructor TLandrixGaebItem.Destroy;
begin
  FSubDescriptions.Free;
  inherited Destroy;
end;

function TLandrixGaebItem.DescriptionRole: TLandrixGaebDescriptionRole;
begin
  if Item.RefDescr = '' then
    Result := gdrNormal
  else if Item.RefDescr = 'Ref' then
    Result := gdrReference
  else if Item.RefDescr = 'Rep' then
    Result := gdrRepetition
  else
    Result := gdrUnrecognized;
end;

function TLandrixGaebItem.HoldOutType: TLandrixGaebString;
begin
  Result := Item.HoldOutType;
end;

function TLandrixGaebItem.RefBaseItemCount: Integer;
begin
  Result := 0;
  if Item.HasRefBaseItem then
    Result := Integer(Item.RefBaseItem.Count);
end;

function TLandrixGaebItem.RefBaseItem(AIndex: Integer): TLandrixGaebReference;
begin
  CheckIndex(AIndex, RefBaseItemCount);
  Result := Bill.Resolve(Item.RefBaseItem[AIndex].IDRef, [gnkItem]);
end;

function TLandrixGaebItem.QtySplitCount: Integer;
begin
  Result := 0;
  if Item.HasQtySplit then
    Result := Integer(Item.QtySplit.Count);
end;

function TLandrixGaebItem.QtySplits(AIndex: Integer): TLandrixGaebQtySplit;
begin
  CheckIndex(AIndex, QtySplitCount);
  Result.Qty := Item.QtySplit[AIndex].Qty;
  Result.QtyPcnt := Item.QtySplit[AIndex].QtyPcnt;
end;

function TLandrixGaebItem.BidCommentCount: Integer;
begin
  Result := 0;
  if Item.HasBidComm then
    Result := Integer(Item.BidComm.Count);
end;

function TLandrixGaebItem.BidCommentNode(AIndex: Integer): TLandrixGaebXmlNode;
begin
  CheckIndex(AIndex, BidCommentCount);
  Result := Item.BidComm[AIndex];
end;

function TLandrixGaebItem.IsSumDescription: Boolean;
begin
  Result := YesOf(Item.SumDescr);
end;

function TLandrixGaebItem.SubDescriptionCount: Integer;
var
  I: Integer;
begin
  if FSubDescriptions = nil then
  begin
    FSubDescriptions := TObjectList.Create;
    if Item.HasSubDescr then
      for I := 0 to Integer(Item.SubDescr.Count) - 1 do
        FSubDescriptions.Add(TLandrixGaebSubDescription.Create(Self, Item.SubDescr[I], I + 1));
  end;
  Result := Integer(FSubDescriptions.Count);
end;

function TLandrixGaebItem.SubDescriptions(AIndex: Integer): TLandrixGaebSubDescription;
begin
  CheckIndex(AIndex, SubDescriptionCount);
  Result := TLandrixGaebSubDescription(FSubDescriptions[AIndex]);
end;

{ TLandrixGaebSubDescription }

constructor TLandrixGaebSubDescription.Create(AItem: TLandrixGaebItem; ASyntaxNode: TLandrixGaebXmlSubDescr;
  APosition: Integer);
begin
  inherited Create;
  FItem := AItem;
  FSyntaxNode := ASyntaxNode;
  FPosition := APosition;
end;

function TLandrixGaebSubDescription.Path: TLandrixGaebString;
begin
  Result := FItem.Path + '/SubDescr[' + LandrixXmlUtf8ToWide(LandrixXmlStringToUtf8(IntToStr(FPosition))) + ']';
end;

function TLandrixGaebSubDescription.Number: TLandrixGaebString;
begin
  Result := FSyntaxNode.SubDNo;
end;

function TLandrixGaebSubDescription.QtyTBD: Boolean;
begin
  Result := YesOf(FSyntaxNode.QtyTBD);
end;

function TLandrixGaebSubDescription.Qty: TLandrixGaebDecimal;
begin
  Result := FSyntaxNode.Qty;
end;

procedure TLandrixGaebSubDescription.SetQty(const AValue: TLandrixGaebDecimal);
begin
  FSyntaxNode.Qty := AValue;
end;

procedure TLandrixGaebSubDescription.ClearQty;
begin
  FSyntaxNode.Qty.Clear;
end;

function TLandrixGaebSubDescription.GetQU: TLandrixGaebString;
begin
  Result := FSyntaxNode.QU;
end;

procedure TLandrixGaebSubDescription.SetQU(const AValue: TLandrixGaebString);
begin
  FSyntaxNode.QU := AValue;
end;

function TLandrixGaebSubDescription.UP: TLandrixGaebDecimal;
begin
  Result := FSyntaxNode.UP;
end;

procedure TLandrixGaebSubDescription.SetUP(const AValue: TLandrixGaebDecimal);
begin
  FSyntaxNode.UP := AValue;
end;

procedure TLandrixGaebSubDescription.ClearUP;
begin
  FSyntaxNode.UP.Clear;
end;

function TLandrixGaebSubDescription.UPComp(ANumber: Integer): TLandrixGaebDecimal;
begin
  CheckComp(ANumber);
  case ANumber of
    1: Result := FSyntaxNode.UPComp1;
    2: Result := FSyntaxNode.UPComp2;
    3: Result := FSyntaxNode.UPComp3;
    4: Result := FSyntaxNode.UPComp4;
    5: Result := FSyntaxNode.UPComp5;
  else
    Result := FSyntaxNode.UPComp6;
  end;
end;

procedure TLandrixGaebSubDescription.SetUPComp(ANumber: Integer; const AValue: TLandrixGaebDecimal);
begin
  CheckComp(ANumber);
  case ANumber of
    1: FSyntaxNode.UPComp1 := AValue;
    2: FSyntaxNode.UPComp2 := AValue;
    3: FSyntaxNode.UPComp3 := AValue;
    4: FSyntaxNode.UPComp4 := AValue;
    5: FSyntaxNode.UPComp5 := AValue;
  else
    FSyntaxNode.UPComp6 := AValue;
  end;
end;

procedure TLandrixGaebSubDescription.ClearUPComp(ANumber: Integer);
begin
  SetUPComp(ANumber, NoValue);
end;

function TLandrixGaebSubDescription.DetailTextNode: TLandrixGaebXmlNode;
var
  C: TLandrixGaebXmlCompleteText;
  O: TLandrixGaebXmlOutlineText;
begin
  C := nil;
  O := nil;
  if FSyntaxNode.HasDescription then
    DescriptionTexts(FSyntaxNode.Description, C, O);
  Result := DetailOf(C);
end;

function TLandrixGaebSubDescription.OutlineTextNode: TLandrixGaebXmlNode;
var
  C: TLandrixGaebXmlCompleteText;
  O: TLandrixGaebXmlOutlineText;
begin
  C := nil;
  O := nil;
  if FSyntaxNode.HasDescription then
    DescriptionTexts(FSyntaxNode.Description, C, O);
  Result := OutlineOf(C, O);
end;

function TLandrixGaebSubDescription.ShortText: TLandrixGaebString;
begin
  Result := PlainOrEmpty(OutlineTextNode);
end;

function TLandrixGaebSubDescription.LongText: TLandrixGaebString;
begin
  Result := PlainOrEmpty(DetailTextNode);
end;

{ TLandrixGaebMarkupItem }

function TLandrixGaebMarkupItem.Markup: TLandrixGaebXmlMarkupItem;
begin
  Result := TLandrixGaebXmlMarkupItem(SyntaxNode);
end;

procedure TLandrixGaebMarkupItem.GetTexts(out AComplete: TLandrixGaebXmlCompleteText;
  out AOutline: TLandrixGaebXmlOutlineText);
begin
  AComplete := nil;
  AOutline := nil;
  if Markup.HasDescription then
    DescriptionTexts(Markup.Description, AComplete, AOutline);
end;

function TLandrixGaebMarkupItem.MarkupType: TLandrixGaebString;
begin
  Result := Markup.MarkupType;
end;

function TLandrixGaebMarkupItem.MarkupPcnt: TLandrixGaebDecimal;
begin
  Result := Markup.Markup;
end;

function TLandrixGaebMarkupItem.ITMarkup: TLandrixGaebDecimal;
begin
  Result := Markup.ITMarkup;
end;

function TLandrixGaebMarkupItem.IT: TLandrixGaebDecimal;
begin
  Result := Markup.IT;
end;

procedure TLandrixGaebMarkupItem.SetMarkupPcnt(const AValue: TLandrixGaebDecimal);
begin
  Markup.Markup := AValue;
end;

procedure TLandrixGaebMarkupItem.SetITMarkup(const AValue: TLandrixGaebDecimal);
begin
  Markup.ITMarkup := AValue;
end;

procedure TLandrixGaebMarkupItem.SetIT(const AValue: TLandrixGaebDecimal);
begin
  Markup.IT := AValue;
end;

function TLandrixGaebMarkupItem.AlternativeSerial: TLandrixGaebString;
begin
  Result := Markup.ALNSerNo;
end;

function TLandrixGaebMarkupItem.IsAlternative: Boolean;
begin
  Result := IsAlternativeSerial(Markup.ALNSerNo);
end;

function TLandrixGaebMarkupItem.NotApplicable: Boolean;
begin
  Result := YesOf(Markup.NotAppl);
end;

function TLandrixGaebMarkupItem.CountStatus: TLandrixGaebCountStatus;
begin
  Result := NodeCountStatus(Bill, FTreeNode);
end;

{ TLandrixGaebRemark }

procedure TLandrixGaebRemark.GetTexts(out AComplete: TLandrixGaebXmlCompleteText;
  out AOutline: TLandrixGaebXmlOutlineText);
begin
  AComplete := nil;
  AOutline := nil;
  if TLandrixGaebXmlRemark(SyntaxNode).HasDescription then
    DescriptionTexts(TLandrixGaebXmlRemark(SyntaxNode).Description, AComplete, AOutline);
end;

{ TLandrixGaebPerfDescr }

procedure TLandrixGaebPerfDescr.GetTexts(out AComplete: TLandrixGaebXmlCompleteText;
  out AOutline: TLandrixGaebXmlOutlineText);
var
  D: TLandrixGaebXmlPerfDescription;
begin
  AComplete := nil;
  AOutline := nil;
  if not TLandrixGaebXmlPerfDescr(SyntaxNode).HasDescription or
    (TLandrixGaebXmlPerfDescr(SyntaxNode).Description.Count = 0) then
    Exit;
  D := TLandrixGaebXmlPerfDescr(SyntaxNode).Description[0];
  if D.HasCompleteText then
    AComplete := D.CompleteText;
  if D.HasOutlineText then
    AOutline := D.OutlineText;
end;

function TLandrixGaebPerfDescr.PerfNo: TLandrixGaebString;
begin
  Result := TLandrixGaebXmlPerfDescr(SyntaxNode).PerfNo;
end;

function TLandrixGaebPerfDescr.PerfLbl: TLandrixGaebString;
begin
  Result := TLandrixGaebXmlPerfDescr(SyntaxNode).PerfLbl;
end;

{ TLandrixGaebTotals }

constructor TLandrixGaebTotals.Create(ABill: TLandrixGaebBillOfQuantities; AOwner: TLandrixGaebXmlNode);
begin
  inherited Create;
  FBill := ABill;
  FOwner := AOwner;
end;

function TLandrixGaebTotals.SyntaxNode: TLandrixGaebXmlTotals;
var
  Info: TLandrixGaebXmlBoQInfo;
begin
  Result := nil;
  if FOwner is TLandrixGaebXmlBoQCtgy then
  begin
    if TLandrixGaebXmlBoQCtgy(FOwner).HasTotals then
      Result := TLandrixGaebXmlBoQCtgy(FOwner).Totals;
  end
  else if FOwner is TLandrixGaebXmlLotGrp then
  begin
    if TLandrixGaebXmlLotGrp(FOwner).HasTotals then
      Result := TLandrixGaebXmlLotGrp(FOwner).Totals;
  end
  else
  begin
    Info := FBill.Info;
    if (Info <> nil) and Info.HasTotals then
      Result := Info.Totals;
  end;
end;

function TLandrixGaebTotals.Ensure: TLandrixGaebXmlTotals;
begin
  if FOwner is TLandrixGaebXmlBoQCtgy then
    Result := TLandrixGaebXmlBoQCtgy(FOwner).Totals
  else if FOwner is TLandrixGaebXmlLotGrp then
    Result := TLandrixGaebXmlLotGrp(FOwner).Totals
  else
    Result := FBill.Document.Award.BoQ.BoQInfo.Totals;
end;

function TLandrixGaebTotals.Exists: Boolean;
begin
  Result := SyntaxNode <> nil;
end;

function TLandrixGaebTotals.Value(AField: TLandrixGaebTotalField): TLandrixGaebDecimal;
var
  T: TLandrixGaebXmlTotals;
begin
  Result.Clear;
  T := SyntaxNode;
  if T = nil then
    Exit;
  case AField of
    gtfTotal: Result := T.Total;
    gtfDiscountPcnt: Result := T.DiscountPcnt;
    gtfDiscountAmt: Result := T.DiscountAmt;
    gtfTotAfterDisc: Result := T.TotAfterDisc;
    gtfTotalLSUM: Result := T.TotalLSUM;
    gtfVAT: Result := T.VAT;
    gtfTotalNet: Result := T.TotalNet;
    gtfVATAmount: Result := T.VATAmount;
  else
    Result := T.TotalGross;
  end;
end;

procedure SetTotalsField(T: TLandrixGaebXmlTotals; AField: TLandrixGaebTotalField; const AValue: TLandrixGaebDecimal);
begin
  case AField of
    gtfTotal: T.Total := AValue;
    gtfDiscountPcnt: T.DiscountPcnt := AValue;
    gtfDiscountAmt: T.DiscountAmt := AValue;
    gtfTotAfterDisc: T.TotAfterDisc := AValue;
    gtfTotalLSUM: T.TotalLSUM := AValue;
    gtfVAT: T.VAT := AValue;
    gtfTotalNet: T.TotalNet := AValue;
    gtfVATAmount: T.VATAmount := AValue;
  else
    T.TotalGross := AValue;
  end;
end;

procedure TLandrixGaebTotals.SetValue(AField: TLandrixGaebTotalField; const AValue: TLandrixGaebDecimal);
begin
  SetTotalsField(Ensure, AField, AValue);
end;

procedure TLandrixGaebTotals.ClearValue(AField: TLandrixGaebTotalField);
var
  T: TLandrixGaebXmlTotals;
begin
  T := SyntaxNode;
  if T <> nil then
    SetTotalsField(T, AField, NoValue);
end;

function TLandrixGaebTotals.Amount: TLandrixGaebDecimal;
var
  T: TLandrixGaebXmlTotals;
begin
  Result.Clear;
  T := SyntaxNode;
  if T = nil then
    Exit;
  if T.TotAfterDisc.HasValue then
    Result := T.TotAfterDisc
  else if T.TotalLSUM.HasValue then
    Result := T.TotalLSUM
  else
    Result := T.Total;
end;

function TLandrixGaebTotals.UPCompTotal(ANumber: Integer): TLandrixGaebDecimal;
var
  T: TLandrixGaebXmlTotals;
  C: TLandrixGaebXmlTotalNetUpComp;
begin
  CheckComp(ANumber);
  Result.Clear;
  T := SyntaxNode;
  if (T = nil) or not T.HasTotalNetUpComp then
    Exit;
  C := T.TotalNetUpComp;
  case ANumber of
    1: Result := C.UpComp1;
    2: Result := C.UpComp2;
    3: Result := C.UpComp3;
    4: Result := C.UpComp4;
    5: Result := C.UpComp5;
  else
    Result := C.UpComp6;
  end;
end;

function TLandrixGaebTotals.VATPartCount: Integer;
var
  T: TLandrixGaebXmlTotals;
begin
  Result := 0;
  T := SyntaxNode;
  if (T <> nil) and T.HasVATPart then
    Result := Integer(T.VATPart.Count);
end;

function TLandrixGaebTotals.VATParts(AIndex: Integer): TLandrixGaebVATPart;
var
  P: TLandrixGaebXmlVATPart;
begin
  CheckIndex(AIndex, VATPartCount);
  P := SyntaxNode.VATPart[AIndex];
  Result.TotalNet := P.TotalNetPart;
  Result.VATAmount := P.VATAmount;
  Result.VATPcnt := P.VATPcnt;
end;

{ TLandrixGaebLotGroup }

constructor TLandrixGaebLotGroup.Create(ABill: TLandrixGaebBillOfQuantities; ASyntaxNode: TLandrixGaebXmlLotGrp);
begin
  inherited Create;
  FBill := ABill;
  FSyntaxNode := ASyntaxNode;
  FTotals := TLandrixGaebTotals.Create(ABill, ASyntaxNode);
end;

destructor TLandrixGaebLotGroup.Destroy;
begin
  FTotals.Free;
  inherited Destroy;
end;

function TLandrixGaebLotGroup.Number: TLandrixGaebString;
begin
  Result := FSyntaxNode.LotGrNo;
end;

function TLandrixGaebLotGroup.LotCount: Integer;
begin
  Result := 0;
  if FSyntaxNode.HasRefLotNo then
    Result := Integer(FSyntaxNode.RefLotNo.Count);
end;

function TLandrixGaebLotGroup.Lots(AIndex: Integer): TLandrixGaebReference;
begin
  CheckIndex(AIndex, LotCount);
  Result := FBill.Resolve(FSyntaxNode.RefLotNo[AIndex].IDRef, [gnkCategory]);
end;

{ TLandrixGaebParty }

constructor TLandrixGaebParty.Create(ABill: TLandrixGaebBillOfQuantities; ARole: TLandrixGaebPartyRole;
  AIndex: Integer);
begin
  inherited Create;
  FBill := ABill;
  FRole := ARole;
  FIndex := AIndex;
end;

function TLandrixGaebParty.Requester: TLandrixGaebXmlRequester;
var
  D: TLandrixGaebXmlGAEB;
begin
  Result := nil;
  D := FBill.Document;
  if (FRole = gprRequester) and D.HasAward and D.Award.HasRequester and (FIndex >= 0) and
    (FIndex < Integer(D.Award.Requester.Count)) then
    Result := D.Award.Requester[FIndex];
end;

function TLandrixGaebParty.Address(ACreate: Boolean): TLandrixGaebXmlAddress;
var
  D: TLandrixGaebXmlGAEB;
  R: TLandrixGaebXmlRequester;
begin
  Result := nil;
  D := FBill.Document;
  if FRole = gprRequester then
  begin
    R := Requester;
    if R = nil then
    begin
      if ACreate then
        raise ELandrixGaebError.Create('the requester is not in the document');
      Exit;
    end;
    if ACreate or R.HasAddress then
      Result := R.Address;
    Exit;
  end;
  if not ACreate then
  begin
    if not D.HasAward then
      Exit;
    if FRole = gprOwner then
    begin
      if D.Award.HasOWN and D.Award.OWN.HasAddress then
        Result := D.Award.OWN.Address;
    end
    else if D.Award.HasCTR and D.Award.CTR.HasAddress then
      Result := D.Award.CTR.Address;
    Exit;
  end;
  if FRole = gprOwner then
    Result := D.Award.OWN.Address
  else
    Result := D.Award.CTR.Address;
end;

function TLandrixGaebParty.Exists: Boolean;
begin
  Result := Address(False) <> nil;
end;

function TLandrixGaebParty.GetField(AIndex: Integer): TLandrixGaebString;
var
  A: TLandrixGaebXmlAddress;
  R: TLandrixGaebXmlRequester;
begin
  Result := '';
  if AIndex >= 13 then
  begin
    R := Requester;
    if R = nil then
      Exit;
    if AIndex = 13 then
      Result := R.RequestIDNo
    else
      Result := R.RequestName;
    Exit;
  end;
  A := Address(False);
  if A = nil then
    Exit;
  case AIndex of
    0: Result := A.Name1;
    1: Result := A.Name2;
    2: Result := A.Name3;
    3: Result := A.Name4;
    4: Result := A.Street;
    5: Result := A.PCode;
    6: Result := A.City;
    7: Result := A.Country;
    8: Result := A.Contact;
    9: Result := A.Phone;
    10: Result := A.Fax;
    11: Result := A.Email;
  else
    Result := A.VATID;
  end;
end;

procedure TLandrixGaebParty.SetField(AIndex: Integer; const AValue: TLandrixGaebString);
var
  A: TLandrixGaebXmlAddress;
  R: TLandrixGaebXmlRequester;
begin
  if AIndex >= 13 then
  begin
    R := Requester;
    if R = nil then
      raise ELandrixGaebError.Create('RequestIDNo and RequestName belong to a requester in the document');
    if AIndex = 13 then
      R.RequestIDNo := AValue
    else
      R.RequestName := AValue;
    Exit;
  end;
  A := Address(True);
  case AIndex of
    0: A.Name1 := AValue;
    1: A.Name2 := AValue;
    2: A.Name3 := AValue;
    3: A.Name4 := AValue;
    4: A.Street := AValue;
    5: A.PCode := AValue;
    6: A.City := AValue;
    7: A.Country := AValue;
    8: A.Contact := AValue;
    9: A.Phone := AValue;
    10: A.Fax := AValue;
    11: A.Email := AValue;
  else
    A.VATID := AValue;
  end;
end;

{ TLandrixGaebBillOfQuantities }

constructor TLandrixGaebBillOfQuantities.Create(ADocument: TLandrixGaebXmlGAEB;
  const ATarget: TLandrixGaebTarget; AOwnsDocument: Boolean);
begin
  inherited Create;
  FDocument := ADocument;
  FTarget := ATarget;
  FOwnsDocument := AOwnsDocument;
  FNodes := TObjectList.Create;
  FRoot := TLandrixGaebNodeList.Create;
  FAllItems := TLandrixGaebNodeList.Create;
  FOwner := TLandrixGaebParty.Create(Self, gprOwner, 0);
  FContractor := TLandrixGaebParty.Create(Self, gprContractor, 0);
  FTotals := TLandrixGaebTotals.Create(Self, nil);
  FWriteOptions := LandrixGaebXmlDefaultWriteOptions;
  Build(TLandrixGaebTree.Create(FDocument), nil);
end;

destructor TLandrixGaebBillOfQuantities.Destroy;
begin
  ClearViews;
  FTotals.Free;
  FContractor.Free;
  FOwner.Free;
  FAllItems.Free;
  FRoot.Free;
  FNodes.Free;
  if FOwnsDocument then
    FDocument.Free;
  inherited Destroy;
end;

procedure TLandrixGaebBillOfQuantities.ClearViews;
begin
  if FNodes <> nil then
    FNodes.Clear;
  if FRoot <> nil then
    FRoot.FList.Clear;
  if FAllItems <> nil then
    FAllItems.FList.Clear;
  FRequesters.Free;
  FRequesters := nil;
  FLotGroups.Free;
  FLotGroups := nil;
  FIds.Free;
  FIds := nil;
  FOtherId.Free;
  FOtherId := nil;
  FTree.Free;
  FTree := nil;
end;

{ Builds the views over ATree (taken over by the bill); with AOld the
  views of the elements that are still there are reused. }
procedure TLandrixGaebBillOfQuantities.Build(ATree: TObject; AOld: TObjectList);
var
  Tree: TLandrixGaebTree;
  I, Cur: Integer;
  T: TLandrixGaebTreeNode;
  Views: TObjectList;
  Parent: TLandrixGaebCategory;
  V: TLandrixGaebNode;
begin
  Tree := TLandrixGaebTree(ATree);
  FTree := Tree;
  Cur := 0;
  Views := TObjectList.Create(False);
  try
    { tree node -> view, by the position of the tree node (Order - 1) }
    for I := 0 to Integer(Tree.Nodes.Count) - 1 do
    begin
      T := TLandrixGaebTreeNode(Tree.Nodes[I]);
      Parent := nil;
      if (T.Parent <> nil) and (T.Parent <> Tree.Root) then
        Parent := TLandrixGaebCategory(Views[T.Parent.Order - 1]);
      if (AOld <> nil) and (Cur < Integer(AOld.Count)) and (TLandrixGaebNode(AOld[Cur]).SyntaxNode = T.Node) then
      begin
        { the element is still there: keep its view }
        V := TLandrixGaebNode(AOld[Cur]);
        AOld[Cur] := nil;
        Inc(Cur);
        V.FParent := Parent;
        V.FTreeNode := T;
        if V is TLandrixGaebCategory then
          TLandrixGaebCategory(V).Children.FList.Clear;
      end
      else
        case T.Kind of
          LandrixGaebTreeCtgy:
            V := TLandrixGaebCategory.Create(Self, Parent, TLandrixGaebXmlBoQCtgy(T.Node), T);
          LandrixGaebTreeItem:
            V := TLandrixGaebItem.Create(Self, gnkItem, Parent, T.Node, T);
          LandrixGaebTreeMarkup:
            V := TLandrixGaebMarkupItem.Create(Self, gnkMarkupItem, Parent, T.Node, T);
          LandrixGaebTreeRemark:
            V := TLandrixGaebRemark.Create(Self, gnkRemark, Parent, T.Node, T);
        else
          V := TLandrixGaebPerfDescr.Create(Self, gnkPerfDescr, Parent, T.Node, T);
        end;
      FNodes.Add(V);
      Views.Add(V);
      if Parent = nil then
        FRoot.Add(V)
      else
        Parent.Children.Add(V);
      if V.Kind in [gnkItem, gnkMarkupItem] then
        FAllItems.Add(V);
    end;
  finally
    Views.Free;
  end;
end;

procedure TLandrixGaebBillOfQuantities.Refresh;
begin
  ClearViews;
  Build(TLandrixGaebTree.Create(FDocument), nil);
end;

{ Rebuilds the tree after AddCategory, AddItem or Remove, keeping the view
  objects of all elements that are still there. Neither operation moves an
  element, so the remaining views are in the order of the new tree (Build
  matches them in one pass). }
procedure TLandrixGaebBillOfQuantities.Rebuild;
var
  Old: TObjectList;
  I: Integer;
  Tree: TObject;
begin
  { the new tree first; if it fails (out of memory), all views are freed
    as by Refresh, so that none points to a removed element }
  try
    Tree := TLandrixGaebTree.Create(FDocument);
  except
    ClearViews;
    raise;
  end;
  Old := TObjectList.Create(False);
  try
    FNodes.OwnsObjects := False;
    for I := 0 to Integer(FNodes.Count) - 1 do
      Old.Add(FNodes[I]);
    FNodes.Clear;
    FNodes.OwnsObjects := True;
    FRoot.FList.Clear;
    FAllItems.FList.Clear;
    FIds.Free;
    FIds := nil;
    FOtherId.Free;
    FOtherId := nil;
    FTree.Free;
    FTree := nil;
    try
      Build(Tree, Old);
    finally
      { views whose element is gone (Build sets the reused ones to nil) }
      for I := 0 to Integer(Old.Count) - 1 do
        Old[I].Free;
    end;
  finally
    Old.Free;
  end;
end;

function TLandrixGaebBillOfQuantities.Body(AParent: TLandrixGaebCategory): TLandrixGaebXmlBoQBody;
begin
  if AParent = nil then
    Result := FDocument.Award.BoQ.BoQBody
  else
  begin
    if AParent.Bill <> Self then
      raise ELandrixGaebError.Create('the category belongs to another bill');
    Result := AParent.Ctgy.BoQBody;
  end;
end;

function TLandrixGaebBillOfQuantities.NewId(const APrefix: TLandrixGaebString): TLandrixGaebString;
begin
  repeat
    Inc(FNextId);
    Result := APrefix + LandrixXmlUtf8ToWide(LandrixXmlStringToUtf8(IntToStr(FNextId)));
  until Resolve(Result, []).Status = grsNotFound;
end;

function TLandrixGaebBillOfQuantities.ViewOf(ASyntaxNode: TLandrixGaebXmlNode): TLandrixGaebNode;
var
  I: Integer;
begin
  for I := 0 to Integer(FNodes.Count) - 1 do
  begin
    Result := TLandrixGaebNode(FNodes[I]);
    if Result.SyntaxNode = ASyntaxNode then
      Exit;
  end;
  raise ELandrixGaebError.Create('internal: no view of the new element');
end;

function HasCategoryChildren(ABody: TLandrixGaebXmlBoQBody): Boolean;
begin
  Result := ABody.HasChildren;
end;

function TLandrixGaebBillOfQuantities.AddCategory(AParent: TLandrixGaebCategory;
  const ARNoPart, ALbl: TLandrixGaebString): TLandrixGaebCategory;
var
  B: TLandrixGaebXmlBoQBody;
  C: TLandrixGaebXmlBoQCtgy;
  Id: TLandrixGaebString;
begin
  B := Body(AParent);
  if B.HasItemlist then
    raise ELandrixGaebError.Create('a category body with items takes no category');
  Id := NewId('LGC');
  C := B.AddBoQCtgy;
  C.ID := Id;
  C.RNoPart := ARNoPart;
  SetMLText(C.LblTx, ALbl);
  Rebuild;
  Result := ViewOf(C) as TLandrixGaebCategory;
end;

function TLandrixGaebBillOfQuantities.AddItem(AParent: TLandrixGaebCategory;
  const ARNoPart: TLandrixGaebString): TLandrixGaebItem;
var
  B: TLandrixGaebXmlBoQBody;
  It: TLandrixGaebXmlItem;
  Id: TLandrixGaebString;
begin
  B := Body(AParent);
  if HasCategoryChildren(B) then
    raise ELandrixGaebError.Create('a category body with categories takes no item');
  Id := NewId('LGI');
  { an item list made here stays when its last item is removed again }
  B.Itemlist.Present := True;
  It := B.Itemlist.AddItem;
  It.ID := Id;
  It.RNoPart := ARNoPart;
  Rebuild;
  Result := ViewOf(It) as TLandrixGaebItem;
end;

{ Frees the views of ANode and everything in it (taken out of ANodes). }
procedure FreeViews(ANodes: TObjectList; ANode: TLandrixGaebNode);
var
  I: Integer;
begin
  if ANode is TLandrixGaebCategory then
    for I := TLandrixGaebCategory(ANode).Children.Count - 1 downto 0 do
      FreeViews(ANodes, TLandrixGaebCategory(ANode).Children[I]);
  I := Integer(ANodes.IndexOf(ANode));
  if I >= 0 then
    ANodes.Delete(I);
end;

procedure TLandrixGaebBillOfQuantities.Remove(ANode: TLandrixGaebNode);
var
  B: TLandrixGaebXmlBoQBody;
  E: TLandrixGaebXmlNode;
  I: Integer;
begin
  if (ANode = nil) or (ANode.Bill <> Self) then
    raise ELandrixGaebError.Create('the node belongs to another bill');
  B := Body(ANode.Parent);
  E := ANode.SyntaxNode;
  FreeViews(FNodes, ANode);
  I := -1;
  if B.HasItemlist then
    I := Integer(B.Itemlist.Children.IndexOf(E));
  if I >= 0 then
    B.Itemlist.Children.Delete(I)
  else
  begin
    I := Integer(B.Children.IndexOf(E));
    if I < 0 then
      raise ELandrixGaebError.Create('internal: element not in its body');
    B.Children.Delete(I);
  end;
  Rebuild;
end;

function TLandrixGaebBillOfQuantities.FindByOZ(const AOZ, AIndex: TLandrixGaebString; ACategory: Boolean;
  out ANode: TLandrixGaebNode): TLandrixGaebFindResult;
var
  Key, Part: TLandrixGaebString;
  I, P: Integer;
  V: TLandrixGaebNode;
  Rest: TLandrixGaebString;
begin
  { the key as the tree builds it: parts by LandrixGaebKeyPart }
  Key := '';
  Rest := AOZ;
  repeat
    P := Pos('.', Rest);
    if P > 0 then
    begin
      Part := Copy(Rest, 1, P - 1);
      Rest := Copy(Rest, P + 1, MaxInt);
    end
    else
    begin
      Part := Rest;
      Rest := '';
    end;
    if Key <> '' then
      Key := Key + '.';
    Key := Key + LandrixGaebKeyPart(Part);
  until P = 0;
  if AIndex <> '' then
    Key := Key + '#' + AIndex;
  ANode := nil;
  Result := gfrNotFound;
  for I := 0 to Integer(FNodes.Count) - 1 do
  begin
    V := TLandrixGaebNode(FNodes[I]);
    if (V.Kind = gnkCategory) <> ACategory then
      Continue;
    if not (V.Kind in [gnkCategory, gnkItem, gnkMarkupItem]) then
      Continue;
    if TreeNodeOf(V.FTreeNode).Key <> Key then
      Continue;
    if ANode = nil then
    begin
      ANode := V;
      Result := gfrFound;
    end
    else
    begin
      Result := gfrAmbiguous;
      Exit;
    end;
  end;
end;

function TLandrixGaebBillOfQuantities.GetProjectName: TLandrixGaebString;
begin
  Result := '';
  if FDocument.HasPrjInfo then
    Result := FDocument.PrjInfo.NamePrj;
end;

procedure TLandrixGaebBillOfQuantities.SetProjectName(const AValue: TLandrixGaebString);
begin
  FDocument.PrjInfo.NamePrj := AValue;
end;

function TLandrixGaebBillOfQuantities.BoQName: TLandrixGaebString;
begin
  Result := '';
  if FDocument.HasAward and FDocument.Award.HasBoQ and FDocument.Award.BoQ.HasBoQInfo then
    Result := FDocument.Award.BoQ.BoQInfo.Name;
end;

function TLandrixGaebBillOfQuantities.Currency: TLandrixGaebString;
begin
  Result := '';
  if FDocument.HasAward and FDocument.Award.HasAwardInfo then
    Result := FDocument.Award.AwardInfo.Cur;
  if (Result = '') and FDocument.HasPrjInfo then
    Result := FDocument.PrjInfo.Cur;
end;

function IntOrMinusOne(const S: TLandrixGaebString): Integer;
begin
  Result := StrToIntDef(Trim(LandrixXmlUtf8ToString(LandrixXmlWideToUtf8(S))), -1);
end;

function TLandrixGaebBillOfQuantities.UPFracDig: Integer;
begin
  Result := -1;
  if FDocument.HasPrjInfo then
    Result := IntOrMinusOne(FDocument.PrjInfo.UPFracDig);
end;

function TLandrixGaebBillOfQuantities.NoUPComps: Integer;
begin
  Result := -1;
  if FDocument.HasAward and FDocument.Award.HasBoQ and FDocument.Award.BoQ.HasBoQInfo then
    Result := IntOrMinusOne(FDocument.Award.BoQ.BoQInfo.NoUPComps);
end;

function TLandrixGaebBillOfQuantities.UPCompLabel(ANumber: Integer): TLandrixGaebString;
var
  Info: TLandrixGaebXmlBoQInfo;
begin
  CheckComp(ANumber);
  Result := '';
  if not (FDocument.HasAward and FDocument.Award.HasBoQ and FDocument.Award.BoQ.HasBoQInfo) then
    Exit;
  Info := FDocument.Award.BoQ.BoQInfo;
  case ANumber of
    1: if Info.HasLblUPComp1 then Result := Info.LblUPComp1.Value;
    2: if Info.HasLblUPComp2 then Result := Info.LblUPComp2.Value;
    3: if Info.HasLblUPComp3 then Result := Info.LblUPComp3.Value;
    4: if Info.HasLblUPComp4 then Result := Info.LblUPComp4.Value;
    5: if Info.HasLblUPComp5 then Result := Info.LblUPComp5.Value;
  else
    if Info.HasLblUPComp6 then
      Result := Info.LblUPComp6.Value;
  end;
end;

function TLandrixGaebBillOfQuantities.Total: TLandrixGaebDecimal;
begin
  Result := FTotals.Amount;
end;

function TLandrixGaebBillOfQuantities.Info: TLandrixGaebXmlBoQInfo;
begin
  Result := nil;
  if FDocument.HasAward and FDocument.Award.HasBoQ and FDocument.Award.BoQ.HasBoQInfo then
    Result := FDocument.Award.BoQ.BoQInfo;
end;

{ The ID of an element of the tree ('' if it has none). }
function SyntaxID(ANode: TLandrixGaebXmlNode): TLandrixGaebString;
begin
  Result := '';
  if ANode is TLandrixGaebXmlBoQCtgy then
    Result := TLandrixGaebXmlBoQCtgy(ANode).ID
  else if ANode is TLandrixGaebXmlItem then
    Result := TLandrixGaebXmlItem(ANode).ID
  else if ANode is TLandrixGaebXmlMarkupItem then
    Result := TLandrixGaebXmlMarkupItem(ANode).ID
  else if ANode is TLandrixGaebXmlPerfDescr then
    Result := TLandrixGaebXmlPerfDescr(ANode).ID
  else if ANode is TLandrixGaebXmlRemark then
    Result := TLandrixGaebXmlRemark(ANode).ID;
end;

type
  { Collects the IDs of the text complements of a text. }
  TIdCollector = class(TLandrixGaebTextVisitor)
  private
    FIds: TLandrixGaebKeyIndex;
    FOther: TLandrixGaebTreeNode;
  public
    procedure Visit(const AEvent: TLandrixGaebTextEvent); override;
  end;

procedure TIdCollector.Visit(const AEvent: TLandrixGaebTextEvent);
begin
  if (AEvent.Kind = gteComplement) and (TLandrixGaebXmlTextComplement(AEvent.Node).ID <> '') then
    FIds.Add(TLandrixGaebXmlTextComplement(AEvent.Node).ID, FOther);
end;

procedure AddOtherId(AIds: TLandrixGaebKeyIndex; AOther: TLandrixGaebTreeNode; const AID: TLandrixGaebString);
begin
  if AID <> '' then
    AIds.Add(AID, AOther);
end;

{ IDs of a description and of the text complements of its texts. }
procedure AddDescriptionIds(AIds: TLandrixGaebKeyIndex; AOther: TLandrixGaebTreeNode;
  ACollector: TIdCollector; const AID: TLandrixGaebString; C: TLandrixGaebXmlCompleteText;
  O: TLandrixGaebXmlOutlineText);
begin
  AddOtherId(AIds, AOther, AID);
  VisitNode(DetailOf(C), ACollector);
  { both outline texts, also when a faulty file has both }
  if (C <> nil) and C.HasOutlineText and C.OutlineText.HasOutlTxt then
    VisitNode(C.OutlineText.OutlTxt, ACollector);
  if (O <> nil) and O.HasOutlTxt then
    VisitNode(O.OutlTxt, ACollector);
end;

{ All IDs of the bill: the nodes with their tree nodes; every other element
  (BoQ, lot groups, descriptions, quantity determination, text
  complements) with AOther, which stands for "an element of another kind". }
procedure CollectIds(ABill: TLandrixGaebBillOfQuantities; ANodes: TObjectList; AIds: TLandrixGaebKeyIndex;
  AOther: TLandrixGaebTreeNode);
var
  I, K: Integer;
  V: TLandrixGaebNode;
  D: TLandrixGaebXmlDescription;
  BoQ: TLandrixGaebXmlBoQ;
  Coll: TIdCollector;
  C: TLandrixGaebXmlCompleteText;
  O: TLandrixGaebXmlOutlineText;
  Item: TLandrixGaebXmlItem;
  Perf: TLandrixGaebXmlPerfDescr;
begin
  Coll := TIdCollector.Create;
  try
    Coll.FIds := AIds;
    Coll.FOther := AOther;
    for I := 0 to Integer(ANodes.Count) - 1 do
    begin
      V := TLandrixGaebNode(ANodes[I]);
      if SyntaxID(V.SyntaxNode) <> '' then
        AIds.Add(SyntaxID(V.SyntaxNode), TreeNodeOf(V.FTreeNode));
      D := nil;
      if V.SyntaxNode is TLandrixGaebXmlItem then
      begin
        Item := TLandrixGaebXmlItem(V.SyntaxNode);
        if Item.HasDescription then
          D := Item.Description;
        if Item.HasSubDescr then
          for K := 0 to Integer(Item.SubDescr.Count) - 1 do
            if Item.SubDescr[K].HasDescription then
            begin
              DescriptionTexts(Item.SubDescr[K].Description, C, O);
              AddDescriptionIds(AIds, AOther, Coll, Item.SubDescr[K].Description.ID, C, O);
            end;
      end
      else if V.SyntaxNode is TLandrixGaebXmlMarkupItem then
      begin
        if TLandrixGaebXmlMarkupItem(V.SyntaxNode).HasDescription then
          D := TLandrixGaebXmlMarkupItem(V.SyntaxNode).Description;
      end
      else if V.SyntaxNode is TLandrixGaebXmlRemark then
      begin
        if TLandrixGaebXmlRemark(V.SyntaxNode).HasDescription then
          D := TLandrixGaebXmlRemark(V.SyntaxNode).Description;
      end
      else if V.SyntaxNode is TLandrixGaebXmlPerfDescr then
      begin
        Perf := TLandrixGaebXmlPerfDescr(V.SyntaxNode);
        if Perf.HasDescription then
          for K := 0 to Integer(Perf.Description.Count) - 1 do
          begin
            C := nil;
            O := nil;
            if Perf.Description[K].HasCompleteText then
              C := Perf.Description[K].CompleteText;
            if Perf.Description[K].HasOutlineText then
              O := Perf.Description[K].OutlineText;
            AddDescriptionIds(AIds, AOther, Coll, Perf.Description[K].ID, C, O);
          end;
      end;
      if D <> nil then
      begin
        DescriptionTexts(D, C, O);
        AddDescriptionIds(AIds, AOther, Coll, D.ID, C, O);
      end;
    end;
  finally
    Coll.Free;
  end;
  if ABill.Document.HasAward and ABill.Document.Award.HasBoQ then
  begin
    BoQ := ABill.Document.Award.BoQ;
    AddOtherId(AIds, AOther, BoQ.ID);
    if BoQ.HasLotGrp then
      for I := 0 to Integer(BoQ.LotGrp.Count) - 1 do
        AddOtherId(AIds, AOther, BoQ.LotGrp[I].ID);
    if BoQ.HasBoQInfo and BoQ.BoQInfo.HasQtyDetermInfo then
      AddOtherId(AIds, AOther, BoQ.BoQInfo.QtyDetermInfo.ID);
  end;
  AIds.Sort;
end;

function TLandrixGaebBillOfQuantities.Resolve(const AIDRef: TLandrixGaebString;
  AKinds: TLandrixGaebNodeKinds): TLandrixGaebReference;
var
  Ids: TLandrixGaebKeyIndex;
  I: Integer;
  T: TLandrixGaebTreeNode;
  V: TLandrixGaebNode;
begin
  if FIds = nil then
  begin
    FOtherId := TLandrixGaebTreeNode.Create;
    FIds := TLandrixGaebKeyIndex.Create;
    CollectIds(Self, FNodes, TLandrixGaebKeyIndex(FIds), TLandrixGaebTreeNode(FOtherId));
  end;
  Ids := TLandrixGaebKeyIndex(FIds);
  Result.IDRef := AIDRef;
  Result.Node := nil;
  I := Ids.IndexOf(AIDRef);
  if I < 0 then
  begin
    Result.Status := grsNotFound;
    Exit;
  end;
  if (I + 1 < Ids.Count) and (Ids.Key(I + 1) = AIDRef) then
  begin
    Result.Status := grsAmbiguous;
    Exit;
  end;
  T := Ids.Node(I);
  Result.Status := grsWrongKind;
  if T = FOtherId then
    Exit;
  V := TLandrixGaebNode(FNodes[T.Order - 1]);
  if V.Kind in AKinds then
  begin
    Result.Status := grsResolved;
    Result.Node := V;
  end;
end;

function TLandrixGaebBillOfQuantities.RequesterCount: Integer;
var
  I: Integer;
begin
  if FRequesters = nil then
  begin
    FRequesters := TObjectList.Create;
    if FDocument.HasAward and FDocument.Award.HasRequester then
      for I := 0 to Integer(FDocument.Award.Requester.Count) - 1 do
        FRequesters.Add(TLandrixGaebParty.Create(Self, gprRequester, I));
  end;
  Result := Integer(FRequesters.Count);
end;

function TLandrixGaebBillOfQuantities.Requesters(AIndex: Integer): TLandrixGaebParty;
begin
  CheckIndex(AIndex, RequesterCount);
  Result := TLandrixGaebParty(FRequesters[AIndex]);
end;

function TLandrixGaebBillOfQuantities.GetAwardField(AIndex: Integer): TLandrixGaebString;
var
  A: TLandrixGaebXmlAwardInfo;
begin
  Result := '';
  if not (FDocument.HasAward and FDocument.Award.HasAwardInfo) then
    Exit;
  A := FDocument.Award.AwardInfo;
  case AIndex of
    0: Result := A.ContrNo;
    1: Result := A.ContrDate;
    2: Result := A.BidDate;
    3: Result := A.CnstStart;
  else
    Result := A.CnstEnd;
  end;
end;

procedure TLandrixGaebBillOfQuantities.SetAwardField(AIndex: Integer; const AValue: TLandrixGaebString);
var
  A: TLandrixGaebXmlAwardInfo;
begin
  A := FDocument.Award.AwardInfo;
  case AIndex of
    0: A.ContrNo := AValue;
    1: A.ContrDate := AValue;
    2: A.BidDate := AValue;
    3: A.CnstStart := AValue;
  else
    A.CnstEnd := AValue;
  end;
end;

function TLandrixGaebBillOfQuantities.BreakdownCount: Integer;
begin
  Result := 0;
  if (Info <> nil) and Info.HasBoQBkdn then
    Result := Integer(Info.BoQBkdn.Count);
end;

function TLandrixGaebBillOfQuantities.Breakdowns(AIndex: Integer): TLandrixGaebBreakdown;
var
  B: TLandrixGaebXmlBoQBkdn;
begin
  CheckIndex(AIndex, BreakdownCount);
  B := Info.BoQBkdn[AIndex];
  if B.TypeElement = 'Lot' then
    Result.Kind := gbkLot
  else if B.TypeElement = 'BoQLevel' then
    Result.Kind := gbkLevel
  else if B.TypeElement = 'Item' then
    Result.Kind := gbkItem
  else if B.TypeElement = 'Index' then
    Result.Kind := gbkIndex
  else
    Result.Kind := gbkUnrecognized;
  Result.Lbl := B.LblBoQBkdn;
  Result.Length := IntOrMinusOne(B.LengthElement);
  Result.Numeric := YesOf(B.Num);
  Result.Alignment := B.Alignment;
end;

function TLandrixGaebBillOfQuantities.HasLots: Boolean;
begin
  Result := (BreakdownCount > 0) and (Info.BoQBkdn[0].TypeElement = 'Lot');
end;

function TLandrixGaebBillOfQuantities.LotGroupCount: Integer;
var
  I: Integer;
begin
  if FLotGroups = nil then
  begin
    FLotGroups := TObjectList.Create;
    if FDocument.HasAward and FDocument.Award.HasBoQ and FDocument.Award.BoQ.HasLotGrp then
      for I := 0 to Integer(FDocument.Award.BoQ.LotGrp.Count) - 1 do
        FLotGroups.Add(TLandrixGaebLotGroup.Create(Self, FDocument.Award.BoQ.LotGrp[I]));
  end;
  Result := Integer(FLotGroups.Count);
end;

function TLandrixGaebBillOfQuantities.LotGroups(AIndex: Integer): TLandrixGaebLotGroup;
begin
  CheckIndex(AIndex, LotGroupCount);
  Result := TLandrixGaebLotGroup(FLotGroups[AIndex]);
end;

class function TLandrixGaebBillOfQuantities.LoadFromFile(const AFileName: string;
  ADiagnostics: TLandrixGaebDiagnostics; AMaxSize: Int64): TLandrixGaebBillOfQuantities;
var
  Doc: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
begin
  Doc := LandrixGaebXmlReadFile(AFileName, ADiagnostics, AMaxSize, Det);
  Result := TLandrixGaebBillOfQuantities.Create(Doc, Det.Target, True);
end;

class function TLandrixGaebBillOfQuantities.LoadFromStream(AStream: TStream;
  ADiagnostics: TLandrixGaebDiagnostics; AMaxSize: Int64): TLandrixGaebBillOfQuantities;
var
  Doc: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
begin
  Doc := LandrixGaebXmlReadStream(AStream, ADiagnostics, AMaxSize, Det);
  Result := TLandrixGaebBillOfQuantities.Create(Doc, Det.Target, True);
end;

procedure TLandrixGaebBillOfQuantities.SaveToFile(const AFileName: string; ADiagnostics: TLandrixGaebDiagnostics);
begin
  LandrixGaebXmlWriteFile(FDocument, FTarget, AFileName, FWriteOptions, ADiagnostics);
end;

procedure TLandrixGaebBillOfQuantities.SaveToStream(AStream: TStream; ADiagnostics: TLandrixGaebDiagnostics);
begin
  LandrixGaebXmlWriteStream(FDocument, FTarget, AStream, FWriteOptions, ADiagnostics);
end;

end.

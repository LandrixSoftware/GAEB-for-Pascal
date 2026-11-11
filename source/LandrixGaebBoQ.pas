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

  The views are built by the constructor and by Refresh. A structural
  change made in the syntax model behind the facade (adding or removing a
  category or an item) needs Refresh, which frees all earlier views.

  DE: Fachliche Fassade ueber dem Syntaxmodell eines GAEB-DA-XML-Dokuments:
  das Leistungsverzeichnis als Baum aus Bereichen, Positionen,
  Zuschlagspositionen, Bemerkungen und Ausfuehrungsbeschreibungen mit
  Ordnungszahlen (OZ), Mengen, Preisen, Positionsarten, Parteien und Texten.
  Die Fassade haelt keine Kopie der Daten: jeder Wert wird aus dem
  Syntaxmodell (LandrixGaebXmlModel) gelesen und in es geschrieben, das die
  vollstaendige Quelle bleibt. Lesen ueber die Fassade aendert nichts von
  dem, was der Schreiber schreibt oder eine HasX-Funktion des Modells
  meldet; ein Setter aendert nur den Wert, den er nennt.

  Die Sichten entstehen im Konstruktor und durch Refresh. Eine
  Strukturaenderung im Syntaxmodell an der Fassade vorbei (Bereich oder
  Position hinzufuegen oder entfernen) braucht Refresh; Refresh gibt alle
  frueheren Sichten frei. }

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
  LandrixGaebXmlBase,
  LandrixGaebXmlModel;

type
  { Kind of a node of the bill. DE: Art eines Knotens des LV. }
  TLandrixGaebNodeKind = (gnkCategory, gnkItem, gnkMarkupItem, gnkRemark, gnkPerfDescr);

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

  TLandrixGaebBillOfQuantities = class;
  TLandrixGaebCategory = class;

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
    function Ctgy: TLandrixGaebXmlBoQCtgy;
  public
    { Created by the bill only. DE: Nur vom LV angelegt. }
    constructor Create(ABill: TLandrixGaebBillOfQuantities; AParent: TLandrixGaebCategory;
      ASyntaxNode: TLandrixGaebXmlBoQCtgy; ATreeNode: TObject);
    { Frees the view and its child list. DE: Gibt die Sicht und ihre
      Kinderliste frei. }
    destructor Destroy; override;
    { Children: categories, execution descriptions, remarks, then items and
      markup items. DE: Kinder: Bereiche, Ausfuehrungsbeschreibungen,
      Bemerkungen, dann Positionen und Zuschlagspositionen. }
    property Children: TLandrixGaebNodeList read FChildren;
    { Plain text of the label (LblTx). DE: Klartext der Bezeichnung
      (LblTx). }
    function Lbl: TLandrixGaebString;
    { Alternative category (ALNBGroupNo, ALNBSerNo other than 0).
      DE: Alternativbereich (ALNBGroupNo, ALNBSerNo ungleich 0). }
    function AlternativeGroup: TLandrixGaebString;
    function AlternativeSerial: TLandrixGaebString;
    function IsAlternative: Boolean;
    { NotApplBoQ. DE: NotApplBoQ. }
    function NotApplicable: Boolean;
    { Accepted (award). DE: Accepted (Auftrag). }
    function Accepted: TLandrixGaebString;
    { Total of the category (TotAfterDisc, else TotalLSUM, else Total);
      no value if absent. DE: Summe des Bereichs (TotAfterDisc, sonst
      TotalLSUM, sonst Total); ohne Wert, wenn nicht vorhanden. }
    function Total: TLandrixGaebDecimal;
    { Whether the category enters the totals of its parent. DE: Ob der
      Bereich in die Summe seines Elternknotens eingeht. }
    function CountStatus: TLandrixGaebCountStatus;
  end;

  { An item: quantities, prices, kinds and texts. Decimal values are read
    by the functions and written by SetX/ClearX (a value of the function
    is a copy). Values are never rounded.
    DE: Eine Position: Mengen, Preise, Arten und Texte. Dezimalwerte
    werden ueber die Funktionen gelesen und mit SetX/ClearX geschrieben
    (ein Wert der Funktion ist eine Kopie). Werte werden nie gerundet. }
  TLandrixGaebItem = class(TLandrixGaebNode)
  private
    function Item: TLandrixGaebXmlItem;
    function GetQU: TLandrixGaebString;
    procedure SetQU(const AValue: TLandrixGaebString);
  protected
    procedure GetTexts(out AComplete: TLandrixGaebXmlCompleteText; out AOutline: TLandrixGaebXmlOutlineText); override;
  public
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

  { A party (owner OWN, contractor CTR): its address. Reading an absent
    party gives ''; writing creates it.
    DE: Eine Partei (Auftraggeber OWN, Auftragnehmer CTR): ihre Anschrift.
    Lesen einer fehlenden Partei liefert ''; Schreiben legt sie an. }
  TLandrixGaebParty = class(TObject)
  private
    FBill: TLandrixGaebBillOfQuantities;
    FOwner: Boolean;
    function Address(ACreate: Boolean): TLandrixGaebXmlAddress;
    function GetField(AIndex: Integer): TLandrixGaebString;
    procedure SetField(AIndex: Integer; const AValue: TLandrixGaebString);
  public
    { The owner (AOwner) or the contractor of ABill. DE: Der Auftraggeber
      (AOwner) oder der Auftragnehmer von ABill. }
    constructor Create(ABill: TLandrixGaebBillOfQuantities; AOwner: Boolean);
    { True if the party is in the document. DE: True, wenn die Partei im
      Dokument steht. }
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
    procedure Build;
    procedure ClearViews;
    function GetProjectName: TLandrixGaebString;
    procedure SetProjectName(const AValue: TLandrixGaebString);
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
    { The document and the target it was read for or is to be written for.
      DE: Das Dokument und das Ziel, fuer das es gelesen wurde oder
      geschrieben werden soll. }
    property Document: TLandrixGaebXmlGAEB read FDocument;
    property Target: TLandrixGaebTarget read FTarget;
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
    { Total of the bill (BoQInfo/Totals: TotAfterDisc, else TotalLSUM, else
      Total). DE: Summe des LV (BoQInfo/Totals: TotAfterDisc, sonst
      TotalLSUM, sonst Total). }
    function Total: TLandrixGaebDecimal;
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

function TLandrixGaebNode.DetailTextNode: TLandrixGaebXmlNode;
var
  C: TLandrixGaebXmlCompleteText;
  O: TLandrixGaebXmlOutlineText;
begin
  Result := nil;
  GetTexts(C, O);
  if (C <> nil) and C.HasDetailTxt then
    Result := C.DetailTxt;
end;

function TLandrixGaebNode.OutlineTextNode: TLandrixGaebXmlNode;
var
  C: TLandrixGaebXmlCompleteText;
  O: TLandrixGaebXmlOutlineText;
begin
  Result := nil;
  GetTexts(C, O);
  if (C <> nil) and C.HasOutlineText and C.OutlineText.HasOutlTxt then
    Result := C.OutlineText.OutlTxt
  else if (O <> nil) and O.HasOutlTxt then
    Result := O.OutlTxt;
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

{ TLandrixGaebCategory }

constructor TLandrixGaebCategory.Create(ABill: TLandrixGaebBillOfQuantities; AParent: TLandrixGaebCategory;
  ASyntaxNode: TLandrixGaebXmlBoQCtgy; ATreeNode: TObject);
begin
  inherited Create(ABill, gnkCategory, AParent, ASyntaxNode, ATreeNode);
  FChildren := TLandrixGaebNodeList.Create;
end;

destructor TLandrixGaebCategory.Destroy;
begin
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
  Result.Clear;
  if not Ctgy.HasTotals then
    Exit;
  if Ctgy.Totals.TotAfterDisc.HasValue then
    Result := Ctgy.Totals.TotAfterDisc
  else if Ctgy.Totals.TotalLSUM.HasValue then
    Result := Ctgy.Totals.TotalLSUM
  else
    Result := Ctgy.Totals.Total;
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

{ TLandrixGaebParty }

constructor TLandrixGaebParty.Create(ABill: TLandrixGaebBillOfQuantities; AOwner: Boolean);
begin
  inherited Create;
  FBill := ABill;
  FOwner := AOwner;
end;

function TLandrixGaebParty.Address(ACreate: Boolean): TLandrixGaebXmlAddress;
var
  D: TLandrixGaebXmlGAEB;
begin
  Result := nil;
  D := FBill.Document;
  if not ACreate then
  begin
    if not D.HasAward then
      Exit;
    if FOwner then
    begin
      if D.Award.HasOWN and D.Award.OWN.HasAddress then
        Result := D.Award.OWN.Address;
    end
    else if D.Award.HasCTR and D.Award.CTR.HasAddress then
      Result := D.Award.CTR.Address;
    Exit;
  end;
  if FOwner then
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
begin
  Result := '';
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
begin
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
  FOwner := TLandrixGaebParty.Create(Self, True);
  FContractor := TLandrixGaebParty.Create(Self, False);
  Build;
end;

destructor TLandrixGaebBillOfQuantities.Destroy;
begin
  ClearViews;
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
  FTree.Free;
  FTree := nil;
end;

procedure TLandrixGaebBillOfQuantities.Build;
var
  Tree: TLandrixGaebTree;
  I: Integer;
  T: TLandrixGaebTreeNode;
  Views: TObjectList;
  Parent: TLandrixGaebCategory;
  V: TLandrixGaebNode;
begin
  Tree := TLandrixGaebTree.Create(FDocument);
  FTree := Tree;
  Views := TObjectList.Create(False);
  try
    { tree node -> view, by the position of the tree node (Order - 1) }
    for I := 0 to Integer(Tree.Nodes.Count) - 1 do
    begin
      T := TLandrixGaebTreeNode(Tree.Nodes[I]);
      Parent := nil;
      if (T.Parent <> nil) and (T.Parent <> Tree.Root) then
        Parent := TLandrixGaebCategory(Views[T.Parent.Order - 1]);
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
  Build;
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
var
  Info: TLandrixGaebXmlBoQInfo;
begin
  Result.Clear;
  if not (FDocument.HasAward and FDocument.Award.HasBoQ and FDocument.Award.BoQ.HasBoQInfo) then
    Exit;
  Info := FDocument.Award.BoQ.BoQInfo;
  if not Info.HasTotals then
    Exit;
  if Info.Totals.TotAfterDisc.HasValue then
    Result := Info.Totals.TotAfterDisc
  else if Info.Totals.TotalLSUM.HasValue then
    Result := Info.Totals.TotalLSUM
  else
    Result := Info.Totals.Total;
end;

end.

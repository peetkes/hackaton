xquery version "1.0-ml";
module namespace local = "http://hackaton.com/kruisvalidaties/rapport";

declare option xdmp:mapping "false";

declare variable $ALLOWED_OBJECTTYPES := (
  "Activiteit", "Ambtsgebied",
  "Divisie", "Divisietekst",
  "Gebied", "Gebiedengroep", "Gebiedsaanwijzing", "Geometrie",
  "Hoofdlijn",
  "Instructieregel",
  "Kaart",
  "Lijn", "Lijnengroep",
  "Omgevingsnorm", "Omgevingswaarderegel", "Omgevingswaarde",
  "Pons", "Punt", "Puntengroep",
  "Regelingsgebied", "Regeltekst", "RegelVoorIedereen",
  "SymbolisatieItem",
  "Tekstdeel"
);

declare variable $SPARQL-PREFIX as xs:string := '
PREFIX lvbb: <http://koop.overheid.nl/ontology/lvbb/>
PREFIX imow: <http://koop.overheid.nl/ontology/imow/>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
';

declare variable $SPARQL-REFERENTIES-PER-DOEL as xs:string :=
$SPARQL-PREFIX || '
SELECT distinct ?doelId ?regelingId
WHERE {
  ?owAanlevering  imow:linkToDoel ?doel ;
                  imow:linkToRegelingObject ?regeling .
  ?doel rdf:type lvbb:doel ;
        dc:identifier ?doelId .
  ?versie lvbb:vastgesteldDoorDoel ?doel .
  ?regeling lvbb:heeftVersie ?versie ;
            rdf:type lvbb:Regeling ;
            dc:identifier ?regelingId .
}
';

declare variable $SPARQL-GEOMETRIE-IDENTIFICATIES as xs:string :=
$SPARQL-PREFIX || '
SELECT ?gmlId
WHERE {
  ?owAanlevering imow:linkToDoel ?doel ;
                 imow:heeftBestand ?owLink .
  ?doel dc:identifier ?doelId .
  ?owBestand imow:linkToManifestBestand ?owLink ;
             rdf:type imow:owBestand ;
             imow:heeftGebied ?gebied .
  ?gebied imow:heeftGeometrieRef ?geometrie .
  ?geometrie dc:identifier ?gmlId
}
';
declare variable $SPARQL-REFERENTIES-PER-REGELING as xs:string :=
$SPARQL-PREFIX || '
SELECT ?regelingId ?wRef ?wId ?regeltekstId
WHERE {
  ?owAanlevering imow:linkToDoel ?doel ;
                 imow:heeftBestand ?owLink ;
                 imow:linkToRegelingObject ?regeling .
  ?doel dc:identifier @doelId .
  ?regeling dc:identifier ?regelingId ;
            rdf:type lvbb:Regeling .
  ?owBestand imow:linkToManifestBestand ?owLink ;
           rdf:type imow:owBestand ;
           imow:heeftRegeltekst ?regeltekst .
  ?regeltekst rdf:type imow:Regeltekst ;
              dc:identifier ?regeltekstId ;
              imow:linkToWId ?wRef .
  OPTIONAL { ?wRef dc:identifier ?wId . }
}
ORDER BY ?regelingId ?regeltekstId
';

declare variable $SPARQL-DISTINCT_OBJECTTYPES as xs:string :=
$SPARQL-PREFIX || '
SELECT distinct ?objectType ?type
WHERE {
  ?aanlevering rdf:type imow:Aanlevering ;
               imow:heeftBestand ?bestand .
  ?bestand rdf:type imow:Bestand ;
           imow:heeftObjectType ?objectType .
  OPTIONAL { ?objectType rdfs:label ?type . }
}
';

(:~
 : Deze functie maakt een kruisvalidatie rapport zoals OZON dat pleegt te doen.
 : De volgende zaken worden gecontroleerd:
 : - gebruik van niet bestaande objectTypen in manifest-ow.
 : - gebruik van objectTypen in manifest-ow die NIET voorkomen in de ow bestanden
 : Als er geen fouten ontdekt zijn, bevat het rapport per doelId en regelingId de geometrie identifiers en het overzicht van
 : referenties per regeling
 :
 : @param $oin        id van de aanleveraar
 : @param $idlevering id van de aanlevering
 : @return json:object met daarin de rapportage
 :)
declare function local:maak-kruisvalidatie-rapport(
  $oin as xs:string,
  $idlevering as xs:string
) as json:object
{
  let $query := cts:or-query((
    cts:and-query((
      cts:collection-query(fn:concat("/opera/oin/", $oin)),
      cts:collection-query(fn:concat("/opera/idlevering/", $idlevering)),
      cts:collection-query("/opera/options/opdrachtbestanden")
    )),
    cts:collection-query("/graph/imow-ontology")
  ))
  let $stores := (sem:store("document", $query), sem:store("properties", $query))
  let $validatie := local:check-object-types($stores)
  return
    if (fn:empty($validatie))
    then local:maak-goed-rapport($stores)
    else local:maak-fout-rapport($validatie)
};

(: PRIVATE FUNCTIONS :)
(:~
 : Deze functie maakt een foutrapport met de bijgevoegde meldingen
 :
 : @param $meldingen  sequence van foutmeldingen
 : @return json:object met daarin de rapportage
 :)
declare private function local:maak-fout-rapport(
  $meldingen as json:object*
) as json:object
{
  json:object()
  =>map:with("identificatie", sem:uuid())
  =>map:with("referentie", sem:uuid())
  =>map:with("status", "NOK")
  =>map:with("typeRapport", "REFERENTIES")
  =>map:with("meldingen", ($meldingen,
    object-node {
      "code": "EINDE CONTROLES",
      "omschrijving": "De controles zijn helemaal klaar, maar met FATALE fouten.",
      "detail": "EINDE CONTROLE"
    }))
  =>map:with("referentiesTeValideren", array-node {})
};

(:~
 : Deze functie maakt een goed rapport met de bijgevoegde meldingen
 :
 : @param $store    restrictie op het aantal triples
 : @return json:object met daarin de rapportage
 :)
declare private function local:maak-goed-rapport(
  $stores as sem:store*
) as json:object
{
  let $doelen := sem:sparql($SPARQL-REFERENTIES-PER-DOEL, (), ("map"), $stores)
  return
    object-node {
    "identificatie": sem:uuid(),
    "referentie": sem:uuid(),
    "status": "OK",
    "typeRapport": "REFERENTIES",
    "meldingen": array-node {},
    "referentiesTeValideren": array-node {
      for $doel in $doelen
      let $doelId := map:get($doel, "doelId")
      let $regelingId := map:get($doel, "regelingId")
      let $geometrieIdentificaties :=  sem:sparql($SPARQL-GEOMETRIE-IDENTIFICATIES, $doel, (), $stores)
      let $referentiesPerDoel := sem:sparql($SPARQL-REFERENTIES-PER-REGELING, $doel, (), $stores)
      return object-node {
        "doel": $doelId,
        "referentiesPerDoel": array-node {
          object-node {
            "geometrieIdentificaties": array-node { $geometrieIdentificaties ! map:get(., "gmlId") },
            "referentiesPerRegeling": array-node {
              for $referentie in $referentiesPerDoel
              let $wId := local:get-wId($referentie)
              return object-node {
                "regeltekstId": map:get($referentie, "regeltekstId"),
                "wId": $wId
              }
(: check if wId in regeling van de aanlevering zit
                if (map:contains($referentie, "wId") and map:get($referentie, "wId") ne ())
                then object-node {
                  "regeltekstId": map:get($referentie, "regeltekstId"),
                  "wId": $wId
                }
                else object-node {
                  "regeltekstId": map:get($referentie, "regeltekstId"),
                  "wId": $wId,
                  "error" : fn:concat("Let op: ", $wId, " is NIET gevonden in aanlevering-regeling ", $regelingId)
                }
:)
            },
            "wIdRegeling": $regelingId
          }
        }
      }
    }
  }
};

(:~
 : Deze functie checkt de objectTypes in de ow aanlevering
 :
 : @param $store    restrictie op het aantal triples
 : @return json:object met daarin de rapportage
 :)
declare function local:check-object-types(
  $stores as sem:store*
) as json:object*
{
  let $object-types := sem:sparql($SPARQL-DISTINCT_OBJECTTYPES,(),(),$stores) ! local:get-object-type(.)
  let $all-allowed := every $type in  $object-types satisfies $type = $ALLOWED_OBJECTTYPES
  let $intersect := local:intersect($stores)
  return
    if ($all-allowed)
    then ()
    else (
      local:check-allowed-object-types($object-types),
      local:check-intersect($intersect)
    )
};

(:~
 : Deze functie checkt of de objecttypen in manifest-ow ook voorkomen in ow bestanden
 :
 : @param $object-types   sequence van objectTypen
 : @return json:object met daarin de rapportage
 :)
declare function local:check-intersect(
  $object-types as xs:string*
) as json:object*
{
  for $object in $object-types
  return json:object()
  =>map:with("code", "REFERENTIE.05")
  =>map:with("omschrijving","referentie controleopdracht mislukt")
  =>map:with("detail","Onbekende fout: Het objectType '" || $object ||
    "' in het manifest komt NIET voor in de owBestanden.")
};

(:~
 : Deze functie checkt of de objectTypen van het manifest-ow binnen de toegestane reeks vallen
 :
 : @param $object-types   sequence van objectTypen
 : @return json:object met daarin de rapportage
 :)
declare function local:check-allowed-object-types(
  $object-types as xs:string*
) as json:object*
{
  let $objects := fn:filter(function($a) { fn:not($a = $ALLOWED_OBJECTTYPES) },  $object-types)
  for $object in $objects
  return json:object()
  =>map:with("code", "REFERENTIE.04")
  =>map:with("omschrijving","referentie controleopdracht mislukt")
  =>map:with("detail","Onbekende fout: Het objectType in het manifest is " || $object ||
    " maar moet een van de volgende waarden zijn: " || fn:string-join($ALLOWED_OBJECTTYPES, ','))
};

(:~
 : Deze functie bepaalt de string voor een objectType, als het een onbekend objectType is wordt het laatste deel van van de IRI gebruikt
 :
 : @param $item    resultaat van een sparql query
 : @return type van het object
 :)
declare function local:get-object-type(
  $item as item()
) as xs:string?
{
  let $objectType := map:get($item, "objectType")
  let $type := map:get($item, "type")
  return ($type, fn:tokenize(fn:string($objectType),"/")[last()])[1]
};

(:~
 : Deze functie bepaalt het wId, als het een onbekend wId is (niet in de regeling) wordt het laatste deel van de IRI van de wRef gebruikt
 :
 : @param $item    resultaat van een sparql query
 : @return wId van de wetsreferentie
 :)
declare function local:get-wId(
  $item as item()
) as xs:string?
{
  let $wRef := map:get($item, "wRef")
  let $wId := map:get($item, "wId")
  return ($wId, fn:tokenize(fn:string($wRef),"/")[last()])[1]
};

(:~
 : Deze functie checkt of de valide objectTypen van het manifestow voorkomen in de ow bestanden
 :
 : @param $store    restrictie op het aantal triples
 : @return sequence van strings voor die ojectTpen die niet voorkomen in de ow bestanden
 :)
declare function local:intersect(
  $store as sem:store*
) as xs:string*
{
  let $sparql := $SPARQL-PREFIX || '
  SELECT ?type
  WHERE {
    ?aanlevering rdf:type imow:Aanlevering ;
                 imow:heeftBestand ?bestand .
    ?bestand rdf:type imow:Bestand ;
             imow:heeftObjectType ?objectType .
    ?objectType rdfs:label ?type
    MINUS {
      SELECT ?type
      WHERE {
        ?bestand rdf:type imow:owBestand ;
                 imow:heeftObjectType ?objectType .
        ?objectType rdfs:label ?type .
      }
    }
  }'
  return sem:sparql($sparql,(),(), $store) ! map:get(.,"type")
};


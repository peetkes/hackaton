xquery version "1.0-ml";
module namespace local = "http://hackaton.com/kruisvalidaties/rapport";

declare option xdmp:mapping "false";

declare variable $ALLOWED_OBJECTTYPES := (
"Activiteit",
"Regeltekst",
"RegelVoorIedereen",
"Instructieregel",
"Omgevingswaarderegel",
"Divisie",
"Divisietekst",
"Tekstdeel",
"Hoofdlijn",
"Gebied",
"Gebiedengroep",
"Lijn",
"Lijnengroep",
"Punt",
"Puntengroep",
"Ambtsgebied",
"Gebiedsaanwijzing",
"Omgevingsnorm",
"Omgevingswaarde",
"Pons",
"Kaart",
"Regelingsgebied",
"Geometrie",
"SymbolisatieItem"
);

declare variable $SPARQL-PREFIX as xs:string := '
PREFIX lvbb: <http://koop.overheid.nl/ontology/lvbb/>
PREFIX imow: <http://koop.overheid.nl/ontology/imow/>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
';
declare variable $SPARQL-REFERENTIES-PER-DOEL as xs:string :=  $SPARQL-PREFIX || '
SELECT distinct ?doelId ?regelingId
WHERE {
  ?owAanlevering  imow:linkToDoel ?doel ;
                  imow:linkToRegelingObject ?regeling .
  ?doel rdf:type lvbb:doel ;
        rdfs:label ?doelId .
  ?versie lvbb:vastgesteldDoorDoel ?doel .
  ?regeling lvbb:heeftVersie ?versie ;
            rdf:type lvbb:Regeling ;
            rdfs:label ?regelingId .
}
';

declare variable $SPARQL-GEOMETRIE-IDENTIFICATIES as xs:string :=  $SPARQL-PREFIX || '
SELECT ?gmlId
WHERE {
  ?owAanlevering imow:linkToDoel ?doel ;
                 imow:heeftBestand ?bestand .
  ?doel rdfs:label @doelId .
  ?bestand imow:heeftObjectType imow:Gebied ;
           rdfs:label ?naam .
  ?ow imow:bestand ?bestand2 .
  ?bestand2 imow:heeftObjectType imow:Gebied ;
            rdfs:label ?naam ;
            imow:heeftGebied ?gebied .
  ?gebied imow:heeftGeometrieRef ?geometrie .
  ?geometrie rdfs:label ?gmlId
}
';
declare variable $SPARQL-REFERENTIES-PER-REGELING as xs:string :=  $SPARQL-PREFIX || '
SELECT ?regelingId ?wId ?regeltekstId
WHERE {
  ?owAanlevering imow:linkToDoel ?doel ;
                 imow:heeftBestand ?linkId ;
                 imow:linkToRegelingObject ?regeling .
  ?doel rdfs:label @doelId .
  ?regeling rdfs:label ?regelingId ;
            rdf:type lvbb:Regeling .
  ?linkId owl:sameAs ?bestandId .
  ?bestandId rdfs:label ?naam ;
             imow:heeftRegeltekst ?regeltekst .
  ?regeltekst rdf:type imow:Regeltekst ;
              rdfs:label ?regeltekstId ;
              imow:linkToWId ?wRef .
  ?wRef rdfs:label ?wId .
}
ORDER BY ?regelingId ?regeltekstId
';

declare variable  $SPARQL-DISTINCT-OBJECTTYPEN as xs:string := '
PREFIX imow: <http://www.geostandaarden.nl/imow/>
SELECT distinct ?objectType ?type
WHERE {
   ?s imow:heeftObjectType ?objectType .
   ?objectType rdfs:label  ?type .
}
';

declare function local:maak-rapport(
  $doelen as xs:string*,
  $store as sem:store*
) as item()*
{
  object-node {
    "identificatie": sem:uuid(),
    "meldingen": array-node {},
    "referentie": sem:uuid(),
    "referentiesTeValideren": array-node {
      for $doel in $doelen
      let $doelId := map:get($doel, "doelId")
      let $regelingId := map:get($doel, "regelingId")
      let $geometrieIdentificaties :=  sem:sparql($SPARQL-GEOMETRIE-IDENTIFICATIES, $doel, (), $store)
      let $referentiesPerDoel := sem:sparql($SPARQL-REFERENTIES-PER-REGELING, $doel, (), $store)
      return object-node {
        "doel": $doelId,
        "referentiesPerDoel": array-node {
          object-node {
            "geometrieIdentificaties": array-node { $geometrieIdentificaties ! map:get(., "gmlId") },
            "referentiesPerRegeling": array-node { $referentiesPerDoel ! object-node { "regeltekstId": map:get(., "regeltekstId"), "wId": map:get(., "wId") } },
            "wIdRegeling": $regelingId
          }
        }
      }
    }
  }
};

declare function local:check-ow-object-types(
) as item()*
{
  ()
};
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
PREFIX imow: <http://www.geostandaarden.nl/imow/>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX imowType: <http://www.geostandaarden.nl/imow/objecttype/>
';
declare variable $SPARQL-REFERENTIES-PER-DOEL as xs:string :=  $SPARQL-PREFIX || '
SELECT distinct ?doelId ?regelingId
WHERE {
  ?regeling rdfs:label ?regelingId ;
            rdf:type lvbb:Regeling ;
            lvbb:heeftVersie ?versie ;
            lvbb:linkToOwObject ?mow .
  ?versie lvbb:vastgesteldDoorDoel ?doel .
  ?doel rdf:type lvbb:doel ;
        rdfs:label ?doelId ;
        lvbb:linkToOwObject ?mow .
}
';

declare variable $SPARQL-GEOMETRIE-IDENTIFICATIES as xs:string :=  $SPARQL-PREFIX || '
SELECT ?gmlId
WHERE {
  ?doel lvbb:linkToOwObject ?mow ;
          rdf:type lvbb:doel ;
          rdfs:label @doelId .
  ?mow rdf:type imowType:Gebied;
      imow:bestandsnaam ?bestand .
  ?ow imow:bestand ?bestand ;
      imow:heeftGebied ?gebied .
  ?gebied rdf:type imow:Gebied ;
          imow:geometrie ?geoLocatie .
  ?geoLocatie rdf:type ?type ;
              rdfs:label ?gmlId

}
';
declare variable $SPARQL-REFERENTIES-PER-REGELING as xs:string :=  $SPARQL-PREFIX || '
SELECT ?regelingId ?wId ?regeltekstId
WHERE {
  ?regeling lvbb:linkToOwObject ?mow ;
              rdfs:label ?regelingId ;
              rdf:type lvbb:Regeling ;
              lvbb:heeftVersie ?versie .
  ?versie lvbb:vastgesteldDoorDoel ?doel .
  ?doel lvbb:linkToOwObject ?mow ;
          rdf:type lvbb:doel ;
          rdfs:label @doelId .
  ?mow rdf:type imowType:Regeltekst;
      imow:bestandsnaam ?bestand .
  ?ow2 imow:bestand ?bestand ;
       imow:heeftRegeltekst ?regeltekst .
  ?regeltekst rdf:type imow:Regeltekst ;
          rdfs:label ?regeltekstId ;
          lvbb:linkToWId ?wRef .
  ?wRef rdfs:label ?wId .
}
ORDER BY ?regelingId ?regeltekstId
';

declare function local:maak-rapport(
  $doelen as xs:string*,
  $map as map:map
) as item()*
{
  object-node {
    "identificatie": sem:uuid(),
    "meldingen": array-node {},
    "referentie": sem:uuid(),
    "referentiesTeValideren": array-node {
      for $doel in $doelen
      return object-node {
        "doel": $doel,
        "referentiesPerDoel": array-node {
          object-node {
            "geometrieIdentificaties": array-node {
              map:get(map:get($map, $doel),"geometrieIdentificaties") ! map:get(., "gmlId")
            }
          }
        }
      }
    }
  }
};

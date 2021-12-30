xquery version "1.0-ml";

module namespace local = "http://koop.overheid.nl/hackaton/mlcp/adjust-collections";

declare namespace opera = "http://koop.overheid.nl/apps/opera/";
declare namespace geo = "https://standaarden.overheid.nl/stop/imop/geo/";
declare namespace basisgeo = "http://www.geostandaarden.nl/basisgeometrie/1.0";
declare namespace gml = "http://www.opengis.net/gml/3.2";

declare option xdmp:mapping "false";

declare variable $TRACE-ID-XML := "hackaton-xml";
declare variable $TRACE-ID-BINARY := "hackaton-binary";

declare function local:adjust-collections(
  $content as map:map,
  $context as map:map
) as map:map*
{
  let $extra-collections := local:parse-transform-param(map:get($context, "transform_param"))=>local:create-collections()
  let $doc := map:get($content, "value")
  let $doc-kind := xdmp:node-kind($doc)
  return (
    xdmp:trace("hackaton", map:get($content, "uri") || " is of type " || $doc-kind),
    map:put($context, "collections", (
      map:get($context, "collections"),
      $extra-collections
    )),
    if ($doc-kind eq "binary")
    then local:process-binary($content, $context)
    else local:process-document($content, $context)
  )
};

declare function local:create-collections(
  $params as map:map?
) as xs:string*
{
  (
    "/opera/options/opdrachtbestanden",
    for $key in map:keys($params)
    where fn:string-length(map:get($params, $key)) gt 0
    return fn:concat("/opera/", $key, "/", map:get($params, $key))
  )
};

declare function local:parse-transform-param(
  $param as xs:string?
) as map:map?
{
  if (fn:empty($param) or fn:not(fn:contains($param,"=")))
  then ()
  else
    let $result := map:map()
    let $items := fn:tokenize(fn:normalize-space($param),",")
    return (
      for $item in $items
      return map:put($result,fn:substring-before($item,"="), fn:substring-after($item,"=")),
      $result
    )
};

declare function local:process-binary(
  $content as map:map,
  $context as map:map
) as map:map*
{
  let $uri := map:get($content, "uri")
  let $extension := fn:tokenize(fn:tokenize(fn:lower-case($uri),"/")[last()], "\.")[last()]
  let $collection := local:add-binary-collection($extension)
  let $_ :=
    if ($extension eq "gml")
    then (
      map:put($context, "metadata", map:map()
        =>map:with("key1", "value1")
        =>map:with("key2", ("value1","value2"))
      ),
      let $properties := local:get-geo-properties($uri, map:get($content, "value"))
      return (
        xdmp:trace($TRACE-ID-BINARY, "Properties fragment for " || $uri || " hash=" || $properties//opera:hash),
        xdmp:document-set-properties($uri, $properties)
      )
    )
    else ()
  return (
    map:put($context, "collections", (map:get($context, "collections"), $collection)),
    $content
  )
};

declare function local:process-document(
  $content as map:map,
  $context as map:map
) as map:map*
{
  let $root-element := fn:local-name(map:get($content, "value")/*)
  let $collection := local:add-doc-collections($root-element)
  return (
    xdmp:trace($TRACE-ID-XML, "Root element = " || $root-element),
    map:put($context, "collections", (map:get($context, "collections"), $collection)),
    $content
  )
};

declare function local:add-doc-collections(
  $root-element as xs:string
) as xs:string*
{
  switch($root-element)
  case "owBestand" return "/opera/document/ow-bestand"
  case "AanleveringInformatieObject" return ("/opera/document/informatie-object", "/opera/document/werk-informatie-object")
  case "Aanleveringen" return "/opera/document/manifest-ow"
  case "AanleveringBesluit" return "/opera/document/besluit"
  case "AanleveringKennisgeving" return "/opera/document/kennisgeving"
  default return "/opera/document/" || $root-element

};

declare function local:add-binary-collection(
  $extension as xs:string
) as xs:string?
{
  switch($extension)
  case "gml" return "/opera/document/gml"
  case "png" return "/opera/document/subitem"
  case "pdf" return "/opera/document/externe-bijlage"
  default return ()
};

declare function local:get-geo-properties(
  $uri as xs:string,
  $content as binary()
) as element()?
{
  let $gml := xdmp:unquote(xdmp:binary-decode($content,"UTF-8"))/element()
  return <opera:gml-properties>
    <opera:schemaversie>{$gml/@schemaversie/fn:string()}</opera:schemaversie>
    <opera:gml-filenaam>{fn:tokenize($uri,'/')[last()]}</opera:gml-filenaam>
    <opera:hash>{ xdmp:sha512($content) }</opera:hash>
    <opera:join-id-werk>{$gml//geo:FRBRWork/fn:string()}</opera:join-id-werk>
    <opera:join-id-expressie>{$gml//geo:FRBRExpression/fn:string()}</opera:join-id-expressie>
    {
      if ($gml//geo:wasID)
      then <opera:was-id>{$gml//geo:wasID/fn:string()}</opera:was-id>
      else ()
    }
    <opera:geo-locaties>
    {
      for $geometrie in $gml//basisgeo:Geometrie
      return <opera:gml-id>{$geometrie/basisgeo:id/fn:string()}</opera:gml-id>
    }
    </opera:geo-locaties>
  </opera:gml-properties>
};
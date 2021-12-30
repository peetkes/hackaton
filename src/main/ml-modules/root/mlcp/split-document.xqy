xquery version "1.0-ml";
(:~
: User: pkester
: Date: 27/12/2021
: Time: 13:53
:)
module namespace local = "http://koop.overheid.nl/hackaton/mlcp/split-document";
import module namespace ac = "http://koop.overheid.nl/hackaton/mlcp/adjust-collections" at "adjust-collections.xqy";

declare option xdmp:mapping "false";

declare variable $TRACE-ID := "hackaton";
declare variable $TRACE-ID-XML := "hackaton-xml";

declare function local:split-document(
  $content as map:map,
  $context as map:map
) as map:map*
{
  let $extra-collections := ac:parse-transform-param(map:get($context, "transform_param"))=>ac:create-collections()
  let $doc := map:get($content, "value")
  let $doc-kind := xdmp:node-kind($doc)
  return (
    xdmp:trace($TRACE-ID, map:get($content, "uri") || " is of type " || $doc-kind),
    map:put($context, "collections", (
      map:get($context, "collections"),
      $extra-collections
    )),
    local:process-document($content, $context)
  )
};

declare function local:process-document(
  $content as map:map,
  $context as map:map
) as map:map*
{
  let $root-element := fn:local-name(map:get($content, "value")/*)
  let $collection := ac:add-doc-collections($root-element)
  return (
    xdmp:trace($TRACE-ID, "Root element = " || $root-element),
    map:put($context, "collections", (map:get($context, "collections"), $collection)),
    local:split($content)
  )
};

declare function local:split(
  $content as map:map
) as map:map*
{
  let $stylesheet :=
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:sl="http://www.geostandaarden.nl/bestanden-ow/standlevering-generiek"
    xmlns:ow-dc="http://www.geostandaarden.nl/imow/bestanden/deelbestand"
    version="2.0">

  <xsl:template match="/ow-dc:owBestand">
    <xsl:for-each select="descendant::sl:stand">
      <xsl:variable name="objectTypen" select="ow-dc:owObject/*/local-name()"/>
      <ow-dc:owBestand>
        <sl:standBestand>
          <xsl:copy-of select="sl:dataset" copy-namespaces="no"/>
          <sl:inhoud>
            <xsl:copy-of select="../sl:inhoud/sl:gebied" copy-namespaces="no"/>
            <xsl:copy-of select="../sl:inhoud/sl:leveringsId" copy-namespaces="no"/>
            <sl:objectTypen>
              <xsl:for-each select="$objectTypen">
                <sl:objectType><xsl:value-of select="."/></sl:objectType>
              </xsl:for-each>
            </sl:objectTypen>
          </sl:inhoud>
          <xsl:copy-of select="ow-dc:owObject" copy-namespaces="no"/>
        </sl:standBestand>
      </ow-dc:owBestand>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>

  let $doc := map:get($content, "value")
  let $splits := xdmp:xslt-eval($stylesheet, $doc)/*
  return (
    for $split in $splits
    let $identifier := $split//*:identificatie/fn:string()
    return map:map()
    =>map:with("uri", fn:concat(map:get($content,"uri"),"/", $identifier))
    =>map:with("value", $split)
  )
};


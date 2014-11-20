<?xml version="1.0"?>

<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:template match="/">
<html>
  <head>
    <meta charset="utf-8"/>
    <link href="http://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/css/bootstrap-combined.no-icons.min.css" rel="stylesheet"/>
    <style type="text/css">
        body { margin: 0.5em 2em; }
        h1 { font-size: 20px; line-height: 21px; margin:3px 0; }
        h2 { font-size: 18px; line-height: 19px; margin:3px 0; }
        dl { margin: 5px 5px;}
        hr { margin: 5px 0; }
        p  { margin:0 0 5px; }
        .total-counts { font-weight: bold; }
    </style>
  </head>
  <body>
    <header>
      <h1>Prechecker results:</h1>
      <p class="total-counts">(<xsl:value-of select="//smurf/@numerrors"/> errors, <xsl:value-of select="//smurf/@numwarnings"/> warnings)</p>
    </header>
    <hr />
    <main>
      <xsl:for-each select="smurf/check">
        <article>
          <h2><xsl:value-of select="@title"/></h2>
          <p>(<xsl:value-of select="@numerrors"/> errors, <xsl:value-of select="@numwarnings"/> warnings)</p>
          <p><xsl:value-of select="description"/></p>
          <dl>
            <xsl:for-each select="mess/problem">
              <xsl:choose>
                <xsl:when test="@file = preceding-sibling::problem[1]/@file">
                </xsl:when>
                <xsl:otherwise>
                  <dt><xsl:value-of select="@file"/></dt>
                </xsl:otherwise>
              </xsl:choose>
              <dd>
                <xsl:attribute name="class">text-<xsl:value-of select="@type"/></xsl:attribute>
                  <xsl:if test="@linefrom != 0">(#<xsl:value-of select="@linefrom"/>
                    <xsl:if test="@lineto != 0 and @lineto != @linefrom">-<xsl:value-of select="@lineto"/></xsl:if>)
                  </xsl:if>
                <a>
                  <xsl:attribute name="class">text-<xsl:value-of select="@type"/></xsl:attribute>
                  <xsl:attribute name="href"><xsl:value-of select="@url"/></xsl:attribute>
                  <xsl:value-of select="message"/>
                </a>
              </dd>
              <dd>
                <details class="muted"><summary>Details:</summary>
                  <dl class="dl-horizontal">
                    <dt>API</dt>
                      <dd><xsl:value-of select="@api"/></dd>
                      <dt>Package</dt>
                      <dd><xsl:value-of select="@package"/></dd>
                      <dt>Class</dt>
                      <dd><xsl:value-of select="@class"/></dd>
                      <dt>Method</dt>
                      <dd><xsl:value-of select="@method"/></dd>
                      <dt>Ruleset</dt>
                      <dd><xsl:value-of select="@ruleset"/></dd>
                      <dt>Rule</dt>
                      <dd><xsl:value-of select="@rule"/></dd>
                      <dt>Code</dt>
                      <dd><xsl:value-of select="code"/></dd>
                    </dl>
                  </details>
                </dd>
            </xsl:for-each>
          </dl>
        </article>
        <hr />
      </xsl:for-each>
    </main>
  </body>
</html>
</xsl:template>

</xsl:stylesheet>

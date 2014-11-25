<?xml version="1.0"?>

<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:template match="/">
<html>
  <head>
    <meta charset="utf-8"/>
    <link href="http://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/css/bootstrap-combined.min.css" rel="stylesheet"/>
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
      <h1 id="top">
        Prechecker results:
        <span>
          <xsl:attribute name="class">text-<xsl:value-of select="//smurf/summary/@status"/></xsl:attribute>
          <xsl:value-of select="//smurf/summary/@status"/>
        </span>
      </h1>
    </header>
    <nav>
      <span>
        <xsl:attribute name="class">total-counts text-<xsl:value-of select="//smurf/summary/@status"/></xsl:attribute>
        (<xsl:value-of select="//smurf/summary/@numerrors"/> errors/<xsl:value-of select="//smurf/summary/@numwarnings"/> warnings)
        =>
      </span>
      <xsl:for-each select="smurf/summary/detail">
        <a>
          <xsl:attribute name="class">text-<xsl:value-of select="@status"/></xsl:attribute>
          <xsl:attribute name="href">#<xsl:value-of select="@name"/></xsl:attribute>
          <xsl:value-of select="@name"/>
          (<xsl:value-of select="@numerrors"/>/<xsl:value-of select="@numwarnings"/>),
        </a>
      </xsl:for-each>
    </nav>
    <hr />
    <main>
      <xsl:for-each select="smurf/check">
        <article>
          <h2>
            <xsl:attribute name="id"><xsl:value-of select="@id"/></xsl:attribute>
            <xsl:value-of select="@title"/>
            <a href="#top"> <span class="icon icon-chevron-up"/></a>
          </h2>
          <p>(<xsl:value-of select="@numerrors"/> errors, <xsl:value-of select="@numwarnings"/> warnings)</p>
          <p>
            <xsl:value-of select="description"/>
            <a>
              <xsl:attribute name="href"><xsl:value-of select="@url"/></xsl:attribute>
              [More info]
            </a>
          </p>
          <dl>
            <xsl:for-each select="mess/problem">
              <xsl:choose>
                <xsl:when test="@file = preceding-sibling::problem[1]/@file">
                </xsl:when>
                <xsl:otherwise>
                        <xsl:choose>
                            <xsl:when test="ancestor::check[1]/@id='commit'">
                                <dt>
                                <xsl:element name="a">
                                <xsl:attribute name="href"><xsl:value-of select="@diffurl"/></xsl:attribute>
                                <xsl:value-of select="@file"/>
                                </xsl:element>
                                </dt>
                            </xsl:when>
                            <xsl:otherwise>
                                <dt><xsl:value-of select="@file"/></dt>
                            </xsl:otherwise>
                        </xsl:choose>
                </xsl:otherwise>
              </xsl:choose>
              <dd>
                <a>
                  <xsl:attribute name="class">text-<xsl:value-of select="@type"/></xsl:attribute>
                  <xsl:attribute name="href"><xsl:value-of select="@diffurl"/></xsl:attribute>
                  <xsl:if test="@linefrom != 0">(#<xsl:value-of select="@linefrom"/>
                    <xsl:if test="@lineto != 0 and @lineto != @linefrom">-<xsl:value-of select="@lineto"/></xsl:if>)
                  </xsl:if>
                  <xsl:value-of select="message"/>
                </a>
                <xsl:if test="ancestor::check[1]/@url!=@url">
                  <a>
                    <xsl:attribute name="href"><xsl:value-of select="@url"/></xsl:attribute>
                    [More info]
                  </a>
                </xsl:if>
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

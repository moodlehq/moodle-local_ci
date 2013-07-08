<?xml version="1.0"?>

<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:template match="/">
<html>
  <head>
    <meta charset="utf-8"/>
    <link href="http://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/css/bootstrap-combined.no-icons.min.css" rel="stylesheet"/>
    <style type="text/css">
        body { margin: 2em; }
    </style>
  </head>
  <body>
    <header><h1>Prechecker results:</h1></header>
    <main>
      <xsl:for-each select="smurf/check">
        <article>
          <h2><xsl:value-of select="@title"/></h2>
          <p><xsl:value-of select="description"/></p>
          <dl>
            <xsl:for-each select="mess/problem">
                <dt><xsl:attribute name="class">priority<xsl:value-of select="@weight"/></xsl:attribute><xsl:value-of select="@file"/></dt>
                <dd>Lines: <xsl:value-of select="@linefrom"/>-<xsl:value-of select="@lineto"/></dd>
                <dd><a class="text-error"><xsl:attribute name="href"><xsl:value-of select="@url"/></xsl:attribute><xsl:value-of select="message"/></a></dd>
                <dd>
                  <details><summary>Details:</summary>
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
      </xsl:for-each>
    </main>
  </body>
</html>
</xsl:template>

</xsl:stylesheet>

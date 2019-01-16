<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">

  <!-- convert xml output generated in checkstyle xml into smurf xml format -->
  <xsl:output method="xml" indent="yes"/>

  <xsl:param name="abbr">abbr</xsl:param>
  <xsl:param name="title">checkstyle</xsl:param>
  <xsl:param name="url">http://pear.php.net/package/PHP_CodeSniffer</xsl:param>
  <xsl:param name="description">checkstyle description</xsl:param>
  <xsl:param name="codedir"/>
  <xsl:param name="errorweight">3</xsl:param>
  <xsl:param name="warningweight">1</xsl:param>
  <xsl:param name="allowfiltering">1</xsl:param>
  <xsl:param name="sorting">0</xsl:param>

  <xsl:template match="/">
    <check>
      <xsl:attribute name="id"><xsl:value-of select="$abbr"/></xsl:attribute>
      <xsl:attribute name="title"><xsl:value-of select="$title"/></xsl:attribute>
      <xsl:attribute name="url"><xsl:value-of select="$url"/></xsl:attribute>
      <xsl:attribute name="numerrors"><xsl:value-of select="count(//error[@severity = 'error'])"/></xsl:attribute>
      <xsl:attribute name="numwarnings"><xsl:value-of select="count(//error[@severity != 'error'])"/></xsl:attribute>
      <xsl:attribute name="allowfiltering"><xsl:value-of select="$allowfiltering"/></xsl:attribute>
      <description>
        <xsl:value-of select="$description"/>
      </description>
      <mess>
          <xsl:choose>
              <xsl:when test="$sorting='1'">
                  <xsl:apply-templates select="checkstyle/file/error">
                      <xsl:sort select="substring-after(../@name, $codedir)"/>
                      <xsl:sort select="@line" data-type="number"/>
                      <xsl:sort select="@source"/>
                      <xsl:sort select="@severity"/>
                  </xsl:apply-templates>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:apply-templates select="checkstyle/file/error"/>
              </xsl:otherwise>
              </xsl:choose>
      </mess>
    </check>
  </xsl:template>

  <xsl:template match="checkstyle/file/error">
    <problem>
      <xsl:attribute name="file"><xsl:value-of select="substring-after(../@name, $codedir)"/></xsl:attribute>
      <xsl:attribute name="linefrom"><xsl:value-of select="./@line"/></xsl:attribute>
      <xsl:attribute name="lineto"><xsl:value-of select="./@line"/></xsl:attribute>
      <xsl:attribute name="method"></xsl:attribute>
      <xsl:attribute name="class"></xsl:attribute>
      <xsl:attribute name="package"></xsl:attribute>
      <xsl:attribute name="api"></xsl:attribute>
      <xsl:attribute name="diffurl"><xsl:value-of select="./@diffurl"/></xsl:attribute>
      <xsl:choose>
        <xsl:when test="contains(./@source, '.')">
          <xsl:attribute name="ruleset"><xsl:value-of select="substring-before(./@source, '.')"/></xsl:attribute>
          <xsl:attribute name="rule"><xsl:value-of select="substring-after(./@source, '.')"/></xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="ruleset">moodle</xsl:attribute>
          <xsl:attribute name="rule"><xsl:value-of select="./@source"/></xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:attribute name="url"><xsl:value-of select="$url"/></xsl:attribute>
      <xsl:attribute name="type"><xsl:value-of select="./@severity"/></xsl:attribute>
      <xsl:choose>
        <xsl:when test="./@severity = 'error'">
          <xsl:attribute name="weight"><xsl:value-of select="$errorweight"/></xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="weight"><xsl:value-of select="$warningweight"/></xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
      <message>
        <xsl:value-of select="./@message"/>
      </message>
      <description/>
      <code/>
    </problem>
  </xsl:template>

</xsl:stylesheet>

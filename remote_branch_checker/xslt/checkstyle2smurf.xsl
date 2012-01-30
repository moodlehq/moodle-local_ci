<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">

  <!-- convert xml output generated in checkstyle xml into smurf xml format -->
  <xsl:output method="xml" indent="yes"/>

  <xsl:param name="title">checkstyle</xsl:param>
  <xsl:param name="url">http://pear.php.net/package/PHP_CodeSniffer</xsl:param>
  <xsl:param name="description">checkstyle description</xsl:param>
  <xsl:param name="codedir"/>
  <xsl:param name="errorweight">3</xsl:param>
  <xsl:param name="warningweight">1</xsl:param>

  <xsl:template match="/">
    <check>
      <xsl:attribute name="title"><xsl:value-of select="$title"/></xsl:attribute>
      <xsl:attribute name="url"><xsl:value-of select="$url"/></xsl:attribute>
      <description>
        <xsl:value-of select="$description"/>
      </description>
      <mess>
        <xsl:apply-templates select="checkstyle/file/error"/>
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

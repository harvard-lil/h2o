<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
                version="1.0">
  <xsl:output method="xml" encoding="utf-8" omit-xml-declaration="yes" indent="yes" />

  <xsl:template match="a[starts-with(@href, 'http://') or starts-with(@href, 'https://')]" priority="1">
    <Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="{@href}" TargetMode="External">
      <xsl:attribute name="Id">rId<xsl:value-of select="count(preceding::a[starts-with(@href, 'http://') or starts-with(@href, 'https://')]) + 8"/></xsl:attribute>
    </Relationship>
  </xsl:template>

  <xsl:template match="/">
    <Relationships>
      <Relationship Id="rId3" Type="http://schemas.microsoft.com/office/2007/relationships/stylesWithEffects" Target="stylesWithEffects.xml"/>
      <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
      <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/webSettings" Target="webSettings.xml"/>
      <Relationship Id="rId6" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/>
      <Relationship Id="rId7" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
      <xsl:apply-templates select="*"/>
    </Relationships>
  </xsl:template>

  <xsl:template match="text()|@*"/>
</xsl:stylesheet>

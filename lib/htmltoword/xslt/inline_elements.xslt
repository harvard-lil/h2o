<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output encoding="utf-8" omit-xml-declaration="yes" indent="yes" />

  <xsl:strip-space elements="*"/>

  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()[1]"/>
    </xsl:copy>
    <xsl:apply-templates select="following-sibling::node()[1]"/>
  </xsl:template>

  <!-- get first inline element of a sequence or text having block element siblings... -->
  <xsl:template match="node()[self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text()][parent::div|parent::li|parent::td]">
    <div>
      <xsl:attribute name="class"><xsl:value-of select="../@class"/></xsl:attribute>
      <xsl:attribute name="style"><xsl:value-of select="../@style"/></xsl:attribute>
      <xsl:call-template name="inlineElement"/>
    </div>
    <xsl:apply-templates select="following-sibling::node()[not((self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text())[parent::div|parent::li|parent::td])][1]"/>
  </xsl:template>

  <!-- get following inline elements... -->
  <xsl:template match="
     a[preceding-sibling::node()[1][self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text()]]
    |b[preceding-sibling::node()[1][self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text()]]
    |i[preceding-sibling::node()[1][self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text()]]
    |s[preceding-sibling::node()[1][self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text()]]
    |span[preceding-sibling::node()[1][self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text()]]
    |sub[preceding-sibling::node()[1][self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text()]]
    |sup[preceding-sibling::node()[1][self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text()]]
    |u[preceding-sibling::node()[1][self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text()]]
    |text()[preceding-sibling::node()[1][self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text()]]"
    name="inlineElement">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()[1]"/>
    </xsl:copy>
    <xsl:apply-templates select="following-sibling::node()[1][self::a|self::b|self::i|self::s|self::span|self::sub|self::sup|self::u|self::text()]"/>
  </xsl:template>
</xsl:stylesheet>

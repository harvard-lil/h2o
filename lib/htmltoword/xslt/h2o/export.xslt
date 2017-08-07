<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                xmlns:ext="http://exslt.org/common"
                version="1.0"
                exclude-result-prefixes="ext"
                extension-element-prefixes="func">

  <xsl:template match="//span[contains(concat(' ', @class, ' '), ' annotate elide ')]">
    <w:r>
      <w:rPr>
        <w:rStyle w:val="Elision"/>
      </w:rPr>
      <w:t xml:space="preserve">[ ... ]</w:t>
    </w:r>
  </xsl:template>

  <xsl:template match="//span[contains(concat(' ', @class, ' '), ' annotate elided ')]"></xsl:template>

  <xsl:template match="//span[contains(concat(' ', @class, ' '), ' annotate highlighted ')]">
    <w:r>
      <w:rPr>
        <w:highlight w:val="yellow" />
      </w:rPr>
        <w:t xml:space="preserve"><xsl:value-of select="."/></w:t>
    </w:r>
  </xsl:template>

  <xsl:template match="body/main/p">
    <w:p>
      <w:pPr>
        <w:pStyle w:val="CaseText"/>
      </w:pPr>
      <xsl:apply-templates />
    </w:p>
  </xsl:template>

  <xsl:template match="body/header">
    <xsl:param name="class" select="@class" />
    <w:p>
      <w:pPr>
        <w:pStyle w:val="{$class}"/>
      </w:pPr>
      <w:r>
        <w:t xml:space="preserve"><xsl:value-of select="."/></w:t>
      </w:r>
    </w:p>
  </xsl:template>

  <!-- If the center tag contains only text nodes, make it a p -->
  <xsl:template match="center[text() and not(*[not(self::text())])]">
      <xsl:variable name="preprocess">
        <p class="center">
          <xsl:value-of select="." />
        </p>
      </xsl:variable>

      <xsl:apply-templates
        select="ext:node-set($preprocess)/*"/>
  </xsl:template>

  <!-- otherwise make it a div -->
  <xsl:template match="center[*[not(self::text())]]">
      <xsl:variable name="preprocess">
        <div class="center">
          <xsl:value-of select="." />
        </div>
      </xsl:variable>

      <xsl:apply-templates
        select="ext:node-set($preprocess)/*"/>
  </xsl:template>

        <!-- convert unprocessable tags to <p> -->
    <xsl:template match="blockquote">
      <!-- <xsl:param name="tagname" select="local-name()" /> -->

      <xsl:variable name="preprocess">
        <p class="unsupported-tag">
          <xsl:value-of select="." />
        </p>
      </xsl:variable>

        <xsl:apply-templates
          select="ext:node-set($preprocess)/*"/>
    </xsl:template>

    <xsl:template match="font">
      <!-- <xsl:param name="tagname" select="local-name()" /> -->
      <xsl:comment>this is a font tag</xsl:comment>
<!--
      <xsl:variable name="preprocess">
        <p class="unsupported-tag">
          <xsl:value-of select="." />
        </p>
      </xsl:variable>

        <xsl:apply-templates
          select="ext:node-set($preprocess)/*"/> -->
    </xsl:template>
</xsl:stylesheet>

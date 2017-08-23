<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                xmlns:ext="http://exslt.org/common"
                version="1.0"
                exclude-result-prefixes="ext"
                extension-element-prefixes="func">

  <xsl:template match="table-of-contents">
    <w:sdt>
      <w:sdtPr>
        <w:docPartObj>
          <w:docPartGallery w:val="Table of Contents"/>
          <w:docPartUnique/>
        </w:docPartObj>
      </w:sdtPr>
      <w:sdtContent>
        <w:p>
          <w:pPr>
            <w:pStyle w:val="TOCHeading"/>
          </w:pPr>
          <w:r>
            <w:t>Table of Contents</w:t>
          </w:r>
        </w:p>
        <w:p>
          <w:r>
            <w:rPr>
              <w:b w:val="0"/>
              <w:bCs w:val="0"/>
            </w:rPr>
            <w:fldChar w:fldCharType="begin"/>
          </w:r>
          <w:r>
            <w:instrText xml:space="preserve"> TOC \o "1-3" \h \z \u </w:instrText>
          </w:r>
          <w:r>
            <w:rPr>
              <w:b w:val="0"/>
              <w:bCs w:val="0"/>
            </w:rPr>
            <w:fldChar w:fldCharType="separate"/>
          </w:r>
        </w:p>
        <xsl:apply-templates />
        <w:p>
          <w:r>
            <w:fldChar w:fldCharType="end"/>
          </w:r>
        </w:p>
      </w:sdtContent>
    </w:sdt>
  </xsl:template>

  <xsl:template match="toc-entry">
    <xsl:variable name="toc_depth" select="@data-depth"/>
    <xsl:variable name="toc_idx" select="@data-idx"/>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="TOC{$toc_depth}"/>
        <w:tabs>
          <w:tab w:val="right" w:leader="dot" w:pos="9350"/>
        </w:tabs>
        <w:rPr>
          <w:noProof/>
        </w:rPr>
      </w:pPr>
      <w:hyperlink w:anchor="_auto_toc_{$toc_idx}" w:history="1">
        <w:r>
          <w:rPr>
            <w:rStyle w:val="Hyperlink"/>
            <w:noProof/>
          </w:rPr>
          <w:t>
            <xsl:value-of select="."/>
          </w:t>
        </w:r>
        <w:r>
          <w:rPr>
            <w:noProof/>
            <w:webHidden/>
          </w:rPr>
          <w:tab/>
        </w:r>
        <w:r>
          <w:rPr>
            <w:noProof/>
            <w:webHidden/>
          </w:rPr>
          <w:fldChar w:fldCharType="begin"/>
        </w:r>
        <w:r>
          <w:rPr>
            <w:noProof/>
            <w:webHidden/>
          </w:rPr>
          <w:instrText xml:space="preserve"> PAGEREF _auto_toc_<xsl:value-of select="$toc_idx" /> \h </w:instrText>
        </w:r>
        <w:r>
          <w:rPr>
            <w:noProof/>
            <w:webHidden/>
          </w:rPr>
        </w:r>
        <w:r>
          <w:rPr>
            <w:noProof/>
            <w:webHidden/>
          </w:rPr>
          <w:fldChar w:fldCharType="separate"/>
        </w:r>
        <w:r>
          <w:rPr>
            <w:noProof/>
            <w:webHidden/>
          </w:rPr>
          <w:t>[ ]</w:t>
        </w:r>
        <w:r>
          <w:rPr>
            <w:noProof/>
            <w:webHidden/>
          </w:rPr>
          <w:fldChar w:fldCharType="end"/>
        </w:r>
      </w:hyperlink>
    </w:p>
  </xsl:template>

  <xsl:template match="span[contains(concat(' ', @class, ' '), ' annotate elide ') and not(parent::table)]">
    <w:r>
      <w:rPr>
        <w:rStyle w:val="Elision"/>
      </w:rPr>
      <w:t xml:space="preserve">[ ... ]</w:t>
    </w:r>
  </xsl:template>


  <!-- <xsl:template match="span[contains(concat(' ', @class, ' '), ' annotate highlighted ') and not(ancestor::*[@data-elided-annotation]) and not(descendant::h1|descendant::h2|descendant::h3|descendant::h4|descendant::h5|descendant::h6)]">
    <w:r>
      <w:rPr>
        <w:highlight w:val="yellow" />
      </w:rPr>
        <w:t xml:space="preserve"><xsl:value-of select="."/></w:t>
    </w:r>
  </xsl:template> -->

  <xsl:template match="p[not(ancestor::li|ancestor::p|ancestor::tr|ancestor::center[not(ancestor::h1|ancestor::h2|ancestor::h3|ancestor::h4|ancestor::h5|ancestor::h6) and not(ancestor::center) and not(ancestor::li) and not(ancestor::td) and not(ancestor::th) and not(ancestor::p) and not(descendant::div) and not(descendant::p) and not(descendant::h1) and not(descendant::h2) and not(descendant::h3) and not(descendant::h4) and not(descendant::h5) and not(descendant::h6) and not(descendant::table) and not(descendant::li) and not(descendant::pre)]) and not(@data-elided-annotation)]">
    <w:p>
      <w:pPr>
        <w:pStyle w:val="CaseText"/>
      </w:pPr>
      <xsl:apply-templates />
    </w:p>
  </xsl:template>

  <xsl:template match="span[contains(concat(' ', @class, ' '), ' annotate elided ')]"></xsl:template>

  <xsl:template match="body/header">
    <xsl:param name="class" select="@class" />
    <xsl:param name="toc_idx" select="@data-toc-idx" />
    <w:p>
      <w:pPr>
        <w:pStyle w:val="{$class}"/>
      </w:pPr>

      <xsl:if test="string($toc_idx)">
          <w:bookmarkStart w:id="{$toc_idx}" w:name="_auto_toc_{$toc_idx}"/>
      </xsl:if>
      <w:r>
        <w:t xml:space="preserve"><xsl:value-of select="."/></w:t>
      </w:r>
      <xsl:if test="string($toc_idx)">
          <w:bookmarkEnd w:id="{$toc_idx}"/>
      </xsl:if>
    </w:p>
  </xsl:template>

    <xsl:template match="blockquote">

      <xsl:variable name="preprocess">
        <p class="unsupported-tag">
          <xsl:value-of select="." />
        </p>
      </xsl:variable>

        <xsl:apply-templates
          select="ext:node-set($preprocess)/*"/>
    </xsl:template>

</xsl:stylesheet>

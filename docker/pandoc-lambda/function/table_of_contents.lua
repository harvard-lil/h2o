toc_prefix = [[
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
]]

toc_suffix = [[
        <w:p>
          <w:r>
            <w:fldChar w:fldCharType="end"/>
          </w:r>
        </w:p>
      </w:sdtContent>
    </w:sdt>
]]

toc_entry = [[
    <w:p>
      <w:pPr>
        <w:pStyle w:val="TOC%s"/>
        <w:rPr>
          <w:noProof/>
        </w:rPr>
      </w:pPr>
      <w:hyperlink w:anchor="_auto_toc_%s" w:history="1">
        <w:r>
          <w:rPr>
            <w:noProof/>
            <w:iCs/>
          </w:rPr>
          <w:t>
            %s
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
          <w:instrText xml:space="preserve"> PAGEREF _auto_toc_%s \h </w:instrText>
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
]]

bookmark = [[
  <w:bookmarkStart w:id="%s" w:name="_auto_toc_%s"/>
  <w:bookmarkEnd w:id="%s"/>
]]

function Div(div)
    if div.classes[1] == 'table-of-contents' then
        local toc = {toc_prefix}
        entries = pandoc.walk_block(div, {
            Div = function(inner_div)
              table.insert(toc, string.format(
                toc_entry,
                inner_div.attributes['depth'],
                inner_div.attributes['idx'],
                inner_div.attributes['data-title'],
                inner_div.attributes['idx']
              ))
              return nil
            end }
        )
        table.insert(toc, toc_suffix)
        return {pandoc.RawBlock('openxml', table.concat(toc,"\n"))}
    elseif div.attributes['toc-idx'] then
       local b = string.format(bookmark, div.attributes['toc-idx'], div.attributes['toc-idx'], div.attributes['toc-idx'])
       return {pandoc.RawBlock('openxml', b), div}
    else
        -- an attempt to clear out existing styles. I had this in a separate filter as the docs recommend, but that
        -- initiates a separate doc crawl and takes up a ton of time. We've got nearly as much problematic formatting
        -- in inline tags, but tackling spans alone in a lua filter increased run time by ~ 30% so I canned it. We may
        -- consider using TinyMCE to make pasted content more compliant with our existing uses
       div.classes = {}
       div.attributes['style'] = nil
       return div
    end
end

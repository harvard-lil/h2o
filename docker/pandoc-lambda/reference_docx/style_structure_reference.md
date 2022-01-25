* Latent
* Lost
* Paragraph
  * Font Family: Default Title and Structure  
    * heading 1 basedOn: FontFamilyDefaultTitleandStructure 
      * heading 2 basedOn: Heading1 
        * heading 3 basedOn: Heading2 
          * Case Header basedOn: Heading3 
          * heading 4 basedOn: Heading3 
            * heading 5 basedOn: Heading4 
              * heading 6 basedOn: Heading5 
                * heading 7 basedOn: Heading6 
                  * heading 8 basedOn: Heading7 
                    * heading 9 basedOn: Heading8 
              * Subheading 5 basedOn: Heading5 
                * Subheading 6 basedOn: Subheading5 
                  * Subheading 7 basedOn: Subheading6 
            * Subheading 4 basedOn: Heading4 
          * Subheading 3 basedOn: Heading3 
        * Subheading 2 basedOn: Heading2 
      * Subheading 1 basedOn: Heading1 
    * H Struct 01 Title basedOn: FontFamilyDefaultTitleandStructure link HStruct01TitleChar
      * H Struct 02 Title basedOn: HStruct01Title 
        * Hierarchy Level 1-2 Headnote Text basedOn: HStruct02Title 
          * Hierarchy Level 3-4-5 Headnote Text basedOn: HierarchyLevel1-2HeadnoteText 
            * Casebook Headnote basedOn: HierarchyLevel3-4-5HeadnoteText 
            * About Page Instructions basedOn: HierarchyLevel3-4-5HeadnoteText 
            * Chapter Headnote basedOn: HierarchyLevel3-4-5HeadnoteText 
            * Section Headnote basedOn: HierarchyLevel3-4-5HeadnoteText 
              * Resource Headnote basedOn: SectionHeadnote 
          * Casebook Blurb basedOn: HierarchyLevel1-2HeadnoteText 
        * Casebook Headnote Title basedOn: HStruct02Title 
        * Acknowledgements Title basedOn: HStruct02Title 
        * TOC Heading basedOn: HStruct02Title 
        * Chapter Title basedOn: HStruct02Title 
          * Chapter Number basedOn: ChapterTitle 
      * H Struct 03 Title basedOn: HStruct01Title 
        * Section Title basedOn: HStruct03Title 
          * Section Number basedOn: SectionTitle 
      * H Struct 04 Title basedOn: HStruct01Title 
        * Casebook Author basedOn: HStruct04Title 
        * About Page Title basedOn: HStruct04Title 
      * H Struct 05 Title basedOn: HStruct01Title 
        * Resource Title basedOn: HStruct05Title 
          * Resource Number basedOn: ResourceTitle 
      * H Struct 01 Subtitle basedOn: HStruct01Title 
        * H Struct 02 Subtitle basedOn: HStruct01Subtitle 
          * Chapter Subtitle basedOn: HStruct02Subtitle 
        * H Struct 03 Subtitle basedOn: HStruct01Subtitle 
        * H Struct 04 Subtitle basedOn: HStruct01Subtitle 
          * H Struct 05 Subtitle basedOn: HStruct04Subtitle 
            * Acknowledgements Subtitle basedOn: HStruct05Subtitle 
            * Credit Authors basedOn: HStruct05Subtitle 
              * Credit Title basedOn: CreditAuthors 
            * Resource Subtitle basedOn: HStruct05Subtitle 
              * Resource Link basedOn: ResourceSubtitle 
          * Section Subtitle basedOn: HStruct04Subtitle 
        * Casebook Subtitle basedOn: HStruct01Subtitle 
        * Subtitle basedOn: HStruct01Subtitle 
      * Casebook Title basedOn: HStruct01Title 
      * Title basedOn: HStruct01Title 
    * toc 1 basedOn: FontFamilyDefaultTitleandStructure 
      * toc 2 basedOn: TOC1 
      * toc 3 basedOn: TOC1 
        * toc 4 basedOn: TOC3 
          * toc 5 basedOn: TOC4 
            * toc 6 basedOn: TOC5 
              * toc 7 basedOn: TOC6 
                * toc 8 basedOn: TOC7 
                  * toc 9 basedOn: TOC8 
    * Bibliography basedOn: FontFamilyDefaultTitleandStructure 
    * caption basedOn: FontFamilyDefaultTitleandStructure 
      * Table Caption basedOn: Caption 
      * Image Caption basedOn: Caption 
    * header basedOn: FontFamilyDefaultTitleandStructure 
      * Header: PageNumber basedOn: Header 
  * Font Family: Default Case Content Body  
    * Body Text basedOn: FontFamilyDefaultCaseContentBody link BodyTextChar
      * Body Text First Indent basedOn: BodyText link BodyTextFirstIndentChar
      * First Paragraph basedOn: BodyText 
      * Compact basedOn: BodyText 
      * Case Body basedOn: BodyText 
        * Author basedOn: CaseBody 
        * Date basedOn: CaseBody 
        * Abstract basedOn: CaseBody 
        * Figure basedOn: CaseBody 
          * Captioned Figure basedOn: Figure 
      * Credits basedOn: BodyText 
      * Quote basedOn: BodyText 
        * Block Text basedOn: Quote 
      * Definition basedOn: BodyText 
        * Definition Term basedOn: Definition 
        * Image Centered Large basedOn: Definition 
        * Image Left Medium basedOn: Definition 
        * Image Right Medium basedOn: Definition 
        * Image Centered Medium basedOn: Definition 
      * footer basedOn: BodyText 
    * footnote text basedOn: FontFamilyDefaultCaseContentBody 
      * Footnote Labeled Link basedOn: FootnoteText 
        * Footnote Labeled Case basedOn: FootnoteLabeledLink 
  * Font Family: Default Source Code  
    * Source Code basedOn: FontFamilyDefaultSourceCode link VerbatimChar
  * Normal  
  * Front Matter End  
  * Head Separator  
  * Chapter Spacer  
  * Head Field Separator  
  * Head End  
  * Node Start  
  * Node End  
* Character
  * Default Paragraph Font  
    * Body Text Char basedOn: DefaultParagraphFont link BodyText
      * Body Text First Indent Char basedOn: BodyTextChar link BodyTextFirstIndent
      * Case Footnote Reference basedOn: BodyTextChar 
    * Unresolved Mention basedOn: DefaultParagraphFont 
    * H Struct 01 Title Char basedOn: DefaultParagraphFont link HStruct01Title
    * FollowedHyperlink basedOn: DefaultParagraphFont 
    * Caption Char basedOn: DefaultParagraphFont link Caption
  * Verbatim Char  link SourceCode
  * Elision  
    * Replacement Text basedOn: Elision 
  * Highlighted Text  
  * Hyperlink  
  * AlertTok  
  * AnnotationTok  
  * AttributeTok  
  * BaseNTok  
  * BuiltInTok  
  * CharTok  
  * CommentTok  
  * CommentVarTok  
  * ControlFlowTok  
  * DataTypeTok  
  * DocumentationTok  
  * ErrorTok  
  * ExtensionTok  
  * FloatTok  
  * FunctionTok  
  * ImportTok  
  * InformationTok  
  * KeywordTok  
  * NormalTok  
  * OperatorTok  
  * OtherTok  
  * PreprocessorTok  
  * RegionMarkerTok  
  * SpecialCharTok  
  * SpecialSTringTok  
  * StringTok  
  * VariableTok  
  * VerbatimStringTok  
  * WarningTok  
* Table
  * Table  
  * Normal Table  
    * Plain Table 4 basedOn: TableNormal 
    * Table Grid basedOn: TableNormal 
* Numbering
  * No List  
  * Current List1  
  * Current List2  
  * Current List3  
  * Current List4  

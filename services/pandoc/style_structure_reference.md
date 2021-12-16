-- Character --

* **DefaultParagraphFont
**  * **BodyTextChar** [ based on: DefaultParagraphFont ] *[ linked to: BodyText ]*
    * **BodyTextFirstIndentChar** [ based on: BodyTextChar ] *[ linked to: BodyTextFirstIndent ]*
    * **CaseFootnoteReference** [ based on: BodyTextChar ]
  * **CaptionChar** [ based on: DefaultParagraphFont ] *[ linked to: Caption ]*
    * **FootnoteReference** [ based on: CaptionChar ]
    * **VerbatimChar** [ based on: CaptionChar ] *[ linked to: SourceCode ]*
  * **CoverPageLink** [ based on: DefaultParagraphFont ]
  * **Elision** [ based on: DefaultParagraphFont ]
    * **ReplacementText** [ based on: Elision ]
  * **FollowedHyperlink** [ based on: DefaultParagraphFont ]
  * **FooterChar** [ based on: DefaultParagraphFont ] *[ linked to: Footer ]*
  * **HStruct01TitleChar** [ based on: DefaultParagraphFont ] *[ linked to: HStruct01Title ]*
    * **HStruct04TitleChar** [ based on: HStruct01TitleChar ] *[ linked to: HStruct04Title ]*
  * **HeaderChar** [ based on: DefaultParagraphFont ]
  * **HeaderChar1** [ based on: DefaultParagraphFont ] *[ linked to: Header ]*
  * **Heading1Char** [ based on: DefaultParagraphFont ] *[ linked to: Heading1 ]*
    * **CoverPageTitleChar** [ based on: Heading1Char ] *[ linked to: CoverPageTitle ]*
  * **Heading2Char** [ based on: DefaultParagraphFont ] *[ linked to: Heading2 ]*
  * **Heading3Char** [ based on: DefaultParagraphFont ] *[ linked to: Heading3 ]*
  * **Heading4Char** [ based on: DefaultParagraphFont ] *[ linked to: Heading4 ]*
  * **Heading5Char** [ based on: DefaultParagraphFont ] *[ linked to: Heading5 ]*
  * **Heading6Char** [ based on: DefaultParagraphFont ] *[ linked to: Heading6 ]*
  * **Heading7Char** [ based on: DefaultParagraphFont ] *[ linked to: Heading7 ]*
  * **PageNumber** [ based on: DefaultParagraphFont ]
  * **UnresolvedMention** [ based on: DefaultParagraphFont ]
* **HierarchyNumeral
*** HighlightedText
* **Hyperlink

--** Numbering --

* **CurrentList1
*** CurrentList2
* **CurrentList3
*** CurrentList4
* **NoList

--** Paragraph --

* **CoverPageTitle**  *[ linked to: CoverPageTitleChar ]*
* **FontFamilyDefaultCaseContentBody
**  * **BodyText** [ based on: FontFamilyDefaultCaseContentBody ] *[ linked to: BodyTextChar ]*
    * **BodyTextFirstIndent** [ based on: BodyText ] *[ linked to: BodyTextFirstIndentChar ]*
    * **CaseBody** [ based on: BodyText ]
      * **Abstract** [ based on: CaseBody ]
      * **Author** [ based on: CaseBody ]
      * **Date** [ based on: CaseBody ]
      * **Figure** [ based on: CaseBody ]
        * **CaptionedFigure** [ based on: Figure ]
    * **CaseText** [ based on: BodyText ]
    * **Compact** [ based on: BodyText ]
      * **Instructions** [ based on: Compact ]
      * **InstructionsListHeaders** [ based on: Compact ]
      * **Instructionsbullets** [ based on: Compact ]
    * **Credits** [ based on: BodyText ]
    * **Definition** [ based on: BodyText ]
      * **DefinitionTerm** [ based on: Definition ]
      * **ImageCenteredLarge** [ based on: Definition ]
      * **ImageCenteredMedium** [ based on: Definition ]
      * **ImageLeftMedium** [ based on: Definition ]
      * **ImageRightMedium** [ based on: Definition ]
    * **FirstParagraph** [ based on: BodyText ]
      * **CoverpageSubtitle** [ based on: FirstParagraph ]
        * **CoverPageInstructionsTitle** [ based on: CoverpageSubtitle ]
    * **Footer** [ based on: BodyText ] *[ linked to: FooterChar ]*
    * **Quote** [ based on: BodyText ]
      * **BlockText** [ based on: Quote ]
  * **FootnoteText** [ based on: FontFamilyDefaultCaseContentBody ]
    * **FootnoteLabeledLink** [ based on: FootnoteText ]
      * **FootnoteLabeledCase** [ based on: FootnoteLabeledLink ]
* **FontFamilyDefaultSourceCode
**  * **SourceCode** [ based on: FontFamilyDefaultSourceCode ] *[ linked to: VerbatimChar ]*
* **FontFamilyDefaultTitleandStructure
**  * **Bibliography** [ based on: FontFamilyDefaultTitleandStructure ]
  * **Caption** [ based on: FontFamilyDefaultTitleandStructure ] *[ linked to: CaptionChar ]*
    * **ImageCaption** [ based on: Caption ]
    * **TableCaption** [ based on: Caption ]
  * **HStruct01Title** [ based on: FontFamilyDefaultTitleandStructure ] *[ linked to: HStruct01TitleChar ]*
    * **CasebookTitle** [ based on: HStruct01Title ]
    * **HStruct01Subtitle** [ based on: HStruct01Title ]
      * **CasebookSubtitle** [ based on: HStruct01Subtitle ]
      * **HStruct02Subtitle** [ based on: HStruct01Subtitle ]
      * **HStruct03Subtitle** [ based on: HStruct01Subtitle ]
        * **ChapterSubtitle** [ based on: HStruct03Subtitle ]
      * **HStruct04Subtitle** [ based on: HStruct01Subtitle ]
        * **HStruct05Subtitle** [ based on: HStruct04Subtitle ]
          * **AcknowledgementsSubtitle** [ based on: HStruct05Subtitle ]
          * **CreditAuthors** [ based on: HStruct05Subtitle ]
            * **CreditTitle** [ based on: CreditAuthors ]
          * **ResourceSubtitle** [ based on: HStruct05Subtitle ]
            * **ResourceLink** [ based on: ResourceSubtitle ]
        * **SectionSubtitle** [ based on: HStruct04Subtitle ]
      * **Header** [ based on: HStruct01Subtitle ] *[ linked to: HeaderChar1 ]*
      * **Subtitle** [ based on: HStruct01Subtitle ]
    * **HStruct02Title** [ based on: HStruct01Title ]
      * **AcknowledgementsTitle** [ based on: HStruct02Title ]
      * **CasebookHeadnoteTitle** [ based on: HStruct02Title ]
      * **HierarchyLevel1-2HeaderText** [ based on: HStruct02Title ]
        * **CasebookBlurb** [ based on: HierarchyLevel1-2HeaderText ]
        * **HierarchyLevel3-4-5HeaderText** [ based on: HierarchyLevel1-2HeaderText ]
          * **CasebookHeadnote** [ based on: HierarchyLevel3-4-5HeaderText ]
          * **ChapterHeadnote** [ based on: HierarchyLevel3-4-5HeaderText ]
          * **SectionHeadnote** [ based on: HierarchyLevel3-4-5HeaderText ]
            * **ResourceHeadnote** [ based on: SectionHeadnote ]
      * **TOCHeading** [ based on: HStruct02Title ]
    * **HStruct03Title** [ based on: HStruct01Title ]
      * **ChapterTitle** [ based on: HStruct03Title ]
        * **ChapterNumber** [ based on: ChapterTitle ]
      * **SectionTitle** [ based on: HStruct03Title ]
        * **SectionNumber** [ based on: SectionTitle ]
    * **HStruct04Title** [ based on: HStruct01Title ] *[ linked to: HStruct04TitleChar ]*
      * **CasebookAuthor** [ based on: HStruct04Title ]
    * **HStruct05Title** [ based on: HStruct01Title ]
      * **ResourceTitle** [ based on: HStruct05Title ]
        * **ResourceNumber** [ based on: ResourceTitle ]
    * **Title** [ based on: HStruct01Title ]
  * **Heading1** [ based on: FontFamilyDefaultTitleandStructure ] *[ linked to: Heading1Char ]*
    * **Subheading1** [ based on: Heading1 ]
    * **Heading2** [ based on: Heading1 ] *[ linked to: Heading2Char ]*
      * **Subheading2** [ based on: Heading2 ]
      * **Heading3** [ based on: Heading2 ] *[ linked to: Heading3Char ]*
        * **Subheading3** [ based on: Heading3 ]
        * **CaseHeader** [ based on: Heading3 ]
        * **Heading4** [ based on: Heading3 ] *[ linked to: Heading4Char ]*
          * **Subheading4** [ based on: Heading4 ]
          * **Heading5** [ based on: Heading4 ] *[ linked to: Heading5Char ]*
            * **Heading6** [ based on: Heading5 ] *[ linked to: Heading6Char ]*
              * **Heading7** [ based on: Heading6 ] *[ linked to: Heading7Char ]*
                * **Heading8** [ based on: Heading7 ]
                  * **Heading9** [ based on: Heading8 ]
            * **Subheading5** [ based on: Heading5 ]
              * **Subheading6** [ based on: Subheading5 ]
                * **Subheading7** [ based on: Subheading6 ]
  * **TOC1** [ based on: FontFamilyDefaultTitleandStructure ]
    * **TOC2** [ based on: TOC1 ]
      * **TOC3** [ based on: TOC2 ]
        * **TOC4** [ based on: TOC3 ]
          * **TOC5** [ based on: TOC4 ]
            * **TOC6** [ based on: TOC5 ]
              * **TOC7** [ based on: TOC6 ]
                * **TOC8** [ based on: TOC7 ]
                  * **TOC9** [ based on: TOC8 ]
* **InstructionsHeadline
*** Normal
* **Revision
*** invisibleseparator

-- Table --

* **Table
*** TableNormal
  * **PlainTable4** [ based on: TableNormal ]
  * **TableGrid** [ based on: TableNormal ]
#!/bin/zsh

mv ./reference.docx ../archive/"old_"$(date +%d.%m.%Y_%d_%m_%H_%M_%S).docx
zip -r ./reference.docx word _rels docProps \[Content_Types\].xml
python3 update_style_structure_md.py reference.docx style_structure_reference.md
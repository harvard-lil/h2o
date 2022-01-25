#!/bin/zsh

rm ./reference.docx
zip -r ./reference.docx word _rels docProps \[Content_Types\].xml

echo
if read -q "choice?Update Docs? : "; then
	python3 update_style_structure_md.py reference.docx style_structure_reference.md
fi

if read -q "choice?Overwrite lambda version? : "; then
	cp reference.docx ../function/
fi

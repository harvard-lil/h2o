#!/bin/zsh

echo
if read -q "choice?Archive before overwriting copy in this directory? "; then
	mv ./reference.docx ../archive/"old_"$(date +%d.%m.%Y_%d_%m_%H_%M_%S).docx
else
	rm ./reference.docx
fi

zip -r ./reference.docx word _rels docProps \[Content_Types\].xml

echo
if read -q "choice?Update Docs? : "; then
	python3 update_style_structure_md.py reference.docx style_structure_reference.md
fi

if read -q "choice?Overwrite lambda version? : "; then
	cp reference.docx ../../../../docker/pandoc-lambda/function/
fi

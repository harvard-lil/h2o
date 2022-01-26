#!/bin/zsh

rm ./reference.docx
cd src || exit
zip -r ../reference.docx * || cd - || exit
cd - || exit

echo
if read -q "choice?Update Docs? : "; then
	python3 update_style_structure_md.py reference.docx style_structure_reference.md
fi

if read -q "choice?Overwrite lambda version? : "; then
	cp reference.docx ../../function/
fi

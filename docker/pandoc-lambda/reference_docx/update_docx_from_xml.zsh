#!/bin/zsh


echo
if read -q "choice?Update working reference.docx in THIS DIRECTORY? The subsequent two commands will use non-updated data if you don't: [y/N] (don't press return after)"; then
  rm ./reference.docx
  cd src || exit
  zip -r ../reference.docx * || cd - || exit
  cd - || exit
else
  echo "Ok, Not Updating."
fi

echo
if read -q "choice?Update Markdown Style Document? : [y/N] (don't press return after)"; then
  echo; echo "Updating..."
	python3 update_style_structure_md.py reference.docx style_structure_reference.md
else
  echo "Ok, Not Updating."
fi

echo
if read -q "choice?Overwrite the deployed reference.docx in the LAMBDA FUNCTION DIRECTORY with the version in THIS DIRECTORY? : "; then
  echo; echo "Overwriting version in code directory..."
	cp reference.docx ../function/
else
  echo "Ok, Not Replacing"
fi
echo

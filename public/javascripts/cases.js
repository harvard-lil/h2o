jQuery.fn.selectedText = function(win){
	win = win || window;
	
	var anchorNode = null;
        var focusNode = null;
	var text = null;

	// Get parent element to determine the formatting applied to the selected text
	if(win.getSelection){
		var anchorNode = win.getSelection().anchorNode;

		var text = win.getSelection().toString();
		// Mozilla seems to be selecting the wrong Node, the one that comes before the selected node.
		// I'm not sure if there's a configuration to solve this,
		var sel = win.getSelection();
		console.log(win.getSelection());
		if(!sel.isCollapsed && jQuery.browser.mozilla){
			// If we've selected an element, (note: only works on Anchors, only checked bold and spans)
			// we can use the anchorOffset to find the childNode that has been selected
			if(sel.focusNode.nodeName !== '#text'){
				// Is selection spanning more than one node, then select the parent
				if((sel.focusOffset - sel.anchorOffset)>1) {
					console.log("Selected spanning more than one",anchorNode = sel.anchorNode);
                                } else if ( sel.anchorNode.childNodes[sel.anchorOffset].nodeName !== '#text' ){
					console.log("Selected non-text",anchorNode = sel.anchorNode.childNodes[sel.anchorOffset]);
                                } else {
					console.log("Selected whole element",anchorNode = sel.anchorNode);
                                }
			}
			// if we have selected text which does not touch the boundaries of an element
			// the anchorNode and the anchorFocus will be identical
			else if( sel.anchorNode.data === sel.focusNode.data ){
				console.log("Selected non bounding text",anchorNode = sel.anchorNode.parentNode);
			}
			// This is the first element, the element defined by anchorNode is non-text.
			// Therefore it is the anchorNode that we want
			else if( sel.anchorOffset === 0 && !sel.anchorNode.data ){
				console.log("Selected whole element at start of paragraph (whereby selected element has not text e.g. &lt;script&gt;",anchorNode = sel.anchorNode);
			}
			// If the element is the first child of another (no text appears before it)
			else if( typeof sel.anchorNode.data !== 'undefined' 
						&& sel.anchorOffset === 0 
						&& sel.anchorOffset < sel.anchorNode.data.length ){
				console.log("Selected whole element at start of paragraph",anchorNode = sel.anchorNode.parentNode);
			}
			// If we select text preceeding an element. Then the focusNode becomes that element
			// The difference between selecting the preceeding word is that the anchorOffset is less that the anchorNode.length
			// Thus
			else if( typeof sel.anchorNode.data !== 'undefined'
						&& sel.anchorOffset < sel.anchorNode.data.length ){
				console.log("Selected preceeding element text",anchorNode = sel.anchorNode.parentNode);
			}
			// Selected text which fills an element, i.e. ,.. <b>some text</b> ...
			// The focusNode becomes the suceeding node
			// The previous element length and the anchorOffset will be identical
			// And the focus Offset is greater than zero
			// So basically we are at the end of the preceeding element and have selected 0 of the current.
			else if( typeof sel.anchorNode.data !== 'undefined' 
					&& sel.anchorOffset === sel.anchorNode.data.length 
					&& sel.focusOffset === 0 ){
				console.log("Selected whole element text", anchorNode = (sel.anchorNode.nextSibling || sel.focusNode.previousSibling));
			}
			// if the suceeding text, i.e. it bounds an element on the left
			// the anchorNode will be the preceeding element
			// the focusNode will belong to the selected text
			else if( sel.focusOffset > 0 ){
				console.log("Selected suceeding element text", anchorNode = sel.focusNode.parentNode);
			}
		} else if(sel.isCollapsed) {
			anchorNode = anchorNode.parentNode;
                }
		
	}
	else if(win.document.selection){
		var sel = win.document.selection.createRange();
		var anchorNode = sel;

		if(sel.parentElement){
			anchorNode = sel.parentElement();
                } else {
			anchorNode = sel.item(0);
                }

		text = sel.text || sel;
	
		if(text.toString){
			text = text.toString();
                }
	} else {
		throw 'Error';
        }
		
	// webkit
	if(anchorNode.nodeName==='#text'){
		anchorNode = anchorNode.parentNode;
        }

	// if the selected object has no tagName then return false.
	if(typeof anchorNode.tagName === 'undefined'){
		return false;
        }

	return {'anchorNode':anchorNode,'text':text};
};

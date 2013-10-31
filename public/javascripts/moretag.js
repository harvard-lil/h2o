tinymce.PluginManager.add('moretag', function(editor, url) {
    // Add a button that opens a window
    editor.addButton('moretag', {
        text: 'More Tag',
        icon: false,
        onclick: function() {
            editor.insertContent('<!--more-->');
        }
    });
});

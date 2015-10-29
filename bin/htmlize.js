//PhantomJS script

console.log('htmlize.js running...');

var system = require('system'),
    address, output, size;
address = system.args[1];
output_file = system.args[2];
options_file = system.args[3];
var page = require('webpage').create();
var filesystem = require('fs');
var cookies = {};

var set_cookies = function(address, options_file) {
    var parser = document.createElement('a');
    parser.href = address;
    var cookie_domain = parser.hostname;
    var json_string, json;
    try {
        json_string = filesystem.read(options_file);
        console.log('json_file: ' + json_string);
        json = JSON.parse(json_string);
    } catch(e) {
        console.log('Error reading/parsing JSON options file: ' + e);
        phantom.exit(1);
    }
    Object.keys(json).forEach(function(name) {
        cookies[name] = json[name];
        var cookie = {
            'name': name,
            'value': json[name],
            'domain': cookie_domain,
            'path': '/'
        };
        //console.log('Baking: ',  JSON.stringify(cookie, null, 2) );
        phantom.addCookie(cookie);
    });
}

set_cookies(address, options_file);
//console.log('c?: ' + JSON.stringify(phantom.cookies, null, 2)); phantom.exit();

page.onConsoleMessage = function(msg) {
    console.log(msg);
};

page.onError = function(msg, trace) {
    var msgStack = ['ERROR: ' + msg];
    if (trace && trace.length) {
        msgStack.push('TRACE:');
        trace.forEach(function(t) {
          msgStack.push(' -> ' + t.file + ': ' + t.line + (t.function ? ' (in function "' + t.function +'")' : ''));
        });
    }
    console.error(msgStack.join('\n'));
};

console.log('Opening: ' + address );
page.open(address, function (status) {
    if (status !== 'success') {
        console.log('Unable to load page. Status was: ' + status);
        phantom.exit(1);
    }

    window.setTimeout(function () {
        //Standard PhantomJS pattern: Do everything inside a setTimeout to ensure
        // everything loads and runs inside the page.
        set_styling(page);
        set_toc(cookies['toc_levels']);
        write_file(output_file, page.content);
        phantom.exit();
    }, 200);
});

var set_toc = function(maxLevel) {
  if (!maxLevel) {return;}

  // https://support.office.com/en-in/article/Field-codes-TOC-Table-of-Contents-field-1f538bc4-60e6-4854-9f64-67754d78d05c
  var tocHtml = [
    "<!--[if supportFields]>",
    "<span style='mso-element:field-begin'></span>",
    'TOC \\o "1-' + maxLevel + '" \\u',
    "<span style='mso-element:field-separator'></span>",
    "<![endif]-->",
    "<span style='mso-no-proof:yes' id='word-doc-toc-container'>",
    "[TOC Preview: To update, right-click and choose &quot;Update field&quot;]",
    "</span>",
    "<!--[if supportFields]>",
    "<span style='mso-element:field-end'></span>",
    "<![endif]-->",
  ].join('\n');

  page.evaluate(function(tocHtml) {
    $('#toc-container').append(tocHtml);
    $('#word-doc-toc-container').append($('#toc').detach());
  }, tocHtml);
}

var get_doc_styles = function() {
  var requested_theme = cookies['print_theme'];
  if (!requested_theme) {return '';}

  theme = requested_theme.replace(/\W/g, '');
  console.log('THEME: ' + theme);

  var css;
  try {
    css = filesystem.read('app/assets/stylesheets/doc-styles/' + theme + '.css');
  } catch (e) {
    console.log('ERROR: Failed to open requested theme: ' + theme);
    return '';
  }
  return css;

//  css = css.replace(/(font-family:)(.+)(;)/g, '$1' + cookies['font_face_mapped'] + '$2');
  //scale fonts, converting from pixel to pt: 1 px = 0.75 point; 1 point = 1.333333 px
  /*
    function font_size_replacer(match, p1, p2, offset, string) {
    //font_size_mapped
    //This probably needs to get the adjustment factor from a global variable.
    var scaled_size = parseInt( parseFloat(p2) * 1.2 );
    return p1 + scaled_size + 'pt';
    }

    size_line = size_line.replace(/(font-size:)(.+pt)/g, font_size_replacer);
    face_line = ' font-family: Garamond, sans-serif;';
    face_line = face_line.replace(/(font-family:)(.+);/g, '$1Dingbats;');
    var theme = '/home/root/boop.txt';
    console.log( theme.replace(/\W/g, '') );
  */
  /*
    We have two types of font scaling to consider here:
    A) each font face has its own base size
    B) the user dictates what "size" font they want in the web UI

    Now we have to apply those rules to the numbers present in the doc style.
    Let's ignore A for the moment, and implement B now. A might actually end up
    being as simple as "adding a small percentage of our scaling factor" to the
    number in B anyways.

    fonts.js shows jumps of 4 pixels per font size change. 4px = 3pt.
    Our scaling algo could be:
    style_size = 36pt; (from regex)
    baseline = 'medium'
    font_size = 'large';
    medium scaled to large represents a 3pt increase (aka 4px)
    adjustment = 3;
    new_style_size = 36 + adjustment + 'pt';
    this is really a whole new way to scale fonts, so it's not going to line up
    with how the web UI works via export.js:setFontPrint(). This might be OK,
    based on how Adam wants this to behave in Word.
    We might be able to make things a little nicer if we scale the adjustment factor
    itself based on how base_font_sizes has different baseline sizes (i.e. for all
    the medium fonts. That might really be splitting hairs, though.
    
*/

  return css;
}

var set_styling = function(page) {
  //TODO: use the same parsing technique that get_doc_styles does, for var header (below)
  var doc_styles = get_doc_styles();

  page.evaluate(function(doc_styles, cookies) {

        var html = $('html');
        html.attr('xmlns:v', 'urn:schemas-microsoft-com:vml');
        html.attr('xmlns:o', 'urn:schemas-microsoft-com:office:office');
        html.attr('xmlns:w', 'urn:schemas-microsoft-com:office:word');
        html.attr('xmlns:m', 'http://schemas.microsoft.com/office/2004/12/omml');
        html.attr('xmlns', 'http://www.w3.org/TR/REC-html40');

        var margins = [
            cookies['print_margin_top'],
            cookies['print_margin_right'],
            cookies['print_margin_bottom'],
            cookies['print_margin_left'],
        ].join(' ');

      var font_face_string = cookies['print_font_face_mapped'];
      var font_size_string = cookies['print_font_size_mapped'];

        var header = [
            "<!--[if gte mso 9]>",
            "<xml><w:WordDocument><w:View>Print</w:View>",
            "<w:Zoom>100</w:Zoom><w:DoNotOptimizeForBrowser/></w:WordDocument></xml>",
            "<![endif]-->",
            "<link rel='File-List' href='boop_files/filelist.xml'>",
            "<style><!-- ",
            "@page WordSection1 {margin: " + margins + "; size:8.5in 11.0in; mso-paper-source:0;}",
            "div.WordSection1 {page:WordSection1;}",
            //NOTE: This works in conjunction with the non-Microsoft-specific CSS we inject, too.
            "p.MsoNormal, li.MsoNormal, div.MsoNormal, .MsoToc1 { ",
            "font-family:" + font_face_string + "; font-size:" + font_size_string + "; }",
            ".MsoChpDefault, h1, h2, h3, h4, h5, h6   { font-family:" + font_face_string + "; }",
            "@list l0:level1 { mso-level-text: ''; }",
          doc_styles,
            "--></style>",
        ].join("\n");

        //console.log('header reader: ' + header);
        $('title').after($(header));

        var sheets = [];
        $('.stylesheet-link-tag').not("[media^=screen]").each(function(i, el) {
            sheets.push( el );
        });

        //TODO: Remove ui.css <link> node just in case
        for (var i in sheets) {
            var sheet = sheets[i];
            $('#export-styles').append($(sheet).cssText());
            $(sheet).remove();  //prevents "missing asset" error in Word
        }
        $('#additional_styles').append($('#additional_styles').cssText());


        //BUG: Highlights do not work in DOC, nor do any of the below attempted workarounds.
        //TODO: Perhaps just wrap highlighted text with <u> tags as a lame workaround?
        //var foo = ".highlight-hex-ff3800 { text-decoration: underline; }";
        //$('#highlight_styles').append(foo);
        $('#highlight_styles').append($('#highlight_styles').cssText());

        // Forcibly remove bullets from LI tags and undo Word's LI indentation
        $('li').attr('style', 'mso-list:l0 level1; margin-left: -.5in;');

  }, doc_styles, cookies);
}

var write_file = function(output_file, content) {
    if (output_file == '-') {
        console.log(content);
        return;
    }

    try {
        filesystem.write(output_file, content, 'w');
        console.log('Wrote ' + content.length + ' bytes to ' + output_file);
    } catch(e) {
        console.log(e);
    }
}

/*
var get_css = function(stylesheets) {
    var content = [];
  for (var i in stylesheets) {
        var url = stylesheets[i];

        var page2 = require('webpage').create();
        page2.onConsoleMessage = function(msg) {
            console.log(msg);
        };

        console.log( 'GC: ' + url);
        page2.open(url, function(status) {
            console.log('L1');
            if (status !== 'success') {
                console.log('Unable to load CSS (' + url + '). Status was: ' + status);
                phantom.exit(1);
            }

            content.push(page2.content);
            console.log(url + ' => ' + page2.content);
            //page2.close();
        });
    }
  return(content.join("\n"));
}
  */


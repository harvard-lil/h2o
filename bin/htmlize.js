//PhantomJS script

console.log('htmlize.js running...');

var system = require('system'),
    address, output, size;
address = system.args[1];
output_file = system.args[2];
options_file = system.args[3];
var page = require('webpage').create();
var cookies = {};

var set_cookies = function(address, options_file) {
    var parser = document.createElement('a');
    parser.href = address;
    var cookie_domain = parser.hostname;

    var json_string, json;
    try {
        json_string = require('fs').read(options_file);
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
        //Do everything inside a setTimeout to ensure everything loads and runs inside the page

        set_styling(page);
        set_toc(cookies['toc_levels']);
        write_file(output_file, page.content);
        phantom.exit();
    }, 200);
});

var set_toc = function(maxLevel) {
    console.log('St: ' + maxLevel);
    if (!maxLevel) {return;}
    // https://support.office.com/en-in/article/Field-codes-TOC-Table-of-Contents-field-1f538bc4-60e6-4854-9f64-67754d78d05c

    page.evaluate(function(maxLevel) {
        var f = ["<!--[if supportFields]>",
                 "<span style='mso-element:field-begin'></span>",
                 'TOC \\o "1-' + maxLevel + '" \\u',
                 "<span style='mso-element:field-separator'></span>",
                 "<![endif]-->",
                 "<span style='mso-no-proof:yes'>[To update TOC, right-click and choose &quot;Update field&quot;]</span>",
                 "<!--[if supportFields]>",
                 "<span style='mso-element:field-end'></span>",
                 "<![endif]-->",
                ];
        $('.MsoToc1').append(f.join('\n'));
    }, maxLevel);
}


var set_styling = function(page) {

    page.evaluate(function(cookies) {

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
        //console.log('Newmargins: ' + margins);

        var font_face_string = export_h2o_fonts['font_map_fallbacks'][ cookies['print_font_face'] ];
        var font_size_string = export_h2o_fonts['base_font_sizes'][ cookies['print_font_face'] ][ cookies['print_font_size'] ];
        //console.log('ffS: ' + font_face_string + ' -> font-size: ' + font_size_string);

        /* NOTE: We express font-size here in pt, even though it is expressed in px in the
         * browser, but this seems to match up rather well in testing. Small text might be a
         * little too big in the DOC, however. It's not perfect now, but it's pretty good.
         */
        var header = [
            "<!--[if gte mso 9]>",
            "<xml><w:WordDocument><w:View>Edit</w:View><w:Zoom>100</w:Zoom><w:DoNotOptimizeForBrowser/></w:WordDocument></xml>",
            "<![endif]-->",
            "<link rel='File-List' href='boop_files/filelist.xml'>",
            "<style><!-- ",
            //top, right, bottom, left
            "@page WordSection1 {margin: " + margins + "; size:8.5in 11.0in; mso-paper-source:0;}",
            "div.WordSection1 {page:WordSection1;}",
            //NOTE: This works in conjunction with the non-Microsoft-specific CSS we inject, too.
            //TODO: convert font size to points
            "p.MsoNormal, li.MsoNormal, div.MsoNormal { font-family:" + font_face_string + "; font-size:" + font_size_string + "pt; }",
            ".MsoChpDefault, h1, h2, h3, h4, h5, h6   { font-family:" + font_face_string + "; }",
            ".MsoToc1 { font-family:" + font_face_string + ";   list-style-type: none !important;}",
            ".MsoToc1 * { font-family:" + font_face_string + ";   list-style-type: none !important;}",
            "--></style>",
        ];
        $('title').after($(header.join("\n")));

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

        //BUG: Highlights do not work, nor do any of the below attempted workarounds.
        //TODO: Perhaps just wrap highlighted text with <u> tags as a lame workaround?
        //var foo = ".highlight-hex-ff3800 { text-decoration: underline; }";
        //$('#highlight_styles').append(foo);
        $('#highlight_styles').append($('#highlight_styles').cssText());

        /*
         * @example $.rule('p,div').filter(function(){ return this.style.display != 'block'; }).remove();
         * @example $.rule('div{ padding:20px;background:#CCC}, p{ border:1px red solid; }').appendTo('style');
         * @example $.rule('div{}').append('margin:40px').css('margin-left',0).appendTo('link:eq(1)');
         * @example var text = $.rule('#screen h2').add('h4').end().eq(4).text();
         */

    }, cookies);
}

var write_file = function(output_file, content) {
    if (output_file == '-') {
        console.log(content);
        return;
    }

    try {
        require('fs').write(output_file, content, 'w');
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


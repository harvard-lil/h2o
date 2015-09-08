//PhantomJS script

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

    var json_string = require('fs').read(options_file);
    console.log('json_file: ' + json_string);
    var json = JSON.parse(json_string);
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

var cssFiles = [];
page.onResourceRequested = function(requestData) {
    var url = requestData['url'];
    if ((/http.+?\.css\b/gi).test(url)) {
        cssFiles.push(url);
        //console.log( JSON.stringify(requestData, null, 2) );
    }
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
        //for (var i in cssFiles) { console.log('file: ' + cssFiles[i]); }
        write_file(output_file, page.content);
        phantom.exit();
    }, 200);
});

var set_styling = function(page) {
    var margin_string = Array(5).join(cookies['print_margin_size'] + ' ');
    console.log('MS: ' + margin_string);

    page.evaluate(function(margin_string) {
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

        var html = $('html');
        html.attr('xmlns:v', 'urn:schemas-microsoft-com:vml');
        html.attr('xmlns:o', 'urn:schemas-microsoft-com:office:office');
        html.attr('xmlns:w', 'urn:schemas-microsoft-com:office:word');
        html.attr('xmlns:m', 'http://schemas.microsoft.com/office/2004/12/omml');
        html.attr('xmlns', 'http://www.w3.org/TR/REC-html40');

        var header = [
            "<!--[if gte mso 9]>",
            "<xml><w:WordDocument><w:View>Edit</w:View><w:Zoom>100</w:Zoom><w:DoNotOptimizeForBrowser/></w:WordDocument></xml>",
            "<![endif]-->",
            "<link rel='File-List' href='boop_files/filelist.xml'>",
            "<style><!-- ",
            //top, right, bottom, left
            "@page WordSection1 {margin: " + margin_string + "; size:8.5in 11.0in; mso-paper-source:0;}",
            "div.WordSection1 {page:WordSection1;}",
            "p.MsoNormal, li.MsoNormal, div.MsoNormal { font-size: 18.0pt; font-family:'Garamond',serif; }",
            "--></style>",
        ];

        $('title').after($(header.join("\n")));

        //Note: Setting width here has no effect in DOC. WE PROBABLY DO NOT NEED THIS AT ALL.
        //$('#export-styles').append("\n .wrapper { margin: " + margin_string + " !important; }");
    }, margin_string);
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


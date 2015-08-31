
//console.log("dev-exiting"); phantom.exit();

var system = require('system'),
    address, output, size;
address = system.args[1];
output_file = system.args[2];
options_file = system.args[3];
var page = require('webpage').create();

var set_cookies = function(address, options_file) {
    phantom.clearCookies();  //TODO: is this really needed?

    var parser = document.createElement('a');
    parser.href = address;
    var cookie_domain = parser.hostname;

    var json_string = require('fs').read(options_file);
    console.log('json_file: ' + json_string);
    var json = JSON.parse(json_string);
    Object.keys(json).forEach(function(name) {
        var cookie = {
            'name': name,
            'value': json[name],
            'domain': cookie_domain,
            'path': '/'
        };
        //console.log('Baking: ',  JSON.stringify(cookie, null, 2) );
        phantom.addCookie(cookie);
    });
} //set_cookies

//page.viewportSize = { width: 824, height: 600 };
//page.paperSize = { width: size[0], height: size[1], margin: '0px' };
/*
     page.paperSize = {
        format: 'A4',
        margin: {
            left: marginLeft,
            top: marginTop,
            right: marginRight,
            bottom: marginBottom
        }
    };  
*/

set_cookies(address, options_file);

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
console.log('Opening: ' + address );
page.open(address, function (status) {
    if (status !== 'success') {
        console.log('Unable to load the address. Status was: ' + status);
        phantom.exit(1);
    }

    window.setTimeout(function () {
        //Do everything inside a setTimeout to ensure everything loads and runs inside the page
        get_stylesheets(page)
        for (var i in cssFiles) {
            // console.log('file: ' + cssFiles[i]);
        }
        write_file(output_file, page.content);

        phantom.exit();
    }, 200);
});

var get_stylesheets = function(page) {
    page.evaluate(function() {
        var sheets = [];
        $('.stylesheet-link-tag').not("[media^=screen]").each(function(i, el) {
            //console.log( JSON.stringify($(el).attr('media'), null, 2) );
            //sheets.push( $(el).get(0).href );
            sheets.push( el );
            //console.log(el);
        });

        for (var i in sheets) {
            var sheet = sheets[i];
            console.log('injecting: ' + $(sheet).get(0).href);

            //s.appendTo($(sheet));
            $('#export-styles').append($(sheet).cssText());
            //$(sheet).after($(sheet).cssText());
            //$('#css-ui').cssText()  in the context of the page, will give us the CSS it points at! \o/
            //$(target).after(contentToBeInserted)
        }
    });
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

var get_css = function(stylesheets) {
    var content = [];
/*
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
  */
  return(content.join("\n"));
}


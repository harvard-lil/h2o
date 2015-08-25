

phantom.clearCookies();
//var cookie_domain = 'h2o.law.harvard.edu';
var cookie_domain = 'sskardal03.murk.law.harvard.edu';

var cookies = [
    {
        'name': 'print_dates_details',
        'value': true
    },
    {
        'name': 'print_paragraph_numbers',
        'value': false
    },
    {
        'name': 'print_annotations',
        'value': true
    },
    {
        'name': 'hidden_text_display',
        'value': true
    },
    {
        'name': 'print_highlights',
        'value': 'all'
    },
    {
        'name': 'print_export',
        'value': true
    }
];


//console.log("dev-exiting"); phantom.exit();

var system = require('system'),
    address, output, size;
address = system.args[1];
output_file = system.args[2];
var page = require('webpage').create();

cookies.forEach(function(cookie) {
    //TODO: set the domain from $address
    cookie.domain = cookie_domain;
    cookie.path = '/';
    phantom.addCookie(cookie);
});

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
console.log('running...');
page.open(address, function (status) {
    if (status !== 'success') {
        console.log('Unable to load the address. Status was: ' + status);
        phantom.exit(1);
    }

    window.setTimeout(function () {
        //We need this delay to make sure everything loads and runs inside the page
        process_page(page);
        phantom.exit();
    }, 200);
});

var process_page = function(page) {
    console.log('starting');
    get_stylesheets(page)

    for (var i in cssFiles) {
       // console.log('file: ' + cssFiles[i]);
    }

    write_file(output_file, page.content);
}

var get_stylesheets = function(page) {
    page.evaluate(function() {

        //console.log( $('.stylesheet-link-tag').not("[media^=screen]").first().get(0).href );
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
            //    (copy into an array to avoid modifying that iterator during iteration
            //  iterate over each CSS tag, append its cssText() to it as a sibling
        }
    });
}

var write_file = function(output_file, content) {
    if (!output_file) {
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


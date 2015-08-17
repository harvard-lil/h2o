
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

cookies.forEach(function(cookie) { 
    cookie.domain = cookie_domain;
    phantom.addCookie(cookie);
});

//console.log("dev-exiting"); phantom.exit();

var page = require('webpage').create();
var system = require('system'),
    address, output, size;

address = system.args[1];
output_file = system.args[2];

if (!output_file) {
    console.log('Missing required argument for output file');
    phantom.exit(1);
}
    
 
page.viewportSize = { width: 824, height: 600 };
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

//page.onResourceRequested = function(requestData, request) { console.log( 'RESOURCE: ' + requestData['url'] ); };

var cssFiles = {}
page.onResourceRequested = function(requestData, request) {
    var url = requestData['url'];
    if (url.match(/\.css\b/)) {
        //console.log( 'RESOURCE: ' + requestData['url'] );
        //console.log( '????????: ' + requestData );
        cssFiles[url] = true;
    }
    
};
//This could be where we keep the javascript we need to run in the page rather than
//loading it for screen and making it all operate under a big if $.cookie('force_download') if-statement.
//phantom.injectJs('app/assets/javascript/modernizr.js'); 

page.open(address, function (status) {
    if (status !== 'success') {
        console.log('Unable to load the address. Status was: ' + status);
        phantom.exit(1);
    }
    window.setTimeout(function () {
        //We need this delay to make sure everything loads and runs inside the page
        //page.evaluate(function() {
        //    $("h1").first().text($("h1").first().text() + ": modified by phantomJS javascript");
        //});
        //page.render(output_file);

        page.evaluate(function() {
            //export_functions.title_debug('BOOPTEST 2');
        });

        console.log('CSS files: ', cssFiles.keys);

        var fs = require('fs');
        try {
            fs.write(output_file, page.content, 'w');
            console.log('Wrote ' + page.content.length + ' bytes to ' + output_file);
        } catch(e) {
            console.log(e);
        }

        phantom.exit();
    }, 200);
});

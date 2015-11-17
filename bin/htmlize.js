//PhantomJS script

console.log('htmlize.js running...');

var system = require('system');
var address = system.args[1];
var output_file = system.args[2];
var options_file = system.args[3];
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
        json = JSON.parse(json_string);
    } catch(e) {
        console.error('Error reading/parsing JSON options file: ' + e);
        phantom.exit(1);
    }
    //console.log('json_file: ' + json_string);

    Object.keys(json).forEach(function(name) {
        cookies[name] = json[name];
        var cookie = {
          name: name,
          value: json[name],
          domain: cookie_domain,
          path: '/',
        };
        //console.log('Baking: ',  JSON.stringify(cookie, null, 2) );
        phantom.addCookie(cookie);
    });
}

set_cookies(address, options_file);
//console.log('c?: ' + JSON.stringify(phantom.cookies, null, 2));

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
page.open(address, function(status) {
  if (status !== 'success') {
    console.log('Unable to load page. Status was: ' + status);
    phantom.exit(1);
  }

  //waitFor does not work exactly as advertised due to a bug in PhantomJS.
  //It only fires once, and only at the end of the page load completing.
  //We might need an additional setTimeout around this one, but the
  //internet is reporting mixed results with that workaround.
  setTimeout(function() {
    waitFor(
      function() {  //"test condition" function
        return page.evaluate(function() {
          console.log('window.status: ' + window.status);
          return window.status == 'annotation_load_complete';
        });
      },
      function() {  //thing to do when it's ready function
        console.log('READY GOGOGO');
        set_styling(page);
        set_toc(cookies['toc_levels']);
        //TODO: Do export post-processing work here
        write_file(output_file, page.content);

        window.setTimeout(function () {
          phantom.exit();
        }, 2000);
      },
      1200000  //Arbitrarily huge number of seconds to let giant playlists finish
    );
  }, 10);
});

/**
 * @param testFx javascript condition that evaluates to a boolean,
 * it can be passed in as a string (e.g.: "1 == 1" or "$('#bar').is(':visible')" or
 * as a callback function.
 * @param onReady what to do when testFx condition is fulfilled,
 * it can be passed in as a string (e.g.: "1 == 1" or "$('#bar').is(':visible')" or
 * as a callback function.
 * @param timeOutMillis the max amount of time to wait.
 */
var waitFor = function(testFx, onReady, timeOutMillis) {
  var maxtimeOutMillis = timeOutMillis ? timeOutMillis : 20000;
  var start = new Date().getTime();
  var condition = false;
  var interval = setInterval(function() {
    if ((new Date().getTime() - start < maxtimeOutMillis) && !condition) {
      // If not time-out yet and condition not yet fulfilled
      condition = (typeof(testFx) === "string" ? eval(testFx) : testFx());
    } else {
      if(!condition) {
        console.log("'waitFor()' timeout");
        phantom.exit(1);
      } else {
        // Condition fulfilled (timeout and/or condition is true)
        console.log("'waitFor()' finished in " + (new Date().getTime() - start) + "ms.");
        typeof(onReady) === "string" ? eval(onReady) : onReady();
        clearInterval(interval);
      }
    }
  }, 300); //< repeat check every X milliseconds
};

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
  var theme = cookies['print_theme'];
  var font_face_string = cookies['print_font_face_mapped'];
  var font_size_string = cookies['print_font_size_mapped'];

  var css = filesystem.read('app/assets/stylesheets/doc-export.css').replace(
    /(font-family:)(.+);/g,
    '$1' + font_face_string + ';'
  );

  var font_size_replacer = function (match, p1, p2, p3, offset, string) {
    var scaling_name = cookies['print_font_size'];
    // This is the same 4px jump from fonts.js, converted to pt, assuming the base
    // Doc style is sized as medium and thus requires no scaling.
    var size_conversion = {
      small: -3,
      medium: 0,
      large: 3,
      xlarge: 6,
    }
    var new_size = parseInt(parseFloat(p2) + size_conversion[scaling_name]);
    return p1 + new_size + p3;
  }

  return css.replace(/(font-size:)(.+)(pt;)/g, font_size_replacer);
}

var set_styling = function(page) {
  var doc_styles = get_doc_styles();
  //console.log('STYLES: ' + doc_styles);

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


var h2o_fonts = {
  font_map: {
	goudy: 'sorts-mill-goudy',
	leitura: 'leitura-news',
	garamond: 'adobe-garamond-pro',
	futura: 'futura-pt',
	dagny: 'ff-dagny-web-pro',
	proxima: 'proxima-nova',
	verdana: 'Verdana'
  },
  font_map_fallbacks: {
    // Double-quoting fonts with spaces in the name seems to cause errors for exports opened in Mac Word 2011
	goudy: "sorts-mill-goudy,Sorts Mill Goudy,Goudy,Goudy Old Style,Garamond",
	leitura: "leitura-news,Leitura News,adobe-garamond-pro,Garamond,Adobe Garamond Pro,GaramondNo8",
	garamond: "adobe-garamond-pro,Garamond,Adobe Garamond Pro,GaramondNo8",
	futura: "futura-pt,Futura PT,Futura,Garamond",
	dagny: "ff-dagny-web-pro,FF Dagny Web Pro,FF Dagny Pro,FF Dagny,Verdana,Arial,Helvetica,sans-serif,Garamond",
	proxima: "proxima-nova,Proxima Nova,futura-pt,Futura PT,Futura,Garamond",
	verdana: "Verdana,Arial,Helvetica,sans-serif"
  },
  //sizes are in pixels
  base_font_sizes: {
	  goudy: {
	    'small' : 14,
	    'medium' : 18,
	    'large' : 22,
	    'xlarge' : 26
	  },
	  leitura: {
	    'small' : 13,
	    'medium' : 17,
	    'large' : 21,
	    'xlarge' : 25
	  },
	  garamond: {
	    'small' : 16,
	    'medium' : 20,
	    'large' : 24,
	    'xlarge' : 28
	  },
	  futura: {
	    'small' : 16,
	    'medium' : 20,
	    'large' : 24,
	    'xlarge' : 28
	  },
	  dagny: {
	    'small' : 14,
	    'medium' : 18,
	    'large' : 22,
	    'xlarge' : 26
	  },
	  proxima: {
	    'small' : 14,
	    'medium' : 18,
	    'large' : 22,
	    'xlarge' : 26
	  },
	  verdana: {
	    'small' : 11,
	    'medium' : 15,
	    'large' : 19,
	    'xlarge' : 23
	  }
  }
};

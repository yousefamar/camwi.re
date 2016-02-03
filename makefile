export PATH := $(shell npm bin):$(PATH)

all: camwire.min.js server/server.js style.css

server/server.js: server/server.ls
	lsc -c $<

camwire.min.js: camwire.ls
	# TODO Actually minify. :) This is just a basic bundle.
	browserify -t [ anyify --ls [ livescript?compile ] ] $< > $@

style.css: style.scss
	node-sass $< > $@

clean:
	@rm -rf camwire.min.js server/server.js style.css

.PHONY: all clean

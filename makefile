export PATH := $(shell npm bin):$(PATH)

# Directory for built server-side files
LIB=lib
# Directory for built client-side files
STATIC=static

all: server client

server: $(LIB)/server.js

client: $(STATIC)/index.html $(STATIC)/main.js $(STATIC)/style.css

$(LIB)/server.js: server/main.ls
	@mkdir -p $(LIB)
	lsc --compile --print $< > $@

$(STATIC)/main.js: client/main.ls
	@mkdir -p $(STATIC)
	browserify -t [ anyify --ls [ livescript?compile ] ] $< > $@

$(STATIC)/style.css: style.scss
	@mkdir -p $(STATIC)
	node-sass $< > $@

$(STATIC)/index.html: index.html
	@mkdir -p $(STATIC)
	cp $< $@

clean:
	@rm -rf $(STATIC) $(LIB)

.PHONY: all client server clean

all: data/gzs data/repos.txt.gz data/repos.json.gz
%.txt: %.json
	jq -r '.full_name' $< > $@
%.gz: %
	gzip -c -9 $< >$@
%.abbrev.json: %.json
	jq -c '{id, full_name, fork, description}' $< >$@
data/gzs: $(patsubst %.json,%.json.gz,$(wildcard data/repos-*.json))
data/repos.txt: $(patsubst %.json,%.txt,$(sort $(wildcard data/repos-*.json)))
	find data -name 'repos-*.txt' | sort | while read f; do cat $$f; done >$@
data/repos.json: $(patsubst %.json,%.abbrev.json,$(sort $(wildcard data/repos-*.json)))
	find data -name 'repos-*.abbrev.json' | sort | while read f; do cat $$f; done >$@

all: data/gzs data/repos.txt data/repos.txt.gz
%.txt: %.json
	jq -r '.full_name' $< > $@
%.gz: %
	rm -f $@
	gzip -c --keep -9 $< >$@
data/gzs: $(patsubst %.json,%.json.gz,$(wildcard data/*.json))
data/repos.txt: $(patsubst %.json,%.txt,$(sort $(wildcard data/*.json)))
	find data -name 'repos-*.txt' | sort | while read f; do cat $$f; done > data/repos.txt

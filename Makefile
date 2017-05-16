all: data/repos.txt.gz data/repos.json.gz
%.txt: %.json.gz
	zcat $< | jq -r '.full_name' > $@
%.gz: %
	gzip -c -9 $< >$@
%.json.abbrev.gz: %.json.gz
	zcat $< | jq -c '{id, full_name, fork, description}' | gzip >$@
data/repos.txt: $(patsubst %.json.gz,%.txt,$(sort $(wildcard data/repos-*.json.gz)))
	find data -name 'repos-*.txt' | sort | while read f; do cat $$f; done >$@
data/repos.json.gz: $(patsubst %.json.gz,%.json.abbrev.gz,$(sort $(wildcard data/repos-*.json.gz)))
	find data -name 'repos-*.json.abbrev.gz' | sort | while read f; do zcat $$f; done | gzip >$@

all: data/xzs data/repos.txt data/repos.txt.xz
%.txt: %.json
	jq -r '.full_name' $< > $@
%.gz: %
	rm $@
	gzip --keep $<
data/xzs: $(patsubst %.json,%.json.xz,$(wildcard data/*.json))
data/repos.txt: $(patsubst %.json,%.txt,$(sort $(wildcard data/*.json)))
	cat $^ > $@

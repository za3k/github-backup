all: data/gzs data/repos.txt data/repos.txt.gz
%.txt: %.json
	jq -r '.full_name' $< > $@
%.gz: %
	rm $@
	gzip --keep -9 $<
data/gzs: $(patsubst %.json,%.json.gz,$(wildcard data/*.json))
data/repos.txt: $(patsubst %.json,%.txt,$(sort $(wildcard data/*.json)))
	cat $^ > $@

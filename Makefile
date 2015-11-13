all: data/xzs data/repos.txt data/repos.txt.xz
%.txt: %.json
	jq -r '.full_name' $< > $@
%.xz: %
	xz --keep $<
data/xzs: $(patsubst %.json,%.json.xz,$(wildcard data/*.json))
data/repos.txt: $(patsubst %.json,%.txt,$(wildcard data/*.json))
	cat $^ > $@

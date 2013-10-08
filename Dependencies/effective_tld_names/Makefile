.PHONY: all clean

PRODUCT=ANTEffectiveTLDNames.c

all: $(PRODUCT)

$(PRODUCT): effective_tld_names.dat process.py
	./process.py $< | xcrun gperf -L ANSI-C >$@


clean:
	rm -f $(PRODUCT)

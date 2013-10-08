.PHONY: all clean

PRODUCT=ANTEffectiveTLDNames.c

all: $(PRODUCT)

$(PRODUCT): effective_tld_names.dat process.py Makefile
	./process.py $< | xcrun gperf -L ANSI-C  --multiple-iterations=10 >$@


clean:
	rm -f $(PRODUCT)

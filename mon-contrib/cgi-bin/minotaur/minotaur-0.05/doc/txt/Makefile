# The new rules

include ../common/rules

txt: $(notdir $(patsubst %.sgml,%.txt, $(wildcard ../sgml/*.sgml)))

clean:
	-rm -f *.txt


MAKEFLAGS+= --no-builtin-rules
MAKEFLAGS+= --no-builtin-variables

USERS+= john
USERS+= jane

USER_PHOTO= $(addprefix user-photo-,$(addsuffix .doe.jpg,$(USERS)))

.PHONY: all clean

all: $(USER_PHOTO)

user-photo-%.doe.jpg: user-badge.svg
	sed -E 's,@@NAME@@,$*,g' $< \
		| inkscape --pipe -h 448 --export-type png \
		| convert - $@

clean:
	rm -f *.doe.jpg

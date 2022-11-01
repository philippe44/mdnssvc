ifeq ($(CC),cc)
CC=$(lastword $(subst /, ,$(shell readlink -f `which cc`)))
endif

ifeq ($(findstring gcc,$(CC)),gcc)
CFLAGS  += -Wno-stringop-truncation -Wno-stringop-overflow -Wno-format-truncation
LDFLAGS += -s
else
CFLAGS += -fno-temp-file	
endif

PLATFORM ?= $(firstword $(subst -, ,$(CC)))
HOST ?= $(word 2, $(subst -, ,$(CC)))

SRC 		= .
BIN		= bin/climdnssvc-$(HOST)-$(PLATFORM)
LIB		= lib/$(HOST)/$(PLATFORM)/libmdnssvc.a
BUILDDIR	= build/$(HOST)/$(PLATFORM)

DEFINES  = -DNDEBUG 
CFLAGS  += -Wall -fPIC -O2 $(DEFINES) -ggdb -fdata-sections -ffunction-sections
LDFLAGS += -lpthread -ldl -lm -L. 

vpath %.c $(SRC)

INCLUDE = -I$(SRC) 

SOURCES = mdns.c mdnsd.c 
		
OBJECTS = $(SOURCES:%.c=$(BUILDDIR)/%.o) 

all: lib $(BIN)
lib: directory $(LIB)
directory:
	@mkdir -p bin
	@mkdir -p lib/$(HOST)/$(PLATFORM)	
	@mkdir -p $(BUILDDIR)

$(BIN): $(BUILDDIR)/climdnssvc.o  $(LIB)
	$(CC) $^ $(CFLAGS) $(LDFLAGS) -o $@
	
$(LIB): $(OBJECTS)
	$(AR) -rcs $@ $^

$(BUILDDIR)/%.o : %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(INCLUDE) $< -c -o $@

cleanlib:
	rm -f $(BUILDDIR)/*.o $(LIB) 

clean: cleanlib
	rm -f $(BIN)

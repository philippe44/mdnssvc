ifeq ($(CC),cc)
CC=$(lastword $(subst /, ,$(shell readlink -f `which cc`)))
endif

PLATFORM ?= $(firstword $(subst -, ,$(CC)))
HOST ?= $(word 2, $(subst -, ,$(CC)))

SRC 		= .
BIN			= bin/tinysvcmdns-$(PLATFORM)
LIB			= lib/$(HOST)/$(PLATFORM)/libtinysvcmdns.a
BUILDDIR	= build/$(PLATFORM)

DEFINES  = -DNDEBUG
CFLAGS  += -Wall -Wno-stringop-truncation -Wno-stringop-overflow -Wno-format-truncation -fPIC -ggdb -O2 $(OPTS) $(INCLUDE) $(DEFINES) -fdata-sections -ffunction-sections 
LDFLAGS += -s -lpthread -ldl -lm -lrt -L. 

vpath %.c $(SRC)

INCLUDE = -I$(SRC) 

SOURCES = mdns.c mdnsd.c tinysvcmdns.c
		
OBJECTS = $(patsubst %.c,$(BUILDDIR)/%.o,$(SOURCES)) 
LIBOBJECTS = $(patsubst %.c,$(BUILDDIR)/lib/%.o,$(SOURCES)) 

all: directory $(BIN) $(LIB)

$(BIN): $(OBJECTS)
	echo $(BIN)
	$(CC) $(OBJECTS) $(LIBRARY) $(LDFLAGS) -o $@

$(LIB): $(LIBOBJECTS)
	$(AR) rcs $@ $(LIBOBJECTS) 

directory:
	@mkdir -p bin
	@mkdir -p lib/$(HOST)/$(PLATFORM)	
	@mkdir -p $(BUILDDIR)/lib

$(BUILDDIR)/%.o : %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(INCLUDE) $< -c -o $@

$(BUILDDIR)/lib/%.o : %.c
	$(CC) $(CFLAGS) -g -DMDNS_SVC $(CPPFLAGS) $(INCLUDE) $< -c -o $@
	
clean:
	rm -f $(OBJECTS) $(LIBOBJECTS) $(BIN) $(LIB)


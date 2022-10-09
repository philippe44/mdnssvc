ifeq ($(CC),cc)
CC=$(lastword $(subst /, ,$(shell readlink -f `which cc`)))
endif

PLATFORM ?= $(firstword $(subst -, ,$(CC)))
HOST ?= $(word 2, $(subst -, ,$(CC)))

SRC 		= .
BIN			= bin/climdnssvc-$(PLATFORM)
LIB			= lib/$(HOST)/$(PLATFORM)/libtinysvcmdns.a
BUILDDIR	= build/$(PLATFORM)

DEFINES  = -DNDEBUG
CFLAGS  += -Wall -Wno-stringop-truncation -Wno-stringop-overflow -Wno-format-truncation -fPIC -ggdb -O2 $(DEFINES) -fdata-sections -ffunction-sections 
LDFLAGS += -s -lpthread -ldl -lm -lrt -L. 

vpath %.c $(SRC)

INCLUDE = -I$(SRC) 

SOURCES = mdns.c mdnsd.c 
		
OBJECTS = $(SOURCES:%.c=$(BUILDDIR)/%.o) 

all: directory $(BIN) $(LIB)

$(BIN): $(BUILDDIR)/climdnssvc.o $(LIB)
	$(CC) $^ $(LIBRARY) $(LDFLAGS) -o $@
	
$(LIB): $(OBJECTS)
	$(AR) rcs $@ $^
	
directory:
	@mkdir -p bin
	@mkdir -p lib/$(HOST)/$(PLATFORM)	
	@mkdir -p $(BUILDDIR)/lib

$(BUILDDIR)/%.o : %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(INCLUDE) $< -c -o $@

clean:
	rm -f $(BUILDDIR)/*.o $(BIN) $(LIB)


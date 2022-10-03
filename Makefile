ifeq ($(CC),cc)
CC=$(lastword $(subst /, ,$(shell readlink -f `which cc`)))
endif

PLATFORM ?= $(firstword $(subst -, ,$(CC)))
HOST ?= $(word 2, $(subst -, ,$(CC)))

SRC 		= .
EXECUTABLE	= bin/tinysvcmdns-$(PLATFORM)
LIB		= lib/$(PLATFORM)/tinysvcmdns.a
OBJ		= build/$(PLATFORM)
LIBOBJ	= build/lib/$(PLATFORM)

DEFINES  = -DNDEBUG
CFLAGS  += -Wall -Wno-stringop-truncation -Wno-stringop-overflow -Wno-format-truncation -fPIC -ggdb -O2 $(OPTS) $(INCLUDE) $(DEFINES) -fdata-sections -ffunction-sections 
LDFLAGS += -s -lpthread -ldl -lm -lrt -L. 

vpath %.c $(SRC)

INCLUDE = -I$(SRC) 

SOURCES = mdns.c mdnsd.c tinysvcmdns.c
		
OBJECTS = $(patsubst %.c,$(OBJ)/%.o,$(SOURCES)) 
LIBOBJECTS = $(patsubst %.c,$(LIBOBJ)/%.o,$(SOURCES)) 

all: $(EXECUTABLE) $(LIB)

$(EXECUTABLE): $(OBJECTS)
	$(CC) $(OBJECTS) $(LIBRARY) $(LDFLAGS) -o $@

$(LIB): $(LIBOBJECTS)
	$(AR) rcs $@ $(LIBOBJECTS) 

$(OBJECTS): | bindir $(OBJ)
$(LIBOBJECTS): | libdir $(LIBOBJ)

$(OBJ):
	@mkdir -p $@

$(LIBOBJ):
	@mkdir -p $@
	
bindir:	
	@mkdir -p bin

libdir:
	@mkdir -p lib/$(PLATFORM)

$(OBJ)/%.o : %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(INCLUDE) $< -c -o $@

$(LIBOBJ)/%.o : %.c
	$(CC) $(CFLAGS) -DMDNS_SVC $(CPPFLAGS) $(INCLUDE) $< -c -o $@
	
clean:
	rm -f $(OBJECTS) $(LIBOBJECTS) $(EXECUTABLE) $(LIB)


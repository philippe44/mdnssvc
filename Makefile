SRC 		= .
EXECUTABLE	= ./bin/tinysvcmdns-$(PLATFORM)
LIB		= ./targets/linux/$(PLATFORM)/tinysvcmnds.a
OBJ		= build/$(PLATFORM)
LIBOBJ		= build/lib/$(PLATFORM)

DEFINES  = -DNDEBUG
CFLAGS  += -Wall -Wno-stringop-truncation -Wno-format-truncation -fPIC -ggdb -O2 $(OPTS) $(INCLUDE) $(DEFINES) -fdata-sections -ffunction-sections 
LDFLAGS += -lpthread -ldl -lm -lrt -L. 

vpath %.c $(SRC)

INCLUDE = -I$(SRC) 

SOURCES = mdns.c mdnsd.c tinysvcmdns.c
		
OBJECTS = $(patsubst %.c,$(OBJ)/%.o,$(SOURCES)) 
LIBOBJECTS = $(patsubst %.c,$(LIBOBJ)/%.o,$(SOURCES)) 

all: $(EXECUTABLE) $(LIB)

$(EXECUTABLE): $(OBJECTS)
	$(CC) $(OBJECTS) $(LIBRARY) $(LDFLAGS) -o $@

$(LIB): $(LIBOBJECTS)
	ar rcs $@ $(LIBOBJECTS) 

$(OBJECTS): | bin $(OBJ)
$(LIBOBJECTS): | lib $(LIBOBJ)

$(OBJ):
	@mkdir -p $@

$(LIBOBJ):
	@mkdir -p $@
	
bin:	
	@mkdir -p bin

lib:
	@mkdir -p targets/linux/$(PLATFORM)

$(OBJ)/%.o : %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(INCLUDE) $< -c -o $@

$(LIBOBJ)/%.o : %.c
	$(CC) $(CFLAGS) -DMDNS_SVC $(CPPFLAGS) $(INCLUDE) $< -c -o $@
	
clean:
	rm -f $(OBJECTS) $(LIBOBJECTS) $(EXECUTABLE) $(LIB)


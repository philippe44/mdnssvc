SRC 		= .
LIBRARY 	=
EXECUTABLE	= ./bin/tinysvcmdns-$(PLATFORM)
OBJ		= build/$(PLATFORM)

DEFINES  = -DNDEBUG
CFLAGS  += -Wall -Wno-stringop-truncation -Wno-format-truncation -fPIC -ggdb -O2 $(OPTS) $(INCLUDE) $(DEFINES) -fdata-sections -ffunction-sections 
LDFLAGS += -lpthread -ldl -lm -lrt -L. 

vpath %.c $(SRC)

INCLUDE = -I$(SRC) 

SOURCES = mdns.c mdnsd.c tinysvcmdns.c
		
OBJECTS = $(patsubst %.c,$(OBJ)/%.o,$(SOURCES)) 

all: $(EXECUTABLE)

$(EXECUTABLE): $(OBJECTS)
	$(CC) $(OBJECTS) $(LIBRARY) $(LDFLAGS) -o $@

$(OBJECTS): | bin $(OBJ)

$(OBJ):
	@mkdir -p $@
	
bin:	
	@mkdir -p bin

$(OBJ)/%.o : %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(INCLUDE) $< -c -o $@
	
clean:
	rm -f $(OBJECTS) $(EXECUTABLE) $(LIB)


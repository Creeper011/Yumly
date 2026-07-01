ROOT := ../../..
LIBDIR := $(abspath $(ROOT)/build/lib/c)
TARGET := yumagotchi
SOURCES := src/main.c src/config.c src/pet.c

CPPFLAGS += -I$(ROOT)/include
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic -O2
LDFLAGS += -L$(LIBDIR) -Wl,-rpath,$(LIBDIR)
LDLIBS += -lyumly

.PHONY: all run clean libyumly

all: $(TARGET)

libyumly:
	cd $(ROOT) && nimble --nimbleDir:build/nimble buildC

$(TARGET): $(SOURCES) src/config.h src/pet.h libyumly
	$(CC) $(CPPFLAGS) $(CFLAGS) $(SOURCES) $(LDFLAGS) $(LDLIBS) -o $@

run: $(TARGET)
	./$(TARGET)

clean:
	$(RM) $(TARGET)

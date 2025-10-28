TARGET = io-watch
CC = cc
CFLAGS = -Wall -Wextra -Werror
LDFLAGS = 
SOURCES = io/watch.c io/watch/inotify.c
OBJECTS = $(SOURCES:.c=.o)
PREFIX = /home/runner/work/empirical/empirical/vendor/bundle/ruby/3.2.0/extensions/x86_64-linux-gnu/3.2.0/io-watch-0.6.3

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^

# To create object files
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Clean Target
clean:
	rm -f $(TARGET) $(OBJECTS)

install: $(TARGET)
	@echo "Installing $(TARGET) to $(PREFIX)/bin"
	mkdir -p $(PREFIX)/bin
	install -m 755 $(TARGET) $(PREFIX)/bin

uninstall:
	@echo "Removing $(TARGET) from $(PREFIX)/bin"
	rm -f $(PREFIX)/bin/$(TARGET)

.PHONY: all clean install uninstall

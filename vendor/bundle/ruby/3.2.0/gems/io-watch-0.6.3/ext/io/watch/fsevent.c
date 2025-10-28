#include "watch.h"

#include <CoreServices/CoreServices.h>
#include <dispatch/dispatch.h>
#include <stdio.h>

enum {
	DEBUG = 0,
};

static
int IO_Watch_path_prefix(const char *path, const char *prefix) {
	size_t path_size = strlen(path);
	size_t prefix_size = strlen(prefix);
	
	if (path_size < prefix_size) {
		return 0;
	}
	
	return strncmp(path, prefix, prefix_size) == 0;
}

static
ssize_t IO_Watch_find_path(struct IO_Watch *watch, const char *path) {
	size_t index = 0;
	
	while (index < watch->size) {
		if (IO_Watch_path_prefix(path, watch->paths[index])) {
			return index;
		}
		
		index += 1;
	}
	
	return -1;
}

// Function to handle filesystem events
void IO_Watch_FSEvent_callback(
	ConstFSEventStreamRef streamRef,
	void *context,
	size_t numberOfEvents,
	void *eventData,
	const FSEventStreamEventFlags eventFlags[],
	const FSEventStreamEventId eventIds[]) {
	
	(void)streamRef; // unused
	const char **eventPaths = (const char**)eventData;
	struct IO_Watch *watch = context;
	
	for (size_t i = 0; i < numberOfEvents; i++) {
		if (DEBUG) fprintf(stderr, "io-watch:IO_Watch_FSEvent_callback: Event %s\n", eventPaths[i]);
		
		// Find the index of the path in the paths array
		ssize_t index = IO_Watch_find_path(watch, eventPaths[i]);
		
		if (index != -1) {
			// Output event data as newline-delimited JSON
			printf("{\"index\":%zu,\"flags\":%u,\"id\":%llu}\n", index, eventFlags[i], eventIds[i]);
		} else {
			fprintf(stderr, "io-watch:IO_Watch_FSEvent_callback: Path not found %s\n", eventPaths[i]);
		}
	}
	
	fflush(stdout);
}

void IO_Watch_run(struct IO_Watch *watch) {
	CFStringRef *pathsToWatch = malloc(sizeof(CFStringRef) * watch->size);
	for (size_t i = 0; i < watch->size; i++) {
		pathsToWatch[i] = CFStringCreateWithCString(NULL, watch->paths[i], kCFStringEncodingUTF8);
	}
	
	CFArrayRef pathsToWatchArray = CFArrayCreate(NULL, (const void **)pathsToWatch, watch->size, &kCFTypeArrayCallBacks);
	
	FSEventStreamContext context = {0, watch, NULL, NULL, NULL};
	
	FSEventStreamRef stream;
	CFAbsoluteTime latency = watch->latency;
	
	stream = FSEventStreamCreate(
		NULL,
		&IO_Watch_FSEvent_callback,
		&context,
		pathsToWatchArray,
		kFSEventStreamEventIdSinceNow,
		latency,
		kFSEventStreamCreateFlagNone
	);
	
	dispatch_queue_t queue = dispatch_queue_create("com.example.fsevents.queue", NULL);
	FSEventStreamSetDispatchQueue(stream, queue);
	FSEventStreamStart(stream);
	
	printf("{\"status\":\"started\"}\n");
	fflush(stdout);
	
	dispatch_main();
	
	FSEventStreamStop(stream);
	FSEventStreamInvalidate(stream);
	FSEventStreamRelease(stream);
	for (size_t i = 0; i < watch->size; i++) {
		CFRelease(pathsToWatch[i]);
	}
	free(pathsToWatch);
	CFRelease(pathsToWatchArray);
}

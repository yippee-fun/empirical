#include "watch/watch.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
	DEBUG = 0,
};

int main(int argc, char **argv) {
	if (argc < 2) {
		fprintf(stderr, "Usage: %s <directory_to_watch> [<directory_to_watch> ...]\n", argv[0]);
		return 1;
	}

	struct IO_Watch watch;
	watch.latency = 0.1;
	watch.size = argc - 1;
	watch.paths = (const char **) &argv[1];
	
	char * latency = getenv("IO_WATCH_LATENCY");
	if (latency != NULL) {
		watch.latency = atof(latency);
	}
	
	for (size_t i = 0; i < watch.size; i++) {
		char *real_path = realpath(watch.paths[i], NULL);
		if (real_path == NULL) {
			fprintf(stderr, "io-watch:main: Realpath failed for %s\n", watch.paths[i]);
			return 1;
		} else {
			if (DEBUG) fprintf(stderr, "io-watch:main: Watching %s\n", real_path);
			watch.paths[i] = real_path;
		}
	}

	IO_Watch_run(&watch);

	for (size_t i = 0; i < watch.size; i++) {
		free((void *) watch.paths[i]);
	}

	return 0;
}
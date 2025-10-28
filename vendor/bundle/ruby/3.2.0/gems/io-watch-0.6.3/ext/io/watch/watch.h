#pragma once

#include <stddef.h>
#include <sys/types.h>

struct IO_Watch {
	float latency;
	
	size_t size;
	const char **paths;
};

void IO_Watch_run(struct IO_Watch *watch);

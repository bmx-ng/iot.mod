#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>

#include "brl.mod/blitz.mod/blitz.h"

int open_(BBString * path, int flags) {
	char * p = bbStringToUTF8String(path);
	int fd = open(p, flags);
	bbMemFree(p);
	return fd;
}

int ioctl_(int fd, unsigned int request, int * data) {
	return ioctl(fd, request, data);
}

int ioctli_(int fd, unsigned int request, int data) {
	return ioctl(fd, request, data);
}

BBInt64 write_(int fd, void * buf, size_t count) {
	return write(fd, buf, count);
}

BBInt64 read_(int fd, void * buf, size_t count) {
	return read(fd, buf, count);
}

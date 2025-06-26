#include "l2tp.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifdef __ANDROID__
#include <sys/system_properties.h>
#include <limits.h>
#endif

// Definition of the global variable (no initializer here either yet)
const char* CONTROL_PIPE = NULL; // Initialize to NULL or a sensible default if appropriate

const char* get_control_pipe(void) {
#ifdef __ANDROID__
    static char control_pipe_value[PROP_VALUE_MAX];
    const char *default_pipe_path = "/data/local/tmp/l2tp-control"; // Android default

    int len = __system_property_get("xl2tpd.control_pipe", control_pipe_value);
    if (len > 0) {
        return control_pipe_value;
    } else {
        if (strlen(default_pipe_path) < PROP_VALUE_MAX) {
            strcpy(control_pipe_value, default_pipe_path);
            return control_pipe_value;
        } else {
            fprintf(stderr, "Error: Default control pipe path is too long.\n");
            return default_pipe_path; // Or return a literal and handle upstream
        }
    }
#else
    const char* env_path = getenv("XL2TPD_CONTROL_PIPE");
    if (env_path != NULL && env_path[0] != '\0') {
        return env_path;
    } else {
        return "/var/run/xl2tpd/l2tp-control"; // Non-Android default
    }
#endif
}

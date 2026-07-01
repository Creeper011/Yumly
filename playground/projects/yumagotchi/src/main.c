#include <stdio.h>
#include <stdlib.h>

#include "config.h"
#include "pet.h"

int main(int argc, char **argv) {
    const char *path = argc > 1 ? argv[1] : "config.yumly";
    struct pet_config config = {0};

    if (!pet_config_load(path, &config)) {
        return EXIT_FAILURE;
    }

    pet_run(&config);
    pet_config_destroy(&config);
    return EXIT_SUCCESS;
}

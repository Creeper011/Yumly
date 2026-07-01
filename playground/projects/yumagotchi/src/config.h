#ifndef YUMAGOTCHI_CONFIG_H
#define YUMAGOTCHI_CONFIG_H

#include <stddef.h>

struct action_config {
    char *name;
    char key;
    int fullness;
    int happiness;
    int energy;
    char **messages;
    size_t message_count;
};

struct mood_config {
    int threshold;
    char *message;
};

struct pet_config {
    char *name;
    int initial_fullness;
    int initial_happiness;
    int initial_energy;
    struct action_config *actions;
    size_t action_count;
    struct mood_config *moods;
    size_t mood_count;
};

int pet_config_load(const char *path, struct pet_config *output);
void pet_config_destroy(struct pet_config *config);

#endif

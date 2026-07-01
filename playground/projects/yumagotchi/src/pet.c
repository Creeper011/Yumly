#include "pet.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

struct pet {
    int fullness;
    int happiness;
    int energy;
};

static int clamp(int value) {
    if (value < 0) {
        return 0;
    }
    if (value > 100) {
        return 100;
    }
    return value;
}

static void bar(const char *label, int value) {
    int filled = value / 10;
    printf("%-12s [", label);
    for (int i = 0; i < 10; ++i) {
        fputs(i < filled ? "#" : ".", stdout);
    }
    printf("] %3d\n", value);
}

static const char *mood(const struct pet_config *config, int happiness) {
    for (size_t i = 0; i < config->mood_count; ++i) {
        if (happiness >= config->moods[i].threshold) {
            return config->moods[i].message;
        }
    }
    return "...";
}

static void draw(const struct pet_config *config, const struct pet *pet,
                 const char *message) {
    fputs("\033[2J\033[H", stdout);
    printf("          %s ♡\n\n", config->name);
    fputs("           /\\_/\\\n", stdout);
    fputs("          ( •ᴗ• )\n", stdout);
    fputs("           > ^ <\n\n", stdout);
    bar("fullness", pet->fullness);
    bar("happiness", pet->happiness);
    bar("energy", pet->energy);
    printf("\n%s\n", message != NULL ? message : mood(config, pet->happiness));
    fputs("\n", stdout);

    for (size_t i = 0; i < config->action_count; ++i) {
        printf("[%c] %s  ", config->actions[i].key, config->actions[i].name);
    }
    fputs("[q] quit\n> ", stdout);
    fflush(stdout);
}

static const struct action_config *find_action(const struct pet_config *config,
                                                char key) {
    for (size_t i = 0; i < config->action_count; ++i) {
        if (config->actions[i].key == key) {
            return &config->actions[i];
        }
    }
    return NULL;
}

void pet_run(const struct pet_config *config) {
    struct pet pet = {
        config->initial_fullness,
        config->initial_happiness,
        config->initial_energy,
    };
    char input[64];
    const char *message = NULL;

    srand((unsigned int)time(NULL));
    for (;;) {
        const struct action_config *action = NULL;
        draw(config, &pet, message);

        if (fgets(input, sizeof(input), stdin) == NULL || input[0] == 'q') {
            break;
        }

        action = find_action(config, input[0]);
        if (action == NULL) {
            message = "Yummie tilts her head... unknown key :c";
            continue;
        }

        pet.fullness = clamp(pet.fullness + action->fullness - 3);
        pet.happiness = clamp(pet.happiness + action->happiness - 2);
        pet.energy = clamp(pet.energy + action->energy - 2);
        message = action->messages[rand() % action->message_count];

        if (pet.fullness == 0 || pet.energy == 0) {
            message = "Yummie needs care right now!! >_<";
        }
    }

    printf("\n%s waves a tiny paw. see you later ♡\n", config->name);
}

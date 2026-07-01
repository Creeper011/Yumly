#include "config.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "yumly.h"

static int member(const yumly_value *object, const char *key,
                  const yumly_value **output) {
    yumly_status status = yumly_object_get(object, key, output);
    if (status == YUMLY_OK) {
        return 1;
    }

    fprintf(stderr, "config: '%s' is %s\n", key,
            status == YUMLY_NOT_FOUND ? "missing" : "not inside an object");
    return 0;
}

static int integer_member(const yumly_value *object, const char *key,
                          int *output) {
    const yumly_value *value = NULL;
    int64_t integer = 0;

    if (!member(object, key, &value)) {
        return 0;
    }
    if (yumly_value_get_int(value, &integer) != YUMLY_OK) {
        fprintf(stderr, "config: '%s' must be an int\n", key);
        return 0;
    }
    if (integer < -1000000 || integer > 1000000) {
        fprintf(stderr, "config: '%s' is outside Yumagotchi's range\n", key);
        return 0;
    }

    *output = (int)integer;
    return 1;
}

static int string_copy(const yumly_value *value, char **output) {
    const char *text = NULL;
    size_t length = 0;
    char *copy = NULL;

    if (yumly_value_get_string(value, &text, &length) != YUMLY_OK) {
        return 0;
    }

    copy = malloc(length + 1);
    if (copy == NULL) {
        return 0;
    }
    memcpy(copy, text, length);
    copy[length] = '\0';
    *output = copy;
    return 1;
}

static int string_member(const yumly_value *object, const char *key,
                         char **output) {
    const yumly_value *value = NULL;
    if (!member(object, key, &value)) {
        return 0;
    }
    if (!string_copy(value, output)) {
        fprintf(stderr, "config: '%s' must be a string\n", key);
        return 0;
    }
    return 1;
}

static int load_messages(const yumly_value *object,
                         struct action_config *action) {
    const yumly_value *messages = NULL;

    if (!member(object, "messages", &messages) ||
        yumly_list_size(messages, &action->message_count) != YUMLY_OK) {
        fprintf(stderr, "config: 'messages' must be a list\n");
        return 0;
    }
    if (action->message_count == 0) {
        fprintf(stderr, "config: an action needs at least one message\n");
        return 0;
    }

    action->messages = calloc(action->message_count, sizeof(*action->messages));
    if (action->messages == NULL) {
        return 0;
    }

    for (size_t i = 0; i < action->message_count; ++i) {
        const yumly_value *message = NULL;
        if (yumly_list_get(messages, i, &message) != YUMLY_OK ||
            !string_copy(message, &action->messages[i])) {
            fprintf(stderr, "config: every action message must be a string\n");
            return 0;
        }
    }
    return 1;
}

static int load_actions(const yumly_value *root, struct pet_config *config) {
    const yumly_value *actions = NULL;

    if (!member(root, "actions", &actions) ||
        yumly_list_size(actions, &config->action_count) != YUMLY_OK) {
        fprintf(stderr, "config: 'actions' must be a list\n");
        return 0;
    }
    if (config->action_count == 0) {
        fprintf(stderr, "config: at least one action is required\n");
        return 0;
    }

    config->actions = calloc(config->action_count, sizeof(*config->actions));
    if (config->actions == NULL) {
        return 0;
    }

    for (size_t i = 0; i < config->action_count; ++i) {
        const yumly_value *object = NULL;
        char *key = NULL;

        if (yumly_list_get(actions, i, &object) != YUMLY_OK ||
            !string_member(object, "key", &key) || strlen(key) != 1 ||
            !string_member(object, "name", &config->actions[i].name) ||
            !integer_member(object, "fullness", &config->actions[i].fullness) ||
            !integer_member(object, "happiness", &config->actions[i].happiness) ||
            !integer_member(object, "energy", &config->actions[i].energy) ||
            !load_messages(object, &config->actions[i])) {
            fprintf(stderr, "config: invalid action at index %zu\n", i);
            free(key);
            return 0;
        }

        config->actions[i].key = key[0];
        free(key);
    }
    return 1;
}

static int load_moods(const yumly_value *root, struct pet_config *config) {
    const yumly_value *moods = NULL;

    if (!member(root, "moods", &moods) ||
        yumly_list_size(moods, &config->mood_count) != YUMLY_OK) {
        fprintf(stderr, "config: 'moods' must be a list\n");
        return 0;
    }

    config->moods = calloc(config->mood_count, sizeof(*config->moods));
    if (config->moods == NULL && config->mood_count != 0) {
        return 0;
    }

    for (size_t i = 0; i < config->mood_count; ++i) {
        const yumly_value *object = NULL;
        if (yumly_list_get(moods, i, &object) != YUMLY_OK ||
            !integer_member(object, "threshold", &config->moods[i].threshold) ||
            !string_member(object, "message", &config->moods[i].message)) {
            fprintf(stderr, "config: invalid mood at index %zu\n", i);
            return 0;
        }
    }
    return 1;
}

static int validate_config(const struct pet_config *config) {
    if (config->initial_fullness < 0 || config->initial_fullness > 100 ||
        config->initial_happiness < 0 || config->initial_happiness > 100 ||
        config->initial_energy < 0 || config->initial_energy > 100) {
        fputs("config: initial stats must be between 0 and 100\n", stderr);
        return 0;
    }

    for (size_t i = 0; i < config->action_count; ++i) {
        const struct action_config *action = &config->actions[i];
        if (action->fullness < -100 || action->fullness > 100 ||
            action->happiness < -100 || action->happiness > 100 ||
            action->energy < -100 || action->energy > 100) {
            fprintf(stderr, "config: action '%c' deltas must be between -100 and 100\n",
                    action->key);
            return 0;
        }
        for (size_t j = 0; j < i; ++j) {
            if (config->actions[j].key == action->key) {
                fprintf(stderr, "config: action key '%c' is duplicated\n", action->key);
                return 0;
            }
        }
    }

    for (size_t i = 0; i < config->mood_count; ++i) {
        if (config->moods[i].threshold < 0 || config->moods[i].threshold > 100) {
            fputs("config: mood thresholds must be between 0 and 100\n", stderr);
            return 0;
        }
        if (i > 0 && config->moods[i - 1].threshold < config->moods[i].threshold) {
            fputs("config: moods must be ordered by descending threshold\n", stderr);
            return 0;
        }
    }
    return 1;
}

static void print_yumly_error(const yumly_error *error) {
    const char *path = yumly_error_path(error);
    const char *code = yumly_error_code(error);

    if (path != NULL && path[0] != '\0') {
        fprintf(stderr, "%s:%llu:%llu: ", path,
                (unsigned long long)yumly_error_line(error),
                (unsigned long long)yumly_error_column(error));
    }
    const char *message = yumly_error_message(error);
    if (code != NULL && message != NULL && strcmp(code, message) != 0) {
        fprintf(stderr, "%s: %s\n", code, message);
    } else {
        fprintf(stderr, "%s\n", message != NULL ? message : "yumly.error");
    }
}

int pet_config_load(const char *path, struct pet_config *output) {
    yumly_document *document = NULL;
    yumly_error *error = NULL;
    const yumly_value *root = NULL;
    const yumly_value *pet = NULL;
    const yumly_value *stats = NULL;
    int ok = 0;

    if (output == NULL) {
        return 0;
    }
    memset(output, 0, sizeof(*output));

    if (yumly_document_load_file(path, &document, &error) != YUMLY_OK) {
        print_yumly_error(error);
        goto cleanup;
    }

    root = yumly_document_root(document);
    if (!member(root, "pet", &pet) ||
        !string_member(pet, "name", &output->name) ||
        !member(pet, "initial-stats", &stats) ||
        !integer_member(stats, "fullness", &output->initial_fullness) ||
        !integer_member(stats, "happiness", &output->initial_happiness) ||
        !integer_member(stats, "energy", &output->initial_energy) ||
        !load_actions(root, output) || !load_moods(root, output) ||
        !validate_config(output)) {
        goto cleanup;
    }

    ok = 1;

cleanup:
    yumly_error_free(error);
    yumly_document_free(document);
    if (!ok) {
        pet_config_destroy(output);
    }
    return ok;
}

void pet_config_destroy(struct pet_config *config) {
    if (config == NULL) {
        return;
    }

    free(config->name);
    for (size_t i = 0; i < config->action_count; ++i) {
        free(config->actions[i].name);
        for (size_t j = 0; j < config->actions[i].message_count; ++j) {
            free(config->actions[i].messages[j]);
        }
        free(config->actions[i].messages);
    }
    free(config->actions);

    for (size_t i = 0; i < config->mood_count; ++i) {
        free(config->moods[i].message);
    }
    free(config->moods);
    memset(config, 0, sizeof(*config));
}

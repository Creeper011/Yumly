#ifndef YUMLY_H
#define YUMLY_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define YUMLY_ABI_VERSION 1u

typedef struct yumly_document yumly_document;
typedef struct yumly_value yumly_value;
typedef struct yumly_error yumly_error;

typedef enum yumly_status {
    YUMLY_OK = 0,
    YUMLY_INVALID_ARGUMENT = 1,
    YUMLY_IO_ERROR = 2,
    YUMLY_PARSE_ERROR = 3,
    YUMLY_NOT_FOUND = 4,
    YUMLY_TYPE_ERROR = 5,
    YUMLY_OUT_OF_RANGE = 6,
    YUMLY_INTERNAL_ERROR = 7
} yumly_status;

typedef enum yumly_kind {
    YUMLY_INVALID = 0,
    YUMLY_STRING = 1,
    YUMLY_INT = 2,
    YUMLY_FLOAT = 3,
    YUMLY_BOOL = 4,
    YUMLY_LIST = 5,
    YUMLY_OBJECT = 6
} yumly_kind;

uint32_t yumly_abi_version(void);

/* On success, *output owns a document and must be freed. */
yumly_status yumly_document_load_file(
    const char *path,
    yumly_document **output,
    yumly_error **error
);

yumly_status yumly_document_load_content(
    const char *content,
    const char *working_dir,
    yumly_document **output,
    yumly_error **error
);

void yumly_document_free(yumly_document *document);

/* Every value returned below is borrowed from its document. */
const yumly_value *yumly_document_root(const yumly_document *document);
yumly_kind yumly_value_kind(const yumly_value *value);

yumly_status yumly_object_get(
    const yumly_value *object,
    const char *key,
    const yumly_value **output
);

yumly_status yumly_list_size(const yumly_value *list, size_t *output);
yumly_status yumly_list_get(
    const yumly_value *list,
    size_t index,
    const yumly_value **output
);

/* String data is borrowed, NUL-terminated, and may also be read by length. */
yumly_status yumly_value_get_string(
    const yumly_value *value,
    const char **output,
    size_t *length
);
yumly_status yumly_value_get_int(const yumly_value *value, int64_t *output);
yumly_status yumly_value_get_float(const yumly_value *value, double *output);
yumly_status yumly_value_get_bool(const yumly_value *value, int *output);

/* Error accessors return borrowed strings valid until yumly_error_free(). */
const char *yumly_error_message(const yumly_error *error);
const char *yumly_error_code(const yumly_error *error);
const char *yumly_error_path(const yumly_error *error);
uint64_t yumly_error_line(const yumly_error *error);
uint64_t yumly_error_column(const yumly_error *error);
void yumly_error_free(yumly_error *error);

#ifdef __cplusplus
}
#endif

#endif

#include "config.h"
#include <json.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#define error(...) do {fprintf(stderr, __VA_ARGS__); goto cleanup;} while (0)

int main(int argc, char const *argv[])
{
    int rval = -1;
    struct json_object* root = NULL;
    if (argc != 2) error("Usage: %s FILENAME\n", argv[0]);
    root = json_object_from_file(argv[1]);
    if (!root) error("Could not parse file.\n");
    struct json_object* name_obj;
    bool found = json_object_object_get_ex(root, "name", &name_obj);
    if (!found) error("No name field in input file.\n");
    if (!json_object_is_type(name_obj, json_type_string))
        error("Name entry has wrong type.\n");
    printf("%s\n", json_object_get_string(name_obj));
    rval = 0;
cleanup:
    if (root) json_object_put(root);
    return rval;
}
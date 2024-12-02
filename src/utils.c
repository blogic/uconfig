/* SPDX-License-Identifier: ISC */

/* Copyright (C) 2024 John Crispin <john@phrozen.org> */

#include <ucode/module.h>

#include <crypt.h>
#include <errno.h>

static uc_value_t *
uc_crypt(uc_vm_t *vm, size_t nargs) {
	uc_value_t *phrase = uc_fn_arg(0);
	uc_value_t *setting = uc_fn_arg(1);
	char *hash;

	if (ucv_type(phrase) != UC_STRING || ucv_type(setting) != UC_STRING)
		return NULL;

	errno = 0;
	hash = crypt(ucv_string_get(phrase), ucv_string_get(setting));

	if (hash == NULL || errno != 0)
		return NULL;

	return ucv_string_new(hash);
}

static const uc_function_list_t global_fns[] = {
        { "crypt",	uc_crypt },
};

void
uc_module_init(uc_vm_t *vm, uc_value_t *scope)
{
        uc_function_list_register(scope, global_fns);
}

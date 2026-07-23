/* SPDX-License-Identifier: GPL-3.0-or-later */
/*
 * Copyright (C) 2026 Aneesh Pradhan <aneeshpradhan@acm.org>
 *
 * Sysfs LED torch helpers for perry Phosh quick settings.
 * Brightness nodes are group-writable by feedbackd on postmarketOS.
 */

#pragma once

#include <glib.h>

gboolean perry_torch_led_exists (const char *led_name);
int      perry_torch_led_get_brightness (const char *led_name);
int      perry_torch_led_get_max_brightness (const char *led_name);
gboolean perry_torch_led_set_on (const char *led_name, gboolean on);
gboolean perry_torch_led_is_on (const char *led_name);

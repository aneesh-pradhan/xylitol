/* SPDX-License-Identifier: GPL-3.0-or-later */
/*
 * Copyright (C) 2026 Aneesh Pradhan <aneeshpradhan@acm.org>
 */

#include "perry-torch-led.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define LED_SYSFS_DIR "/sys/class/leds"

static char *
led_attr_path (const char *led_name, const char *attr)
{
  return g_strdup_printf ("%s/%s/%s", LED_SYSFS_DIR, led_name, attr);
}

gboolean
perry_torch_led_exists (const char *led_name)
{
  g_autofree char *path = led_attr_path (led_name, "brightness");

  return g_file_test (path, G_FILE_TEST_EXISTS);
}

int
perry_torch_led_get_brightness (const char *led_name)
{
  g_autofree char *path = led_attr_path (led_name, "brightness");
  g_autofree char *contents = NULL;
  gsize len = 0;

  if (!g_file_get_contents (path, &contents, &len, NULL))
    return -1;

  return atoi (contents);
}

int
perry_torch_led_get_max_brightness (const char *led_name)
{
  g_autofree char *path = led_attr_path (led_name, "max_brightness");
  g_autofree char *contents = NULL;

  if (!g_file_get_contents (path, &contents, NULL, NULL))
    return 1;

  return MAX (atoi (contents), 1);
}

gboolean
perry_torch_led_is_on (const char *led_name)
{
  return perry_torch_led_get_brightness (led_name) > 0;
}

gboolean
perry_torch_led_set_on (const char *led_name, gboolean on)
{
  g_autofree char *path = led_attr_path (led_name, "brightness");
  char buf[16];
  int value = 0;
  int len;
  int fd;
  gboolean ok = TRUE;

  if (on) {
    int maxb = perry_torch_led_get_max_brightness (led_name);
    /* ~50% — visible torch without hammering the LED at max flash current. */
    value = MAX (maxb / 2, 1);
  }

  len = g_snprintf (buf, sizeof buf, "%d", value);

  /* sysfs attributes must be written in place — g_file_set_contents()'s
   * write-temp-then-rename() doesn't work here, sysfs won't let us create
   * a new file in the directory. */
  fd = open (path, O_WRONLY);
  if (fd < 0) {
    g_warning ("Failed to open %s: %s", path, g_strerror (errno));
    return FALSE;
  }

  if (write (fd, buf, len) != len) {
    g_warning ("Failed to write %s: %s", path, g_strerror (errno));
    ok = FALSE;
  }

  close (fd);
  return ok;
}

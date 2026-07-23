/* SPDX-License-Identifier: GPL-3.0-or-later */
/*
 * Copyright (C) 2026 Aneesh Pradhan <aneeshpradhan@acm.org>
 *
 * Perry dual torch quick settings for Phosh (rear:lamp + front:lamp).
 * Icons match stock Phosh torch (torch-*-symbolic). Status icon is attached
 * via the QuickSetting:status-icon GObject property — the C setter is not
 * exported from libphosh.
 */

#include "perry-torch-led.h"

#include <glib/gi18n.h>
#include <libphosh.h>
#include <phosh-plugin.h>

#define TORCH_ON_ICON  "torch-enabled-symbolic"
#define TORCH_OFF_ICON "torch-disabled-symbolic"

#define PERRY_TYPE_REAR_TORCH_QUICK_SETTING  perry_rear_torch_quick_setting_get_type ()
#define PERRY_TYPE_FRONT_TORCH_QUICK_SETTING perry_front_torch_quick_setting_get_type ()

typedef struct {
  PhoshQuickSetting parent;
  PhoshStatusIcon  *info;
  guint             poll_id;
  const char       *led_name;
  const char       *title;
} PerryTorchQs;

static void
refresh (PerryTorchQs *self)
{
  gboolean present = perry_torch_led_exists (self->led_name);
  gboolean on = present && perry_torch_led_is_on (self->led_name);

  phosh_status_icon_set_icon_name (self->info, on ? TORCH_ON_ICON : TORCH_OFF_ICON);
  phosh_status_icon_set_info (self->info,
                              present ? self->title : _("Torch unavailable"));
  phosh_quick_setting_set_active (PHOSH_QUICK_SETTING (self), on);
  gtk_widget_set_sensitive (GTK_WIDGET (self), present);
}

static void
on_clicked (PerryTorchQs *self)
{
  if (!perry_torch_led_exists (self->led_name))
    return;

  perry_torch_led_set_on (self->led_name, !perry_torch_led_is_on (self->led_name));
  refresh (self);
}

static gboolean
on_poll (gpointer data)
{
  refresh (data);
  return G_SOURCE_CONTINUE;
}

static void
qs_dispose (GObject *object)
{
  PerryTorchQs *self = (PerryTorchQs *) object;
  GObjectClass *parent = g_type_class_peek_parent (G_OBJECT_GET_CLASS (object));

  g_clear_handle_id (&self->poll_id, g_source_remove);
  parent->dispose (object);
}

static void
qs_setup (PerryTorchQs *self, const char *led_name, const char *title)
{
  self->led_name = led_name;
  self->title = title;

  self->info = g_object_new (PHOSH_TYPE_STATUS_ICON,
                             "pixel-size", 16,
                             "visible", TRUE,
                             "icon-name", TORCH_OFF_ICON,
                             NULL);
  /* Prefer GObject property: phosh_quick_setting_set_status_icon() is not
   * exported from libphosh (only used internally via this property). */
  g_object_set (self, "status-icon", self->info, NULL);
  gtk_widget_show (GTK_WIDGET (self->info));

  g_signal_connect_swapped (self, "clicked", G_CALLBACK (on_clicked), self);

  refresh (self);
  self->poll_id = g_timeout_add_seconds (2, on_poll, self);
}

/* ---- rear --------------------------------------------------------------- */

typedef PerryTorchQs             PerryRearTorchQuickSetting;
typedef PhoshQuickSettingClass   PerryRearTorchQuickSettingClass;

G_DEFINE_TYPE (PerryRearTorchQuickSetting, perry_rear_torch_quick_setting,
               PHOSH_TYPE_QUICK_SETTING)

static void
perry_rear_torch_quick_setting_class_init (PerryRearTorchQuickSettingClass *klass)
{
  G_OBJECT_CLASS (klass)->dispose = qs_dispose;
}

static void
perry_rear_torch_quick_setting_init (PerryRearTorchQuickSetting *self)
{
  qs_setup ((PerryTorchQs *) self, "rear:lamp", _("Rear torch"));
}

/* ---- front -------------------------------------------------------------- */

typedef PerryTorchQs             PerryFrontTorchQuickSetting;
typedef PhoshQuickSettingClass   PerryFrontTorchQuickSettingClass;

G_DEFINE_TYPE (PerryFrontTorchQuickSetting, perry_front_torch_quick_setting,
               PHOSH_TYPE_QUICK_SETTING)

static void
perry_front_torch_quick_setting_class_init (PerryFrontTorchQuickSettingClass *klass)
{
  G_OBJECT_CLASS (klass)->dispose = qs_dispose;
}

static void
perry_front_torch_quick_setting_init (PerryFrontTorchQuickSetting *self)
{
  qs_setup ((PerryTorchQs *) self, "front:lamp", _("Front torch"));
}

/* ---- GIO module --------------------------------------------------------- */

void
g_io_module_load (GIOModule *module)
{
  g_type_module_use (G_TYPE_MODULE (module));

  g_io_extension_point_implement (PHOSH_PLUGIN_EXTENSION_POINT_QUICK_SETTING_WIDGET,
                                  PERRY_TYPE_REAR_TORCH_QUICK_SETTING,
                                  "perry-rear-torch-quick-setting",
                                  10);
  g_io_extension_point_implement (PHOSH_PLUGIN_EXTENSION_POINT_QUICK_SETTING_WIDGET,
                                  PERRY_TYPE_FRONT_TORCH_QUICK_SETTING,
                                  "perry-front-torch-quick-setting",
                                  10);
}

void
g_io_module_unload (GIOModule *module)
{
}

char **
g_io_phosh_plugin_perry_torch_quick_setting_query (void)
{
  char *extension_points[] = {
    PHOSH_PLUGIN_EXTENSION_POINT_QUICK_SETTING_WIDGET,
    NULL,
  };

  return g_strdupv (extension_points);
}

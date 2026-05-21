#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gdk/gdkkeysyms.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#include <X11/XF86keysym.h>
#include <X11/Xlib.h>
#endif
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

FlMethodChannel* desktop_feature_channel = nullptr;
GtkWindow* main_window = nullptr;
GDBusConnection* mpris_connection = nullptr;
GDBusNodeInfo* mpris_node_info = nullptr;
guint mpris_owner_id = 0;
guint mpris_registration_id = 0;
guint mpris_player_registration_id = 0;
bool mpris_active = false;
bool mpris_playing = false;
std::string mpris_title;
std::string mpris_artist;
std::string mpris_album;
std::string mpris_artwork_path;
double mpris_duration_seconds = 0;
double mpris_progress_seconds = 0;
GtkWidget* desktop_lyrics_window = nullptr;
GtkWidget* desktop_lyrics_meta_label = nullptr;
GtkWidget* desktop_lyrics_text_label = nullptr;
GtkWidget* desktop_lyrics_next_label = nullptr;
GtkWidget* desktop_lyrics_outer = nullptr;
GtkWidget* desktop_lyrics_toolbar = nullptr;
GtkWidget* desktop_lyrics_previous_button = nullptr;
GtkWidget* desktop_lyrics_play_pause_button = nullptr;
GtkWidget* desktop_lyrics_next_button = nullptr;
GtkWidget* desktop_lyrics_lock_button = nullptr;
GtkWidget* desktop_lyrics_settings_button = nullptr;
GtkWidget* desktop_lyrics_close_button = nullptr;
GtkWidget* desktop_lyrics_reset_button = nullptr;
GtkCssProvider* desktop_lyrics_css_provider = nullptr;
bool desktop_lyrics_locked = false;

const gchar* kMprisObjectPath = "/org/mpris/MediaPlayer2";
const gchar* kMprisBusName = "org.mpris.MediaPlayer2.smplayer_flutter";
const gchar* kMprisIntrospectionXml = R"xml(
<node>
  <interface name="org.mpris.MediaPlayer2">
    <method name="Raise"/>
    <method name="Quit"/>
    <property name="CanQuit" type="b" access="read"/>
    <property name="Fullscreen" type="b" access="readwrite"/>
    <property name="CanSetFullscreen" type="b" access="read"/>
    <property name="CanRaise" type="b" access="read"/>
    <property name="HasTrackList" type="b" access="read"/>
    <property name="Identity" type="s" access="read"/>
    <property name="DesktopEntry" type="s" access="read"/>
    <property name="SupportedUriSchemes" type="as" access="read"/>
    <property name="SupportedMimeTypes" type="as" access="read"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.Player">
    <method name="Next"/>
    <method name="Previous"/>
    <method name="Pause"/>
    <method name="PlayPause"/>
    <method name="Stop"/>
    <method name="Play"/>
    <method name="Seek">
      <arg direction="in" name="Offset" type="x"/>
    </method>
    <method name="SetPosition">
      <arg direction="in" name="TrackId" type="o"/>
      <arg direction="in" name="Position" type="x"/>
    </method>
    <method name="OpenUri">
      <arg direction="in" name="Uri" type="s"/>
    </method>
    <signal name="Seeked">
      <arg name="Position" type="x"/>
    </signal>
    <property name="PlaybackStatus" type="s" access="read"/>
    <property name="LoopStatus" type="s" access="readwrite"/>
    <property name="Rate" type="d" access="readwrite"/>
    <property name="Shuffle" type="b" access="readwrite"/>
    <property name="Metadata" type="a{sv}" access="read"/>
    <property name="Volume" type="d" access="readwrite"/>
    <property name="Position" type="x" access="read"/>
    <property name="MinimumRate" type="d" access="read"/>
    <property name="MaximumRate" type="d" access="read"/>
    <property name="CanGoNext" type="b" access="read"/>
    <property name="CanGoPrevious" type="b" access="read"/>
    <property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/>
    <property name="CanSeek" type="b" access="read"/>
    <property name="CanControl" type="b" access="read"/>
  </interface>
</node>
)xml";

#ifdef GDK_WINDOWING_X11
Display* media_key_display = nullptr;
Window media_key_root = 0;
bool media_key_filter_registered = false;
#endif

void send_desktop_command(const gchar* command) {
  if (desktop_feature_channel == nullptr) {
    return;
  }
  g_autoptr(FlValue) arguments = fl_value_new_string(command);
  fl_method_channel_invoke_method(desktop_feature_channel, "desktopCommand",
                                  arguments, nullptr, nullptr, nullptr);
}

void send_media_session_seek(double seconds) {
  if (desktop_feature_channel == nullptr) {
    return;
  }
  const std::string command = "seek-to:" + std::to_string(seconds);
  g_autoptr(FlValue) arguments = fl_value_new_string(command.c_str());
  fl_method_channel_invoke_method(desktop_feature_channel, "desktopCommand",
                                  arguments, nullptr, nullptr, nullptr);
}

void send_open_external_arguments(gchar** arguments) {
  if (desktop_feature_channel == nullptr || arguments == nullptr ||
      arguments[0] == nullptr) {
    return;
  }

  g_autoptr(FlValue) values = fl_value_new_list();
  for (gchar** argument = arguments; *argument != nullptr; argument++) {
    fl_value_append_take(values, fl_value_new_string(*argument));
  }
  fl_method_channel_invoke_method(desktop_feature_channel,
                                  "openExternalArguments", values, nullptr,
                                  nullptr, nullptr);
}

bool fl_map_bool(FlValue* map, const gchar* key) {
  return fl_value_get_bool(fl_value_lookup_string(map, key));
}

double fl_map_double(FlValue* map, const gchar* key) {
  return fl_value_get_float(fl_value_lookup_string(map, key));
}

std::string fl_map_string(FlValue* map, const gchar* key) {
  return fl_value_get_string(fl_value_lookup_string(map, key));
}

std::string file_uri_from_path(const std::string& path) {
  if (path.empty()) {
    return std::string();
  }
  gchar* uri = g_filename_to_uri(path.c_str(), nullptr, nullptr);
  std::string result = uri == nullptr ? std::string() : uri;
  g_free(uri);
  return result;
}

int fl_map_int(FlValue* map, const gchar* key) {
  return static_cast<int>(fl_value_get_int(fl_value_lookup_string(map, key)));
}

std::string desktop_lyrics_display_text(FlValue* arguments) {
  if (fl_map_bool(arguments, "loading")) {
    return "...";
  }
  const std::string lyric = fl_map_string(arguments, "lyricText");
  if (!lyric.empty()) {
    return lyric;
  }
  return fl_map_string(arguments, "fallbackText");
}

void send_desktop_lyrics_bounds() {
  if (desktop_feature_channel == nullptr || desktop_lyrics_window == nullptr) {
    return;
  }

  gint x = 0;
  gint y = 0;
  gint width = 0;
  gint height = 0;
  gtk_window_get_position(GTK_WINDOW(desktop_lyrics_window), &x, &y);
  gtk_window_get_size(GTK_WINDOW(desktop_lyrics_window), &width, &height);
  const std::string bounds =
      "{\"x\":" + std::to_string(x) + ",\"y\":" + std::to_string(y) +
      ",\"width\":" + std::to_string(width) + ",\"height\":" +
      std::to_string(height) + "}";
  g_autoptr(FlValue) arguments = fl_value_new_string(bounds.c_str());
  fl_method_channel_invoke_method(desktop_feature_channel,
                                  "desktopLyricsBoundsChanged", arguments,
                                  nullptr, nullptr, nullptr);
}

gboolean on_desktop_lyrics_configure(GtkWidget* widget, GdkEvent* event,
                                     gpointer user_data) {
  (void)widget;
  (void)event;
  (void)user_data;
  send_desktop_lyrics_bounds();
  return FALSE;
}

gboolean on_desktop_lyrics_button_press(GtkWidget* widget, GdkEventButton* event,
                                        gpointer user_data) {
  (void)widget;
  (void)user_data;
  if (desktop_lyrics_locked || event->button != 1) {
    return FALSE;
  }
  gtk_window_begin_move_drag(GTK_WINDOW(desktop_lyrics_window), event->button,
                             event->x_root, event->y_root, event->time);
  return FALSE;
}

void on_desktop_lyrics_command_clicked(GtkButton* button, gpointer user_data) {
  (void)button;
  send_desktop_command(static_cast<const gchar*>(user_data));
}

GtkWidget* create_desktop_lyrics_button(const gchar* label,
                                        const gchar* command) {
  GtkWidget* button = gtk_button_new_with_label(label);
  gtk_widget_set_can_focus(button, FALSE);
  g_signal_connect(button, "clicked",
                   G_CALLBACK(on_desktop_lyrics_command_clicked),
                   const_cast<gchar*>(command));
  return button;
}

void apply_desktop_lyrics_style(bool night_mode) {
  if (desktop_lyrics_css_provider == nullptr) {
    desktop_lyrics_css_provider = gtk_css_provider_new();
    GdkScreen* screen = gdk_screen_get_default();
    if (screen != nullptr) {
      gtk_style_context_add_provider_for_screen(
          screen, GTK_STYLE_PROVIDER(desktop_lyrics_css_provider),
          GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
  }

  const std::string card_color =
      night_mode ? "rgba(16, 24, 32, 0.82)" : "rgba(245, 248, 252, 0.88)";
  const std::string text_color = night_mode ? "#e1ebf5" : "#202a36";
  const std::string button_color =
      night_mode ? "rgba(42, 52, 64, 0.92)" : "rgba(222, 230, 240, 0.96)";
  const std::string css =
      "#desktop-lyrics-card {"
      "background: " +
      card_color +
      ";"
      "border-radius: 8px;"
      "border: 1px solid rgba(255,255,255,0.18);"
      "}"
      "#desktop-lyrics-card button {"
      "background: " +
      button_color +
      ";"
      "color: " +
      text_color +
      ";"
      "border-radius: 5px;"
      "padding: 3px 8px;"
      "}"
      "#desktop-lyrics-meta { color: " +
      text_color +
      "; opacity: 0.72; }"
      "#desktop-lyrics-next { color: " +
      text_color + "; opacity: 0.74; }";
  gtk_css_provider_load_from_data(desktop_lyrics_css_provider, css.c_str(), -1,
                                  nullptr);
}

void resolve_desktop_lyrics_bounds(const std::string& raw_bounds, gint* x,
                                   gint* y, gint* width, gint* height) {
  *width = 760;
  *height = 148;
  GdkDisplay* display = gdk_display_get_default();
  GdkMonitor* monitor =
      display == nullptr ? nullptr : gdk_display_get_primary_monitor(display);
  GdkRectangle workarea = {0, 0, 1280, 720};
  if (monitor != nullptr) {
    gdk_monitor_get_workarea(monitor, &workarea);
  }
  *x = workarea.x + (workarea.width - *width) / 2;
  *y = workarea.y + workarea.height - *height - 120;

  if (raw_bounds.empty()) {
    return;
  }
  gint parsed_x = 0;
  gint parsed_y = 0;
  gint parsed_width = 0;
  gint parsed_height = 0;
  if (sscanf(raw_bounds.c_str(),
             "{\"x\":%d,\"y\":%d,\"width\":%d,\"height\":%d}", &parsed_x,
             &parsed_y, &parsed_width, &parsed_height) == 4) {
    *x = parsed_x;
    *y = parsed_y;
    *width = parsed_width > 0 ? parsed_width : *width;
    *height = parsed_height > 0 ? parsed_height : *height;
  }
}

GtkWidget* ensure_desktop_lyrics_window(FlValue* arguments) {
  if (desktop_lyrics_window != nullptr) {
    return desktop_lyrics_window;
  }

  gint x = 0;
  gint y = 0;
  gint width = 0;
  gint height = 0;
  resolve_desktop_lyrics_bounds(fl_map_string(arguments, "bounds"), &x, &y,
                                &width, &height);

  desktop_lyrics_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_decorated(GTK_WINDOW(desktop_lyrics_window), FALSE);
  gtk_window_set_keep_above(GTK_WINDOW(desktop_lyrics_window), TRUE);
  gtk_window_set_skip_taskbar_hint(GTK_WINDOW(desktop_lyrics_window), TRUE);
  gtk_window_set_type_hint(GTK_WINDOW(desktop_lyrics_window),
                           GDK_WINDOW_TYPE_HINT_UTILITY);
  gtk_window_set_default_size(GTK_WINDOW(desktop_lyrics_window), width, height);
  gtk_window_move(GTK_WINDOW(desktop_lyrics_window), x, y);
  gtk_widget_add_events(desktop_lyrics_window, GDK_BUTTON_PRESS_MASK);
  g_signal_connect(desktop_lyrics_window, "configure-event",
                   G_CALLBACK(on_desktop_lyrics_configure), nullptr);
  g_signal_connect(desktop_lyrics_window, "button-press-event",
                   G_CALLBACK(on_desktop_lyrics_button_press), nullptr);

  desktop_lyrics_outer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
  gtk_widget_set_name(desktop_lyrics_outer, "desktop-lyrics-card");
  gtk_widget_set_margin_start(desktop_lyrics_outer, 12);
  gtk_widget_set_margin_end(desktop_lyrics_outer, 12);
  gtk_widget_set_margin_top(desktop_lyrics_outer, 10);
  gtk_widget_set_margin_bottom(desktop_lyrics_outer, 10);
  gtk_container_add(GTK_CONTAINER(desktop_lyrics_window), desktop_lyrics_outer);

  desktop_lyrics_meta_label = gtk_label_new("");
  gtk_widget_set_name(desktop_lyrics_meta_label, "desktop-lyrics-meta");
  gtk_label_set_ellipsize(GTK_LABEL(desktop_lyrics_meta_label),
                          PANGO_ELLIPSIZE_END);
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_outer), desktop_lyrics_meta_label,
                     FALSE, FALSE, 0);

  desktop_lyrics_text_label = gtk_label_new("");
  gtk_label_set_ellipsize(GTK_LABEL(desktop_lyrics_text_label),
                          PANGO_ELLIPSIZE_END);
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_outer), desktop_lyrics_text_label,
                     TRUE, TRUE, 0);

  desktop_lyrics_next_label = gtk_label_new("");
  gtk_widget_set_name(desktop_lyrics_next_label, "desktop-lyrics-next");
  gtk_label_set_ellipsize(GTK_LABEL(desktop_lyrics_next_label),
                          PANGO_ELLIPSIZE_END);
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_outer), desktop_lyrics_next_label,
                     FALSE, FALSE, 0);

  desktop_lyrics_toolbar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_outer), desktop_lyrics_toolbar,
                     FALSE, FALSE, 0);
  desktop_lyrics_previous_button = create_desktop_lyrics_button("<<", "previous");
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_toolbar),
                     desktop_lyrics_previous_button, FALSE, FALSE, 0);
  desktop_lyrics_play_pause_button =
      create_desktop_lyrics_button("Play/Pause", "play-pause");
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_toolbar),
                     desktop_lyrics_play_pause_button, FALSE, FALSE, 0);
  desktop_lyrics_next_button = create_desktop_lyrics_button(">>", "next");
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_toolbar),
                     desktop_lyrics_next_button, FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_toolbar),
                     create_desktop_lyrics_button("-0.1", "offset:-100"),
                     FALSE, FALSE, 0);
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_toolbar),
                     create_desktop_lyrics_button("+0.1", "offset:100"),
                     FALSE, FALSE, 0);
  desktop_lyrics_reset_button =
      create_desktop_lyrics_button("0.0s", "reset-offset");
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_toolbar), desktop_lyrics_reset_button,
                     FALSE, FALSE, 0);
  desktop_lyrics_lock_button =
      create_desktop_lyrics_button("Lock", "toggle-lock");
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_toolbar),
                     desktop_lyrics_lock_button, FALSE, FALSE, 0);
  desktop_lyrics_settings_button =
      create_desktop_lyrics_button("Settings", "open-settings");
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_toolbar),
                     desktop_lyrics_settings_button, FALSE, FALSE, 0);
  desktop_lyrics_close_button = create_desktop_lyrics_button("Close", "disable");
  gtk_box_pack_start(GTK_BOX(desktop_lyrics_toolbar),
                     desktop_lyrics_close_button, FALSE, FALSE, 0);
  return desktop_lyrics_window;
}

void update_desktop_lyrics_window(FlValue* arguments) {
  if (!fl_map_bool(arguments, "visible")) {
    if (desktop_lyrics_window != nullptr) {
      gtk_widget_hide(desktop_lyrics_window);
    }
    return;
  }

  GtkWidget* window = ensure_desktop_lyrics_window(arguments);
  desktop_lyrics_locked = fl_map_bool(arguments, "locked");
  apply_desktop_lyrics_style(fl_map_bool(arguments, "nightMode"));
  gtk_window_set_opacity(GTK_WINDOW(window),
                         fl_map_int(arguments, "opacity") / 100.0);

  const std::string title = fl_map_string(arguments, "songTitle");
  const std::string artist = fl_map_string(arguments, "artist");
  const std::string meta = artist.empty() ? title : title + " - " + artist;
  gtk_label_set_text(GTK_LABEL(desktop_lyrics_meta_label), meta.c_str());
  gtk_label_set_text(GTK_LABEL(desktop_lyrics_text_label),
                     desktop_lyrics_display_text(arguments).c_str());
  gtk_label_set_text(GTK_LABEL(desktop_lyrics_next_label),
                     fl_map_string(arguments, "nextLyricText").c_str());

  const double offset_seconds = fl_map_int(arguments, "offsetMs") / 1000.0;
  char offset_buffer[32];
  snprintf(offset_buffer, sizeof(offset_buffer), "%+.1fs", offset_seconds);
  gtk_button_set_label(GTK_BUTTON(desktop_lyrics_reset_button),
                       offset_buffer);
  gtk_button_set_label(GTK_BUTTON(desktop_lyrics_previous_button),
                       fl_map_string(arguments, "labelPrevious").c_str());
  gtk_button_set_label(GTK_BUTTON(desktop_lyrics_play_pause_button),
                       fl_map_string(arguments, "labelPlayPause").c_str());
  gtk_button_set_label(GTK_BUTTON(desktop_lyrics_next_button),
                       fl_map_string(arguments, "labelNext").c_str());
  gtk_button_set_label(
      GTK_BUTTON(desktop_lyrics_lock_button),
      fl_map_string(arguments,
                    desktop_lyrics_locked ? "labelUnlock" : "labelLock")
          .c_str());
  gtk_button_set_label(GTK_BUTTON(desktop_lyrics_settings_button),
                       fl_map_string(arguments, "labelSettings").c_str());
  gtk_button_set_label(GTK_BUTTON(desktop_lyrics_close_button),
                       fl_map_string(arguments, "labelClose").c_str());

  gtk_widget_show_all(window);
  gtk_widget_set_visible(desktop_lyrics_toolbar, !desktop_lyrics_locked);
  gtk_window_present(GTK_WINDOW(window));
}

GVariant* build_mpris_metadata() {
  GVariantBuilder builder;
  g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));
  if (!mpris_active) {
    return g_variant_builder_end(&builder);
  }

  g_variant_builder_add(
      &builder, "{sv}", "mpris:trackid",
      g_variant_new_object_path("/org/mpris/MediaPlayer2/Track/Current"));
  g_variant_builder_add(&builder, "{sv}", "xesam:title",
                        g_variant_new_string(mpris_title.c_str()));
  GVariantBuilder artist_builder;
  g_variant_builder_init(&artist_builder, G_VARIANT_TYPE("as"));
  g_variant_builder_add(&artist_builder, "s", mpris_artist.c_str());
  g_variant_builder_add(&builder, "{sv}", "xesam:artist",
                        g_variant_builder_end(&artist_builder));
  g_variant_builder_add(&builder, "{sv}", "xesam:album",
                        g_variant_new_string(mpris_album.c_str()));
  if (!mpris_artwork_path.empty()) {
    const std::string artwork_uri = file_uri_from_path(mpris_artwork_path);
    if (!artwork_uri.empty()) {
      g_variant_builder_add(&builder, "{sv}", "mpris:artUrl",
                            g_variant_new_string(artwork_uri.c_str()));
    }
  }
  if (mpris_duration_seconds > 0) {
    g_variant_builder_add(
        &builder, "{sv}", "mpris:length",
        g_variant_new_int64(
            static_cast<gint64>(mpris_duration_seconds * 1000000)));
  }
  return g_variant_builder_end(&builder);
}

GVariant* empty_string_array() {
  GVariantBuilder builder;
  g_variant_builder_init(&builder, G_VARIANT_TYPE("as"));
  return g_variant_builder_end(&builder);
}

GVariant* get_mpris_property(GDBusConnection* connection,
                             const gchar* sender,
                             const gchar* object_path,
                             const gchar* interface_name,
                             const gchar* property_name,
                             GError** error,
                             gpointer user_data) {
  (void)connection;
  (void)sender;
  (void)object_path;
  (void)error;
  (void)user_data;

  if (g_strcmp0(interface_name, "org.mpris.MediaPlayer2") == 0) {
    if (g_strcmp0(property_name, "CanQuit") == 0) {
      return g_variant_new_boolean(FALSE);
    }
    if (g_strcmp0(property_name, "Fullscreen") == 0) {
      return g_variant_new_boolean(FALSE);
    }
    if (g_strcmp0(property_name, "CanSetFullscreen") == 0) {
      return g_variant_new_boolean(FALSE);
    }
    if (g_strcmp0(property_name, "CanRaise") == 0) {
      return g_variant_new_boolean(TRUE);
    }
    if (g_strcmp0(property_name, "HasTrackList") == 0) {
      return g_variant_new_boolean(FALSE);
    }
    if (g_strcmp0(property_name, "Identity") == 0) {
      return g_variant_new_string("Simple Melody Player");
    }
    if (g_strcmp0(property_name, "DesktopEntry") == 0) {
      return g_variant_new_string("simple-melody-player");
    }
    if (g_strcmp0(property_name, "SupportedUriSchemes") == 0 ||
        g_strcmp0(property_name, "SupportedMimeTypes") == 0) {
      return empty_string_array();
    }
  }

  if (g_strcmp0(interface_name, "org.mpris.MediaPlayer2.Player") == 0) {
    if (g_strcmp0(property_name, "PlaybackStatus") == 0) {
      return g_variant_new_string(
          !mpris_active ? "Stopped" : (mpris_playing ? "Playing" : "Paused"));
    }
    if (g_strcmp0(property_name, "LoopStatus") == 0) {
      return g_variant_new_string("None");
    }
    if (g_strcmp0(property_name, "Rate") == 0 ||
        g_strcmp0(property_name, "MinimumRate") == 0 ||
        g_strcmp0(property_name, "MaximumRate") == 0 ||
        g_strcmp0(property_name, "Volume") == 0) {
      return g_variant_new_double(1.0);
    }
    if (g_strcmp0(property_name, "Shuffle") == 0) {
      return g_variant_new_boolean(FALSE);
    }
    if (g_strcmp0(property_name, "Metadata") == 0) {
      return build_mpris_metadata();
    }
    if (g_strcmp0(property_name, "Position") == 0) {
      return g_variant_new_int64(
          static_cast<gint64>(mpris_progress_seconds * 1000000));
    }
    if (g_strcmp0(property_name, "CanGoNext") == 0 ||
        g_strcmp0(property_name, "CanGoPrevious") == 0 ||
        g_strcmp0(property_name, "CanPlay") == 0 ||
        g_strcmp0(property_name, "CanPause") == 0 ||
        g_strcmp0(property_name, "CanSeek") == 0 ||
        g_strcmp0(property_name, "CanControl") == 0) {
      return g_variant_new_boolean(mpris_active);
    }
  }

  return nullptr;
}

void emit_mpris_properties_changed() {
  if (mpris_connection == nullptr) {
    return;
  }
  GVariantBuilder changed;
  g_variant_builder_init(&changed, G_VARIANT_TYPE("a{sv}"));
  g_variant_builder_add(&changed, "{sv}", "PlaybackStatus",
                        g_variant_new_string(!mpris_active
                                                 ? "Stopped"
                                                 : (mpris_playing ? "Playing"
                                                                  : "Paused")));
  g_variant_builder_add(&changed, "{sv}", "Metadata", build_mpris_metadata());
  g_variant_builder_add(&changed, "{sv}", "CanGoNext",
                        g_variant_new_boolean(mpris_active));
  g_variant_builder_add(&changed, "{sv}", "CanGoPrevious",
                        g_variant_new_boolean(mpris_active));
  g_variant_builder_add(&changed, "{sv}", "CanPlay",
                        g_variant_new_boolean(mpris_active));
  g_variant_builder_add(&changed, "{sv}", "CanPause",
                        g_variant_new_boolean(mpris_active));
  g_variant_builder_add(&changed, "{sv}", "CanSeek",
                        g_variant_new_boolean(mpris_active));
  g_variant_builder_add(&changed, "{sv}", "CanControl",
                        g_variant_new_boolean(mpris_active));

  GVariantBuilder invalidated;
  g_variant_builder_init(&invalidated, G_VARIANT_TYPE("as"));
  g_variant_builder_add(&invalidated, "s", "Position");
  g_dbus_connection_emit_signal(
      mpris_connection, nullptr, kMprisObjectPath,
      "org.freedesktop.DBus.Properties", "PropertiesChanged",
      g_variant_new("(sa{sv}as)", "org.mpris.MediaPlayer2.Player", &changed,
                    &invalidated),
      nullptr);
}

void update_mpris_state(FlValue* arguments) {
  mpris_active = fl_map_bool(arguments, "active");
  mpris_title = fl_map_string(arguments, "title");
  mpris_artist = fl_map_string(arguments, "artist");
  mpris_album = fl_map_string(arguments, "album");
  mpris_artwork_path = fl_map_string(arguments, "artworkPath");
  mpris_playing = fl_map_bool(arguments, "playing");
  mpris_duration_seconds = fl_map_double(arguments, "durationSeconds");
  mpris_progress_seconds = fl_map_double(arguments, "progressSeconds");
  emit_mpris_properties_changed();
}

void handle_mpris_method_call(GDBusConnection* connection,
                              const gchar* sender,
                              const gchar* object_path,
                              const gchar* interface_name,
                              const gchar* method_name,
                              GVariant* parameters,
                              GDBusMethodInvocation* invocation,
                              gpointer user_data) {
  (void)connection;
  (void)sender;
  (void)object_path;
  (void)interface_name;
  (void)user_data;

  if (g_strcmp0(method_name, "Raise") == 0) {
    if (main_window != nullptr) {
      gtk_window_present(main_window);
    }
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  if (g_strcmp0(method_name, "Next") == 0) {
    send_desktop_command("next");
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  if (g_strcmp0(method_name, "Previous") == 0) {
    send_desktop_command("previous");
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  if (g_strcmp0(method_name, "PlayPause") == 0) {
    send_desktop_command("play-pause");
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  if (g_strcmp0(method_name, "Play") == 0) {
    if (!mpris_playing) {
      send_desktop_command("play-pause");
    }
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  if (g_strcmp0(method_name, "Pause") == 0) {
    if (mpris_playing) {
      send_desktop_command("play-pause");
    }
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  if (g_strcmp0(method_name, "Stop") == 0) {
    send_desktop_command("stop");
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  if (g_strcmp0(method_name, "Seek") == 0) {
    gint64 offset = 0;
    g_variant_get(parameters, "(x)", &offset);
    send_media_session_seek(mpris_progress_seconds + (offset / 1000000.0));
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  if (g_strcmp0(method_name, "SetPosition") == 0) {
    const gchar* track_id = nullptr;
    gint64 position = 0;
    g_variant_get(parameters, "(&ox)", &track_id, &position);
    (void)track_id;
    send_media_session_seek(position / 1000000.0);
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }
  if (g_strcmp0(method_name, "OpenUri") == 0 ||
      g_strcmp0(method_name, "Quit") == 0) {
    g_dbus_method_invocation_return_value(invocation, nullptr);
    return;
  }

  g_dbus_method_invocation_return_error(invocation, G_IO_ERROR,
                                        G_IO_ERROR_NOT_SUPPORTED,
                                        "Unsupported MPRIS method.");
}

const GDBusInterfaceVTable kMprisInterfaceVTable = {
    handle_mpris_method_call,
    get_mpris_property,
    nullptr,
};

void on_mpris_bus_acquired(GDBusConnection* connection,
                           const gchar* name,
                           gpointer user_data) {
  (void)name;
  (void)user_data;
  mpris_connection = static_cast<GDBusConnection*>(g_object_ref(connection));
  mpris_node_info = g_dbus_node_info_new_for_xml(kMprisIntrospectionXml, nullptr);
  const GDBusInterfaceInfo* root_interface =
      g_dbus_node_info_lookup_interface(mpris_node_info,
                                        "org.mpris.MediaPlayer2");
  const GDBusInterfaceInfo* player_interface =
      g_dbus_node_info_lookup_interface(mpris_node_info,
                                        "org.mpris.MediaPlayer2.Player");
  mpris_registration_id = g_dbus_connection_register_object(
      connection, kMprisObjectPath,
      const_cast<GDBusInterfaceInfo*>(root_interface), &kMprisInterfaceVTable,
      nullptr, nullptr, nullptr);
  mpris_player_registration_id = g_dbus_connection_register_object(
      connection, kMprisObjectPath,
      const_cast<GDBusInterfaceInfo*>(player_interface), &kMprisInterfaceVTable,
      nullptr, nullptr, nullptr);
}

void register_mpris_service() {
  if (mpris_owner_id != 0) {
    return;
  }
  mpris_owner_id = g_bus_own_name(G_BUS_TYPE_SESSION, kMprisBusName,
                                  G_BUS_NAME_OWNER_FLAGS_NONE,
                                  on_mpris_bus_acquired, nullptr, nullptr,
                                  nullptr, nullptr);
}

void unregister_mpris_service() {
  if (mpris_owner_id != 0) {
    g_bus_unown_name(mpris_owner_id);
    mpris_owner_id = 0;
  }
  if (mpris_connection != nullptr && mpris_registration_id != 0) {
    g_dbus_connection_unregister_object(mpris_connection, mpris_registration_id);
    mpris_registration_id = 0;
  }
  if (mpris_connection != nullptr && mpris_player_registration_id != 0) {
    g_dbus_connection_unregister_object(mpris_connection,
                                        mpris_player_registration_id);
    mpris_player_registration_id = 0;
  }
  if (mpris_node_info != nullptr) {
    g_dbus_node_info_unref(mpris_node_info);
    mpris_node_info = nullptr;
  }
  if (mpris_connection != nullptr) {
    g_object_unref(mpris_connection);
    mpris_connection = nullptr;
  }
}

void show_main_window(GSimpleAction* action, GVariant* parameter,
                      gpointer user_data) {
  (void)action;
  (void)parameter;
  GtkWindow* window = GTK_WINDOW(user_data);
  gtk_window_present(window);
}

void show_track_notification(GApplication* application, FlValue* arguments) {
  FlValue* title_value = fl_value_lookup_string(arguments, "title");
  FlValue* body_value = fl_value_lookup_string(arguments, "body");
  const gchar* title = fl_value_get_string(title_value);
  const gchar* body = fl_value_get_string(body_value);

  g_autoptr(GNotification) notification = g_notification_new(title);
  g_notification_set_body(notification, body);
  g_notification_set_default_action(notification, "app.show-window");
  g_application_send_notification(application, "track-changed", notification);
}

void handle_desktop_feature_method_call(FlMethodChannel* channel,
                                        FlMethodCall* method_call,
                                        gpointer user_data) {
  (void)channel;
  GApplication* application = G_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "showTrackNotification") == 0) {
    show_track_notification(application, fl_method_call_get_args(method_call));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "updateMediaSession") == 0) {
    update_mpris_state(fl_method_call_get_args(method_call));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "updateDesktopLyricsWindow") == 0) {
    update_desktop_lyrics_window(fl_method_call_get_args(method_call));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

#ifdef GDK_WINDOWING_X11
void grab_media_key(Display* display, Window root, KeySym keysym) {
  const KeyCode key_code = XKeysymToKeycode(display, keysym);
  if (key_code == 0) {
    return;
  }
  XGrabKey(display, key_code, AnyModifier, root, True, GrabModeAsync,
           GrabModeAsync);
}

void ungrab_media_key(Display* display, Window root, KeySym keysym) {
  const KeyCode key_code = XKeysymToKeycode(display, keysym);
  if (key_code == 0) {
    return;
  }
  XUngrabKey(display, key_code, AnyModifier, root);
}

GdkFilterReturn media_key_filter(GdkXEvent* xevent, GdkEvent* event,
                                 gpointer data) {
  XEvent* x_event = static_cast<XEvent*>(xevent);
  if (x_event->type != KeyPress) {
    return GDK_FILTER_CONTINUE;
  }

  const KeySym keysym = XLookupKeysym(&x_event->xkey, 0);
  switch (keysym) {
    case XF86XK_AudioPlay:
      send_desktop_command("play-pause");
      return GDK_FILTER_REMOVE;
    case XF86XK_AudioPrev:
      send_desktop_command("previous");
      return GDK_FILTER_REMOVE;
    case XF86XK_AudioNext:
      send_desktop_command("next");
      return GDK_FILTER_REMOVE;
    case XF86XK_AudioStop:
      send_desktop_command("stop");
      return GDK_FILTER_REMOVE;
    default:
      return GDK_FILTER_CONTINUE;
  }
}

void register_global_media_keys(GtkWindow* window) {
  GdkDisplay* gdk_display = gtk_widget_get_display(GTK_WIDGET(window));
  if (!GDK_IS_X11_DISPLAY(gdk_display)) {
    return;
  }

  media_key_display = GDK_DISPLAY_XDISPLAY(gdk_display);
  media_key_root = DefaultRootWindow(media_key_display);
  grab_media_key(media_key_display, media_key_root, XF86XK_AudioPlay);
  grab_media_key(media_key_display, media_key_root, XF86XK_AudioPrev);
  grab_media_key(media_key_display, media_key_root, XF86XK_AudioNext);
  grab_media_key(media_key_display, media_key_root, XF86XK_AudioStop);
  XFlush(media_key_display);

  if (!media_key_filter_registered) {
    gdk_window_add_filter(nullptr, media_key_filter, nullptr);
    media_key_filter_registered = true;
  }
}

void unregister_global_media_keys() {
  if (media_key_display == nullptr || media_key_root == 0) {
    return;
  }
  ungrab_media_key(media_key_display, media_key_root, XF86XK_AudioPlay);
  ungrab_media_key(media_key_display, media_key_root, XF86XK_AudioPrev);
  ungrab_media_key(media_key_display, media_key_root, XF86XK_AudioNext);
  ungrab_media_key(media_key_display, media_key_root, XF86XK_AudioStop);
  XFlush(media_key_display);
  if (media_key_filter_registered) {
    gdk_window_remove_filter(nullptr, media_key_filter, nullptr);
    media_key_filter_registered = false;
  }
  media_key_display = nullptr;
  media_key_root = 0;
}
#else
void register_global_media_keys(GtkWindow* window) {}
void unregister_global_media_keys() {}
#endif

}  // namespace

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (main_window != nullptr) {
    gtk_window_present(main_window);
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  main_window = window;

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Simple Melody Player");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Simple Melody Player");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
  const GActionEntry actions[] = {
      {"show-window", show_main_window, nullptr, nullptr, nullptr},
  };
  g_action_map_add_action_entries(G_ACTION_MAP(application), actions,
                                  G_N_ELEMENTS(actions), window);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  desktop_feature_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "smplayer_flutter/desktop_features",
      FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_method_channel_set_method_call_handler(
      desktop_feature_channel, handle_desktop_feature_method_call,
      g_object_ref(application), g_object_unref);
  register_mpris_service();
  register_global_media_keys(window);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::command_line.
static int my_application_command_line(GApplication* application,
                                       GApplicationCommandLine* command_line) {
  MyApplication* self = MY_APPLICATION(application);
  int argc = 0;
  gchar** arguments =
      g_application_command_line_get_arguments(command_line, &argc);
  gchar** external_arguments =
      argc > 1 ? g_strdupv(arguments + 1) : g_new0(gchar*, 1);
  g_strfreev(arguments);

  if (main_window == nullptr || desktop_feature_channel == nullptr) {
    g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
    self->dart_entrypoint_arguments = g_strdupv(external_arguments);
    g_application_activate(application);
    g_strfreev(external_arguments);
    return 0;
  }

  send_open_external_arguments(external_arguments);
  gtk_window_present(main_window);
  g_strfreev(external_arguments);
  return 0;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.
  unregister_global_media_keys();
  unregister_mpris_service();
  if (desktop_lyrics_window != nullptr) {
    gtk_widget_destroy(desktop_lyrics_window);
    desktop_lyrics_window = nullptr;
  }
  if (desktop_lyrics_css_provider != nullptr) {
    g_object_unref(desktop_lyrics_css_provider);
    desktop_lyrics_css_provider = nullptr;
  }
  main_window = nullptr;

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_HANDLES_COMMAND_LINE,
                                     nullptr));
}

#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gdk/gdkkeysyms.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#include <X11/XF86keysym.h>
#include <X11/Xlib.h>
#endif

#include "flutter/generated_plugin_registrant.h"

namespace {

FlMethodChannel* desktop_feature_channel = nullptr;

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
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

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
    gtk_header_bar_set_title(header_bar, "smplayer_flutter");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "smplayer_flutter");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  desktop_feature_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "smplayer_flutter/desktop_features",
      FL_METHOD_CODEC(fl_standard_method_codec_new()));
  register_global_media_keys(window);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.
  unregister_global_media_keys();

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
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
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
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}

#include "background_sharing.h"
#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <flutter_secure_storage_linux/flutter_secure_storage_linux_plugin.h>
#include <sqlite3_flutter_libs/sqlite3_flutter_libs_plugin.h>

int run_background_sharing_worker() {
  gtk_init(nullptr, nullptr);
  g_autoptr(FlDartProject) project = fl_dart_project_new();
  gchar worker_argument[] = "--sharing-worker";
  gchar* arguments[] = {worker_argument, nullptr};
  fl_dart_project_set_dart_entrypoint_arguments(project, arguments);
  g_autoptr(FlEngine) engine = fl_engine_new(project);
  g_autoptr(FlPluginRegistrar) secure = fl_plugin_registry_get_registrar_for_plugin(
      FL_PLUGIN_REGISTRY(engine), "FlutterSecureStorageLinuxPlugin");
  flutter_secure_storage_linux_plugin_register_with_registrar(secure);
  g_autoptr(FlPluginRegistrar) sqlite = fl_plugin_registry_get_registrar_for_plugin(
      FL_PLUGIN_REGISTRY(engine), "Sqlite3FlutterLibsPlugin");
  sqlite3_flutter_libs_plugin_register_with_registrar(sqlite);
  g_autoptr(GError) error = nullptr;
  if (!fl_engine_start(engine, &error)) {
    g_warning("Background sharing engine failed: %s", error->message);
    return 1;
  }
  g_autoptr(GMainLoop) loop = g_main_loop_new(nullptr, FALSE);
  g_main_loop_run(loop);
  return 0;
}

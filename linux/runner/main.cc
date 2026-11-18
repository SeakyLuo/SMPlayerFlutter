#include "my_application.h"
#include "background_sharing.h"
#include <cstring>

int main(int argc, char** argv) {
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--sharing-worker") == 0) return run_background_sharing_worker();
  }
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}

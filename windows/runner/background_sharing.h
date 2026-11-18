#ifndef RUNNER_BACKGROUND_SHARING_H_
#define RUNNER_BACKGROUND_SHARING_H_
#include <flutter/binary_messenger.h>
bool IsBackgroundSharingLaunch();
int RunBackgroundSharingWorker();
void RegisterBackgroundSharingChannel(flutter::BinaryMessenger* messenger);
#endif

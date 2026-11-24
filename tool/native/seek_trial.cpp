// Test-only C ABI. The caller supplies the two functions from its own loaded
// libmpv and the existing player handle, so neither the decoder nor VO changes.
#include <cstdint>
#include <cstdio>

#ifdef _WIN32
#define EXPORT extern "C" __declspec(dllexport)
#else
#define EXPORT extern "C" __attribute__((visibility("default")))
#endif

using SetProperty = int (*)(void *, const char *, const char *);
using Command = int (*)(void *, const char **);

EXPORT int trial_seek(void *player, SetProperty set, Command command, int index,
                      int64_t origin_ms) {
  // Ten +5s taps at 80ms intervals, followed by one exact commit.
  if (index > 0 && index < 10 && index % 2 != 0)
    return 0;
  const int steps = index == 10 ? 10 : index + 1;
  const int64_t ms = origin_ms + steps * 5000;
  char seconds[32];
  std::snprintf(seconds, sizeof(seconds), "%lld.%03lld",
                static_cast<long long>(ms / 1000),
                static_cast<long long>(ms % 1000));
  if (index == 0 || index == 10)
    return set(player, "time-pos", seconds);
  const char *args[] = {"seek", seconds, "absolute+keyframes", nullptr};
  return command(player, args);
}

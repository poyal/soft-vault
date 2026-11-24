// Native playback slice for comparison with the same surface in Flutter.
// Arguments: libmpv path, numbered 1080p60 fixture, JSON output, rounds, w, h.
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#else
#include <dlfcn.h>
#endif

extern "C" intptr_t trial_window_open(int, int);
extern "C" int trial_window_frame();
extern "C" void trial_window_close();
using Set = int (*)(void *, const char *, const char *);
using Command = int (*)(void *, const char **);
extern "C" int trial_seek(void *, Set, Command, int, int64_t);
using Clock = std::chrono::steady_clock;
static double ms(Clock::time_point since) {
  return std::chrono::duration<double, std::milli>(Clock::now() - since)
      .count();
}
static void check(int code) {
  if (code < 0)
    throw std::runtime_error("mpv error " + std::to_string(code));
}
extern "C" int run_standalone_trial(int argc, const char *const *argv) {
  if (argc != 7)
    return 2;
  std::ofstream out(argv[3]);
  try {
#ifdef _WIN32
    auto module = LoadLibraryA(argv[1]);
    auto symbol = [&](const char *s) { return GetProcAddress(module, s); };
    const char *decoder = "d3d11va-copy";
#else
    auto module = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto symbol = [&](const char *s) { return dlsym(module, s); };
    const char *decoder = "videotoolbox";
#endif
    if (!module)
      throw std::runtime_error("Cannot load test libmpv");
    auto create = reinterpret_cast<void *(*)()>(symbol("mpv_create"));
    auto option = reinterpret_cast<Set>(symbol("mpv_set_option_string"));
    auto set = reinterpret_cast<Set>(symbol("mpv_set_property_string"));
    auto command = reinterpret_cast<Command>(symbol("mpv_command"));
    auto get = reinterpret_cast<char *(*)(void *, const char *)>(
        symbol("mpv_get_property_string"));
    auto release = reinterpret_cast<void (*)(void *)>(symbol("mpv_free"));
    auto init = reinterpret_cast<int (*)(void *)>(symbol("mpv_initialize"));
    auto destroy =
        reinterpret_cast<void (*)(void *)>(symbol("mpv_terminate_destroy"));
    if (!create || !option || !set || !command || !get || !release || !init ||
        !destroy)
      throw std::runtime_error("Missing libmpv API");
    void *ctx = create();
    if (!ctx)
      throw std::runtime_error("mpv_create failed");
    auto property = [&](const char *name) {
      char *raw = get(ctx, name);
      std::string result = raw ? raw : "";
      if (raw)
        release(raw);
      return result;
    };
    auto view = trial_window_open(std::stoi(argv[5]), std::stoi(argv[6]));
    if (!view)
      throw std::runtime_error("Native window failed");
    check(option(ctx, "wid", std::to_string(view).c_str()));
    check(option(ctx, "config", "no"));
    check(option(ctx, "vo", "gpu"));
    check(option(ctx, "hwdec", decoder));
    check(option(ctx, "volume", "0"));
    check(option(ctx, "hr-seek", "yes"));
    check(option(ctx, "hr-seek-framedrop", "yes"));
    check(option(ctx, "cache", "yes"));
    check(option(ctx, "cache-on-disk", "no"));
    check(option(ctx, "demuxer-max-bytes", "67108864"));
    check(option(ctx, "demuxer-max-back-bytes", "33554432"));
    check(init(ctx));
    const char *cmd[] = {"loadfile", argv[2], nullptr};
    check(command(ctx, cmd));
    auto start = Clock::now();
    int first = -1;
    while (ms(start) < 8000) {
      int next = trial_window_frame();
      if (next >= 0 && first >= 0 && next != first)
        break;
      if (next >= 0)
        first = next;
      std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
    if (ms(start) >= 8000)
      throw std::runtime_error(
          "Native output could not show advancing test frame IDs");
    out << "{\"vo\":\"" << property("current-vo") << "\",\"hwdec\":\""
        << property("hwdec-current") << "\",\"records\":[";
    for (int round = 0; round < std::stoi(argv[4]); round++) {
      check(set(ctx, "pause", "yes"));
      auto reset = 5.5 + (round % 9) * .097;
      check(set(ctx, "time-pos", std::to_string(reset).c_str()));
      auto seekStart = Clock::now();
      for (;;) {
        int frame = trial_window_frame();
        if (frame >= 0 && std::abs(frame / 60. - reset) < .025)
          break;
        if (ms(seekStart) > 6000)
          throw std::runtime_error("Initial exact position timed out");
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
      }
      check(set(ctx, "pause", "no"));
      std::this_thread::sleep_for(std::chrono::milliseconds(350));
      auto origin =
          static_cast<int64_t>(std::stod(property("playback-time")) * 1000);
      auto clock = Clock::now();
      int index = 0, last = -1;
      double released = -1, nextInput = 0, firstTarget = -1, longest = 0,
             changed = 0, maxGap = 0, previous = 0;
      while (released < 0 || ms(clock) < released + 2000) {
        auto sampleStart = Clock::now();
        auto t = ms(clock);
        if (index <= 10 && t >= nextInput) {
          check(trial_seek(ctx, set, command, index, origin));
          if (index == 9) {
            released = t;
            changed = t;
          }
          nextInput = t + (index == 9 ? 150 : 80);
          index++;
        }
        int frame = trial_window_frame();
        t = ms(clock);
        maxGap = std::max(maxGap, t - previous);
        previous = t;
        if (released >= 0 && frame >= 0) {
          if (last != frame) {
            longest = std::max(longest, t - changed);
            changed = t;
            last = frame;
          }
          auto offset = frame / 60. - origin / 1000. - 50;
          if (firstTarget < 0 && offset >= -.021 &&
              offset <= (t - released) / 1000. + .05)
            firstTarget = t - released;
        }
        std::this_thread::sleep_until(sampleStart +
                                      std::chrono::milliseconds(16));
      }
      if (last < 0)
        throw std::runtime_error("No valid native samples after release");
      longest = std::max(longest, previous - changed);
      if (round)
        out << ',';
      out << "{\"round\":" << round << ",\"firstTargetMs\":"
          << (firstTarget < 0 ? "null" : std::to_string(firstTarget))
          << ",\"longestUnchangedMs\":" << longest
          << ",\"largestSampleGapMs\":" << maxGap << "}" << std::flush;
    }
    destroy(ctx);
    trial_window_close();
    out << "],\"complete\":true}";
    return 0;
  } catch (const std::exception &e) {
    std::fprintf(stderr, "%s\n", e.what());
    return 1;
  }
}
#ifdef _WIN32
int main(int argc, char **argv) { return run_standalone_trial(argc, argv); }
#endif

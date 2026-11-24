#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <algorithm>
#include <cmath>
#include <dlfcn.h>

// Only our own diagnostic NSWindow is eligible for capture.
static NSWindow *trialWindow;
static CGRect strip;
static CGWindowID number;
static void onMain(dispatch_block_t block) {
  if ([NSThread isMainThread])
    block();
  else
    dispatch_sync(dispatch_get_main_queue(), block);
}
extern "C" intptr_t trial_window_open(int width, int height) {
  __block intptr_t view = 0;
  onMain(^{
    trialWindow =
        [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, width, height)
                                    styleMask:NSWindowStyleMaskTitled
                                      backing:NSBackingStoreBuffered
                                        defer:NO];
    trialWindow.releasedWhenClosed = NO;
    trialWindow.title = @"Soft Vault playback test";
    [trialWindow center];
    [trialWindow makeKeyAndOrderFront:nil];
    number = (CGWindowID)trialWindow.windowNumber;
    NSRect screen =
        [trialWindow convertRectToScreen:trialWindow.contentView.bounds];
    CGFloat span = std::min(screen.size.width, screen.size.height * 16 / 9);
    strip = CGRectMake(
        NSMidX(screen) - span / 2,
        NSMaxY(NSScreen.screens.firstObject.frame) - NSMidY(screen), span, 2);
    view = (intptr_t)(__bridge void *)trialWindow.contentView;
  });
  return view;
}
extern "C" int trial_window_frame() {
  using Capture = CGImageRef (*)(CGRect, CGWindowListOption, CGWindowID,
                                 CGWindowImageOption);
  static Capture capture =
      (Capture)dlsym(RTLD_DEFAULT, "CGWindowListCreateImage");
  if (!capture || !number)
    return -1;
  CGImageRef image = capture(strip, kCGWindowListOptionIncludingWindow, number,
                             kCGWindowImageBoundsIgnoreFraming);
  if (!image)
    return -1;
  uint8_t row[64 * 4]{};
  CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
  CGContextRef ctx = CGBitmapContextCreate(row, 64, 1, 8, 64 * 4, color,
                                           kCGImageAlphaNoneSkipLast);
  CGContextDrawImage(ctx, CGRectMake(0, 0, 64, 1), image);
  CGContextRelease(ctx);
  CGColorSpaceRelease(color);
  CGImageRelease(image);
  int value = 0;
  for (int i = 0; i < 16; i++) {
    bool white = row[(4 * i + 2) * 4] > 160;
    if (((i == 0 || i == 15) && !white) || (i == 14 && white))
      return -1;
    if (i > 0 && i < 14 && white)
      value |= 1 << (i - 1);
  }
  return value;
}
extern "C" void trial_window_close() {
  onMain(^{
    [trialWindow close];
    trialWindow = nil;
    number = 0;
  });
}

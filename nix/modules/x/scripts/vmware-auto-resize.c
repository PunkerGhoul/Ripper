#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static void apply_auto_mode(const char *xrandr_bin) {
  pid_t pid = fork();

  if (pid == 0) {
    execl(xrandr_bin, xrandr_bin, "--auto", (char *)NULL);
    _exit(127);
  }

  if (pid > 0) {
    int status = 0;
    (void)waitpid(pid, &status, 0);
  }
}

int main(int argc, char **argv) {
  const char *xrandr_bin = argc > 1 ? argv[1] : "xrandr";
  Display *display = XOpenDisplay(NULL);

  if (display == NULL) {
    fprintf(stderr, "ripper-vmware-auto-resize: cannot open DISPLAY\n");
    return 1;
  }

  int event_base = 0;
  int error_base = 0;
  if (!XRRQueryExtension(display, &event_base, &error_base)) {
    fprintf(stderr, "ripper-vmware-auto-resize: XRandR extension not available\n");
    XCloseDisplay(display);
    return 1;
  }

  Window root = RootWindow(display, DefaultScreen(display));
  XRRSelectInput(
      display,
      root,
      RRScreenChangeNotifyMask | RRCrtcChangeNotifyMask |
          RROutputChangeNotifyMask | RROutputPropertyNotifyMask);
  XFlush(display);

  apply_auto_mode(xrandr_bin);

  for (;;) {
    XEvent event;
    XNextEvent(display, &event);

    if (event.type == event_base + RRScreenChangeNotify) {
      XRRUpdateConfiguration(&event);
    }

    while (XPending(display) > 0) {
      XNextEvent(display, &event);
      if (event.type == event_base + RRScreenChangeNotify) {
        XRRUpdateConfiguration(&event);
      }
    }

    apply_auto_mode(xrandr_bin);
  }
}

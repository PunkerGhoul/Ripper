#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static char *copy_name(const char *name, int length) {
  char *copy = calloc((size_t)length + 1, sizeof(char));
  if (copy == NULL) {
    return NULL;
  }

  memcpy(copy, name, (size_t)length);
  copy[length] = '\0';
  return copy;
}

static XRRModeInfo *find_mode(XRRScreenResources *resources, RRMode id) {
  for (int i = 0; i < resources->nmode; i++) {
    if (resources->modes[i].id == id) {
      return &resources->modes[i];
    }
  }

  return NULL;
}

static int ignore_x_error(Display *display, XErrorEvent *event) {
  char message[256];
  XGetErrorText(display, event->error_code, message, sizeof(message));
  fprintf(stderr, "ripper-vmware-auto-resize: ignored X11 error: %s\n", message);
  return 0;
}

static int run_xrandr(const char *xrandr_bin, const char *output,
                      const char *option, const char *value) {
  pid_t pid = fork();

  if (pid == 0) {
    if (value != NULL) {
      execl(xrandr_bin, xrandr_bin, "--output", output, option, value,
            (char *)NULL);
    } else {
      execl(xrandr_bin, xrandr_bin, "--output", output, option, (char *)NULL);
    }
    _exit(127);
  }

  if (pid > 0) {
    int status = 0;
    if (waitpid(pid, &status, 0) == pid && WIFEXITED(status)) {
      return WEXITSTATUS(status) == 0;
    }
  }

  return 0;
}

static int run_xrandr_mode_with_fb(const char *xrandr_bin, const char *output,
                                   const char *mode_name, int width,
                                   int height) {
  char framebuffer[64];
  snprintf(framebuffer, sizeof(framebuffer), "%dx%d", width, height);

  pid_t pid = fork();

  if (pid == 0) {
    execl(xrandr_bin, xrandr_bin, "--fb", framebuffer, "--output", output,
          "--mode", mode_name, (char *)NULL);
    _exit(127);
  }

  if (pid > 0) {
    int status = 0;
    if (waitpid(pid, &status, 0) == pid && WIFEXITED(status)) {
      return WEXITSTATUS(status) == 0;
    }
  }

  return 0;
}

static void apply_preferred_modes(Display *display, Window root,
                                  const char *xrandr_bin) {
  XRRScreenResources *resources = XRRGetScreenResources(display, root);
  if (resources == NULL) {
    fprintf(stderr, "ripper-vmware-auto-resize: cannot read XRandR resources\n");
    return;
  }

  int screen = DefaultScreen(display);
  int mm_width = DisplayWidthMM(display, screen);
  int mm_height = DisplayHeightMM(display, screen);

  for (int i = 0; i < resources->noutput; i++) {
    RROutput output = resources->outputs[i];
    XRROutputInfo *output_info = XRRGetOutputInfo(display, resources, output);
    if (output_info == NULL) {
      continue;
    }

    if (output_info->connection != RR_Connected || output_info->nmode < 1) {
      XRRFreeOutputInfo(output_info);
      continue;
    }

    RRMode mode_id = output_info->npreferred > 0 ? output_info->modes[0] : 0;
    if (mode_id == 0 && output_info->crtc != None) {
      XRRCrtcInfo *crtc_info =
          XRRGetCrtcInfo(display, resources, output_info->crtc);
      if (crtc_info != NULL) {
        mode_id = crtc_info->mode;
        XRRFreeCrtcInfo(crtc_info);
      }
    }
    if (mode_id == 0) {
      mode_id = output_info->modes[0];
    }

    XRRModeInfo *mode = find_mode(resources, mode_id);
    char *output_name = copy_name(output_info->name, output_info->nameLen);
    char *mode_name = mode == NULL ? NULL : copy_name(mode->name, mode->nameLength);

    if (mode != NULL && output_name != NULL && mode_name != NULL) {
      RRCrtc crtc = output_info->crtc;
      if (crtc == None && output_info->ncrtc > 0) {
        crtc = output_info->crtcs[0];
      }

      if (crtc != None) {
        XRRSetScreenSize(display, root, mode->width, mode->height, mm_width,
                         mm_height);
        Status status =
            XRRSetCrtcConfig(display, resources, crtc, CurrentTime, 0, 0,
                             mode->id, RR_Rotate_0, &output, 1);
        XSync(display, False);

        if (status == Success) {
          fprintf(stderr,
                  "ripper-vmware-auto-resize: applied %s mode %s via XRandR\n",
                  output_name, mode_name);
        } else if (run_xrandr_mode_with_fb(xrandr_bin, output_name, mode_name,
                                           (int)mode->width,
                                           (int)mode->height)) {
          fprintf(stderr,
                  "ripper-vmware-auto-resize: applied %s mode %s via xrandr "
                  "--fb\n",
                  output_name, mode_name);
        } else if (run_xrandr(xrandr_bin, output_name, "--mode", mode_name)) {
          fprintf(stderr,
                  "ripper-vmware-auto-resize: applied %s mode %s via xrandr\n",
                  output_name, mode_name);
        } else if (run_xrandr(xrandr_bin, output_name, "--auto", NULL)) {
          fprintf(stderr,
                  "ripper-vmware-auto-resize: applied %s via xrandr --auto\n",
                  output_name);
        } else {
          fprintf(stderr,
                  "ripper-vmware-auto-resize: failed to apply %s mode %s\n",
                  output_name, mode_name);
        }
      }
    }

    free(output_name);
    free(mode_name);
    XRRFreeOutputInfo(output_info);
  }

  XRRFreeScreenResources(resources);
}

int main(int argc, char **argv) {
  const char *xrandr_bin = argc > 1 ? argv[1] : "xrandr";
  XSetErrorHandler(ignore_x_error);
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

  apply_preferred_modes(display, root, xrandr_bin);

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

    apply_preferred_modes(display, root, xrandr_bin);
  }
}

#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>

struct screen_size {
    int width;
    int height;
};

static int is_xrandr_event(int type, int event_base) {
    return type == event_base + RRScreenChangeNotify ||
           type == event_base + RRNotify;
}

static int read_root_size(Display *dpy, Window root, struct screen_size *size) {
    XWindowAttributes attrs;
    if (XGetWindowAttributes(dpy, root, &attrs) == 0) {
        return 0;
    }

    size->width = attrs.width;
    size->height = attrs.height;
    return 1;
}

static int read_stable_root_size(Display *dpy, Window root,
                                 struct screen_size *size) {
    struct screen_size previous;
    struct screen_size current;

    if (!read_root_size(dpy, root, &previous)) {
        return 0;
    }

    for (int i = 0; i < 8; i++) {
        usleep(50000);
        if (!read_root_size(dpy, root, &current)) {
            return 0;
        }

        if (current.width == previous.width &&
            current.height == previous.height) {
            *size = current;
            return 1;
        }

        previous = current;
    }

    *size = previous;
    return 1;
}

static void reap_restart_process(pid_t *pid) {
    if (*pid <= 0) {
        return;
    }

    int status;
    pid_t result = waitpid(*pid, &status, WNOHANG);
    if (result == *pid || result < 0) {
        *pid = -1;
    }
}

static void restart_polybar(pid_t *pid, struct screen_size size) {
    reap_restart_process(pid);
    if (*pid > 0) {
        fprintf(stderr,
                "polybar-reload: resize already queued for %dx%d\n",
                size.width, size.height);
        return;
    }

    const char *home = getenv("HOME");
    if (home == NULL || home[0] == '\0') {
        fprintf(stderr, "polybar-reload: HOME is not set\n");
        return;
    }

    char script[PATH_MAX];
    if (snprintf(script, sizeof(script), "%s/.local/bin/ripper-polybar-start",
                 home) >= (int)sizeof(script)) {
        fprintf(stderr, "polybar-reload: polybar start path is too long\n");
        return;
    }

    pid_t child = fork();
    if (child < 0) {
        perror("polybar-reload: fork");
        return;
    }

    if (child == 0) {
        execl(script, script, (char *)NULL);
        perror("polybar-reload: exec ripper-polybar-start");
        _exit(127);
    }

    *pid = child;
    fprintf(stderr,
            "polybar-reload: screen changed to %dx%d; restarting polybar\n",
            size.width, size.height);
}

static void drain_xrandr_events(Display *dpy, int event_base) {
    XEvent ev;
    while (XPending(dpy) > 0) {
        XNextEvent(dpy, &ev);
        if (ev.type == event_base + RRScreenChangeNotify) {
            XRRUpdateConfiguration(&ev);
        }
    }
}

int main(void) {
    Display *dpy = XOpenDisplay(NULL);
    if (dpy == NULL) {
        fprintf(stderr, "polybar-reload: cannot open display\n");
        return 1;
    }

    Window root = DefaultRootWindow(dpy);

    int event_base;
    int error_base;
    if (!XRRQueryExtension(dpy, &event_base, &error_base)) {
        fprintf(stderr, "polybar-reload: XRandR extension not available\n");
        XCloseDisplay(dpy);
        return 1;
    }
    (void)error_base;

    XRRSelectInput(
        dpy,
        root,
        RRScreenChangeNotifyMask | RRCrtcChangeNotifyMask |
            RROutputChangeNotifyMask | RROutputPropertyNotifyMask);

    struct screen_size current;
    if (!read_root_size(dpy, root, &current)) {
        fprintf(stderr, "polybar-reload: cannot read root window size\n");
        XCloseDisplay(dpy);
        return 1;
    }

    fprintf(stderr, "polybar-reload: watching XRandR at %dx%d\n",
            current.width, current.height);

    pid_t restart_pid = -1;
    XEvent ev;
    while (1) {
        XNextEvent(dpy, &ev);
        reap_restart_process(&restart_pid);

        if (!is_xrandr_event(ev.type, event_base)) {
            continue;
        }

        if (ev.type == event_base + RRScreenChangeNotify) {
            XRRUpdateConfiguration(&ev);
        }

        usleep(120000);
        drain_xrandr_events(dpy, event_base);

        struct screen_size next;
        if (!read_stable_root_size(dpy, root, &next)) {
            fprintf(stderr, "polybar-reload: cannot read changed screen size\n");
            continue;
        }

        if (next.width == current.width && next.height == current.height) {
            continue;
        }

        current = next;
        restart_polybar(&restart_pid, current);
    }
}

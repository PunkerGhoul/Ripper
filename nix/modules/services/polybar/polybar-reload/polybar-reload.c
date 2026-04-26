#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>

static const char polybar_msg[] = "@polybarMsg@";

static int is_xrandr_event(int type, int event_base) {
    return type == event_base + RRScreenChangeNotify ||
           type == event_base + RRNotify;
}

static void restart_polybar(const char *launcher) {
    pid_t pid = fork();
    if (pid != 0) {
        return;
    }

    if (launcher != NULL && launcher[0] != '\0') {
        char *args[] = { (char *)launcher, NULL };
        execv(launcher, args);
        _exit(1);
    }

    char *args[] = { (char *)polybar_msg, "cmd", "restart", NULL };
    execv(polybar_msg, args);
    _exit(1);
}

int main(int argc, char **argv) {
    const char *launcher = argc > 1 ? argv[1] : NULL;

    signal(SIGCHLD, SIG_IGN); /* auto-reap children, no zombies */

    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "polybar-reload: cannot open display\n");
        return 1;
    }

    Window root = DefaultRootWindow(dpy);

    int ev_base, err_base;
    if (!XRRQueryExtension(dpy, &ev_base, &err_base)) {
        fprintf(stderr, "polybar-reload: XRandR extension not available\n");
        XCloseDisplay(dpy);
        return 1;
    }

    XRRSelectInput(
        dpy,
        root,
        RRScreenChangeNotifyMask | RRCrtcChangeNotifyMask |
            RROutputChangeNotifyMask | RROutputPropertyNotifyMask);

    XEvent ev;
    while (1) {
        XNextEvent(dpy, &ev); /* blocks — zero CPU while idle */
        if (is_xrandr_event(ev.type, ev_base)) {
            if (ev.type == ev_base + RRScreenChangeNotify) {
                XRRUpdateConfiguration(&ev);
            }

            usleep(150000);

            while (XPending(dpy) > 0) {
                XNextEvent(dpy, &ev);
                if (ev.type == ev_base + RRScreenChangeNotify) {
                    XRRUpdateConfiguration(&ev);
                }
            }

            restart_polybar(launcher);
        }
    }
}

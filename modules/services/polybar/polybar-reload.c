#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>

static const char polybar_msg[] = "@polybarMsg@";

int main(void) {
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

    /* Subscribe to screen geometry change events */
    XRRSelectInput(dpy, root, RRScreenChangeNotifyMask);

    XEvent ev;
    while (1) {
        XNextEvent(dpy, &ev); /* blocks — zero CPU while idle */
        if (ev.type == ev_base + RRScreenChangeNotify) {
            pid_t pid = fork();
            if (pid == 0) {
                char *args[] = { (char *)polybar_msg, "cmd", "restart", NULL };
                execv(polybar_msg, args);
                _exit(1);
            }
        }
    }
}

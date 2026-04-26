#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/Xrandr.h>

static Atom atom_net_wm_name;
static Atom atom_net_wm_pid;
static Atom atom_net_wm_strut;
static Atom atom_net_wm_strut_partial;

enum bar_role {
    BAR_UNKNOWN = 0,
    BAR_TOP,
    BAR_BOTTOM,
};

static int is_xrandr_event(int type, int event_base) {
    return type == event_base + RRScreenChangeNotify ||
           type == event_base + RRNotify;
}

static int ignore_x_error(Display *dpy, XErrorEvent *event) {
    (void)dpy;
    (void)event;
    return 0;
}

static int contains_ci(const char *haystack, const char *needle) {
    size_t needle_len = strlen(needle);
    if (needle_len == 0) {
        return 1;
    }

    for (const char *p = haystack; *p != '\0'; p++) {
        size_t i = 0;
        while (i < needle_len && p[i] != '\0') {
            char a = p[i];
            char b = needle[i];
            if (a >= 'A' && a <= 'Z') {
                a = (char)(a + ('a' - 'A'));
            }
            if (b >= 'A' && b <= 'Z') {
                b = (char)(b + ('a' - 'A'));
            }
            if (a != b) {
                break;
            }
            i++;
        }
        if (i == needle_len) {
            return 1;
        }
    }

    return 0;
}

static char *read_window_property(Display *dpy, Window window, Atom property) {
    Atom actual_type;
    int actual_format;
    unsigned long item_count;
    unsigned long bytes_after;
    unsigned char *data = NULL;

    if (XGetWindowProperty(
            dpy,
            window,
            property,
            0,
            1024,
            False,
            AnyPropertyType,
            &actual_type,
            &actual_format,
            &item_count,
            &bytes_after,
            &data) != Success ||
        data == NULL) {
        return NULL;
    }

    size_t bytes = item_count;
    if (actual_format == 16) {
        bytes *= 2;
    } else if (actual_format == 32) {
        bytes *= 4;
    }

    char *copy = calloc(bytes + 1, 1);
    if (copy != NULL) {
        memcpy(copy, data, bytes);
    }
    XFree(data);
    return copy;
}

static char *read_window_name(Display *dpy, Window window) {
    char *name = read_window_property(dpy, window, atom_net_wm_name);
    if (name != NULL && name[0] != '\0') {
        return name;
    }
    free(name);

    char *legacy_name = NULL;
    if (XFetchName(dpy, window, &legacy_name) > 0 && legacy_name != NULL) {
        char *copy = strdup(legacy_name);
        XFree(legacy_name);
        return copy;
    }

    return NULL;
}

static int is_polybar_window(Display *dpy, Window window, char **name_out) {
    char *name = read_window_name(dpy, window);
    if (name != NULL && contains_ci(name, "polybar")) {
        *name_out = name;
        return 1;
    }

    XClassHint hint;
    if (XGetClassHint(dpy, window, &hint) != 0) {
        int matched = 0;
        if (hint.res_name != NULL && contains_ci(hint.res_name, "polybar")) {
            matched = 1;
        }
        if (hint.res_class != NULL && contains_ci(hint.res_class, "polybar")) {
            matched = 1;
        }
        if (hint.res_name != NULL) {
            XFree(hint.res_name);
        }
        if (hint.res_class != NULL) {
            XFree(hint.res_class);
        }
        if (matched) {
            *name_out = name != NULL ? name : strdup("polybar");
            return 1;
        }
    }

    free(name);
    *name_out = NULL;
    return 0;
}

static enum bar_role role_from_name(const char *name) {
    if (name == NULL) {
        return BAR_UNKNOWN;
    }

    if (contains_ci(name, "ripper-polybar-bottom") ||
        contains_ci(name, "polybar-bottom")) {
        return BAR_BOTTOM;
    }

    if (contains_ci(name, "ripper-polybar-top") ||
        contains_ci(name, "polybar-top")) {
        return BAR_TOP;
    }

    return BAR_UNKNOWN;
}

static unsigned long read_window_pid(Display *dpy, Window window) {
    Atom actual_type;
    int actual_format;
    unsigned long item_count;
    unsigned long bytes_after;
    unsigned char *data = NULL;
    unsigned long pid = 0;

    if (XGetWindowProperty(
            dpy,
            window,
            atom_net_wm_pid,
            0,
            1,
            False,
            XA_CARDINAL,
            &actual_type,
            &actual_format,
            &item_count,
            &bytes_after,
            &data) == Success &&
        data != NULL && actual_format == 32 && item_count >= 1) {
        pid = ((unsigned long *)data)[0];
    }

    if (data != NULL) {
        XFree(data);
    }

    return pid;
}

static enum bar_role role_from_pid(Display *dpy, Window window) {
    unsigned long pid = read_window_pid(dpy, window);
    if (pid == 0) {
        return BAR_UNKNOWN;
    }

    char path[64];
    snprintf(path, sizeof(path), "/proc/%lu/cmdline", pid);

    FILE *file = fopen(path, "r");
    if (file == NULL) {
        return BAR_UNKNOWN;
    }

    char command[2048];
    size_t bytes = fread(command, 1, sizeof(command) - 1, file);
    fclose(file);

    if (bytes == 0) {
        return BAR_UNKNOWN;
    }

    command[bytes] = '\0';
    for (size_t i = 0; i < bytes; i++) {
        if (command[i] == '\0') {
            command[i] = ' ';
        }
    }

    return role_from_name(command);
}

static void update_dock_strut(Display *dpy, Window window, int screen_width,
                              int bar_height, enum bar_role role) {
    unsigned long strut[4] = {0, 0, 0, 0};
    unsigned long partial[12] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

    if (role == BAR_BOTTOM) {
        strut[3] = (unsigned long)bar_height;
        partial[3] = (unsigned long)bar_height;
        partial[10] = 0;
        partial[11] = (unsigned long)(screen_width > 0 ? screen_width - 1 : 0);
    } else {
        strut[2] = (unsigned long)bar_height;
        partial[2] = (unsigned long)bar_height;
        partial[8] = 0;
        partial[9] = (unsigned long)(screen_width > 0 ? screen_width - 1 : 0);
    }

    XChangeProperty(dpy, window, atom_net_wm_strut, XA_CARDINAL, 32,
                    PropModeReplace, (unsigned char *)strut, 4);
    XChangeProperty(dpy, window, atom_net_wm_strut_partial, XA_CARDINAL, 32,
                    PropModeReplace, (unsigned char *)partial, 12);
}

static int resize_window_tree(Display *dpy, Window window, int screen_width,
                              int screen_height) {
    int changed = 0;
    char *name = NULL;

    if (is_polybar_window(dpy, window, &name)) {
        enum bar_role role = role_from_name(name);
        if (role == BAR_UNKNOWN) {
            role = role_from_pid(dpy, window);
        }
        XWindowAttributes attrs;
        if (role != BAR_UNKNOWN &&
            XGetWindowAttributes(dpy, window, &attrs) != 0 &&
            attrs.map_state != IsUnmapped) {
            int bar_height = attrs.height > 0 ? attrs.height : 28;
            int y = role == BAR_BOTTOM ? screen_height - bar_height : 0;

            XMoveResizeWindow(dpy, window, 0, y, (unsigned int)screen_width,
                              (unsigned int)bar_height);
            update_dock_strut(dpy, window, screen_width, bar_height, role);
            changed++;
        }
    }
    free(name);

    Window root;
    Window parent;
    Window *children = NULL;
    unsigned int child_count = 0;
    if (XQueryTree(dpy, window, &root, &parent, &children, &child_count) == 0) {
        return changed;
    }

    for (unsigned int i = 0; i < child_count; i++) {
        changed += resize_window_tree(dpy, children[i], screen_width,
                                      screen_height);
    }

    if (children != NULL) {
        XFree(children);
    }

    return changed;
}

static int resize_polybar_windows(Display *dpy, Window root) {
    XWindowAttributes root_attrs;
    if (XGetWindowAttributes(dpy, root, &root_attrs) == 0) {
        return 0;
    }

    int screen_width = root_attrs.width;
    int screen_height = root_attrs.height;
    int changed = resize_window_tree(dpy, root, screen_width, screen_height);
    XFlush(dpy);

    if (changed > 0) {
        fprintf(stderr, "polybar-reload: resized %d polybar window(s) to %dx%d\n",
                changed, screen_width, screen_height);
    }

    return changed;
}

int main(void) {
    XSetErrorHandler(ignore_x_error);

    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "polybar-reload: cannot open display\n");
        return 1;
    }

    Window root = DefaultRootWindow(dpy);
    atom_net_wm_name = XInternAtom(dpy, "_NET_WM_NAME", False);
    atom_net_wm_pid = XInternAtom(dpy, "_NET_WM_PID", False);
    atom_net_wm_strut = XInternAtom(dpy, "_NET_WM_STRUT", False);
    atom_net_wm_strut_partial = XInternAtom(dpy, "_NET_WM_STRUT_PARTIAL", False);

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

    if (resize_polybar_windows(dpy, root) == 0) {
        fprintf(stderr, "polybar-reload: no polybar windows found on start\n");
    }

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

            if (resize_polybar_windows(dpy, root) == 0) {
                fprintf(stderr, "polybar-reload: no polybar windows found\n");
            }
        }
    }
}

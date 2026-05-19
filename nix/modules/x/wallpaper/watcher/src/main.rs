use std::env;
use std::ffi::{c_char, c_int, c_long, c_ulong, c_void};
use std::process::Command;
use std::ptr;
use std::thread;
use std::time::{Duration, Instant};

type Bool = c_int;
type Status = c_int;
type Display = c_void;
type Window = c_ulong;

const FALSE: Bool = 0;
const RR_SCREEN_CHANGE_NOTIFY: c_int = 0;
const RR_SCREEN_CHANGE_NOTIFY_MASK: c_long = 1 << 0;
const RR_CRTC_CHANGE_NOTIFY_MASK: c_long = 1 << 1;
const RR_OUTPUT_CHANGE_NOTIFY_MASK: c_long = 1 << 2;
const RR_OUTPUT_PROPERTY_NOTIFY_MASK: c_long = 1 << 3;

#[repr(C)]
union XEvent {
    type_: c_int,
    pad: [c_long; 24],
}

#[link(name = "X11")]
extern "C" {
    fn XOpenDisplay(display_name: *const c_char) -> *mut Display;
    fn XCloseDisplay(display: *mut Display) -> c_int;
    fn XDefaultScreen(display: *mut Display) -> c_int;
    fn XRootWindow(display: *mut Display, screen_number: c_int) -> Window;
    fn XDisplayWidth(display: *mut Display, screen_number: c_int) -> c_int;
    fn XDisplayHeight(display: *mut Display, screen_number: c_int) -> c_int;
    fn XFlush(display: *mut Display) -> c_int;
    fn XNextEvent(display: *mut Display, event_return: *mut XEvent) -> c_int;
    fn XPending(display: *mut Display) -> c_int;
}

#[link(name = "Xrandr")]
extern "C" {
    fn XRRQueryExtension(
        display: *mut Display,
        event_base_return: *mut c_int,
        error_base_return: *mut c_int,
    ) -> Bool;
    fn XRRSelectInput(display: *mut Display, window: Window, mask: c_int);
    fn XRRUpdateConfiguration(event: *mut XEvent) -> Status;
}

struct XDisplay {
    raw: *mut Display,
}

impl XDisplay {
    fn open() -> Result<Self, String> {
        let raw = unsafe { XOpenDisplay(ptr::null()) };
        if raw.is_null() {
            Err("cannot open DISPLAY".to_string())
        } else {
            Ok(Self { raw })
        }
    }

    fn default_screen(&self) -> c_int {
        unsafe { XDefaultScreen(self.raw) }
    }

    fn root(&self) -> Window {
        unsafe { XRootWindow(self.raw, self.default_screen()) }
    }

    fn screen_size(&self) -> (c_int, c_int) {
        let screen = self.default_screen();
        unsafe { (XDisplayWidth(self.raw, screen), XDisplayHeight(self.raw, screen)) }
    }
}

impl Drop for XDisplay {
    fn drop(&mut self) {
        unsafe {
            XCloseDisplay(self.raw);
        }
    }
}

fn event_type(event: &XEvent) -> c_int {
    unsafe { event.type_ }
}

fn restart_wallpaper(command: &str) {
    match Command::new(command).status() {
        Ok(status) if status.success() => {
            eprintln!("ripper-wallpaper-watch: wallpaper restarted");
        }
        Ok(status) => {
            eprintln!("ripper-wallpaper-watch: restart exited with {status}");
        }
        Err(error) => {
            eprintln!("ripper-wallpaper-watch: failed to execute restart command: {error}");
        }
    }
}

fn main() {
    let restart_command =
        env::args().nth(1).unwrap_or_else(|| "ripper-wallpaper-start".to_string());
    let debounce = Duration::from_millis(
        env::var("RIPPER_WALLPAPER_DEBOUNCE_MS")
            .ok()
            .and_then(|value| value.parse::<u64>().ok())
            .unwrap_or(250),
    );

    let display = match XDisplay::open() {
        Ok(display) => display,
        Err(error) => {
            eprintln!("ripper-wallpaper-watch: {error}");
            std::process::exit(1);
        }
    };

    let mut event_base = 0;
    let mut error_base = 0;
    let has_randr =
        unsafe { XRRQueryExtension(display.raw, &mut event_base, &mut error_base) } != FALSE;
    if !has_randr {
        eprintln!("ripper-wallpaper-watch: XRandR extension not available");
        std::process::exit(1);
    }

    unsafe {
        XRRSelectInput(
            display.raw,
            display.root(),
            (RR_SCREEN_CHANGE_NOTIFY_MASK
                | RR_CRTC_CHANGE_NOTIFY_MASK
                | RR_OUTPUT_CHANGE_NOTIFY_MASK
                | RR_OUTPUT_PROPERTY_NOTIFY_MASK) as c_int,
        );
        XFlush(display.raw);
    }

    let mut current_size = display.screen_size();
    eprintln!(
        "ripper-wallpaper-watch: watching RandR at {}x{}",
        current_size.0, current_size.1
    );

    loop {
        let mut event = XEvent { pad: [0; 24] };
        unsafe {
            XNextEvent(display.raw, &mut event);
            if event_type(&event) == event_base + RR_SCREEN_CHANGE_NOTIFY {
                XRRUpdateConfiguration(&mut event);
            }

            while XPending(display.raw) > 0 {
                XNextEvent(display.raw, &mut event);
                if event_type(&event) == event_base + RR_SCREEN_CHANGE_NOTIFY {
                    XRRUpdateConfiguration(&mut event);
                }
            }
        }

        let deadline = Instant::now() + debounce;
        while Instant::now() < deadline {
            thread::sleep(Duration::from_millis(25));

            unsafe {
                while XPending(display.raw) > 0 {
                    XNextEvent(display.raw, &mut event);
                    if event_type(&event) == event_base + RR_SCREEN_CHANGE_NOTIFY {
                        XRRUpdateConfiguration(&mut event);
                    }
                }
            }
        }

        let new_size = display.screen_size();
        if new_size != current_size {
            eprintln!(
                "ripper-wallpaper-watch: screen changed {}x{} -> {}x{}",
                current_size.0, current_size.1, new_size.0, new_size.1
            );
            current_size = new_size;
            restart_wallpaper(&restart_command);
        }
    }
}

package sokol_helpers

// Pass sokol logs into native odin logging system

import "base:runtime"
import "core:log"

Logger :: struct {
    func:      proc "c" (
        tag: cstring,
        log_level: u32,
        log_item: u32,
        message: cstring,
        line_nr: u32,
        filename: cstring,
        user_data: rawptr,
    ),
    user_data: rawptr,
}

// context_ptr: a pointer to a context which persists during the lifetime of the program.
// Note: you can transmute() this into a logger for any specific sokol library.
logger :: proc "contextless" (context_ptr: ^runtime.Context) -> Logger {
    return {func = logger_proc, user_data = cast(rawptr)context_ptr}
}

logger_proc :: proc "c" (
    tag: cstring,
    log_level: u32,
    log_item: u32,
    message: cstring,
    line_nr: u32,
    filename: cstring,
    user_data: rawptr,
) {
    context = (cast(^runtime.Context)user_data)^

    loc := runtime.Source_Code_Location {
        file_path = string(filename),
        line      = i32(line_nr),
    }

    switch log_level {
    case 0:
        log.panicf("Sokol Panic: (%i) %s: %s", log_item, tag, message, location = loc)

    case 1:
        // DUMBAI: escalate sokol error callbacks to panic so crash reports capture backtraces at first graphics failure.
        log.panicf("Sokol Error: (%i) %s: %s", log_item, tag, message, location = loc)
    case 2:
        log.logf(.Warning, "(%i) %s: %s", log_item, tag, message, location = loc)
    case:
        // DUMBAI: keep non-fatal diagnostics as regular logs to avoid turning informational chatter into crashes.
        log.logf(.Info, "(%i) %s: %s", log_item, tag, message, location = loc)
    }
}

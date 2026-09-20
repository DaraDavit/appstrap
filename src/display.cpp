#include "display.h"

#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <thread>

namespace {

ColorMode g_color_mode = ColorMode::Auto;

const char* C_RESET = "\x1b[0m";
const char* C_BOLD = "\x1b[1m";
const char* C_DIM = "\x1b[2m";
const char* C_RED = "\x1b[31m";
const char* C_GREEN = "\x1b[32m";
const char* C_YELLOW = "\x1b[33m";

const char* GLYPH_OK = "\u2713";    // ✓
const char* GLYPH_FAIL = "\u2717";  // ✗
const char* GLYPH_MISS = "\u00b7";  // ·

// Saved terminal state for the SIGINT/SIGTERM handler (picker raw mode).
struct termios g_saved_tios {};
bool g_tios_saved = false;

void restore_terminal() {
    if (g_tios_saved) {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &g_saved_tios);
        g_tios_saved = false;
    }
    static const char seq[] = "\x1b[?25h\x1b[?1049l";
    (void)write(STDOUT_FILENO, seq, sizeof(seq) - 1);
}

void handle_signal(int sig) {
    restore_terminal();
    _exit(128 + sig);
}

// Install-progress spinner (TTY only).
std::thread g_spinner;
std::atomic<bool> g_spinner_stop{false};
bool g_progress_active = false;

void clear_progress() {
    if (!g_progress_active) return;
    g_spinner_stop = true;
    if (g_spinner.joinable()) g_spinner.join();
    g_progress_active = false;
    std::fputs("\r\x1b[2K", stdout);
    std::fflush(stdout);
}

bool color_enabled() {
    if (g_color_mode == ColorMode::Never) return false;
    if (g_color_mode == ColorMode::Always) return true;
    const char* nc = std::getenv("NO_COLOR");
    if (nc && *nc) return false;
    return isatty(STDOUT_FILENO) != 0;
}

std::string paint(const char* code, const std::string& s) {
    if (!color_enabled()) return s;
    return std::string(code) + s + C_RESET;
}

std::string green(const std::string& s) { return paint(C_GREEN, s); }
std::string red(const std::string& s) { return paint(C_RED, s); }
std::string yellow(const std::string& s) { return paint(C_YELLOW, s); }
std::string bold(const std::string& s) { return paint(C_BOLD, s); }
std::string dim(const std::string& s) { return paint(C_DIM, s); }

// Puts stdin in raw mode (no canonical buffering, no echo) and restores the
// original settings on destruction so the terminal is never left broken.
struct TermRaw {
    struct termios orig {};
    bool active = false;

    bool enable() {
        if (!isatty(STDIN_FILENO)) return false;
        if (tcgetattr(STDIN_FILENO, &orig) != 0) return false;
        struct termios raw = orig;
        raw.c_lflag &= ~static_cast<tcflag_t>(ICANON | ECHO);
        raw.c_cc[VMIN] = 1;
        raw.c_cc[VTIME] = 0;
        if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) != 0) return false;
        active = true;
        g_saved_tios = orig;
        g_tios_saved = true;
        return true;
    }

    ~TermRaw() {
        if (active) {
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig);
            g_tios_saved = false;
        }
    }
};

enum Key {
    K_UP = 1000,
    K_DOWN,
    K_PGUP,
    K_PGDN,
    K_HOME,
    K_END,
    K_QUIT
};

int read_key() {
    int c = std::getchar();
    if (c == EOF) return K_QUIT;
    if (c == '\033') {  // ESC: arrow/function-key sequence
        int c2 = std::getchar();
        if (c2 == EOF) return K_QUIT;
        if (c2 == '[' || c2 == 'O') {
            int c3 = std::getchar();
            if (c3 == EOF) return K_QUIT;
            switch (c3) {
                case 'A': return K_UP;
                case 'B': return K_DOWN;
                case 'H': return K_HOME;
                case 'F': return K_END;
                case '5': std::getchar(); return K_PGUP;  // [5~
                case '6': std::getchar(); return K_PGDN;  // [6~
                case '1': std::getchar(); return K_HOME;  // [1~
                case '4': std::getchar(); return K_END;   // [4~
                default: return K_QUIT;
            }
        }
        return K_QUIT;
    }
    return c;
}

// Terminal width/height, or 0 if it cannot be determined.
int term_cols() {
    struct winsize ws {};
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0) {
        return (int)ws.ws_col;
    }
    return 0;
}

int term_rows() {
    struct winsize ws {};
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_row > 0) {
        return (int)ws.ws_row;
    }
    return 0;
}

}  // namespace

void set_color_mode(ColorMode mode) {
    g_color_mode = mode;
}

void print_usage(const std::string& prog) {
    std::cout
        << "appstrap — install a curated set of Linux apps\n\n"
        << "usage:\n"
        << "  " << prog << " detect                        show detected distro + package manager\n"
        << "  " << prog << " list [--all] [options]        list apps and install status\n"
        << "  " << prog << " install [apps...] [options]   install all, or only named apps\n"
        << "  " << prog << " uninstall [apps...] [options] remove all, or only named apps\n"
        << "  " << prog << " update [options]              upgrade installed apps\n"
        << "  " << prog << " select [options]              interactively pick apps to install\n\n"
        << "options:\n"
        << "  --config FILE   path to packages.json (default: ./packages.json or\n"
        << "                  ~/.config/appstrap/packages.json)\n"
        << "  --all           list also shows already-installed apps\n"
        << "  -y, --yes       skip confirmation prompt\n"
        << "  --dry-run       print commands without running them\n"
        << "  --force         reinstall even if already detected on PATH\n"
        << "  --color[=MODE]  color output (auto|always|never), or --no-color\n"
        << "  --version       show version and exit\n"
        << "  -h, --help      show this help\n";
}

void print_version(const std::string& prog) {
    std::cout << prog << " " << APPSTRAP_VERSION << "\n";
}

void print_detect(const Distro& d) {
    std::cout << bold("distro:         ") << d.pretty_name << "\n";
    std::cout << bold("id:             ") << d.id << "\n";
    std::cout << bold("id_like:        ") << d.id_like << "\n";
    std::cout << bold("package manager:") << (d.package_manager.empty() ? " unknown" : " " + d.package_manager)
              << "\n";
    std::cout << bold("running as root:") << (d.is_root ? " yes" : " no") << "\n";
}

void print_list(const Config& cfg, const Installer& inst, bool all) {
    int total = 0;
    int installed = 0;
    for (const auto& a : cfg.apps) {
        if (inst.is_installed(a)) ++installed;
        ++total;
    }

    if (!all) {
        std::cout << green(std::to_string(installed)) << "/" << std::to_string(total)
                  << " installed · ";
        if (total - installed > 0) {
            std::cout << yellow(std::to_string(total - installed)) << " to install";
        } else {
            std::cout << green("nothing to install");
        }
        std::cout << "\n";

        if (installed == total) return;

        size_t label_w = 0;
        for (const auto& group : cfg.grouped_apps()) {
            label_w = std::max(label_w, group.first.size());
        }
        label_w = std::min<size_t>(label_w + 2, 20);

        int width = term_cols();
        if (width <= 0) width = 80;

        std::cout << "\n";
        for (const auto& group : cfg.grouped_apps()) {
            std::vector<std::string> missing;
            for (const App* a : group.second) {
                if (!inst.is_installed(*a)) missing.push_back(a->name);
            }
            if (missing.empty()) continue;

            std::string label = group.first.empty() ? "(other)" : group.first;
            std::cout << std::left << std::setw((int)label_w) << label;

            int col = (int)label_w;
            for (size_t i = 0; i < missing.size(); ++i) {
                const std::string& token = missing[i];
                if (col + (int)token.size() + 2 > width && col > (int)label_w) {
                    std::cout << "\n" << std::string(label_w, ' ');
                    col = (int)label_w;
                }
                std::cout << token;
                col += (int)token.size();
                if (i + 1 < missing.size()) {
                    std::cout << "  ";
                    col += 2;
                }
            }
            std::cout << "\n";
        }
        return;
    }

    size_t max_name = 0;
    for (const auto& a : cfg.apps) {
        max_name = std::max(max_name, a.name.size());
    }

    for (const auto& group : cfg.grouped_apps()) {
        const auto& apps = group.second;
        if (!group.first.empty()) {
            std::cout << bold(group.first) << " (" << apps.size() << ")\n";
        }
        for (size_t i = 0; i < apps.size(); ++i) {
            bool ok = inst.is_installed(*apps[i]);
            std::cout << "  " << (ok ? green(GLYPH_OK) : dim(GLYPH_MISS)) << " "
                      << std::left << std::setw((int)max_name) << apps[i]->name << "  "
                      << dim(inst.source(*apps[i])) << "\n";
        }
        std::cout << "\n";
    }

    std::cout << "Summary: " << total << " apps · " << installed << " installed · "
              << (total - installed) << " to install\n";
}

void print_manifest(const std::string& path, const Distro& d) {
    std::cout << dim("manifest: " + path + " (" + d.package_manager + ")") << "\n";
}

void print_status(const std::string& text) {
    std::cout << text << "\n";
}

void print_stderr(const std::string& text) {
    std::cerr << text << "\n";
}

void print_raw(const std::string& text) {
    clear_progress();
    std::cout << text;
}

void print_section(const std::string& title) {
    clear_progress();
    std::cout << "== " << title << " ==\n";
}

void print_line(const std::string& text) {
    clear_progress();
    std::cout << "  " << text << "\n";
}

void print_dry_run(const std::string& cmd, bool use_sudo) {
    clear_progress();
    std::cout << "  [dry-run] " << (use_sudo ? "sudo " : "") << cmd << "\n";
}

void print_warning(const std::string& text) {
    clear_progress();
    std::cout << "  " << yellow("warning:") << " " << text << "\n";
}

void print_error(const std::string& text) {
    clear_progress();
    std::cout << "  " << red("error:") << " " << text << "\n";
}

void print_result(const std::string& name, InstallStatus status) {
    clear_progress();
    switch (status) {
        case InstallStatus::Installed:
            std::cout << "  " << green(GLYPH_OK) << " " << name << "\n";
            break;
        case InstallStatus::AlreadyInstalled:
            std::cout << "  " << dim(GLYPH_OK) << " " << name << " "
                      << dim("(already installed)") << "\n";
            break;
        case InstallStatus::Failed:
            std::cout << "  " << red(GLYPH_FAIL) << " " << name << "\n";
            break;
    }
}

void print_remove_result(const std::string& name, RemoveStatus status) {
    clear_progress();
    switch (status) {
        case RemoveStatus::Removed:
            std::cout << "  " << green(GLYPH_OK) << " " << name << "\n";
            break;
        case RemoveStatus::NotInstalled:
            std::cout << "  " << dim(GLYPH_MISS) << " " << name << " "
                      << dim("(not installed)") << "\n";
            break;
        case RemoveStatus::Failed:
            std::cout << "  " << red(GLYPH_FAIL) << " " << name << "\n";
            break;
    }
}

void print_update_result(UpdateStatus status) {
    clear_progress();
    switch (status) {
        case UpdateStatus::Updated:
            std::cout << "  " << green(GLYPH_OK) << " update complete\n";
            break;
        case UpdateStatus::Failed:
            std::cout << "  " << red(GLYPH_FAIL) << " update failed\n";
            break;
    }
}

void print_summary(int total, int installed, int already, int failed) {
    std::cout << std::to_string(total) << " apps · "
              << green(std::to_string(installed) + " installed");
    if (already) {
        std::cout << " · " << dim(std::to_string(already) + " already installed");
    }
    if (failed) {
        std::cout << " · " << red(std::to_string(failed) + " failed");
    }
    std::cout << "\n";
}

void print_summary_remove(int total, int removed, int skipped, int failed) {
    std::cout << std::to_string(total) << " apps · "
              << green(std::to_string(removed) + " removed");
    if (skipped) {
        std::cout << " · " << dim(std::to_string(skipped) + " not installed");
    }
    if (failed) {
        std::cout << " · " << red(std::to_string(failed) + " failed");
    }
    std::cout << "\n";
}

void progress_start(const std::string& name, int index, int total) {
    if (!isatty(STDOUT_FILENO) || g_progress_active) return;
    std::printf("  [%d/%d] installing %s ", index, total, name.c_str());
    std::fflush(stdout);
    g_spinner_stop = false;
    g_spinner = std::thread([] {
        static const char frames[] = {'|', '/', '-', '\\'};
        size_t i = 0;
        while (!g_spinner_stop.load()) {
            std::fputc('\b', stdout);
            std::fputc(frames[i++ % 4], stdout);
            std::fflush(stdout);
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    });
    g_progress_active = true;
}

std::vector<int> checkbox_select(const std::vector<std::string>& rows,
                                 const std::vector<bool>& selectable) {
    const int n = (int)rows.size();

    int first = -1;
    int last = -1;
    int sel_total = 0;
    for (int i = 0; i < n; ++i) {
        if (selectable[i]) {
            if (first < 0) first = i;
            last = i;
            ++sel_total;
        }
    }
    if (first < 0) return {};

    TermRaw raw;
    if (!raw.enable()) {
        std::cerr << "stdin is not a terminal; cannot show picker.\n";
        return {};
    }

    std::vector<bool> selected(n, false);
    int cursor = first;
    int scroll = 0;

    int height = term_rows();
    int visible = (height > 0) ? height - 3 : n;  // title, status, spare bottom line
    if (visible < 1) visible = 1;

    std::fputs("\x1b[?1049h", stdout);  // alternate screen buffer
    std::fputs("\x1b[?25l", stdout);  // hide cursor

    struct sigaction sa {};
    struct sigaction old_int {};
    struct sigaction old_term {};
    sa.sa_handler = handle_signal;
    sigaction(SIGINT, &sa, &old_int);
    sigaction(SIGTERM, &sa, &old_term);

    auto ensure_visible = [&]() {
        if (cursor < scroll) scroll = cursor;
        if (cursor >= scroll + visible) scroll = cursor - visible + 1;
        if (scroll > n - visible) scroll = n - visible;
        if (scroll < 0) scroll = 0;
    };

    auto render = [&]() {
        int sel_count = 0;
        for (int i = 0; i < n; ++i) {
            if (selectable[i] && selected[i]) ++sel_count;
        }

        std::printf("\x1b[H\x1b[2J");  // home + full clear every frame
        std::printf("select apps to install:\n");
        for (int i = scroll; i < n && i < scroll + visible; ++i) {
            if (i == cursor) std::fputs("\x1b[7m", stdout);  // reverse video
            if (selectable[i]) {
                std::printf(" [%c] %s", selected[i] ? 'x' : ' ', rows[i].c_str());
            } else {
                std::fputs("\x1b[1m", stdout);  // bold header
                std::printf("  %s", rows[i].c_str());
                std::fputs("\x1b[0m", stdout);
            }
            if (i == cursor) std::fputs("\x1b[0m", stdout);
            std::fputs("\n", stdout);
        }
        std::printf("selected: %d/%d  |  up/down move · space toggle · a all · c clear · enter ok · q quit\n",
                    sel_count, sel_total);
        std::fputs("\n", stdout);  // keep the status line off the bottom row
        std::fflush(stdout);
    };

    render();

    bool done = false;
    while (!done) {
        int k = read_key();
        switch (k) {
            case K_UP:
            case 'k': {
                int p = cursor - 1;
                while (p >= 0 && !selectable[p]) --p;
                if (p >= 0) cursor = p;
                break;
            }
            case K_DOWN:
            case 'j': {
                int p = cursor + 1;
                while (p < n && !selectable[p]) ++p;
                if (p < n) cursor = p;
                break;
            }
            case K_HOME:
                cursor = first;
                break;
            case K_END:
                cursor = last;
                break;
            case K_PGUP: {
                int p = cursor - visible;
                if (p < first) p = first;
                while (p < n && !selectable[p]) ++p;
                cursor = (p < n) ? p : last;
                break;
            }
            case K_PGDN: {
                int p = cursor + visible;
                if (p >= n) p = n - 1;
                while (p >= 0 && !selectable[p]) --p;
                cursor = (p >= 0) ? p : last;
                break;
            }
            case ' ':
                if (selectable[cursor]) selected[cursor] = !selected[cursor];
                break;
            case 'a':
                for (int i = 0; i < n; ++i) {
                    if (selectable[i]) selected[i] = true;
                }
                break;
            case 'c':
                for (int i = 0; i < n; ++i) selected[i] = false;
                break;
            case '\n':
            case '\r':
                done = true;
                break;
            case 'q':
            case K_QUIT:
                sigaction(SIGINT, &old_int, nullptr);
                sigaction(SIGTERM, &old_term, nullptr);
                std::fputs("\x1b[?25h", stdout);  // restore cursor
                std::fputs("\x1b[?1049l", stdout);  // leave alt screen
                std::fputs("\n", stdout);
                return {};
            default:
                break;
        }
        ensure_visible();
        render();
    }

    sigaction(SIGINT, &old_int, nullptr);
    sigaction(SIGTERM, &old_term, nullptr);
    std::fputs("\x1b[?25h", stdout);  // restore cursor
    std::fputs("\x1b[0m", stdout);
    std::fputs("\x1b[?1049l", stdout);  // leave alt screen
    std::fputs("\n", stdout);

    std::vector<int> out;
    for (int i = 0; i < n; ++i) {
        if (selectable[i] && selected[i]) out.push_back(i);
    }
    return out;
}

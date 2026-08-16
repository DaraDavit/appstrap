#include <unistd.h>

#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

#include "config.h"
#include "display.h"
#include "distro.h"
#include "installer.h"

namespace {

std::string default_config_path() {
    const char* home = std::getenv("HOME");
    if (home) {
        std::string p = std::string(home) + "/.config/appstrap/packages.json";
        if (access(p.c_str(), F_OK) == 0) return p;
    }
    return "packages.json";
}

int cmd_detect() {
    Distro d = detect_distro();
    print_detect(d);
    return 0;
}

int cmd_list(const Config& cfg, const Installer& inst, bool all) {
    print_list(cfg, inst, all);
    return 0;
}

int cmd_install(const Config& cfg, Installer& inst, const std::vector<std::string>& names,
                const InstallOptions& opts, bool yes) {
    std::vector<const App*> todo;

    if (names.empty()) {
        for (const auto& a : cfg.apps) todo.push_back(&a);
    } else {
        for (const auto& n : names) {
            const App* a = cfg.find(n);
            if (!a) {
                print_status("unknown app: " + n + " (see `list`)");
                return 1;
            }
            todo.push_back(a);
        }
    }

    if (todo.empty()) {
        print_status("nothing to do (empty manifest?)");
        return 1;
    }

    if (!yes && !opts.dry_run) {
        std::cout << "install " << todo.size() << " app(s)? [y/N] ";
        std::cout.flush();
        std::string answer;
        std::getline(std::cin, answer);
        if (answer != "y" && answer != "Y" && answer != "yes") {
            print_status("aborted.");
            return 0;
        }
    }

    int installed = 0;
    int already = 0;
    int failed = 0;
    for (const App* a : todo) {
        InstallStatus s = inst.install(*a, opts);
        switch (s) {
            case InstallStatus::Installed: ++installed; break;
            case InstallStatus::AlreadyInstalled: ++already; break;
            case InstallStatus::Failed: ++failed; break;
        }
        if (opts.dry_run) {
            std::cout << "\n";
        } else {
            print_result(a->name, s);
        }
    }

    if (!opts.dry_run) {
        print_summary((int)todo.size(), installed, already, failed);
    }
    return failed == 0 ? 0 : 1;
}

int cmd_select(const Config& cfg, Installer& inst, const InstallOptions& opts, bool yes) {
    std::vector<std::string> rows;
    std::vector<bool> selectable;
    std::vector<const App*> row_app;

    for (const auto& group : cfg.grouped_apps()) {
        if (!group.first.empty()) {
            rows.push_back(group.first);
            selectable.push_back(false);
            row_app.push_back(nullptr);
        }
        for (const App* a : group.second) {
            rows.push_back(a->name);
            selectable.push_back(true);
            row_app.push_back(a);
        }
    }

    std::vector<int> idx = checkbox_select(rows, selectable);
    if (idx.empty()) {
        print_status("nothing selected.");
        return 0;
    }

    std::vector<std::string> selected;
    for (int i : idx) selected.push_back(row_app[i]->name);

    return cmd_install(cfg, inst, selected, opts, yes);
}

}  // namespace

int main(int argc, char** argv) {
    std::string cmd = (argc >= 2) ? argv[1] : "select";
    if (cmd == "-h" || cmd == "--help" || cmd == "help") {
        print_usage(argv[0]);
        return 0;
    }

    std::string config_path;
    bool yes = false;
    bool all = false;
    InstallOptions opts;
    std::vector<std::string> names;

    for (int i = 2; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "--config" && i + 1 < argc) {
            config_path = argv[++i];
        } else if (a == "-y" || a == "--yes") {
            yes = true;
        } else if (a == "--dry-run") {
            opts.dry_run = true;
        } else if (a == "--force") {
            opts.force = true;
        } else if (a == "--all") {
            all = true;
        } else if (a == "--no-color") {
            set_color_mode(ColorMode::Never);
        } else if (a == "--color") {
            set_color_mode(ColorMode::Always);
        } else if (a.rfind("--color=", 0) == 0) {
            std::string v = a.substr(8);
            if (v == "always") set_color_mode(ColorMode::Always);
            else if (v == "never") set_color_mode(ColorMode::Never);
            else set_color_mode(ColorMode::Auto);
        } else if (a == "-h" || a == "--help") {
            print_usage(argv[0]);
            return 0;
        } else {
            names.push_back(a);
        }
    }

    if (cmd == "detect") {
        return cmd_detect();
    }

    if (config_path.empty()) {
        config_path = default_config_path();
    }

    Config cfg = load_config(config_path);
    if (cfg.apps.empty()) {
        print_stderr("error: could not load manifest from " + config_path +
                     " (use --config FILE)");
        return 1;
    }

    Distro d = detect_distro();
    Installer inst(d);

    if (cmd == "list") {
        print_manifest(config_path, d);
        return cmd_list(cfg, inst, all);
    }

    if (cmd == "install") {
        print_manifest(config_path, d);
        return cmd_install(cfg, inst, names, opts, yes);
    }

    if (cmd == "select") {
        print_manifest(config_path, d);
        return cmd_select(cfg, inst, opts, yes);
    }

    print_stderr("unknown command: " + cmd);
    print_usage(argv[0]);
    return 1;
}

#include "installer.h"

#include "display.h"
#include "runner.h"

namespace {

std::string join(const std::vector<std::string>& items, const std::string& sep) {
    std::string out;
    for (size_t i = 0; i < items.size(); ++i) {
        if (i) out += sep;
        out += items[i];
    }
    return out;
}

}  // namespace

std::string Installer::install_command(const std::vector<std::string>& pkgs) const {
    std::string args = join(pkgs, " ");
    const std::string& pm = distro_.package_manager;

    if (pm == "apt") return "apt-get install -y " + args;
    if (pm == "dnf") return "dnf install -y " + args;
    if (pm == "pacman") return "pacman -S --noconfirm --needed " + args;
    if (pm == "zypper") return "zypper --non-interactive install " + args;
    if (pm == "apk") return "apk add " + args;

    return "";
}

bool Installer::is_installed(const App& app) const {
    if (!app.flatpak.empty()) {
        return run("flatpak info --user " + app.flatpak).ok();
    }
    return run("command -v " + app.bin).ok();
}

std::string Installer::source(const App& app) const {
    if (!app.flatpak.empty()) return "flatpak";
    if (resolve_family(distro_, app.packages).empty()) return "-";
    if (distro_.package_manager.empty()) return "-";
    return distro_.package_manager;
}

void Installer::refresh_index(const InstallOptions& opts) {
    if (distro_.package_manager != "apt" || apt_updated_) return;
    const std::string cmd = "apt-get update";
    if (opts.dry_run) {
        print_dry_run(cmd);
        apt_updated_ = true;
        return;
    }
    CmdResult r = run(cmd, true);
    if (!r.ok()) {
        print_warning("apt-get update failed");
    }
    apt_updated_ = true;
}

void Installer::run_post(const App& app, const InstallOptions& opts) {
    for (const auto& p : app.post) {
        if (opts.dry_run) {
            print_dry_run(p);
            continue;
        }
        CmdResult r = run(p, true);
        if (!r.ok()) {
            print_warning("post command failed");
        }
    }
}

bool Installer::ensure_flatpak(const InstallOptions& opts) {
    if (flatpak_ready_) return true;

    const std::string add_remote =
        "flatpak remote-add --user --if-not-exists flathub "
        "https://flathub.org/repo/flathub.flatpakrepo";

    if (run("command -v flatpak").ok()) {
        flatpak_ready_ = true;
        if (opts.dry_run) {
            print_dry_run(add_remote);
            return true;
        }
        CmdResult r = run(add_remote);
        if (!r.ok()) {
            print_warning("could not add flathub remote");
        }
        return true;
    }

    std::string cmd = install_command({"flatpak"});
    if (cmd.empty()) {
        print_error("cannot install flatpak (unsupported package manager)");
        return false;
    }

    if (opts.dry_run) {
        print_dry_run(cmd, true);
        print_dry_run(add_remote);
        flatpak_ready_ = true;
        return true;
    }

    refresh_index(opts);

    CmdResult r = run(cmd, true);
    if (!r.ok()) {
        print_error("failed to install flatpak:");
        print_raw(r.output);
        return false;
    }

    CmdResult ar = run(add_remote);
    if (!ar.ok()) {
        print_warning("could not add flathub remote");
    }
    flatpak_ready_ = true;
    return true;
}

InstallStatus Installer::install(const App& app, const InstallOptions& opts) {
    if (opts.dry_run) {
        print_section(app.name);
    }

    if (is_installed(app) && !opts.force) {
        if (opts.dry_run) {
            print_line("already installed" +
                       (app.flatpak.empty() ? " (" + app.bin + ")"
                                            : " (flatpak " + app.flatpak + ")"));
        }
        return InstallStatus::AlreadyInstalled;
    }

    // Flatpak install path.
    if (!app.flatpak.empty()) {
        if (!ensure_flatpak(opts)) return InstallStatus::Failed;
        std::string cmd = "flatpak install -y --user flathub " + app.flatpak;
        if (opts.dry_run) {
            print_dry_run(cmd);
        } else {
            CmdResult r = run(cmd);
            if (!r.ok()) {
                print_error("flatpak install failed:");
                print_raw(r.output);
                return InstallStatus::Failed;
            }
        }
        run_post(app, opts);
        return InstallStatus::Installed;
    }

    // Package-manager install path.
    std::string family = resolve_family(distro_, app.packages);
    std::vector<std::string> pkgs;
    if (!family.empty()) {
        pkgs = app.packages.at(family);
    }

    std::string setup_family = resolve_family(distro_, app.setup);
    bool ran_setup = false;
    if (!setup_family.empty()) {
        const auto& cmds = app.setup.at(setup_family);
        for (const auto& cmd : cmds) {
            if (opts.dry_run) {
                print_dry_run(cmd, true);
                ran_setup = true;
                continue;
            }
            CmdResult r = run(cmd, true);
            if (!r.ok()) {
                print_error("setup command failed:");
                print_raw(r.output);
                return InstallStatus::Failed;
            }
            ran_setup = true;
        }
    }

    if (ran_setup) {
        refresh_index(opts);
    }

    if (pkgs.empty()) {
        print_line("no packages mapped for this distro (" + distro_.package_manager + ")");
        return InstallStatus::Failed;
    }

    std::string cmd = install_command(pkgs);
    if (cmd.empty()) {
        print_error("unsupported package manager");
        return InstallStatus::Failed;
    }

    refresh_index(opts);

    if (opts.dry_run) {
        print_dry_run(cmd, true);
    } else {
        CmdResult r = run(cmd, true);
        if (!r.ok()) {
            print_error("install failed:");
            print_raw(r.output);
            return InstallStatus::Failed;
        }
    }

    run_post(app, opts);
    return InstallStatus::Installed;
}

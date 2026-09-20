#pragma once

#include <string>
#include <vector>

#include "config.h"
#include "distro.h"

enum class InstallStatus { Installed, AlreadyInstalled, Failed };

enum class RemoveStatus { Removed, NotInstalled, Failed };

enum class UpdateStatus { Updated, Failed };

struct InstallOptions {
    bool dry_run = false;
    bool force = false;
};

class Installer {
public:
    explicit Installer(const Distro& d) : distro_(d) {}

    // Returns the package-manager install command for the given packages
    // (without sudo). Empty when no matching package manager is known.
    std::string install_command(const std::vector<std::string>& pkgs) const;

    // Returns the package-manager remove command for the given packages
    // (without sudo). Empty when no matching package manager is known.
    std::string remove_command(const std::vector<std::string>& pkgs) const;

    // True when the app is already installed: checks `flatpak info <id>` for
    // flatpak apps, otherwise `command -v <bin>`.
    bool is_installed(const App& app) const;

    // Install method label: "flatpak", the package manager name, or "-" when
    // no packages are mapped for this distro.
    std::string source(const App& app) const;

    // Installs one app (flatpak or package manager path).
    InstallStatus install(const App& app, const InstallOptions& opts);

    // Removes one app (flatpak or package manager path). Skips apps that are
    // not installed.
    RemoveStatus remove(const App& app, const InstallOptions& opts);

    // Upgrades all installed packages and flatpak apps.
    UpdateStatus update(const InstallOptions& opts);

    // Runs `apt-get update` once (after adding third-party repos and before the
    // first apt install). No-op for non-apt package managers.
    void refresh_index(const InstallOptions& opts);

    const Distro& distro_;

private:
    void run_post(const App& app, const InstallOptions& opts);
    bool ensure_flatpak(const InstallOptions& opts);

    bool flatpak_ready_ = false;
    bool apt_updated_ = false;
};

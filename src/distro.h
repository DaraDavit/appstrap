#pragma once

#include <string>

struct Distro {
    std::string id;              // /etc/os-release ID, e.g. "fedora"
    std::string id_like;         // ID_LIKE, e.g. "rhel fedora"
    std::string pretty_name;     // PRETTY_NAME, e.g. "Fedora Linux 44"
    std::string package_manager; // "apt", "dnf", "pacman", "zypper", "apk", or ""
    bool is_root = false;
};

// Reads /etc/os-release and resolves the package manager.
Distro detect_distro();

// True when the process is running as root (euid == 0).
bool running_as_root();

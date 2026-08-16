#include "distro.h"

#include <unistd.h>

#include <fstream>
#include <sstream>

namespace {

std::string trim_quotes(const std::string& s) {
    if (s.size() >= 2 && s.front() == '"' && s.back() == '"') {
        return s.substr(1, s.size() - 2);
    }
    return s;
}

bool contains_word(const std::string& haystack, const std::string& needle) {
    if (needle.empty()) return false;
    std::istringstream iss(haystack);
    std::string token;
    while (iss >> token) {
        if (token == needle) return true;
    }
    return false;
}

}  // namespace

bool running_as_root() {
    return geteuid() == 0;
}

Distro detect_distro() {
    Distro d;
    d.is_root = running_as_root();

    std::ifstream f("/etc/os-release");
    if (!f.is_open()) {
        return d;
    }

    std::string line;
    while (std::getline(f, line)) {
        auto eq = line.find('=');
        if (eq == std::string::npos) continue;
        std::string key = line.substr(0, eq);
        std::string val = trim_quotes(line.substr(eq + 1));
        if (key == "ID") d.id = val;
        else if (key == "ID_LIKE") d.id_like = val;
        else if (key == "PRETTY_NAME") d.pretty_name = val;
    }

    std::string family = d.id + " " + d.id_like;
    if (d.id == "debian" || contains_word(family, "debian") || d.id == "ubuntu" ||
        contains_word(family, "ubuntu")) {
        d.package_manager = "apt";
    } else if (d.id == "arch" || contains_word(family, "arch") || d.id == "manjaro" ||
               contains_word(family, "manjaro")) {
        d.package_manager = "pacman";
    } else if (d.id == "fedora" || contains_word(family, "fedora") || d.id == "rhel" ||
               contains_word(family, "rhel") || d.id == "centos" || contains_word(family, "centos")) {
        d.package_manager = "dnf";
    } else if (d.id == "opensuse" || d.id == "suse" || contains_word(family, "suse")) {
        d.package_manager = "zypper";
    } else if (d.id == "alpine" || contains_word(family, "alpine")) {
        d.package_manager = "apk";
    }

    return d;
}

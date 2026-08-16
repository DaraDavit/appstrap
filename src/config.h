#pragma once

#include <map>
#include <string>
#include <utility>
#include <vector>

#include "distro.h"

struct App {
    std::string name;
    std::string bin;      // executable used to check install status (defaults to name)
    std::string category; // grouping label for list/select
    std::string flatpak;  // Flathub app ID; non-empty => install via flatpak
    std::map<std::string, std::vector<std::string>> packages;  // family -> package names
    std::map<std::string, std::vector<std::string>> setup;     // family -> pre-install shell cmds
    std::vector<std::string> post;                             // post-install shell cmds
};

struct Config {
    std::vector<std::string> categories;  // display order (empty => derived)
    std::vector<App> apps;

    const App* find(const std::string& name) const;

    // Apps grouped by category, ordered by `categories` (then first appearance).
    std::vector<std::pair<std::string, std::vector<const App*>>> grouped_apps() const;
};

// Parses packages.json (nlohmann/json).
Config load_config(const std::string& path);

// Resolves the family map for the running distro: matches distro.id first,
// then each token of id_like, then "default". Returns the family key that
// matched, or "" if none.
std::string resolve_family(const Distro& d,
                           const std::map<std::string, std::vector<std::string>>& m);

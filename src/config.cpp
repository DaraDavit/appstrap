#include "config.h"

#include <nlohmann/json.hpp>

#include <fstream>
#include <sstream>

using nlohmann::json;

namespace {

std::vector<std::string> to_string_list(const json& j) {
    std::vector<std::string> out;
    if (j.is_array()) {
        for (const auto& e : j) {
            if (e.is_string()) out.push_back(e.get<std::string>());
        }
    }
    return out;
}

std::map<std::string, std::vector<std::string>> to_string_map(const json& j) {
    std::map<std::string, std::vector<std::string>> out;
    if (j.is_object()) {
        for (auto it = j.begin(); it != j.end(); ++it) {
            out[it.key()] = to_string_list(it.value());
        }
    }
    return out;
}

}  // namespace

const App* Config::find(const std::string& name) const {
    for (const auto& a : apps) {
        if (a.name == name) return &a;
    }
    return nullptr;
}

std::vector<std::pair<std::string, std::vector<const App*>>> Config::grouped_apps() const {
    // Category display order: explicit list first, then first-appearance order,
    // then any remaining (including the empty-string group) appended last.
    std::vector<std::string> order = categories;
    for (const auto& a : apps) {
        bool seen = false;
        for (const auto& c : order) {
            if (c == a.category) {
                seen = true;
                break;
            }
        }
        if (!seen) order.push_back(a.category);
    }

    std::vector<std::pair<std::string, std::vector<const App*>>> groups;
    for (const auto& cat : order) {
        std::vector<const App*> members;
        for (const auto& a : apps) {
            if (a.category == cat) members.push_back(&a);
        }
        if (!members.empty()) groups.emplace_back(cat, members);
    }
    return groups;
}

Config load_config(const std::string& path) {
    Config cfg;

    std::ifstream f(path);
    if (!f.is_open()) {
        return cfg;
    }

    json root;
    try {
        f >> root;
    } catch (const std::exception&) {
        return cfg;
    }

    if (!root.contains("apps") || !root["apps"].is_array()) {
        return cfg;
    }

    cfg.categories = to_string_list(root.value("categories", json::array()));

    for (const auto& japp : root["apps"]) {
        App app;
        app.name = japp.value("name", "");
        app.bin = japp.value("bin", app.name);
        app.category = japp.value("category", "");
        app.flatpak = japp.value("flatpak", "");
        app.packages = to_string_map(japp.value("packages", json::object()));
        app.setup = to_string_map(japp.value("setup", json::object()));
        app.post = to_string_list(japp.value("post", json::array()));
        if (!app.name.empty()) {
            cfg.apps.push_back(std::move(app));
        }
    }

    return cfg;
}

std::string resolve_family(const Distro& d,
                           const std::map<std::string, std::vector<std::string>>& m) {
    if (m.empty()) return "";

    if (m.count(d.id)) return d.id;

    std::istringstream iss(d.id_like);
    std::string token;
    while (iss >> token) {
        if (m.count(token)) return token;
    }

    if (m.count("default")) return "default";

    return "";
}

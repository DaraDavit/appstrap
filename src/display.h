#pragma once

#include <string>
#include <vector>

#include "config.h"
#include "distro.h"
#include "installer.h"

enum class ColorMode { Auto, Always, Never };
void set_color_mode(ColorMode mode);

// Top-level, unindented output.
void print_usage(const std::string& prog);
void print_detect(const Distro& d);
void print_list(const Config& cfg, const Installer& inst, bool all);
void print_manifest(const std::string& path, const Distro& d);
void print_status(const std::string& text);  // stdout + newline
void print_stderr(const std::string& text);  // stderr + newline
void print_raw(const std::string& text);     // stdout, no newline

// Indented per-step output.
void print_section(const std::string& title);              // "== title =="
void print_line(const std::string& text);                  // "  text"
void print_dry_run(const std::string& cmd, bool use_sudo = false);
void print_warning(const std::string& text);               // "  warning: text"
void print_error(const std::string& text);                 // "  error: text"

// Install result + summary.
void print_result(const std::string& name, InstallStatus status);
void print_summary(int total, int installed, int already, int failed);

// Interactive checkbox picker over `rows`; returns indices of toggled-on rows.
std::vector<int> checkbox_select(const std::vector<std::string>& rows,
                                 const std::vector<bool>& selectable);

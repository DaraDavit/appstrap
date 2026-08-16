#pragma once

#include <string>

struct CmdResult {
    int exit_code = -1;
    std::string output;  // combined stdout + stderr
    bool ok() const { return exit_code == 0; }
};

// Runs a shell command, streaming combined stdout+stderr into the result.
// If use_sudo is true and the process is not already root, "sudo " is prepended.
CmdResult run(const std::string& cmd, bool use_sudo = false);

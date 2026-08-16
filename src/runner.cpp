#include "runner.h"

#include <sys/wait.h>

#include <cstdio>
#include <string>

#include "distro.h"

namespace {

// Escapes a string for safe embedding inside single quotes in sh.
std::string shell_quote(const std::string& s) {
    std::string out = "'";
    for (char c : s) {
        if (c == '\'') {
            out += "'\\''";
        } else {
            out += c;
        }
    }
    out += "'";
    return out;
}

}  // namespace

CmdResult run(const std::string& cmd, bool use_sudo) {
    CmdResult res;

    // Wrap sudo'd commands in `sh -c` so redirections/pipes run as root,
    // not just the first word of the command.
    std::string full;
    if (use_sudo && !running_as_root()) {
        full = "sudo sh -c " + shell_quote(cmd);
    } else {
        full = cmd;
    }
    full += " 2>&1";

    FILE* pipe = popen(full.c_str(), "r");
    if (!pipe) {
        return res;
    }

    char buf[4096];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), pipe)) > 0) {
        res.output.append(buf, n);
    }

    int status = pclose(pipe);
    if (WIFEXITED(status)) {
        res.exit_code = WEXITSTATUS(status);
    }

    return res;
}

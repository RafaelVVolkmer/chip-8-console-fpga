// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

#include "Vtb_chip8_top.h"
#include "verilated.h"

#include <cstdlib>
#include <iostream>
#include <memory>

namespace {
constexpr vluint64_t kDefaultMaxTime = 1000000;

vluint64_t max_time_from_env()
{
    const char *value = std::getenv("VERILATOR_MAX_TIME");
    if (value == nullptr || value[0] == '\0') {
        return kDefaultMaxTime;
    }

    char *end = nullptr;
    const auto parsed = std::strtoull(value, &end, 10);
    if (end == value || *end != '\0' || parsed == 0) {
        std::cerr << "invalid VERILATOR_MAX_TIME=" << value << '\n';
        return kDefaultMaxTime;
    }
    return parsed;
}
} // namespace

int main(int argc, char **argv)
{
    auto context = std::make_unique<VerilatedContext>();
    context->commandArgs(argc, argv);

    auto tb = std::make_unique<Vtb_chip8_top>(context.get());
    const vluint64_t max_time = max_time_from_env();

    while (!context->gotFinish() && context->time() < max_time) {
        tb->eval();
        context->timeInc(1);
    }

    tb->final();

    if (!context->gotFinish()) {
        std::cerr << "simulation timed out at time " << context->time()
                  << '\n';
        return 1;
    }

    return 0;
}

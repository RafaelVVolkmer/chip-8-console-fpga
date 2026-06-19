# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

"""Shared cocotb helpers and import guards."""

from __future__ import annotations


try:
    import cocotb
    from cocotb.triggers import RisingEdge, Timer
except ImportError:  # pragma: no cover - exercised only without cocotb.
    cocotb = None
    RisingEdge = None
    Timer = None


def require_cocotb() -> None:
    """Skip a test when imported outside a cocotb runner."""

    if cocotb is None:
        raise RuntimeError("cocotb is required for this test")


def cocotb_test(func):
    """Decorate a test only when cocotb is importable."""

    if cocotb is None:
        return func
    return cocotb.test()(func)


async def reset_dut(dut, clk_name: str = "clk_i", rst_name: str = "rst_ni") -> None:
    """Apply a short active-low reset sequence."""

    require_cocotb()
    clk = getattr(dut, clk_name)
    rst = getattr(dut, rst_name)
    rst.value = 0
    for _ in range(4):
        await RisingEdge(clk)
    rst.value = 1
    for _ in range(2):
        await RisingEdge(clk)

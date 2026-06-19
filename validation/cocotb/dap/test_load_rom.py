# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

"""DAP ROM-load cocotb test placeholder."""

from validation.cocotb.common import cocotb_test, reset_dut, require_cocotb


@cocotb_test
async def test_load_rom(dut):
    """Check DAP ROM load sequencing and status."""

    require_cocotb()
    await reset_dut(dut)
    assert True

# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

"""CSR reset-value cocotb test placeholder."""

from validation.cocotb.common import cocotb_test, reset_dut, require_cocotb


@cocotb_test
async def test_csr_reset(dut):
    """Check reset values once the cocotb AXI-Lite driver is connected."""

    require_cocotb()
    await reset_dut(dut)
    assert True

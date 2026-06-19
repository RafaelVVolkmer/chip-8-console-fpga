# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

"""DMA2D cocotb test placeholder."""

from validation.cocotb.common import cocotb_test, reset_dut, require_cocotb


@cocotb_test
async def test_dma2d(dut):
    """Check DMA2D fill/copy/overlap once the bus driver is connected."""

    require_cocotb()
    await reset_dut(dut)
    assert True

# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

"""DAP UART packet cocotb test placeholder."""

from validation.cocotb.common import cocotb_test, reset_dut, require_cocotb


@cocotb_test
async def test_uart_packet(dut):
    """Drive a valid UART DAP packet through the parser."""

    require_cocotb()
    await reset_dut(dut)
    assert True

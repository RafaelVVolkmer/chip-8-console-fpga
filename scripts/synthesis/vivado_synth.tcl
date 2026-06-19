# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

set top   [expr {[info exists ::env(RTL_TOP)] ? $::env(RTL_TOP) : "chip8_top"}]
set part  [expr {[info exists ::env(PART)] ? $::env(PART) : ""}]
set files [expr {[info exists ::env(FILES)] ? $::env(FILES) : "files.f"}]

if {$part eq ""} {
  error "PART is required, for example: make vivado-synth PART=xc7a35tcpg236-1"
}

file mkdir build
file mkdir "build/${top}"
file mkdir reports

set fh [open $files r]
set rtl_files [split [read $fh] "\n"]
close $fh
foreach rtl_file $rtl_files {
  if {$rtl_file ne ""} {
    read_verilog -sv $rtl_file
  }
}

set xdc_file "constraints/xilinx/${top}.xdc"
if {[file exists $xdc_file]} {
  read_xdc $xdc_file
}

synth_design -top $top -part $part
opt_design
place_design
route_design
report_utilization -file "reports/${top}_vivado_utilization.rpt"
report_timing_summary -file "reports/${top}_vivado_timing_summary.rpt"
write_bitstream -force "build/${top}/${top}.bit"

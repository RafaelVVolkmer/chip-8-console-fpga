# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

set top    [expr {[info exists ::env(RTL_TOP)] ? $::env(RTL_TOP) : "chip8_top"}]
set part   [expr {[info exists ::env(PART)] ? $::env(PART) : ""}]
set family [expr {[info exists ::env(FAMILY)] ? $::env(FAMILY) : "Cyclone V"}]
set files  [expr {[info exists ::env(FILES)] ? $::env(FILES) : "files.f"}]

if {$part eq ""} {
  error "PART is required, for example: make quartus-synth PART=5CSEBA6U23I7"
}

set project "build/${top}_quartus"
file mkdir build reports

project_new $project -overwrite
set_global_assignment -name FAMILY $family
set_global_assignment -name DEVICE $part
set_global_assignment -name TOP_LEVEL_ENTITY $top
set fh [open $files r]
set rtl_files [split [read $fh] "\n"]
close $fh
foreach rtl_file $rtl_files {
  if {$rtl_file ne ""} {
    set_global_assignment -name SYSTEMVERILOG_FILE $rtl_file
  }
}

set qsf_file "constraints/intel/${top}.qsf"
if {[file exists $qsf_file]} {
  source $qsf_file
}

set sdc_file "constraints/intel/${top}.sdc"
if {[file exists $sdc_file]} {
  set_global_assignment -name SDC_FILE $sdc_file
}

execute_module -tool map
execute_module -tool fit
execute_module -tool asm
execute_module -tool sta
project_close

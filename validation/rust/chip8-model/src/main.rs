// SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
// SPDX-License-Identifier: GPL-3.0-only

use std::env;
use std::process::ExitCode;

use chip8_model::validation::run_validation_suite;

/// Parse the optional fuzz-iteration count from the command line.
fn parse_iterations() -> Result<u32, String> {
    let mut args = env::args().skip(1);
    let Some(iterations) = args.next() else {
        return Ok(1024);
    };
    if let Some(extra) = args.next() {
        return Err(format!(
            "unexpected extra argument `{extra}`; pass at most one iteration count"
        ));
    }
    iterations
        .parse::<u32>()
        .map_err(|err| format!("invalid iteration count `{iterations}`: {err}"))
}

/// Run the validation engine and report a non-zero exit code on failures.
fn main() -> ExitCode {
    let iterations = match parse_iterations() {
        Ok(iterations) => iterations,
        Err(message) => {
            eprintln!("chip8 validation: {message}");
            return ExitCode::from(2);
        }
    };
    let report = run_validation_suite(iterations);
    println!(
        "chip8 validation: cases={} failures={} checksum={:016x}",
        report.cases, report.failures, report.checksum
    );
    if report.failures != 0 {
        return ExitCode::from(1);
    }
    ExitCode::SUCCESS
}

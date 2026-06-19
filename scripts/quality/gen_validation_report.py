#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Rafael V. Volkmer <rafael.v.volkmer@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

"""Generate validation traceability reports from local testplan YAML files."""

from __future__ import annotations

import argparse
import html
import json
from dataclasses import dataclass, field
from pathlib import Path


REQUIRED_KEYS = {
    "id",
    "feature",
    "test",
    "ci_job",
    "artifact",
    "status",
    "level",
}


@dataclass
class TestPoint:
    """One validation testpoint from a testplan."""

    suite: str
    fields: dict[str, str] = field(default_factory=dict)
    coverage: list[str] = field(default_factory=list)


def scalar(value: str) -> str:
    """Return a simple YAML scalar without surrounding whitespace or quotes."""

    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def parse_testplan(path: Path) -> tuple[str, list[TestPoint]]:
    """Parse the constrained testplan YAML subset used by this repository."""

    suite = path.stem.replace(".testplan", "")
    testpoints: list[TestPoint] = []
    current: TestPoint | None = None
    in_testpoints = False
    in_coverage = False

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        stripped = raw_line.strip()
        if stripped.startswith("suite:"):
            suite = scalar(stripped.split(":", 1)[1])
            continue
        if stripped == "testpoints:":
            in_testpoints = True
            continue
        if not in_testpoints:
            continue
        if stripped.startswith("- id:"):
            current = TestPoint(suite=suite)
            current.fields["id"] = scalar(stripped.split(":", 1)[1])
            testpoints.append(current)
            in_coverage = False
            continue
        if current is None:
            continue
        if stripped == "coverage:":
            in_coverage = True
            continue
        if in_coverage and stripped.startswith("- "):
            current.coverage.append(scalar(stripped[2:]))
            continue
        if ":" in stripped:
            key, value = stripped.split(":", 1)
            current.fields[key] = scalar(value)
            in_coverage = False

    return suite, testpoints


def load_testpoints(testplan_dir: Path) -> list[TestPoint]:
    """Load all testpoints from the validation testplan directory."""

    testpoints: list[TestPoint] = []
    for path in sorted(testplan_dir.glob("*.testplan.yml")):
        _, entries = parse_testplan(path)
        testpoints.extend(entries)
    return testpoints


def validate(testpoints: list[TestPoint]) -> list[str]:
    """Return validation errors for malformed or duplicate testpoints."""

    errors: list[str] = []
    seen: set[str] = set()
    for testpoint in testpoints:
        missing = sorted(REQUIRED_KEYS - testpoint.fields.keys())
        if missing:
            errors.append(
                f"{testpoint.suite}: missing {','.join(missing)} in "
                f"{testpoint.fields.get('id', '<unknown>')}"
            )
        identifier = testpoint.fields.get("id", "")
        if identifier in seen:
            errors.append(f"duplicate testpoint id: {identifier}")
        seen.add(identifier)
        if not testpoint.coverage:
            errors.append(f"{identifier}: coverage list is empty")
    return errors


def summarize(testpoints: list[TestPoint]) -> dict[str, object]:
    """Build aggregate status data for JSON consumers."""

    by_status: dict[str, int] = {}
    by_level: dict[str, int] = {}
    by_suite: dict[str, dict[str, int]] = {}
    for item in testpoints:
        status = item.fields["status"]
        level = item.fields["level"]
        by_status[status] = by_status.get(status, 0) + 1
        by_level[level] = by_level.get(level, 0) + 1
        suite_summary = by_suite.setdefault(item.suite, {})
        suite_summary[status] = suite_summary.get(status, 0) + 1
    return {
        "total": len(testpoints),
        "by_status": by_status,
        "by_level": by_level,
        "by_suite": by_suite,
        "testpoints": [
            {
                "suite": item.suite,
                **item.fields,
                "coverage": item.coverage,
            }
            for item in testpoints
        ],
    }


def write_markdown(report: dict[str, object], output: Path) -> None:
    """Write a Markdown report table."""

    rows = [
        "# CHIP-8 Validation Status",
        "",
        f"Total testpoints: {report['total']}",
        "",
        "| Suite | ID | Feature | Test | Coverage | Status | Level | CI job | Artifact |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for item in report["testpoints"]:
        coverage = ", ".join(item["coverage"])
        rows.append(
            "| {suite} | {id} | {feature} | {test} | {coverage} | "
            "{status} | {level} | {ci_job} | {artifact} |".format(
                suite=item["suite"],
                id=item["id"],
                feature=item["feature"],
                test=item["test"],
                coverage=coverage,
                status=item["status"],
                level=item["level"],
                ci_job=item["ci_job"],
                artifact=item["artifact"],
            )
        )
    output.write_text("\n".join(rows) + "\n", encoding="utf-8")


def write_html(report: dict[str, object], output: Path) -> None:
    """Write a small standalone HTML report."""

    rows = []
    for item in report["testpoints"]:
        cells = [
            item["suite"],
            item["id"],
            item["feature"],
            item["test"],
            ", ".join(item["coverage"]),
            item["status"],
            item["level"],
            item["ci_job"],
            item["artifact"],
        ]
        rows.append(
            "<tr>"
            + "".join(f"<td>{html.escape(str(cell))}</td>" for cell in cells)
            + "</tr>"
        )
    output.write_text(
        "\n".join(
            [
                "<!doctype html>",
                "<html lang=\"en\">",
                "<head>",
                "<meta charset=\"utf-8\">",
                "<title>CHIP-8 Validation Status</title>",
                "<style>",
                "body{font-family:sans-serif;margin:2rem;}",
                "table{border-collapse:collapse;width:100%;}",
                "th,td{border:1px solid #ccc;padding:.35rem;text-align:left;}",
                "th{background:#eee;}",
                "</style>",
                "</head>",
                "<body>",
                "<h1>CHIP-8 Validation Status</h1>",
                f"<p>Total testpoints: {report['total']}</p>",
                "<table>",
                "<thead><tr><th>Suite</th><th>ID</th><th>Feature</th>"
                "<th>Test</th><th>Coverage</th><th>Status</th><th>Level</th>"
                "<th>CI job</th><th>Artifact</th></tr></thead>",
                "<tbody>",
                *rows,
                "</tbody></table>",
                "</body></html>",
            ]
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> int:
    """CLI entry point."""

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--testplan-dir",
        default="validation/testplans",
        type=Path,
        help="Directory containing *.testplan.yml files",
    )
    parser.add_argument(
        "--out-dir",
        default="reports/validation",
        type=Path,
        help="Output report directory",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate testplans without generating report files",
    )
    args = parser.parse_args()

    testpoints = load_testpoints(args.testplan_dir)
    errors = validate(testpoints)
    if errors:
        for error in errors:
            print(error)
        return 1
    if args.check:
        print(f"validated {len(testpoints)} testpoints")
        return 0

    report = summarize(testpoints)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "status.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    write_markdown(report, args.out_dir / "summary.md")
    write_html(report, args.out_dir / "index.html")
    print(f"validation report written to {args.out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

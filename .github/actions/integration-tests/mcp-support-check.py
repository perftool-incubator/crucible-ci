#!/usr/bin/env python3
# -*- mode: python; indent-tabs-mode: nil; python-indent-level: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=python

"""Check whether a Crucible checkout has the MCP features used by CI."""

import argparse
import ast
import json
from pathlib import Path


REQUIRED_TOOLS = {
    "crucible_info",
    "validate_run",
    "estimate_run",
    "prepare_run",
    "start_run",
    "get_run_status",
    "get_run_logs",
    "get_run_summary",
    "list_indexed_results",
}

REQUIRED_TOOL_PROPERTIES = {
    "prepare_run": {"persist"},
    "start_run": {"idempotency_key", "plan_handle", "path"},
    "get_run_status": {"mcp_job_id"},
    "list_indexed_results": {"run", "limit"},
}


def literal_string(value):
    if isinstance(value, ast.Constant) and isinstance(value.value, str):
        return value.value
    return None


def tool_schemas(source):
    module = ast.parse(source, filename="server.py")
    for node in module.body:
        if not isinstance(node, ast.Assign):
            continue
        targets = [target.id for target in node.targets if isinstance(target, ast.Name)]
        if "TOOL_DEFINITIONS" not in targets or not isinstance(node.value, (ast.List, ast.Tuple)):
            continue

        schemas = {}
        for tool in node.value.elts:
            if not isinstance(tool, ast.Dict):
                continue
            name = None
            schema = None
            for key, value in zip(tool.keys, tool.values):
                key_name = literal_string(key)
                if key_name == "name":
                    name = literal_string(value)
                elif key_name == "inputSchema":
                    schema = value
            if name is not None and schema is not None:
                schemas[name] = schema
        return schemas
    return {}


def schema_properties(schema):
    properties = set()
    if not isinstance(schema, ast.Dict):
        return properties
    for key, value in zip(schema.keys, schema.values):
        if literal_string(key) != "properties" or not isinstance(value, ast.Dict):
            continue
        for property_key in value.keys:
            property_name = literal_string(property_key)
            if property_name is not None:
                properties.add(property_name)
    return properties


def supported(crucible_home):
    server_path = crucible_home / "mcp" / "crucible_mcp" / "server.py"
    services_path = crucible_home / "config" / "services.json"
    if not server_path.is_file() or not services_path.is_file():
        return False

    try:
        services = json.loads(services_path.read_text(encoding="utf-8"))
        if not isinstance(services.get("mcp-server"), dict):
            return False
        schemas = tool_schemas(server_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, SyntaxError, json.JSONDecodeError):
        return False

    if not REQUIRED_TOOLS.issubset(schemas):
        return False
    return all(
        required_properties.issubset(schema_properties(schemas[tool_name]))
        for tool_name, required_properties in REQUIRED_TOOL_PROPERTIES.items()
    )


def process_options():
    parser = argparse.ArgumentParser(description="Check Crucible MCP CI compatibility")
    parser.add_argument("--crucible-home", required=True, type=Path)
    return parser.parse_args()


def main():
    args = process_options()
    return 0 if supported(args.crucible_home.resolve()) else 1


if __name__ == "__main__":
    raise SystemExit(main())

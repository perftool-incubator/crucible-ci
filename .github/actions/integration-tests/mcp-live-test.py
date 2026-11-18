#!/usr/bin/env python3
# -*- mode: python; indent-tabs-mode: nil; python-indent-level: 4 -*-
# vim: autoindent tabstop=4 shiftwidth=4 expandtab softtabstop=4 filetype=python

"""Exercise a deployed Crucible MCP server with a real run."""

import argparse
import hashlib
import http.client
import json
import ssl
import tempfile
import time
from pathlib import Path
from urllib.parse import urlsplit


class McpLiveTest:
    def __init__(
        self,
        url,
        token_file,
        run_file,
        input_root,
        poll_timeout,
        poll_interval,
    ):
        parsed_url = urlsplit(url)
        if parsed_url.scheme not in {"http", "https"} or not parsed_url.hostname:
            raise ValueError(f"unsupported MCP URL: {url}")
        if parsed_url.port is None:
            raise ValueError("MCP URL must include an explicit port")

        self.scheme = parsed_url.scheme
        self.host = parsed_url.hostname
        self.port = parsed_url.port
        self.path = parsed_url.path or "/mcp"
        self.token = token_file.read_text(encoding="utf-8").strip()
        if not self.token:
            raise ValueError(f"token file is empty: {token_file}")
        if not run_file.is_file():
            raise ValueError(f"run file does not exist: {run_file}")

        self.run_file = run_file
        self.input_root = input_root.resolve()
        resolved_run_file = run_file.resolve()
        if resolved_run_file != self.input_root and self.input_root not in resolved_run_file.parents:
            raise ValueError(f"run file is outside the configured input root: {input_root}")
        self.poll_timeout = poll_timeout
        self.poll_interval = poll_interval
        self.request_id = 0

    def request(self, method, params=None, token=None, expected_status=200):
        self.request_id += 1
        body = json.dumps({
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": method,
            "params": params or {},
        })
        headers = {"Content-Type": "application/json"}
        if token is not None:
            headers["Authorization"] = f"Bearer {token}"

        if self.scheme == "https":
            connection = http.client.HTTPSConnection(
                self.host,
                self.port,
                context=ssl.create_default_context(),
            )
        else:
            connection = http.client.HTTPConnection(self.host, self.port)
        try:
            connection.request("POST", self.path, body=body, headers=headers)
            response = connection.getresponse()
            response_body = response.read()
            status = response.status
        finally:
            connection.close()

        if status != expected_status:
            raise RuntimeError(f"{method} returned HTTP {status}, expected {expected_status}")
        if not response_body:
            raise RuntimeError(f"{method} returned an empty response body")
        return json.loads(response_body)

    def rpc(self, method, params=None):
        payload = self.request(method, params, token=self.token)
        if "error" in payload:
            raise RuntimeError(f"{method} failed: {payload['error']['message']}")
        if "result" not in payload:
            raise RuntimeError(f"{method} returned neither a result nor an error")
        return payload["result"]

    def tool(self, name, arguments):
        result = self.rpc("tools/call", {"name": name, "arguments": arguments})
        structured = result.get("structuredContent")
        if not isinstance(structured, dict):
            raise RuntimeError(f"{name} did not return structured content")
        return structured

    def expect_tool_error(self, name, arguments, expected_code):
        payload = self.request(
            "tools/call",
            {"name": name, "arguments": arguments},
            token=self.token,
        )
        error = payload.get("error")
        if not isinstance(error, dict):
            raise RuntimeError(f"{name} unexpectedly succeeded")
        if expected_code not in error.get("message", ""):
            raise RuntimeError(
                f"{name} returned {error.get('message')}, expected {expected_code}"
            )

    def check_authentication(self):
        invalid_token = "invalid-token"
        if invalid_token == self.token:
            invalid_token = "invalid-token-not-the-bearer"
        for token in (None, invalid_token):
            payload = self.request(
                "initialize",
                token=token,
                expected_status=401,
            )
            if payload.get("error") != "unauthorized":
                raise RuntimeError("unauthenticated request did not return the expected error")

    def check_discovery(self):
        initialized = self.rpc("initialize")
        server_info = initialized.get("serverInfo", {})
        if server_info.get("name") != "crucible-mcp":
            raise RuntimeError("initialize returned an unexpected server name")

        tools = self.rpc("tools/list").get("tools")
        if not isinstance(tools, list):
            raise RuntimeError("tools/list did not return a list")
        tool_names = {tool.get("name") for tool in tools}
        required_tools = {
            "crucible_info",
            "validate_run",
            "prepare_run",
            "estimate_run",
            "start_run",
            "get_run_status",
            "get_run_logs",
            "get_run_summary",
            "list_indexed_results",
        }
        if not required_tools.issubset(tool_names):
            raise RuntimeError(f"tools/list is missing: {sorted(required_tools - tool_names)}")

        resources = self.rpc("resources/list").get("resources")
        if not isinstance(resources, list):
            raise RuntimeError("resources/list did not return a list")

        info = self.tool("crucible_info", {})
        if info.get("name") != "crucible" or not info.get("execution_supported"):
            raise RuntimeError("crucible_info returned incomplete capabilities")

    def check_planning(self):
        validation = self.tool("validate_run", {"path": str(self.run_file)})
        if validation.get("valid") is not True:
            raise RuntimeError(f"run file validation failed: {validation.get('errors')}")

        estimate = self.tool("estimate_run", {"path": str(self.run_file)})
        if estimate.get("validation", {}).get("valid") is not True:
            raise RuntimeError("run file estimate did not validate")

        prepared = self.tool(
            "prepare_run",
            {"path": str(self.run_file), "persist": True},
        )
        if prepared.get("validation", {}).get("valid") is not True:
            raise RuntimeError("run file plan did not validate")
        plan_handle = prepared.get("plan_handle")
        if not isinstance(plan_handle, str) or not plan_handle:
            raise RuntimeError("persisted prepare_run did not return a plan handle")
        return plan_handle

    def check_input_root(self):
        outside_directory = None
        for candidate in (Path(tempfile.gettempdir()), Path("/var/tmp")):
            resolved_candidate = candidate.resolve()
            if resolved_candidate != self.input_root and self.input_root not in resolved_candidate.parents:
                outside_directory = candidate
                break
        if outside_directory is None:
            raise RuntimeError("could not select a temporary directory outside the MCP input root")

        with tempfile.NamedTemporaryFile(
            prefix="crucible-mcp-outside-",
            dir=outside_directory,
        ) as temporary:
            temporary.write(self.run_file.read_bytes())
            temporary.flush()
            self.expect_tool_error(
                "validate_run",
                {"path": temporary.name},
                "input_path_rejected",
            )

    def start_run(self, plan_handle):
        run_digest = hashlib.sha256(self.run_file.read_bytes()).hexdigest()
        idempotency_key = f"mcp-live-{run_digest}-{time.time_ns()}"
        submitted = self.tool(
            "start_run",
            {
                "path": str(self.run_file),
                "plan_handle": plan_handle,
                "idempotency_key": idempotency_key,
            },
        )
        if submitted.get("created") is not True:
            raise RuntimeError("first start_run submission did not create a job")
        return idempotency_key, submitted.get("job", {})

    def poll_run(self, job_id):
        deadline = time.monotonic() + self.poll_timeout
        last_state = None
        last_progress = time.monotonic()
        while True:
            status = self.tool("get_run_status", {"mcp_job_id": job_id})
            state = status.get("state")
            now = time.monotonic()
            if state != last_state or now - last_progress >= 30:
                print(f"MCP job {job_id} state: {state}")
                last_state = state
                last_progress = now

            if state == "completed":
                return status
            if state in {"failed", "recovery_required", "unknown_after_crash"}:
                raise RuntimeError(
                    f"MCP job {job_id} entered terminal state {state}: "
                    f"{status.get('error_message')}"
                )
            if now >= deadline:
                raise TimeoutError(f"MCP job {job_id} did not complete in {self.poll_timeout} seconds")
            time.sleep(self.poll_interval)

    def check_idempotency(self, plan_handle, idempotency_key, job_id):
        resubmitted = self.tool(
            "start_run",
            {
                "path": str(self.run_file),
                "plan_handle": plan_handle,
                "idempotency_key": idempotency_key,
            },
        )
        if resubmitted.get("created") is not False:
            raise RuntimeError("duplicate start_run submission unexpectedly created a job")
        if resubmitted.get("job", {}).get("mcp_job_id") != job_id:
            raise RuntimeError("duplicate start_run submission returned a different job")

    def check_logs(self, job_id):
        offset = 0
        while True:
            logs = self.tool(
                "get_run_logs",
                {"mcp_job_id": job_id, "offset": offset, "limit": 65536},
            )
            if self.token in logs.get("text", "") or self.token in json.dumps(logs):
                raise RuntimeError("bearer token appeared in run logs")
            offset = int(logs.get("next_offset", offset))
            if logs.get("complete") is True:
                return
            if offset <= 0:
                raise RuntimeError("get_run_logs made no forward progress")

    def check_results(self, job_id):
        summary = self.tool("get_run_summary", {"mcp_job_id": job_id})
        if summary.get("result_status") != "available":
            raise RuntimeError("completed MCP job summary is unavailable")
        if not isinstance(summary.get("summary"), dict):
            raise RuntimeError("completed MCP job summary is not an object")

    def check_indexed_result(self, status):
        run_id = status.get("cdm_run_id")
        if not isinstance(run_id, str) or not run_id:
            raise RuntimeError("completed MCP job has no CDM run ID")
        deadline = time.monotonic() + 60
        while True:
            indexed = self.tool(
                "list_indexed_results",
                {"run": run_id, "limit": 1},
            )
            if run_id in indexed.get("run_ids", []):
                return
            if time.monotonic() >= deadline:
                raise RuntimeError("completed MCP run was not returned by list_indexed_results")
            print(f"Waiting for indexed result {run_id} to become visible")
            time.sleep(5)

    def run(self):
        self.check_authentication()
        self.check_discovery()
        plan_handle = self.check_planning()
        self.check_input_root()
        idempotency_key, initial_job = self.start_run(plan_handle)
        job_id = initial_job.get("mcp_job_id")
        if not isinstance(job_id, str) or not job_id:
            raise RuntimeError("start_run did not return an MCP job ID")

        status = self.poll_run(job_id)
        self.check_idempotency(plan_handle, idempotency_key, job_id)
        self.check_logs(job_id)
        self.check_indexed_result(status)
        self.check_results(job_id)
        print(f"MCP live test completed job {job_id}")


def process_options():
    parser = argparse.ArgumentParser(description="Test a live Crucible MCP server")
    parser.add_argument("--url", required=True)
    parser.add_argument("--token-file", required=True, type=Path)
    parser.add_argument("--run-file", required=True, type=Path)
    parser.add_argument("--input-root", required=True, type=Path)
    parser.add_argument("--poll-timeout", type=float, default=3600)
    parser.add_argument("--poll-interval", type=float, default=5)
    return parser.parse_args()


def main():
    args = process_options()
    if args.poll_timeout <= 0 or args.poll_interval <= 0:
        raise ValueError("poll timeout and interval must be positive")

    test = McpLiveTest(
        args.url,
        args.token_file,
        args.run_file,
        args.input_root,
        args.poll_timeout,
        args.poll_interval,
    )
    test.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Ask a live question to Ollama running on one of the doaivm droplets.

Demo tool: opens a temporary SSH tunnel to the droplet (Ollama is
private-only there, bound to 127.0.0.1), sends a prompt to /api/generate,
prints the answer, and closes the tunnel. Standard library only - nothing
to install. Relies on the `ssh` and `terraform` binaries already required
elsewhere in this project.

Usage:
    ./ask_ollama.py --module cpu-qwen3-30b "What is the capital of France?"
    ./ask_ollama.py --host 143.198.111.188 --model qwen3-coder:30b "..."
"""
import argparse
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

# Module name -> the Ollama model tag that module's cloud-init pulls by default.
MODULES = {
    "gpu-qwen3-30b": "qwen3-coder:30b",
    "cpu-qwen3-30b": "qwen3-coder:30b",
    "gpu-rtx4000": "qwen2.5-coder:14b",
    "gpu-rtx4000-llama3": "llama3.1:8b",
}

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))


def get_droplet_ip(module):
    module_dir = os.path.join(REPO_ROOT, module)
    if not os.path.isdir(module_dir):
        sys.exit(f"No such module: {module} (expected one of: {', '.join(sorted(MODULES))})")
    try:
        result = subprocess.run(
            ["terraform", f"-chdir={module_dir}", "output", "-raw", "droplet_public_ip"],
            capture_output=True,
            text=True,
            check=True,
        )
    except FileNotFoundError:
        sys.exit("`terraform` not found on PATH.")
    except subprocess.CalledProcessError as e:
        sys.exit(
            f"Could not read droplet_public_ip for {module} - has it been applied?\n{e.stderr.strip()}"
        )
    ip = result.stdout.strip()
    if not ip:
        sys.exit(f"No droplet_public_ip output for {module} - has it been applied?")
    return ip


def free_local_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def open_tunnel(host, local_port, remote_port=11434):
    proc = subprocess.Popen(
        [
            "ssh",
            "-N",
            "-L",
            f"{local_port}:localhost:{remote_port}",
            "-o",
            "StrictHostKeyChecking=accept-new",
            "-o",
            "ExitOnForwardFailure=yes",
            "-o",
            "ConnectTimeout=10",
            f"root@{host}",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    deadline = time.time() + 20
    while time.time() < deadline:
        if proc.poll() is not None:
            err = proc.stderr.read() if proc.stderr else ""
            sys.exit(f"SSH tunnel failed to start:\n{err.strip()}")
        try:
            with socket.create_connection(("127.0.0.1", local_port), timeout=1):
                return proc
        except OSError:
            time.sleep(0.5)
    proc.terminate()
    sys.exit("Timed out waiting for the SSH tunnel to come up.")


def ask_ollama(local_port, model, prompt, timeout):
    url = f"http://127.0.0.1:{local_port}/api/generate"
    payload = json.dumps({"model": model, "prompt": prompt, "stream": False}).encode()
    req = urllib.request.Request(
        url, data=payload, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())


def main():
    parser = argparse.ArgumentParser(
        description="Ask a question to Ollama running on a doaivm droplet."
    )
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument(
        "--module", choices=sorted(MODULES), help="Which doaivm module's droplet to use."
    )
    target.add_argument("--host", help="Droplet IP/hostname directly, if you already know it.")
    parser.add_argument(
        "--model", help="Ollama model tag (defaults to the module's model; required with --host)."
    )
    parser.add_argument(
        "--timeout", type=int, default=180, help="Seconds to wait for a response (default 180)."
    )
    parser.add_argument("prompt", nargs="+", help="The question to ask.")
    args = parser.parse_args()

    if args.module:
        host = get_droplet_ip(args.module)
        model = args.model or MODULES[args.module]
    else:
        host = args.host
        if not args.model:
            sys.exit("--model is required when using --host")
        model = args.model

    prompt = " ".join(args.prompt)
    local_port = free_local_port()

    print(f"Connecting to {host} (tunneling 127.0.0.1:{local_port} -> droplet:11434)...")
    tunnel = open_tunnel(host, local_port)
    try:
        print(f"Asking {model}: {prompt}\n")
        t0 = time.time()
        result = ask_ollama(local_port, model, prompt, args.timeout)
        elapsed = time.time() - t0
        print(result.get("response", "").strip())
        print(f"\n({elapsed:.1f}s, {result.get('eval_count', '?')} tokens generated)")
    except urllib.error.URLError as e:
        sys.exit(f"Request to Ollama failed: {e}")
    finally:
        tunnel.terminate()
        try:
            tunnel.wait(timeout=5)
        except subprocess.TimeoutExpired:
            tunnel.kill()


if __name__ == "__main__":
    main()

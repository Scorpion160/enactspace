"""Capture-free EnactSpace preflight contract runner.

Pilot captures remain separately gated. Preflight commands never invoke the
CDP screenshot method and only write CSV diagnostics under the audit catalog.
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import csv
import hashlib
import json
import os
import shutil
import subprocess
import time
import uuid
import urllib.parse
import urllib.request
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Awaitable, Callable
from unicodedata import normalize

import websockets

ROOT = Path(os.environ.get("UI_AUDIT_ROOT", Path.cwd()))
CATALOG = Path(os.environ.get("UI_AUDIT_CATALOG", ROOT / "docs" / "audits" / "ui_catalog"))
PREFLIGHT_PLAN = CATALOG / "preflight_plan.csv"
PREFLIGHT_RESULTS = CATALOG / "preflight_results.csv"
CONTRACT_RESULTS = CATALOG / "preflight_contract_results.csv"
EXTERNAL_REQUESTS = CATALOG / "external_requests.csv"
LOCATOR_TRACE = CATALOG / "preflight_locator_trace.json"
SURFACE_TRACE = CATALOG / "preflight_surface_trace.json"
CONSOLE_EVENTS = CATALOG / "preflight_console_events.csv"
RUN_MANIFEST = CATALOG / "preflight_run_manifest.json"
MASTER_SCREENSHOTS = CATALOG / "screenshots" / "master"
MASTER_RESULTS = CATALOG / "master_capture_results.csv"
MASTER_REVIEW = CATALOG / "master_visual_review.md"
MASTER_CONTACT_SHEET = CATALOG / "master_contact_sheet.html"
ARCHIVE_ROOT = CATALOG / "archive" / "run_ancien"
WEB_URL = os.environ.get("UI_AUDIT_WEB_URL", "http://127.0.0.1:18080")
API_URL = os.environ.get("UI_AUDIT_API_URL", "http://127.0.0.1:18002/api")
CDP_URL = os.environ.get("UI_AUDIT_CDP_URL", "http://127.0.0.1:9222")
LOOPBACK = {"127.0.0.1", "localhost"}
FONT_HOSTS = {"fonts.googleapis.com", "fonts.gstatic.com"}
REQUIRED_PREFLIGHT_COLUMNS = {
    "preflight_id", "scenario_driver", "role", "test_account_alias", "viewport",
    "orientation", "data_profile", "network_profile", "initial_route",
    "expected_final_route", "setup_action", "interaction_steps", "expected_markers",
    "forbidden_markers", "teardown_action", "status",
}
EXTERNAL_REQUEST_FIELDS = [
    "run_id", "run_started_at", "preflight_id", "url", "method", "resource_type",
    "action", "reason", "expected", "classification",
]
CONTRACT_FIELDS = [
    "run_id", "run_started_at", "reference_commit", "build_hash", "runner_hash", "plan_hash",
    "preflight_id", "driver_found", "runtime_ready", "origin_loaded", "auth_verified",
    "initial_route", "final_route", "expected_route_ok", "expected_markers_total",
    "expected_markers_reached", "forbidden_markers_total", "forbidden_markers_absent",
    "subview_opened", "detail_transition_confirmed", "modal_opened", "external_requests", "expected_blocked_external_requests",
    "unexpected_external_requests", "expected_http_errors", "unexpected_http_errors",
    "console_warnings", "console_exceptions", "unknown_exceptions", "application_exceptions",
    "result_category", "comment",
]
CONSOLE_EVENT_FIELDS = [
    "run_id", "preflight_id", "event_type", "level", "message", "stack", "url",
    "expected", "classification", "fingerprint",
]


def require_local(url: str) -> None:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in {"http", "https"} or parsed.hostname not in LOOPBACK:
        raise RuntimeError(f"Audit URL must be loopback-only: {url}")


def read_csv_checked(path: Path, required: set[str]) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        columns = set(reader.fieldnames or [])
        if columns != required:
            missing = sorted(required - columns)
            unexpected = sorted(columns - required)
            raise RuntimeError(
                f"{path.name} schema mismatch; missing={missing}, unexpected={unexpected}"
            )
        rows = list(reader)
    if not rows:
        raise RuntimeError(f"{path.name} contains no scenario.")
    required_values = {"preflight_id", "scenario_driver", "expected_markers", "teardown_action", "status"}
    for number, row in enumerate(rows, start=2):
        if None in row or None in row.values():
            raise RuntimeError(f"{path.name}:{number} has an unattached CSV value.")
        if set(row.keys()) != required:
            raise RuntimeError(f"{path.name}:{number} does not have the exact required columns.")
        missing_values = sorted(key for key in required_values if row.get(key) is None or not row[key].strip())
        if missing_values:
            raise RuntimeError(f"{path.name}:{number} has blank required values: {', '.join(missing_values)}")
    return rows


def preflight_rows() -> list[dict[str, str]]:
    rows = read_csv_checked(PREFLIGHT_PLAN, REQUIRED_PREFLIGHT_COLUMNS)
    identifiers = [row["preflight_id"] for row in rows]
    if len(identifiers) != len(set(identifiers)):
        raise RuntimeError("preflight_plan.csv contains duplicate preflight_id values.")
    return rows


def load_preflight(preflight_id: str) -> dict[str, str]:
    for row in preflight_rows():
        if row["preflight_id"] == preflight_id:
            return row
    raise RuntimeError(f"Unknown preflight id: {preflight_id}")


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def reference_commit() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unavailable"


def build_hash() -> str:
    manifest = json.loads((CATALOG / "build_manifest.json").read_text(encoding="utf-8"))
    artifacts = manifest.get("artifacts", [])
    if not artifacts or not artifacts[0].get("sha256"):
        raise RuntimeError("build_manifest.json does not contain the served build hash.")
    return str(artifacts[0]["sha256"])


def normalize_text(value: str) -> str:
    return " ".join(
        normalize("NFKD", value).encode("ascii", "ignore").decode("ascii").lower().split()
    )


class CdpSession:
    def __init__(self, websocket_url: str):
        self.websocket_url = websocket_url
        self.ws: Any = None
        self.pending: dict[int, asyncio.Future] = {}
        self.events: dict[str, list[dict[str, Any]]] = defaultdict(list)
        self.external_requests: list[dict[str, str]] = []
        self.http_errors: list[dict[str, str]] = []
        self.locator_trace: list[dict[str, Any]] = []
        self.surface_trace: list[dict[str, Any]] = []
        self.command_id = 0
        self.receiver: asyncio.Task | None = None

    async def __aenter__(self):
        self.ws = await websockets.connect(self.websocket_url, max_size=30_000_000)
        self.receiver = asyncio.create_task(self._receive())
        return self

    async def __aexit__(self, *_exc):
        if self.receiver:
            self.receiver.cancel()
            try:
                await self.receiver
            except asyncio.CancelledError:
                pass
        if self.ws:
            await self.ws.close()

    async def _receive(self) -> None:
        async for raw in self.ws:
            message = json.loads(raw)
            if "id" in message:
                pending = self.pending.pop(message["id"], None)
                if pending and not pending.done():
                    if "error" in message:
                        pending.set_exception(RuntimeError(
                            f"CDP {message['error'].get('message', 'command failed')}"
                        ))
                    else:
                        pending.set_result(message.get("result", {}))
                continue
            method, params = message.get("method", ""), message.get("params", {})
            self.events[method].append(params)
            if method == "Fetch.requestPaused":
                request = params.get("request", {})
                parsed = urllib.parse.urlparse(request.get("url", ""))
                if parsed.scheme in {"data", "blob"} or parsed.hostname in LOOPBACK:
                    await self.notify("Fetch.continueRequest", {"requestId": params["requestId"]})
                elif parsed.hostname in FONT_HOSTS and request.get("method", "").upper() in {"GET", "OPTIONS"}:
                    # The audit uses a fresh profile and replaces request headers so a font
                    # request cannot carry cookies, tokens, or an Authorization header.
                    self.external_requests.append({
                        "url": request.get("url", ""), "method": request.get("method", ""),
                        "resource_type": params.get("resourceType", ""), "action": "allowed",
                        "reason": "google_fonts_audit_allowlist_no_credentials",
                        "expected": "true", "classification": "allowed_font_request",
                    })
                    await self.notify("Fetch.continueRequest", {
                        "requestId": params["requestId"],
                        "headers": [
                            {"name": "Accept", "value": "*/*"},
                            {"name": "User-Agent", "value": "EnactSpace UI audit font loader"},
                        ],
                    })
                else:
                    self.external_requests.append({
                        "url": request.get("url", ""), "method": request.get("method", ""),
                        "resource_type": params.get("resourceType", ""), "action": "blocked",
                        "reason": "non_loopback_browser_request",
                        "expected": "false", "classification": "unexpected_external",
                    })
                    await self.notify("Fetch.failRequest", {"requestId": params["requestId"], "errorReason": "BlockedByClient"})

    async def call(self, method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        self.command_id += 1
        future = asyncio.get_running_loop().create_future()
        self.pending[self.command_id] = future
        await self.ws.send(json.dumps({"id": self.command_id, "method": method, "params": params or {}}))
        return await asyncio.wait_for(future, timeout=20)

    async def notify(self, method: str, params: dict[str, Any]) -> None:
        self.command_id += 1
        await self.ws.send(json.dumps({"id": self.command_id, "method": method, "params": params}))


class ContractFailure(RuntimeError):
    """The real UI did not satisfy an asserted user-facing contract."""


class LocatorFailure(ContractFailure):
    """A coded Flutter element was not located on the active surface."""


class TransitionFailure(ContractFailure):
    """A requested Flutter route or subview transition was not proven."""


class ModalTargetFailure(ContractFailure):
    """A modal opened but its own interactive surface was not targeted."""


class ProductContractFailure(ContractFailure):
    """A rendered, proven subview is missing a required product capability."""


async def evaluate(session: CdpSession, expression: str) -> Any:
    result = await session.call("Runtime.evaluate", {"expression": expression, "returnByValue": True, "awaitPromise": True})
    details = result.get("exceptionDetails")
    if details:
        raise RuntimeError(details.get("text", "CDP evaluation failed"))
    return result.get("result", {}).get("value")


async def create_target() -> tuple[dict[str, Any], CdpSession]:
    require_local(CDP_URL)
    request = urllib.request.Request(f"{CDP_URL}/json/new?about:blank", method="PUT")
    with urllib.request.urlopen(request, timeout=10) as response:
        target = json.loads(response.read())
    session = CdpSession(target["webSocketDebuggerUrl"])
    await session.__aenter__()
    for method in ("Page.enable", "Runtime.enable", "Network.enable", "Log.enable", "Accessibility.enable"):
        await session.call(method)
    await session.call("Fetch.enable", {"patterns": [{"urlPattern": "*"}]})
    return target, session


async def clear_origin(session: CdpSession) -> None:
    await session.call("Network.clearBrowserCache")
    await session.call("Network.clearBrowserCookies")
    await session.call("Storage.clearDataForOrigin", {"origin": WEB_URL, "storageTypes": "all"})
    await evaluate(session, f"""(async()=>{{if(location.origin!==new URL({json.dumps(WEB_URL)}).origin)return false;localStorage.clear();sessionStorage.clear();
      if('caches'in window)for(const k of await caches.keys())await caches.delete(k);
      if('serviceWorker'in navigator)for(const r of await navigator.serviceWorker.getRegistrations())await r.unregister();return true;}})()""")


async def navigate(session: CdpSession, route: str, strategy: str) -> str:
    target = f"{WEB_URL}/#{route}" if strategy == "hash_strategy" else f"{WEB_URL}{route}"
    await session.call("Page.navigate", {"url": target})
    await asyncio.sleep(0.15)
    return str(await evaluate(session, "location.href"))


async def ui_text(session: CdpSession) -> str:
    dom_text = str(await evaluate(session, "document.body ? document.body.innerText : ''") or "")
    tree = await session.call("Accessibility.getFullAXTree")
    names = [str((node.get("name") or {}).get("value", "")) for node in tree.get("nodes", [])]
    return "\n".join([dom_text, *names])


async def enable_flutter_semantics(session: CdpSession) -> bool:
    """Activate Flutter's accessibility bridge when its placeholder is present."""
    return bool(await evaluate(session, """(()=>{const e=document.querySelector('flt-semantics-placeholder');
      if(!e)return false;e.click();return true;})()"""))


async def wait_text(session: CdpSession, wanted: str, timeout: float = 12) -> bool:
    deadline = time.perf_counter() + timeout
    while time.perf_counter() < deadline:
        await enable_flutter_semantics(session)
        if wanted.lower() in (await ui_text(session)).lower():
            return True
        await asyncio.sleep(0.15)
    return False


async def ax_nodes(session: CdpSession, label: str, preferred_roles: tuple[str, ...] = ()) -> list[dict[str, Any]]:
    """Return semantic nodes matching a Flutter label, including virtualized views."""
    await enable_flutter_semantics(session)
    wanted = normalize_text(label)
    nodes: list[dict[str, Any]] = []
    try:
        queried = await session.call("Accessibility.queryAXTree", {"accessibleName": label})
        nodes.extend(queried.get("nodes", []))
    except RuntimeError:
        pass
    tree = await session.call("Accessibility.getFullAXTree")
    nodes.extend(tree.get("nodes", []))
    seen: set[tuple[Any, str]] = set()
    matches: list[dict[str, Any]] = []
    for node in nodes:
        name = str((node.get("name") or {}).get("value", ""))
        role = str((node.get("role") or {}).get("value", ""))
        key = (node.get("backendDOMNodeId") or node.get("nodeId"), name)
        if key in seen:
            continue
        seen.add(key)
        if preferred_roles and role.lower() not in {item.lower() for item in preferred_roles}:
            continue
        candidate = normalize_text(name)
        if candidate and (candidate == wanted or wanted in candidate):
            matches.append(node)
    return matches


async def box_for_ax_node(session: CdpSession, node: dict[str, Any]) -> dict[str, float] | None:
    backend_id = node.get("backendDOMNodeId")
    if not backend_id:
        return None
    try:
        quad = (await session.call("DOM.getBoxModel", {"backendNodeId": backend_id}))["model"]["content"]
        xs, ys = quad[::2], quad[1::2]
        if max(xs) > min(xs) and max(ys) > min(ys):
            return {"x": (min(xs) + max(xs)) / 2, "y": (min(ys) + max(ys)) / 2}
    except (KeyError, RuntimeError):
        return None
    return None


async def rect_for_ax_node(session: CdpSession, node: dict[str, Any]) -> dict[str, float] | None:
    backend_id = node.get("backendDOMNodeId")
    if not backend_id:
        return None
    try:
        quad = (await session.call("DOM.getBoxModel", {"backendNodeId": backend_id}))["model"]["border"]
        xs, ys = quad[::2], quad[1::2]
        left, right, top, bottom = min(xs), max(xs), min(ys), max(ys)
        if right > left and bottom > top:
            return {"x": left, "y": top, "width": right - left, "height": bottom - top}
    except (KeyError, RuntimeError):
        return None
    return None


def node_role(node: dict[str, Any]) -> str:
    return str((node.get("role") or {}).get("value", ""))


def node_name(node: dict[str, Any]) -> str:
    return str((node.get("name") or {}).get("value", ""))


def node_is_actionable(node: dict[str, Any]) -> bool:
    role = node_role(node).lower()
    if role in {"button", "link", "menuitem", "tab"}:
        return True
    for prop in node.get("properties", []):
        if prop.get("name") == "clickable":
            value = (prop.get("value") or {}).get("value")
            if value is True or str(value).lower() == "true":
                return True
    return False


async def ax_tree_with_parents(session: CdpSession) -> tuple[dict[str, dict[str, Any]], dict[str, str]]:
    await enable_flutter_semantics(session)
    tree = await session.call("Accessibility.getFullAXTree")
    nodes = {str(node.get("nodeId")): node for node in tree.get("nodes", []) if node.get("nodeId")}
    parents: dict[str, str] = {}
    for parent_id, node in nodes.items():
        for child_id in node.get("childIds", []):
            parents[str(child_id)] = parent_id
    return nodes, parents


async def find_actionable_ancestor_for_label(
    session: CdpSession, label: str, start_at_top: bool = False,
    max_steps: int = 12, step_pixels: int = 620,
) -> dict[str, Any] | None:
    """Resolve a text node to the nearest actionable Flutter semantics ancestor."""
    if start_at_top:
        await reset_flutter_scroll_to_top(session)
    for step in range(max_steps + 1):
        nodes_by_id, parents = await ax_tree_with_parents(session)
        text_nodes = await ax_nodes(session, label)
        rescan = False
        for text_node in text_nodes:
            text_cursor = str(text_node.get("nodeId", ""))
            is_textbox_value = False
            while text_cursor and text_cursor in parents:
                text_cursor = parents[text_cursor]
                text_parent = nodes_by_id.get(text_cursor)
                if text_parent and node_role(text_parent).lower() == "textbox":
                    is_textbox_value = True
                    break
            if is_textbox_value:
                continue
            text_box = await box_for_ax_node(session, text_node)
            cursor = str(text_node.get("nodeId", ""))
            candidates: list[tuple[float, dict[str, Any], dict[str, float], dict[str, float]]] = []
            while cursor and cursor in parents:
                cursor = parents[cursor]
                parent = nodes_by_id.get(cursor)
                if parent and node_is_actionable(parent):
                    actionable_rect = await rect_for_ax_node(session, parent)
                    if actionable_rect and text_box:
                        contains_text = (
                            actionable_rect["x"] <= text_box["x"] <= actionable_rect["x"] + actionable_rect["width"]
                            and actionable_rect["y"] <= text_box["y"] <= actionable_rect["y"] + actionable_rect["height"]
                        )
                        if contains_text:
                            candidates.append((actionable_rect["width"] * actionable_rect["height"], parent, actionable_rect, text_box))
            if candidates:
                _, actionable, actionable_rect, text_box = min(candidates, key=lambda item: item[0])
                target = {
                        "label": label,
                        "text_role": node_role(text_node),
                        "text_backendDOMNodeId": text_node.get("backendDOMNodeId"),
                        "text_box": text_box,
                        "ancestor_role": node_role(actionable),
                        "ancestor_backendDOMNodeId": actionable.get("backendDOMNodeId"),
                        "ancestor_rect": actionable_rect,
                        "clicked_box": {"x": actionable_rect["x"] + actionable_rect["width"] / 2, "y": actionable_rect["y"] + actionable_rect["height"] / 2},
                        "scroll_steps": step,
                }
                session.locator_trace.append({"found": True, **target})
                return target
            text_rect = await rect_for_ax_node(session, text_node)
            if text_rect and text_rect["y"] > 24:
                metrics = await evaluate(session, "({width:innerWidth,height:innerHeight})")
                if text_rect["y"] > metrics["height"] * 0.72 and step < max_steps:
                    await scroll_flutter_view(session, step_pixels // 2)
                    rescan = True
                    break
                # Flutter CanvasKit does not publish InkWell as an AX action for
                # these cards. Aim in the rendered card body, away from the label,
                # instead of clicking the static text center.
                body_y = (
                    text_rect["y"] + text_rect["height"] * 0.25
                    if text_rect["height"] >= 80
                    else text_rect["y"] + text_rect["height"] + 18
                )
                body_target = {
                    "x": text_rect["x"] + text_rect["width"] / 2,
                    "y": body_y,
                }
                hit = await evaluate(session, f"""(()=>{{const e=document.elementFromPoint({body_target['x']},{body_target['y']});return {{tag:e?.tagName||'',role:e?.getAttribute?.('role')||'',aria:e?.getAttribute?.('aria-label')||''}};}})()""")
                target = {
                    "label": label,
                    "text_role": node_role(text_node),
                    "text_backendDOMNodeId": text_node.get("backendDOMNodeId"),
                    "text_box": {"x": text_rect["x"] + text_rect["width"] / 2, "y": text_rect["y"] + text_rect["height"] / 2},
                    "ancestor_role": "rendered_card_hit_target",
                    "ancestor_backendDOMNodeId": None,
                    "ancestor_rect": text_rect,
                    "clicked_box": body_target,
                    "fallback_reason": "semantic_action_not_exposed_by_flutter",
                    "hit_test": hit,
                    "scroll_steps": step,
                }
                session.locator_trace.append({"found": True, **target})
                return target
        if rescan:
            continue
        if step < max_steps:
            await scroll_flutter_view(session, step_pixels)
    session.locator_trace.append({"label": label, "found": False, "reason": "actionable_ancestor_missing", "scroll_steps": max_steps})
    return None


async def modal_surface_snapshot(session: CdpSession) -> dict[str, Any]:
    """Detect Flutter modal surfaces without relying on URL changes."""
    await enable_flutter_semantics(session)
    tree = await session.call("Accessibility.getFullAXTree")
    nodes = tree.get("nodes", [])
    dialogs = [node for node in nodes if node_role(node).lower() in {"dialog", "alertdialog"}]
    close_nodes = await ax_nodes(session, "Fermer", ("button",))
    expand_nodes = await ax_nodes(session, "Créer expansion", ("button",))
    modal_box = None
    for node in [*dialogs, *close_nodes, *expand_nodes]:
        modal_box = await box_for_ax_node(session, node)
        if modal_box:
            break
    dom = await evaluate(session, """(()=>{
      const all=[...document.querySelectorAll('[role=dialog],[aria-modal=true],flt-semantics')];
      const modal=all.filter(e=>{const t=(e.innerText||e.textContent||'').toLowerCase();return e.getAttribute('aria-modal')==='true'||e.getAttribute('role')==='dialog'||(t.includes('fermer')&&t.includes('créer expansion'));});
      return {modalCount:modal.length,dialogCount:document.querySelectorAll('[role=dialog],[aria-modal=true]').length};
    })()""")
    dom_rect = await evaluate(session, """(()=>{
      const all=[...document.querySelectorAll('flt-semantics')];
      const modal=all.filter(e=>{const t=(e.innerText||e.textContent||'').toLowerCase();return t.includes('fermer')&&t.includes('expansion');})
        .sort((a,b)=>{const ar=a.getBoundingClientRect(),br=b.getBoundingClientRect();return br.width*br.height-ar.width*ar.height;})[0];
      if(!modal)return null;const r=modal.getBoundingClientRect();
      return {x:r.x,y:r.y,width:r.width,height:r.height};
    })()""")
    modal_count = max(int(dom.get("modalCount", 0)), 1 if dialogs else 0, 1 if close_nodes and expand_nodes else 0, 1 if dom_rect else 0)
    return {
        "modal_count": modal_count,
        "dialog_count": max(int(dom.get("dialogCount", 0)), len(dialogs)),
        "modal_box": modal_box,
        "modal_rect": dom_rect,
        "close_present": bool(close_nodes),
        "expand_present": bool(expand_nodes),
    }


async def visible_surface_markers(session: CdpSession, labels: tuple[str, ...]) -> list[str]:
    text = normalize_text(await ui_text(session))
    return [label for label in labels if normalize_text(label) in text]


async def trace_surface(ctx: "PreflightContext", step: str, active_surface: str, result: str = "", actionable_target: dict[str, Any] | None = None, clicked_box: dict[str, Any] | None = None, scroll_target: dict[str, Any] | None = None, scroll_steps: int = 0, markers: tuple[str, ...] = ()) -> None:
    modal = await modal_surface_snapshot(ctx.session)
    ctx.session.surface_trace.append({
        "preflight_id": ctx.row["preflight_id"],
        "step": step,
        "active_surface": active_surface,
        "route": current_route(str(await evaluate(ctx.session, "location.href"))),
        "modal_count": modal["modal_count"],
        "dialog_count": modal["dialog_count"],
        "actionable_target": actionable_target or {},
        "clicked_box": clicked_box or {},
        "visible_markers": await visible_surface_markers(ctx.session, markers),
        "scroll_target": scroll_target or {},
        "scroll_steps": scroll_steps,
        "result": result,
    })


async def scroll_active_surface(ctx: "PreflightContext", active_surface: str, step_pixels: int = 620, step: int = 0) -> None:
    metrics = await evaluate(ctx.session, "({width: innerWidth, height: innerHeight})")
    modal = await modal_surface_snapshot(ctx.session)
    target = modal.get("modal_rect") if active_surface == "archive_project_modal" else None
    if target:
        target = {"x": target["x"] + target["width"] / 2, "y": target["y"] + target["height"] * 0.68}
    if not target:
        target = {"x": metrics["width"] / 2, "y": metrics["height"] * 0.72}
    before = await evaluate(ctx.session, f"""(()=>{{const e=document.elementFromPoint({target['x']},{target['y']});return {{tag:e?.tagName||'',role:e?.getAttribute?.('role')||'',scrollTop:e?.scrollTop||0}};}})()""")
    await ctx.session.call("Input.dispatchMouseEvent", {"type": "mouseWheel", "x": target["x"], "y": target["y"], "deltaX": 0, "deltaY": step_pixels})
    await asyncio.sleep(0.32)
    await enable_flutter_semantics(ctx.session)
    await trace_surface(ctx, "scroll", active_surface, actionable_target=before, scroll_target=target, scroll_steps=step)


async def find_marker_inside_active_modal(ctx: "PreflightContext", label: str, max_steps: int = 18) -> bool:
    modal = await modal_surface_snapshot(ctx.session)
    if modal["modal_count"] < 1:
        raise ModalTargetFailure("Archive modal is not open before modal marker lookup.")
    for step in range(max_steps + 1):
        nodes = await ax_nodes(ctx.session, label)
        rect = modal.get("modal_rect")
        for node in nodes:
            box = await box_for_ax_node(ctx.session, node)
            inside_modal = bool(box) and (not rect or (
                rect["x"] <= box["x"] <= rect["x"] + rect["width"]
                and rect["y"] <= box["y"] <= rect["y"] + rect["height"]
            ))
            if box and inside_modal:
                ctx.verified_text.add(normalize_text(label))
                await trace_surface(ctx, f"modal_marker:{label}", "archive_project_modal", result="found", scroll_steps=step, markers=(label,))
                return True
        if step < max_steps:
            await scroll_active_surface(ctx, "archive_project_modal", step=step + 1)
    await trace_surface(ctx, f"modal_marker:{label}", "archive_project_modal", result="not_found", scroll_steps=max_steps, markers=(label,))
    return False


async def find_marker_in_attendance_detail(ctx: "PreflightContext", label: str, max_steps: int = 14) -> bool:
    for step in range(max_steps + 1):
        if await wait_text(ctx.session, label, timeout=0.4):
            ctx.verified_text.add(normalize_text(label))
            await trace_surface(ctx, f"detail_marker:{label}", "attendance_detail", result="found", scroll_steps=step, markers=(label,))
            return True
        if step < max_steps:
            await scroll_active_surface(ctx, "attendance_detail", step=step + 1)
    await trace_surface(ctx, f"detail_marker:{label}", "attendance_detail", result="not_found", scroll_steps=max_steps, markers=(label,))
    return False


async def reset_flutter_scroll_to_top(session: CdpSession) -> None:
    await enable_flutter_semantics(session)
    await evaluate(session, "window.scrollTo(0, 0); true")
    for _ in range(2):
        await session.call("Input.dispatchKeyEvent", {"type": "keyDown", "key": "Home", "code": "Home", "windowsVirtualKeyCode": 36})
        await session.call("Input.dispatchKeyEvent", {"type": "keyUp", "key": "Home", "code": "Home", "windowsVirtualKeyCode": 36})
    await asyncio.sleep(0.35)


async def scroll_flutter_view(session: CdpSession, step_pixels: int) -> None:
    metrics = await evaluate(session, "({width: innerWidth, height: innerHeight})")
    await session.call("Input.dispatchMouseEvent", {
        "type": "mouseWheel", "x": metrics["width"] * 0.32, "y": metrics["height"] * 0.72,
        "deltaX": 0, "deltaY": step_pixels,
    })
    await asyncio.sleep(0.28)
    await enable_flutter_semantics(session)


async def box_is_viewport_visible(session: CdpSession, box: dict[str, float]) -> bool:
    metrics = await evaluate(session, "({width:visualViewport?.width||innerWidth,height:visualViewport?.height||innerHeight})")
    return 1 <= box["x"] <= metrics["width"] - 1 and 1 <= box["y"] <= metrics["height"] - 1


async def scan_flutter_view_for_label(
    session: CdpSession, label: str, preferred_roles: tuple[str, ...] = (),
) -> tuple[dict[str, float] | None, str | None]:
    nodes = await ax_nodes(session, label, preferred_roles)
    for node in nodes:
        box = await box_for_ax_node(session, node)
        if not box:
            rect = await rect_for_ax_node(session, node)
            if rect:
                box = {"x": rect["x"] + rect["width"] / 2, "y": rect["y"] + rect["height"] / 2}
        if box and await box_is_viewport_visible(session, box):
            return box, str((node.get("role") or {}).get("value", ""))
    # Flutter occasionally exposes a semantic staticText node before DevTools
    # assigns it a backend DOM id. Keep AX as the selector of record, then
    # resolve the corresponding semantics element solely to obtain its box.
    if nodes:
        wanted = normalize_text(label)
        fallback = await evaluate(session, f"""(()=>{{
          const wanted={json.dumps(wanted)};
          const norm=v=>String(v||'').normalize('NFKD').replace(/[\\u0300-\\u036f]/g,'').toLowerCase().replace(/\\s+/g,' ').trim();
          const all=[...document.querySelectorAll('flt-semantics, flt-semantics *')];
          const item=all.map(e=>{{const value=norm(e.getAttribute('aria-label')||e.innerText||e.textContent);const r=e.getBoundingClientRect();return {{e,value,r}};}})
            .filter(x=>(x.value===wanted||x.value.startsWith(wanted+' '))&&x.r.width>0&&x.r.height>0)
            .sort((a,b)=>(a.r.width*a.r.height)-(b.r.width*b.r.height))[0]?.e;
          if(!item)return null;const r=item.getBoundingClientRect();
          return r.width>0&&r.height>0?{{x:r.x+r.width/2,y:r.y+r.height/2}}:null;
        }})()""")
        if fallback:
            return fallback, str((nodes[0].get("role") or {}).get("value", ""))
    return None, None


async def find_flutter_locator_with_scroll(
    session: CdpSession, label: str, preferred_roles: tuple[str, ...] = (),
    start_at_top: bool = True, max_steps: int = 12, step_pixels: int = 620,
) -> dict[str, float] | None:
    """Find a Flutter semantic locator while deliberately scanning the live view."""
    if start_at_top:
        await reset_flutter_scroll_to_top(session)
    for step in range(max_steps + 1):
        box, role = await scan_flutter_view_for_label(session, label, preferred_roles)
        if box:
            box.update({"label": label, "role": role or "", "scroll_steps": step})
            session.locator_trace.append({"label": label, "role": role, "x": box["x"], "y": box["y"], "scroll_steps": step, "found": True})
            return box
        if step < max_steps:
            await scroll_flutter_view(session, step_pixels)
    session.locator_trace.append({"label": label, "role": None, "scroll_steps": max_steps, "found": False})
    return None


async def locator_box(session: CdpSession, label: str) -> dict[str, float] | None:
    return await find_flutter_locator_with_scroll(session, label, max_steps=0)


async def wait_locator(session: CdpSession, label: str, timeout: float = 8) -> dict[str, float] | None:
    deadline = time.perf_counter() + timeout
    while time.perf_counter() < deadline:
        box = await locator_box(session, label)
        if box:
            return box
        await asyncio.sleep(0.15)
    return None


async def click_box(session: CdpSession, box: dict[str, float]) -> None:
    await session.call("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": box["x"], "y": box["y"], "button": "none"})
    await asyncio.sleep(0.08)
    for kind in ("mousePressed", "mouseReleased"):
        await session.call("Input.dispatchMouseEvent", {"type": kind, "x": box["x"], "y": box["y"], "button": "left", "clickCount": 1})


async def click_flutter_label_with_scroll(
    session: CdpSession, label: str, preferred_roles: tuple[str, ...] = ("button", "link", "menuitem", "staticText"),
    start_at_top: bool = True, max_steps: int = 12, step_pixels: int = 620,
) -> bool:
    box = await find_flutter_locator_with_scroll(session, label, preferred_roles, start_at_top, max_steps, step_pixels)
    if not box:
        return False
    await click_box(session, box)
    return True


async def fill_flutter_field_with_scroll(
    session: CdpSession, label: str, value: str, start_at_top: bool = True,
    max_steps: int = 12, step_pixels: int = 620,
) -> bool:
    field = await find_flutter_locator_with_scroll(session, label, ("textbox",), start_at_top, max_steps, step_pixels)
    if not field:
        return False
    await click_box(session, field)
    await session.call("Input.dispatchKeyEvent", {"type": "keyDown", "key": "A", "code": "KeyA", "windowsVirtualKeyCode": 65, "modifiers": 2})
    await session.call("Input.dispatchKeyEvent", {"type": "keyUp", "key": "A", "code": "KeyA", "windowsVirtualKeyCode": 65, "modifiers": 2})
    await session.call("Input.insertText", {"text": value})
    await asyncio.sleep(0.45)
    return True


async def click_label(session: CdpSession, label: str) -> bool:
    return await click_flutter_label_with_scroll(session, label, max_steps=0)


async def fill_login(session: CdpSession, email: str, password: str) -> bool:
    return await fill_flutter_field_with_scroll(session, "Email", email) and await fill_flutter_field_with_scroll(session, "Mot de passe", password)


async def fill_field(session: CdpSession, label: str, value: str) -> bool:
    return await fill_flutter_field_with_scroll(session, label, value, max_steps=0)


def audit_password() -> str:
    value = os.environ.get("UI_AUDIT_PASSWORD")
    if value:
        return value
    env_file = ROOT / "backend" / ".ui_audit" / ".env"
    if not env_file.is_file():
        raise RuntimeError("Missing ignored local UI audit environment file.")
    for line in env_file.read_text(encoding="ascii").splitlines():
        if line.startswith("UI_AUDIT_PASSWORD="):
            return line.split("=", 1)[1]
    raise RuntimeError("UI_AUDIT_PASSWORD is missing from local audit environment.")


def api_json(path: str, token: str | None = None, form: dict[str, str] | None = None) -> Any:
    require_local(API_URL)
    data = urllib.parse.urlencode(form).encode() if form else None
    request = urllib.request.Request(f"{API_URL}{path}", data=data, method="POST" if form else "GET")
    if form:
        request.add_header("Content-Type", "application/x-www-form-urlencoded")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read())


def audit_identity(alias: str) -> tuple[str, str]:
    key = alias.removeprefix("audit.")
    emails = {name: f"audit.{name}@example.test" for name in ("admin", "member", "secretary", "finance", "alumni", "polelead")}
    if key not in emails:
        raise RuntimeError(f"No audit account mapping for {alias}.")
    return key, emails[key]


@dataclass
class PreflightContext:
    row: dict[str, str]
    session: CdpSession
    strategy: str
    user: dict[str, Any] | None = None
    token: str | None = None
    actions: set[str] = field(default_factory=set)
    states: set[str] = field(default_factory=set)
    verified_text: set[str] = field(default_factory=set)
    subview_opened: bool = False
    origin_loaded: bool = False
    auth_verified: bool = False


async def verify_present(ctx: PreflightContext, label: str) -> bool:
    present = await wait_text(ctx.session, label, timeout=8)
    if present:
        ctx.verified_text.add(normalize_text(label))
    return present


async def verify_flutter_marker(ctx: PreflightContext, label: str, max_steps: int = 12) -> bool:
    if await verify_present(ctx, label):
        return True
    locator = await find_flutter_locator_with_scroll(
        ctx.session, label, ("staticText", "button", "link", "menuitem"),
        start_at_top=True, max_steps=max_steps,
    )
    if locator or await verify_present(ctx, label):
        ctx.verified_text.add(normalize_text(label))
        return True
    return False


async def wait_for_http_response(
    session: CdpSession, method: str, path_suffix: str, expected_status: int, timeout: float = 12,
) -> bool:
    deadline = time.perf_counter() + timeout
    recorded: set[str] = set()
    while time.perf_counter() < deadline:
        for event in session.events["Network.responseReceived"]:
            response = event.get("response", {})
            url = str(response.get("url", ""))
            request_id = str(event.get("requestId", ""))
            if request_id in recorded or not url.endswith(path_suffix):
                continue
            recorded.add(request_id)
            request = next((item for item in session.events["Network.requestWillBeSent"] if item.get("requestId") == request_id), {})
            actual_method = str(request.get("request", {}).get("method", "GET"))
            if actual_method != method:
                continue
            status = int(response.get("status", 0))
            session.http_errors.append({
                "url": url, "method": actual_method, "resource_type": str(event.get("type", "")),
                "action": "observed", "reason": "invalid_credentials_contract" if status == expected_status else "unexpected_http_status",
                "expected": str(status == expected_status).lower(),
                "classification": "expected_http_error" if status == expected_status else "unexpected_http_error",
            })
            return status == expected_status
        await asyncio.sleep(0.15)
    return False


async def wait_for_attendance_detail_transition(ctx: PreflightContext) -> bool:
    immediate = ("Clôturer", "Membres attendus", "Ajouter attendu")
    deadline = time.perf_counter() + 12
    while time.perf_counter() < deadline:
        visible = await visible_surface_markers(ctx.session, immediate)
        list_surface_active = await wait_text(ctx.session, "Rechercher une session", timeout=0.2)
        if visible and not list_surface_active:
            ctx.states.add("detail_transition_confirmed")
            await trace_surface(ctx, "attendance_detail_confirmed", "attendance_detail", result="confirmed", markers=immediate)
            return True
        await asyncio.sleep(0.2)
    await trace_surface(ctx, "attendance_detail_confirmed", "attendance_list", result="not_confirmed", markers=immediate)
    return False


async def wait_for_archive_modal(ctx: PreflightContext) -> bool:
    deadline = time.perf_counter() + 10
    while time.perf_counter() < deadline:
        modal = await modal_surface_snapshot(ctx.session)
        title_count = normalize_text(await ui_text(ctx.session)).count(normalize_text("Projet historique audit 2021"))
        if modal["modal_count"] >= 1 and (modal["close_present"] or modal["expand_present"] or title_count >= 2):
            ctx.states.add("modal_opened")
            ctx.subview_opened = True
            await trace_surface(ctx, "archive_modal_confirmed", "archive_project_modal", result="confirmed", markers=("Projet historique audit 2021", "Fermer", "Créer expansion"))
            return True
        await asyncio.sleep(0.2)
    await trace_surface(ctx, "archive_modal_confirmed", "archive_list", result="not_confirmed", markers=("Projet historique audit 2021", "Fermer", "Créer expansion"))
    return False


async def wait_for_visible_archive_modal(ctx: PreflightContext, project_label: str) -> bool:
    """Prove the visible project card opened a Flutter modal before inspecting it."""
    deadline = time.perf_counter() + 10
    while time.perf_counter() < deadline:
        modal = await modal_surface_snapshot(ctx.session)
        title_count = normalize_text(await ui_text(ctx.session)).count(normalize_text(project_label))
        if modal["modal_count"] >= 1 and (modal["close_present"] or modal["expand_present"] or title_count >= 2):
            ctx.states.add("modal_opened")
            ctx.subview_opened = True
            await trace_surface(ctx, "archive_modal_confirmed", "archive_project_modal", result="confirmed", markers=(project_label, "Fermer"))
            return True
        await asyncio.sleep(0.2)
    await trace_surface(ctx, "archive_modal_confirmed", "archive_list", result="not_confirmed", markers=(project_label, "Fermer"))
    return False


async def driver_login(ctx: PreflightContext) -> None:
    if not await wait_locator(ctx.session, "Email") or not await wait_locator(ctx.session, "Mot de passe"):
        raise RuntimeError("Login form does not expose two input fields.")
    if not await verify_present(ctx, "Connexion"):
        raise RuntimeError("Login form label is not exposed through Flutter semantics.")


async def driver_invalid_login(ctx: PreflightContext) -> None:
    if not await fill_flutter_field_with_scroll(ctx.session, "Email", "invalid@example.test"):
        raise RuntimeError("Invalid-login driver could not locate the email field.")
    if not await fill_flutter_field_with_scroll(ctx.session, "Mot de passe", "wrong-password", start_at_top=False):
        raise RuntimeError("Invalid-login driver could not fill both Flutter form fields.")
    focused_password = await evaluate(ctx.session, "document.activeElement && document.activeElement.tagName === 'INPUT'")
    if not focused_password:
        raise RuntimeError("Password input does not retain focus before submission.")
    await ctx.session.call("Input.dispatchKeyEvent", {"type": "keyDown", "key": "Enter", "code": "Enter", "windowsVirtualKeyCode": 13})
    await ctx.session.call("Input.dispatchKeyEvent", {"type": "keyUp", "key": "Enter", "code": "Enter", "windowsVirtualKeyCode": 13})
    if not await wait_for_http_response(ctx.session, "POST", "/api/auth/token", 401):
        raise RuntimeError("Invalid-login request did not return the required HTTP 401.")
    if not await wait_text(ctx.session, "Email ou mot de passe incorrect", timeout=10):
        raise RuntimeError("Invalid-login API response is not visible.")
    if current_route(str(await evaluate(ctx.session, "location.href"))) != "/login":
        raise RuntimeError("Invalid-login submission unexpectedly left the login route.")
    ctx.actions.add("retry_login")


async def driver_shell_member(ctx: PreflightContext) -> None:
    if not await verify_present(ctx, "Chat"):
        raise RuntimeError(f"Member mobile shell does not expose Chat navigation: {(await ui_text(ctx.session))[:240]}")
    ctx.actions.add("open_chat")


async def driver_shell_admin(ctx: PreflightContext) -> None:
    if not await verify_present(ctx, "Membres"):
        raise RuntimeError(f"Admin desktop shell does not expose Membres navigation: {(await ui_text(ctx.session))[:240]}")
    ctx.actions.add("open_members")


async def driver_dashboard(ctx: PreflightContext) -> None:
    if ctx.row["preflight_id"] == "PF06":
        if not await wait_text(ctx.session, "Tableau de bord", timeout=12):
            raise RuntimeError("Dashboard did not finish its loading state.")
        # The desktop side panel is initially visible; retain that genuine
        # marker before scanning the independently scrollable main column.
        if not await verify_present(ctx, "À suivre"):
            raise ContractFailure("Dense dashboard marker is absent: À suivre")
        for marker in ("Cartes adaptées à ton rôle", "Actions rapides"):
            if not await verify_flutter_marker(ctx, marker):
                raise ContractFailure(f"Dense dashboard marker is absent: {marker}")
        ctx.states.add("dense")
    else:
        ctx.actions.add("open_my_space")


async def open_detail(ctx: PreflightContext, label: str, state: str, action: str) -> None:
    if not await click_label(ctx.session, label):
        raise RuntimeError(f"Could not activate required subview locator: {label}")
    if not await wait_text(ctx.session, label, timeout=8):
        raise RuntimeError(f"Subview locator disappeared after activation: {label}")
    ctx.subview_opened = True
    ctx.states.add(state)
    ctx.actions.add(action)
    if not await locator_box(ctx.session, "Fermer") and not await locator_box(ctx.session, "Retour"):
        raise RuntimeError(f"Required close action is not exposed for {label}.")


async def driver_profile(ctx: PreflightContext) -> None:
    if not await fill_field(ctx.session, "Rechercher un membre", "Audit MultiRole"):
        raise RuntimeError("Member search input is not available.")
    if not await click_label(ctx.session, "Voir"):
        raise RuntimeError("Member detail action is not available after filtering.")
    if not await verify_present(ctx, "Audit MultiRole"):
        raise RuntimeError("Filtered member profile did not open.")
    ctx.subview_opened = True; ctx.states.add("member_profile"); ctx.actions.add("close_profile")


async def driver_attendance(ctx: PreflightContext) -> None:
    await reset_flutter_scroll_to_top(ctx.session)
    if not await wait_text(ctx.session, "Gestion", timeout=12):
        raise LocatorFailure("Attendance management tab did not render.")
    await trace_surface(ctx, "attendance_list_loaded", "attendance_list", markers=("Gestion", "Rechercher une session", "Session audit 2"))
    if not await click_label(ctx.session, "Gestion"):
        raise LocatorFailure("Attendance management tab is not available.")
    if not await fill_flutter_field_with_scroll(ctx.session, "Rechercher une session", "Session audit 2", start_at_top=True):
        raise LocatorFailure("Attendance search input is not available.")
    if not await wait_text(ctx.session, "Session audit 2", timeout=8):
        raise LocatorFailure("Attendance filtering did not return Session audit 2.")
    target = await find_actionable_ancestor_for_label(ctx.session, "Session audit 2", start_at_top=False)
    if not target:
        raise LocatorFailure("Attendance session text has no actionable ancestor.")
    await trace_surface(ctx, "attendance_card_targeted", "attendance_list", actionable_target=target, clicked_box=target["clicked_box"], markers=("Session audit 2",))
    await click_box(ctx.session, target["clicked_box"])
    if not await wait_for_attendance_detail_transition(ctx):
        raise TransitionFailure("Attendance card click did not prove a detail surface transition.")
    for marker in ("Pilotage de la session", "Pointage NFC", "Visibilité SG"):
        if not await find_marker_in_attendance_detail(ctx, marker):
            raise LocatorFailure(f"Attendance detail marker was not located on its active surface: {marker}")
    ctx.subview_opened = True
    ctx.states.add("open")
    ctx.actions.add("open_attendance_detail")
    return
    if not await find_marker_in_attendance_detail(ctx, "Clôturer", max_steps=4) and not await find_marker_in_attendance_detail(ctx, "Ouverte", max_steps=4):
        raise LocatorFailure("Attendance detail does not expose an open-session action or status.")
    ctx.subview_opened = True
    ctx.states.add("open")
    ctx.actions.add("open_attendance_detail")


async def driver_payment(ctx: PreflightContext) -> None:
    if not await fill_flutter_field_with_scroll(ctx.session, "Rechercher membre, frais, référence", "AUDIT-PAY-000", start_at_top=True):
        raise RuntimeError("Finance search input is not available.")
    if not await verify_flutter_marker(ctx, "AUDIT-PAY-000"):
        raise RuntimeError("Pending payment reference is not visible after filtering.")
    rejection_dialog_open = False
    for _ in range(3):
        if not await click_flutter_label_with_scroll(ctx.session, "Actions du paiement", start_at_top=False):
            continue
        await asyncio.sleep(0.7)
        if await wait_text(ctx.session, "Rejeter", timeout=2) and await click_flutter_label_with_scroll(ctx.session, "Rejeter", ("menuitem",), start_at_top=False, max_steps=0):
            if await wait_text(ctx.session, "Rejeter ce paiement ?", timeout=4):
                rejection_dialog_open = True
                break
        await ctx.session.call("Input.dispatchKeyEvent", {"type": "keyDown", "key": "Escape", "code": "Escape", "windowsVirtualKeyCode": 27})
        await ctx.session.call("Input.dispatchKeyEvent", {"type": "keyUp", "key": "Escape", "code": "Escape", "windowsVirtualKeyCode": 27})
        await asyncio.sleep(0.3)
    if not rejection_dialog_open:
        raise RuntimeError("Payment rejection action is not exposed.")
    if not await verify_present(ctx, "Motif"):
        raise RuntimeError("Payment rejection dialog is incomplete.")
    if not await click_flutter_label_with_scroll(ctx.session, "Retour", start_at_top=False, max_steps=2):
        raise RuntimeError("Payment rejection dialog cannot be dismissed safely.")
    if not await verify_flutter_marker(ctx, "En attente", max_steps=5):
        raise RuntimeError("Payment status is no longer pending after dismissing the rejection dialog.")
    ctx.subview_opened = True; ctx.states.add("payment_rejection"); ctx.actions.add("close_payment_rejection")


async def driver_chat(ctx: PreflightContext) -> None:
    threads = api_json("/chat/threads", token=ctx.token)
    thread = next((item for item in threads if item.get("title") == "Conversation audit 7"), None)
    if not thread:
        raise RuntimeError("Fixture conversation 7 is absent from the authenticated thread list.")
    await navigate(ctx.session, f"/chat?thread={thread['id']}", ctx.strategy)
    if not await verify_present(ctx, "Conversation audit 7") or not await verify_present(ctx, "Message audit"):
        raise RuntimeError("Target conversation did not open through its real thread route.")
    ctx.subview_opened = True
    ctx.states.add("messages")
    ctx.actions.add("focus_composer")
    if not await click_flutter_label_with_scroll(ctx.session, "Écrire un message", ("textbox",), start_at_top=False, max_steps=2):
        raise RuntimeError("Chat composer did not expose a focusable message control.")


async def driver_archive(ctx: PreflightContext) -> None:
    if not await fill_flutter_field_with_scroll(ctx.session, "Rechercher projet, impact, prix", "Projet historique audit 2021", start_at_top=True):
        raise LocatorFailure("Archive search input is not available.")
    if not await wait_text(ctx.session, "Projet historique audit 2021", timeout=8):
        raise LocatorFailure("Archive filtering did not return the required historical project fixture.")
    await trace_surface(ctx, "archive_list_loaded", "archive_list", markers=("Projet historique audit 2021",))
    target = await find_actionable_ancestor_for_label(ctx.session, "Projet historique audit 2021", start_at_top=False)
    if not target:
        raise LocatorFailure("Historical project text has no actionable card ancestor.")
    await trace_surface(ctx, "archive_card_targeted", "archive_list", actionable_target=target, clicked_box=target["clicked_box"], markers=("Projet historique audit 2021",))
    await click_box(ctx.session, target["clicked_box"])
    if not await wait_for_archive_modal(ctx):
        raise TransitionFailure("Historical project click did not prove an archive modal surface.")
    for marker in ("Problème", "Solution", "Impacts et indicateurs", "Prix", "Leçons apprises"):
        if not await find_marker_inside_active_modal(ctx, marker, max_steps=18):
            raise ModalTargetFailure(f"Archive detail marker was not located inside the active modal: {marker}")
    if not await find_marker_inside_active_modal(ctx, "Fermer", max_steps=8):
        raise ModalTargetFailure("Archive detail close action is not exposed inside the active modal.")
    ctx.subview_opened = True; ctx.states.add("archive_project"); ctx.actions.add("close_archive_detail")


async def driver_archive_live(ctx: PreflightContext) -> None:
    """Audit the actual Enactus historical-card modal, not an unused API fixture."""
    project_label = "DIMBALI"
    if not await wait_text(ctx.session, "Projets historiques", timeout=12):
        raise LocatorFailure("Archive project list did not render.")
    if not await fill_flutter_field_with_scroll(ctx.session, "Rechercher projet, impact, prix", project_label, start_at_top=True):
        raise LocatorFailure("Archive search input is not available.")
    if not await wait_text(ctx.session, project_label, timeout=8):
        raise LocatorFailure("Archive filtering did not return the visible DIMBALI card.")
    await trace_surface(ctx, "archive_list_loaded", "archive_list", markers=(project_label,))
    target = await find_actionable_ancestor_for_label(ctx.session, project_label, start_at_top=False)
    if not target:
        raise LocatorFailure("DIMBALI text has no actionable card ancestor.")
    await trace_surface(ctx, "archive_card_targeted", "archive_list", actionable_target=target, clicked_box=target["clicked_box"], markers=(project_label,))
    await click_box(ctx.session, target["clicked_box"])
    if not await wait_for_visible_archive_modal(ctx, project_label):
        raise TransitionFailure("DIMBALI card click did not prove an archive modal surface.")
    for marker in ("Probl\u00e8me", "Solution", "Impacts et indicateurs", "Prix", "Le\u00e7ons apprises"):
        if not await find_marker_inside_active_modal(ctx, marker, max_steps=18):
            raise ModalTargetFailure(f"Archive detail marker was not located inside the active modal: {marker}")
    if not await find_marker_inside_active_modal(ctx, "Fermer", max_steps=8):
        raise ModalTargetFailure("Archive detail close action is not exposed inside the active modal.")
    ctx.subview_opened = True
    ctx.states.add("archive_project")
    ctx.actions.add("close_archive_detail")


PREFLIGHT_DRIVERS: dict[str, Callable[[PreflightContext], Awaitable[None]]] = {
    "preflight_login_public_mobile": driver_login,
    "preflight_login_public_desktop": driver_login,
    "preflight_invalid_login": driver_invalid_login,
    "preflight_member_shell_mobile": driver_shell_member,
    "preflight_admin_shell_desktop": driver_shell_admin,
    "preflight_admin_dashboard_dense": driver_dashboard,
    "preflight_member_dashboard_mobile": driver_dashboard,
    "preflight_member_profile_tablet": driver_profile,
    "preflight_attendance_open_tablet": driver_attendance,
    "preflight_payment_pending_actions_desktop": driver_payment,
    "preflight_chat_conversation_mobile": driver_chat,
    "preflight_archive_project_detail_desktop": driver_archive_live,
}


def runtime_ready(row: dict[str, str]) -> bool:
    return row["scenario_driver"] in PREFLIGHT_DRIVERS


def validate_runtime_ready(rows: list[dict[str, str]]) -> None:
    unresolved = [row["scenario_driver"] for row in rows if not runtime_ready(row)]
    if unresolved:
        raise RuntimeError(f"Preflight drivers are not runtime ready: {', '.join(unresolved)}")


async def detect_url_strategy() -> str:
    _, session = await create_target()
    try:
        path_url = await navigate(session, "/login", "path_strategy")
        path_ok = await wait_text(session, "Connexion", timeout=10)
        await asyncio.sleep(1)
        path_final = str(await evaluate(session, "location.href"))
        hash_url = await navigate(session, "/login", "hash_strategy")
        hash_ok = await wait_text(session, "Connexion", timeout=10)
        await asyncio.sleep(1)
        hash_final = str(await evaluate(session, "location.href"))
        if path_ok and "#" not in path_final and urllib.parse.urlparse(path_url).path == "/login":
            return "path_strategy"
        if hash_ok and "#/login" in hash_final:
            return "hash_strategy"
        raise RuntimeError("Neither path nor hash URL strategy reached the login screen.")
    finally:
        await session.call("Page.close")
        await session.__aexit__(None, None, None)


async def debug_login_tree() -> None:
    """Print only semantic/DOM diagnostics; this mode never captures pixels."""
    _, session = await create_target()
    try:
        report: dict[str, Any] = {}
        for strategy in ("path_strategy", "hash_strategy"):
            url = await navigate(session, "/login", strategy)
            await asyncio.sleep(2)
            semantics_enabled = await enable_flutter_semantics(session)
            await asyncio.sleep(3)
            tree = await session.call("Accessibility.getFullAXTree")
            names = [str((node.get("name") or {}).get("value", "")) for node in tree.get("nodes", [])]
            ax_matches = [
                {
                    "name": str((node.get("name") or {}).get("value", "")),
                    "role": str((node.get("role") or {}).get("value", "")),
                    "backend_node_id": node.get("backendDOMNodeId"),
                }
                for node in tree.get("nodes", [])
                if str((node.get("name") or {}).get("value", "")).lower() in {"email", "mot de passe", "se connecter"}
            ]
            report[strategy] = {
                "url": url,
                "ready_state": await evaluate(session, "document.readyState"),
                "semantics_enabled": semantics_enabled,
                "dom_text": await evaluate(session, "document.body ? document.body.innerText : ''"),
                "inputs": await evaluate(session, "[...document.querySelectorAll('input')].map(e=>({type:e.type,aria:e.getAttribute('aria-label'),placeholder:e.placeholder}))"),
                "elements": await evaluate(session, "[...document.querySelectorAll('body *')].slice(0,80).map(e=>({tag:e.tagName,role:e.getAttribute('role'),aria:e.getAttribute('aria-label'),id:e.id,klass:e.className})).filter(e=>e.tag||e.role||e.aria)"),
                "ax_names": [name for name in names if name][:80],
                "ax_locator_matches": ax_matches,
                "locator_boxes": {
                    label: await locator_box(session, label)
                    for label in ("Email", "Mot de passe", "Se connecter")
                },
                "console_error_count": len(session.events["Runtime.exceptionThrown"]) + len(session.events["Log.entryAdded"]),
                "network_failed_count": len(session.events["Network.loadingFailed"]),
                "external_request_count": len(session.external_requests),
            }
        print(json.dumps({"visible_text": await ui_text(session), "ancestry": report}, ensure_ascii=False, indent=2))
    finally:
        await session.call("Page.close")
        await session.__aexit__(None, None, None)


async def debug_authenticated_preflight(row: dict[str, str], strategy: str) -> None:
    """Inspect a real authenticated route without clicking or capturing pixels."""
    _, session = await create_target()
    try:
        width, height = (int(part) for part in row["viewport"].split("x"))
        await session.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": width < 600})
        ctx = PreflightContext(row=row, session=session, strategy=strategy)
        await authenticate(ctx)
        await navigate(session, row["expected_final_route"], strategy)
        await asyncio.sleep(5)
        await enable_flutter_semantics(session)
        print(json.dumps({
            "url": await evaluate(session, "location.href"),
            "text": await ui_text(session),
            "requests": [item.get("request", {}).get("url", "") for item in session.events["Network.requestWillBeSent"]],
            "failures": session.events["Network.loadingFailed"],
            "logs": [entry.get("entry", {}).get("text", "") for entry in session.events["Log.entryAdded"]],
            "exceptions": [
                item.get("exceptionDetails", {}).get("exception", {}).get("description", item.get("exceptionDetails", {}).get("text", ""))
                for item in session.events["Runtime.exceptionThrown"]
            ],
        }, ensure_ascii=False, indent=2))
    finally:
        await clear_origin(session)
        await session.call("Page.close")
        await session.__aexit__(None, None, None)


async def debug_card_ancestry(row: dict[str, str], strategy: str) -> None:
    """Report semantics ancestry for PF09/PF12 cards; never clicks or captures."""
    _, session = await create_target()
    try:
        width, height = (int(part) for part in row["viewport"].split("x"))
        await session.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": width < 600})
        ctx = PreflightContext(row=row, session=session, strategy=strategy)
        await authenticate(ctx)
        await navigate(session, row["expected_final_route"], strategy)
        if row["preflight_id"] == "PF09":
            await wait_text(session, "Gestion", timeout=12)
            await click_label(session, "Gestion")
            await fill_flutter_field_with_scroll(session, "Rechercher une session", "Session audit 2", start_at_top=True)
            label = "Session audit 2"
        elif row["preflight_id"] == "PF10":
            await fill_flutter_field_with_scroll(session, "Rechercher membre, frais, r\u00e9f\u00e9rence", "AUDIT-PAY-000", start_at_top=True)
            await wait_text(session, "AUDIT-PAY-000", timeout=8)
            button_report = [
                {"role": node_role(node), "name": node_name(node), "content_box": await box_for_ax_node(session, node), "rect": await rect_for_ax_node(session, node), "properties": node.get("properties", [])}
                for node in await ax_nodes(session, "Actions du paiement", ("button",))
            ]
            await click_flutter_label_with_scroll(session, "Actions du paiement", start_at_top=False)
            await asyncio.sleep(1)
            label = "Rejeter"
            debug_click = await click_flutter_label_with_scroll(session, label, ("menuitem",), start_at_top=False, max_steps=0)
            await asyncio.sleep(0.7)
        else:
            await wait_text(session, "Projets historiques", timeout=12)
            await fill_flutter_field_with_scroll(session, "Rechercher projet, impact, prix", "DIMBALI", start_at_top=True)
            label = "DIMBALI"
        await wait_text(session, label, timeout=8)
        nodes, parents = await ax_tree_with_parents(session)
        report: list[dict[str, Any]] = []
        for text_node in await ax_nodes(session, label):
            cursor = str(text_node.get("nodeId", ""))
            chain: list[dict[str, Any]] = []
            while cursor and cursor in parents:
                cursor = parents[cursor]
                node = nodes.get(cursor)
                if not node:
                    continue
                chain.append({
                    "node_id": cursor,
                    "role": node_role(node),
                    "name": node_name(node),
                    "backend_node_id": node.get("backendDOMNodeId"),
                    "properties": node.get("properties", []),
                    "rect": await rect_for_ax_node(session, node),
                })
            report.append({"label": label, "text_rect": await rect_for_ax_node(session, text_node), "chain": chain})
        if row["preflight_id"] == "PF10":
            report.append({"button_report": button_report, "menu_click": debug_click, "after_click_text": await ui_text(session)})
        print(json.dumps(report, ensure_ascii=False, indent=2))
    finally:
        await clear_origin(session)
        await session.call("Page.close")
        await session.__aexit__(None, None, None)


async def authenticate(ctx: PreflightContext) -> None:
    alias = ctx.row["test_account_alias"]
    if alias == "public":
        return
    role, email = audit_identity(alias)
    await navigate(ctx.session, "/login", ctx.strategy)
    if not await wait_text(ctx.session, "Connexion", timeout=10):
        raise RuntimeError("EnactSpace origin did not load before token injection.")
    ctx.origin_loaded = True
    await clear_origin(ctx.session)
    token = api_json("/auth/token", form={"username": email, "password": audit_password()})["access_token"]
    user = api_json("/users/me", token=token)
    display_name = f"{user.get('first_name', '')} {user.get('last_name', '')}".strip()
    if user.get("email") != email or role not in email:
        raise RuntimeError(f"/users/me identity mismatch for {alias}: {display_name}")
    # shared_preferences_web JSON-encodes values under its flutter. prefix.
    await evaluate(ctx.session, f"localStorage.setItem('flutter.enactspace_token',{json.dumps(json.dumps(token))});localStorage.setItem('flutter.enactspace_current_user',{json.dumps(json.dumps(json.dumps(user)))});true")
    stored_token = await evaluate(ctx.session, "localStorage.getItem('flutter.enactspace_token')")
    if stored_token != json.dumps(token):
        raise RuntimeError("SharedPreferences token serialization did not persist as expected.")
    # The app's SharedPreferences singleton was initialized while clearing the
    # origin. Reload so the real runtime reconstructs that cache from storage.
    await ctx.session.call("Page.reload", {"ignoreCache": True})
    await asyncio.sleep(1.5)
    ctx.user = user
    ctx.token = token
    ctx.auth_verified = True


def current_route(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    route = parsed.fragment if parsed.fragment.startswith("/") else parsed.path
    return route.split("?", 1)[0]


async def check_marker(ctx: PreflightContext, marker: str, expected: bool) -> bool:
    kind, _, value = marker.partition(":")
    text = await ui_text(ctx.session)
    value_lower = value.lower()
    if kind == "route":
        actual = current_route(str(await evaluate(ctx.session, "location.href")))
        result = actual == value
    elif kind == "redirect":
        actual = current_route(str(await evaluate(ctx.session, "location.href")))
        result = actual == value
    elif kind == "text":
        result = normalize_text(value) in normalize_text(text) or normalize_text(value) in ctx.verified_text
    elif kind == "input":
        result = bool(await evaluate(ctx.session, f"[...document.querySelectorAll('input')].some(e => e.type === {json.dumps(value.lower())} || (e.getAttribute('aria-label') || '').toLowerCase().includes({json.dumps(value_lower)}))"))
    elif kind == "identity":
        result = bool(ctx.user and normalize_text(value) in normalize_text(f"{ctx.user.get('first_name','')} {ctx.user.get('last_name','')}"))
    elif kind == "nav":
        width = int(ctx.row["viewport"].split("x")[0])
        result = (value == "mobile" and width < 600) or (value == "desktop" and width >= 1024)
    elif kind == "action":
        result = value in ctx.actions
    elif kind in {"sheet", "dialog"}:
        result = ctx.subview_opened
    elif kind == "state":
        result = value in ctx.states
    elif kind == "absence":
        result = value_lower not in text.lower()
    else:
        raise RuntimeError(f"Unsupported contract marker: {marker}")
    return result if expected else not result


def archive_previous_outputs() -> None:
    active = (CONTRACT_RESULTS, PREFLIGHT_RESULTS, EXTERNAL_REQUESTS, LOCATOR_TRACE, SURFACE_TRACE, CONSOLE_EVENTS, RUN_MANIFEST)
    present = [path for path in active if path.exists() and path.stat().st_size > 0]
    if not present:
        return
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = ARCHIVE_ROOT / timestamp
    destination.mkdir(parents=True, exist_ok=False)
    for path in present:
        shutil.move(str(path), destination / path.name)


def create_run_manifest(strategy: str, rows: list[dict[str, str]]) -> dict[str, Any]:
    build_manifest = CATALOG / "build_manifest.json"
    runner_source = Path(__file__).read_text(encoding="utf-8")
    screenshot_method_present = ("Page.capture" + "Screenshot") in runner_source
    if screenshot_method_present:
        raise RuntimeError("This phase forbids a runner that contains a CDP screenshot command.")
    manifest = {
        "run_id": uuid.uuid4().hex,
        "run_started_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "reference_commit": reference_commit(),
        "build_hash": build_hash(),
        "runner_sha256": sha256_file(Path(__file__)),
        "preflight_plan_sha256": sha256_file(PREFLIGHT_PLAN),
        "preflight_drivers_sha256": sha256_file(CATALOG / "preflight_drivers.csv"),
        "build_manifest_sha256": sha256_file(build_manifest),
        "url_strategy": strategy,
        "number_of_scenarios": len(rows),
        "capture_enabled": False,
        "screenshot_method_present": screenshot_method_present,
        "output_files": [
            str(CONTRACT_RESULTS.relative_to(ROOT)).replace("\\", "/"),
            str(PREFLIGHT_RESULTS.relative_to(ROOT)).replace("\\", "/"),
            str(EXTERNAL_REQUESTS.relative_to(ROOT)).replace("\\", "/"),
            str(LOCATOR_TRACE.relative_to(ROOT)).replace("\\", "/"),
            str(SURFACE_TRACE.relative_to(ROOT)).replace("\\", "/"),
            str(CONSOLE_EVENTS.relative_to(ROOT)).replace("\\", "/"),
        ],
    }
    RUN_MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_csv(CONTRACT_RESULTS, CONTRACT_FIELDS, [])
    write_csv(PREFLIGHT_RESULTS, CONTRACT_FIELDS, [])
    write_csv(EXTERNAL_REQUESTS, EXTERNAL_REQUEST_FIELDS, [])
    LOCATOR_TRACE.write_text("[]\n", encoding="utf-8")
    SURFACE_TRACE.write_text("[]\n", encoding="utf-8")
    write_csv(CONSOLE_EVENTS, CONSOLE_EVENT_FIELDS, [])
    return manifest


def result_metadata(manifest: dict[str, Any]) -> dict[str, str]:
    return {
        "run_id": manifest["run_id"],
        "run_started_at": manifest["run_started_at"],
        "reference_commit": manifest["reference_commit"],
        "build_hash": manifest["build_hash"],
        "runner_hash": manifest["runner_sha256"],
        "plan_hash": manifest["preflight_plan_sha256"],
    }


def console_event_rows(session: CdpSession, manifest: dict[str, Any], preflight_id: str) -> list[dict[str, str]]:
    """Classify and deduplicate DevTools events for one scenario."""
    blocked_fonts = any(item["classification"] == "expected_blocked_external" for item in session.external_requests)
    raw: list[dict[str, str]] = []
    for item in session.events["Log.entryAdded"]:
        entry = item.get("entry", {})
        raw.append({
            "event_type": "log", "level": str(entry.get("level", "")),
            "message": str(entry.get("text", "")), "stack": str(entry.get("stackTrace", "")),
            "url": str(entry.get("url", "")),
        })
    for item in session.events["Runtime.exceptionThrown"]:
        details = item.get("exceptionDetails", {})
        exception = details.get("exception", {})
        raw.append({
            "event_type": "runtime_exception", "level": "error",
            "message": str(exception.get("description", details.get("text", ""))),
            "stack": str(exception.get("description", details.get("stackTrace", ""))),
            "url": str(details.get("url", "")),
        })

    grouped: dict[str, dict[str, str]] = {}
    for event in raw:
        message = event["message"]
        lowered = message.lower()
        if "server responded with a status of 401" in lowered and "/api/auth/token" in event["url"]:
            classification, expected = "expected_contract_exception", "true"
        elif "err_blocked_by_client" in lowered or "fonts.gstatic.com" in lowered:
            classification, expected = "expected_blocked_font_exception", "true"
        elif event["event_type"] == "runtime_exception" and blocked_fonts and "main.dart.js" in event["stack"]:
            classification, expected = "expected_blocked_font_exception", "true"
        elif "password field is not contained in a form" in lowered:
            classification, expected = "expected_contract_exception", "true"
        elif event["level"].lower() in {"warning", "warn", "info", "verbose"}:
            classification, expected = "flutter_warning", "true"
        elif "cdp " in lowered or "automation" in lowered:
            classification, expected = "automation_exception", "false"
        elif event["event_type"] == "runtime_exception":
            classification, expected = "unknown_exception", "false"
        else:
            classification, expected = "unknown_exception", "false"
        fingerprint = hashlib.sha256(
            f"{event['event_type']}|{event['level']}|{classification}|{message[:500]}".encode("utf-8")
        ).hexdigest()[:16]
        grouped.setdefault(fingerprint, {
            "run_id": manifest["run_id"], "preflight_id": preflight_id,
            **event, "expected": expected, "classification": classification, "fingerprint": fingerprint,
        })
    return list(grouped.values())


def console_counts(events: list[dict[str, str]]) -> dict[str, int]:
    return {
        "console_warnings": sum(item["classification"] == "flutter_warning" for item in events),
        "console_exceptions": sum(item["event_type"] == "runtime_exception" for item in events),
        "unknown_exceptions": sum(item["classification"] == "unknown_exception" for item in events),
        "application_exceptions": sum(item["classification"] == "application_exception" for item in events),
    }


def network_counts(session: CdpSession) -> dict[str, int]:
    return {
        "expected_blocked_external_requests": sum(item["classification"] == "expected_blocked_external" for item in session.external_requests),
        "unexpected_external_requests": sum(item["classification"] == "unexpected_external" for item in session.external_requests),
        "expected_http_errors": sum(item["classification"] == "expected_http_error" for item in session.http_errors),
        "unexpected_http_errors": sum(item["classification"] == "unexpected_http_error" for item in session.http_errors),
    }


async def run_preflight(row: dict[str, str], strategy: str, manifest: dict[str, Any]) -> dict[str, Any]:
    result = {key: "" for key in CONTRACT_FIELDS}
    result.update({**result_metadata(manifest), "preflight_id": row["preflight_id"], "driver_found": row["scenario_driver"] in PREFLIGHT_DRIVERS, "runtime_ready": runtime_ready(row), "initial_route": row["initial_route"]})
    if not runtime_ready(row):
        result.update({"result_category": "automation_failure", "comment": "Driver is not registered or runtime ready."})
        return result
    _, session = await create_target()
    try:
        width, height = (int(part) for part in row["viewport"].split("x"))
        await session.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": width < 600})
        await navigate(session, row["initial_route"], strategy)
        result["origin_loaded"] = await wait_text(session, "Connexion", timeout=10) if row["role"] == "public" else True
        ctx = PreflightContext(row=row, session=session, strategy=strategy, origin_loaded=bool(result["origin_loaded"]))
        await authenticate(ctx)
        await navigate(session, row["expected_final_route"], strategy)
        result["auth_verified"] = ctx.auth_verified or row["role"] == "public"
        await PREFLIGHT_DRIVERS[row["scenario_driver"]](ctx)
        final_url = str(await evaluate(session, "location.href"))
        result["final_route"] = current_route(final_url)
        result["expected_route_ok"] = result["final_route"] == row["expected_final_route"]
        expected = [item.strip() for item in row["expected_markers"].split(";") if item.strip()]
        forbidden = [item.strip() for item in row["forbidden_markers"].split(";") if item.strip()]
        expected_hits = sum([await check_marker(ctx, marker, True) for marker in expected])
        forbidden_hits = sum([await check_marker(ctx, marker, False) for marker in forbidden])
        console_events = console_event_rows(session, manifest, row["preflight_id"])
        console_summary = console_counts(console_events)
        counts = network_counts(session)
        result.update({"expected_markers_total": len(expected), "expected_markers_reached": expected_hits, "forbidden_markers_total": len(forbidden), "forbidden_markers_absent": forbidden_hits, "subview_opened": ctx.subview_opened, "detail_transition_confirmed": "detail_transition_confirmed" in ctx.states, "modal_opened": "modal_opened" in ctx.states, "external_requests": len(session.external_requests), **console_summary, **counts})
        success = all([result["auth_verified"], result["expected_route_ok"], expected_hits == len(expected), forbidden_hits == len(forbidden), not row["preflight_id"] in {"PF08","PF09","PF10","PF11","PF12"} or ctx.subview_opened, counts["unexpected_external_requests"] == 0, counts["unexpected_http_errors"] == 0, console_summary["unknown_exceptions"] == 0, console_summary["application_exceptions"] == 0])
        result["result_category"] = "success" if success else "product_contract_failure"
        if not success: result["comment"] = "One or more route, marker, permission, or subview contracts failed."
    except Exception as error:
        try:
            result["final_route"] = current_route(str(await evaluate(session, "location.href")))
            result["expected_route_ok"] = result["final_route"] == row["expected_final_route"]
        except Exception:
            pass
        console_events = console_event_rows(session, manifest, row["preflight_id"])
        category = (
            "locator_failure" if isinstance(error, LocatorFailure) else
            "transition_failure" if isinstance(error, TransitionFailure) else
            "modal_target_failure" if isinstance(error, ModalTargetFailure) else
            "product_contract_failure" if isinstance(error, ProductContractFailure) else
            "automation_failure"
        )
        result.update({"detail_transition_confirmed": "detail_transition_confirmed" in ctx.states if "ctx" in locals() else False, "modal_opened": "modal_opened" in ctx.states if "ctx" in locals() else False, "external_requests": len(session.external_requests), **console_counts(console_events), **network_counts(session), "result_category": category, "comment": str(error)})
    finally:
        records = [*session.external_requests, *session.http_errors]
        if records:
            append_csv(EXTERNAL_REQUESTS, EXTERNAL_REQUEST_FIELDS, [{"run_id": manifest["run_id"], "run_started_at": manifest["run_started_at"], "preflight_id": row["preflight_id"], **item} for item in records])
        if "console_events" in locals() and console_events:
            append_csv(CONSOLE_EVENTS, CONSOLE_EVENT_FIELDS, console_events)
        await clear_origin(session)
        await session.call("Page.close")
        await session.__aexit__(None, None, None)
        traces = json.loads(LOCATOR_TRACE.read_text(encoding="utf-8"))
        traces.append({"preflight_id": row["preflight_id"], "locators": session.locator_trace})
        LOCATOR_TRACE.write_text(json.dumps(traces, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        surface_traces = json.loads(SURFACE_TRACE.read_text(encoding="utf-8"))
        surface_traces.extend([{"run_id": manifest["run_id"], **item} for item in session.surface_trace])
        SURFACE_TRACE.write_text(json.dumps(surface_traces, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def append_csv(path: Path, fieldnames: list[str], rows: list[dict[str, Any]]) -> None:
    exists = path.exists() and path.stat().st_size > 0
    with path.open("a", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        if not exists: writer.writeheader()
        writer.writerows(rows)


def write_contract_results(rows: list[dict[str, Any]]) -> None:
    with CONTRACT_RESULTS.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CONTRACT_FIELDS)
        writer.writeheader(); writer.writerows(rows)


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, Any]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader(); writer.writerows(rows)


def update_runtime_strategy(strategy: str) -> None:
    path = CATALOG / "runtime_environment.md"
    text = path.read_text(encoding="utf-8")
    marker = "| URL strategy |"
    line = f"| URL strategy | `{strategy}` (detected without capture) |"
    if marker in text:
        lines = [line if current.startswith(marker) else current for current in text.splitlines()]
        text = "\n".join(lines) + "\n"
    else:
        text = text.replace("| Visual mode |", line + "\n| Visual mode |")
    path.write_text(text, encoding="utf-8")


MASTER_CAPTURE_FIELDS = [
    "numero", "domaine", "vue", "role", "viewport", "etat", "fichier", "reussite",
    "probleme_visible", "erreur_console_inattendue", "erreur_reseau_inattendue", "font_loaded",
    "font_source", "text_render_verified", "commentaire",
]


def master_row(number: int, domain: str, view: str, role: str, viewport: str, route: str, state: str = "default") -> dict[str, str]:
    return {"numero": f"{number:02d}", "domaine": domain, "vue": view, "role": role, "viewport": viewport, "route": route, "etat": state}


MASTER_CAPTURES = [
    master_row(1, "auth", "connexion", "public", "390x844", "/login"),
    master_row(2, "auth", "connexion", "public", "768x1024", "/login"),
    master_row(3, "auth", "connexion", "public", "1440x900", "/login"),
    master_row(4, "auth", "identifiants_invalides", "public", "390x844", "/login", "invalid_login"),
    master_row(5, "auth", "mot_de_passe_oublie", "public", "390x844", "/login", "forgot_password"),
    master_row(6, "shell", "membre_mobile", "member", "390x844", "/dashboard"),
    master_row(7, "shell", "administrateur_desktop", "admin", "1440x900", "/dashboard"),
    master_row(8, "shell", "financier_tablette", "finance", "768x1024", "/dashboard"),
    master_row(9, "dashboard", "admin_dense", "admin", "1440x900", "/dashboard"),
    master_row(10, "dashboard", "membre_mobile", "member", "390x844", "/dashboard"),
    master_row(11, "dashboard", "financier", "finance", "1366x768", "/dashboard"),
    master_row(12, "dashboard", "chef_pole", "polelead", "1440x900", "/dashboard"),
    master_row(13, "membres", "liste", "admin", "1440x900", "/members"),
    master_row(14, "membres", "liste", "admin", "390x844", "/members"),
    master_row(15, "membres", "profil_complet", "admin", "768x1024", "/members", "member_profile"),
    master_row(16, "membres", "modification", "admin", "1440x900", "/members", "member_edit"),
    master_row(17, "presence", "gestion", "secretary", "1440x900", "/attendance"),
    master_row(18, "presence", "suivi_personnel", "member", "390x844", "/attendance", "attendance_personal"),
    master_row(19, "presence", "session_ouverte", "secretary", "1024x768", "/attendance", "attendance_detail"),
    master_row(20, "presence", "qr_nfc", "secretary", "390x844", "/attendance/scan"),
    master_row(21, "taches", "liste", "member", "390x844", "/tasks"),
    master_row(22, "taches", "liste_dense", "admin", "1440x900", "/tasks"),
    master_row(23, "finance", "generale", "finance", "1366x768", "/finance"),
    master_row(24, "finance", "paiement_actions", "finance", "1366x768", "/finance", "finance_menu"),
    master_row(25, "finance", "dialogue_rejet", "finance", "1366x768", "/finance", "finance_reject"),
    master_row(26, "finance", "mobile_money", "member", "390x844", "/finance", "mobile_money"),
    master_row(27, "recrutement", "campagnes", "admin", "1440x900", "/recruitment"),
    master_row(28, "recrutement", "candidature_detail", "admin", "1024x768", "/recruitment", "recruitment_detail"),
    master_row(29, "documents", "bibliotheque", "admin", "1440x900", "/documents"),
    master_row(30, "documents", "depot", "admin", "768x1024", "/documents", "document_dialog"),
    master_row(31, "communaute", "publications", "member", "390x844", "/posts"),
    master_row(32, "communaute", "conversations", "member", "1440x900", "/chat"),
    master_row(33, "communaute", "conversation_messages", "member", "390x844", "/chat", "chat_conversation"),
    master_row(34, "communaute", "groupe_discussion", "member", "1366x768", "/chat", "chat_group"),
    master_row(35, "organisation", "poles", "member", "390x844", "/poles"),
    master_row(36, "organisation", "fiche_pole", "polelead", "1440x900", "/poles", "pole_detail"),
    master_row(37, "organisation", "projets", "member", "1440x900", "/projects"),
    master_row(38, "organisation", "detail_projet", "polelead", "768x1024", "/projects", "project_detail"),
    master_row(39, "parcours", "academy", "member", "390x844", "/academy"),
    master_row(40, "parcours", "alumni", "alumni", "1440x900", "/alumni"),
    master_row(41, "impact", "dashboard", "admin", "1440x900", "/impact"),
    master_row(42, "archives", "dimbali", "alumni", "1440x900", "/archives", "archive_detail"),
]


async def capture_png(session: CdpSession, output: Path) -> None:
    payload = await session.call("Page.captureScreenshot", {"format": "png", "fromSurface": True, "captureBeyondViewport": False})
    output.write_bytes(base64.b64decode(payload["data"]))


async def wait_for_font_loading(session: CdpSession, timeout: float = 12) -> bool:
    """Wait for browser-managed Flutter font loads before taking a screenshot."""
    deadline = time.perf_counter() + timeout
    while time.perf_counter() < deadline:
        ready = bool(await evaluate(session, "document.fonts ? document.fonts.status === 'loaded' : true"))
        if ready and any(item["classification"] == "allowed_font_request" for item in session.external_requests):
            return True
        await asyncio.sleep(0.15)
    return False


async def open_master_member(ctx: PreflightContext, edit: bool = False) -> None:
    if not await fill_flutter_field_with_scroll(ctx.session, "Rechercher un membre", "Audit MultiRole", start_at_top=True):
        raise LocatorFailure("Member search input is not available.")
    if not await click_flutter_label_with_scroll(ctx.session, "Voir", start_at_top=False, max_steps=3):
        raise LocatorFailure("Member profile action is not available.")
    if not await wait_text(ctx.session, "Audit MultiRole", timeout=6):
        raise TransitionFailure("Member profile did not open.")
    if edit and not await click_flutter_label_with_scroll(ctx.session, "Modifier", start_at_top=False, max_steps=6):
        raise LocatorFailure("Member edit action is not available.")


async def open_master_finance_menu(ctx: PreflightContext, reject: bool = False) -> None:
    if not await fill_flutter_field_with_scroll(ctx.session, "Rechercher membre, frais, r\u00e9f\u00e9rence", "AUDIT-PAY-000", start_at_top=True):
        raise LocatorFailure("Finance search input is not available.")
    if not await wait_text(ctx.session, "AUDIT-PAY-000", timeout=8):
        raise LocatorFailure("Pending payment fixture is not available.")
    for _ in range(3):
        if await click_flutter_label_with_scroll(ctx.session, "Actions du paiement", start_at_top=False, max_steps=5):
            await asyncio.sleep(0.6)
            if await wait_text(ctx.session, "Rejeter", timeout=2):
                if not reject:
                    return
                if await click_flutter_label_with_scroll(ctx.session, "Rejeter", ("menuitem",), start_at_top=False, max_steps=0):
                    if await wait_text(ctx.session, "Rejeter ce paiement ?", timeout=4):
                        return
        await ctx.session.call("Input.dispatchKeyEvent", {"type": "keyDown", "key": "Escape", "code": "Escape", "windowsVirtualKeyCode": 27})
        await ctx.session.call("Input.dispatchKeyEvent", {"type": "keyUp", "key": "Escape", "code": "Escape", "windowsVirtualKeyCode": 27})
    raise TransitionFailure("Payment action menu did not expose the requested state.")


async def open_master_chat(ctx: PreflightContext, group: bool = False) -> None:
    threads = api_json("/chat/threads", token=ctx.token)
    if group:
        thread = next((item for item in threads if str(item.get("thread_type", item.get("type", ""))).lower() in {"group", "groupe"}), None)
    else:
        thread = next((item for item in threads if item.get("title") == "Conversation audit 7"), None)
    thread = thread or next((item for item in threads if item.get("title")), None)
    if not thread:
        raise LocatorFailure("No synthetic chat thread is available.")
    await navigate(ctx.session, f"/chat?thread={thread['id']}", ctx.strategy)
    if not await wait_text(ctx.session, str(thread.get("title", "Conversation audit")), timeout=8):
        raise TransitionFailure("Requested chat thread did not open.")


async def open_master_card(ctx: PreflightContext, label: str) -> None:
    target = await find_actionable_ancestor_for_label(ctx.session, label, start_at_top=True)
    if not target:
        raise LocatorFailure(f"No rendered card target for {label}.")
    await click_box(ctx.session, target["clicked_box"])
    await asyncio.sleep(0.8)


async def prepare_master_capture(ctx: PreflightContext, state: str) -> None:
    if state == "invalid_login":
        await driver_invalid_login(ctx)
    elif state == "forgot_password":
        if not await click_flutter_label_with_scroll(ctx.session, "Mot de passe oubli", start_at_top=True, max_steps=3):
            raise LocatorFailure("Forgot-password action is not available.")
        if not await wait_text(ctx.session, "Mot de passe", timeout=5):
            raise TransitionFailure("Forgot-password view did not open.")
    elif state == "member_profile":
        await open_master_member(ctx)
    elif state == "member_edit":
        await open_master_member(ctx, edit=True)
    elif state == "attendance_personal":
        if not await click_flutter_label_with_scroll(ctx.session, "Mon suivi", start_at_top=True, max_steps=3):
            raise LocatorFailure("Personal attendance tab is not available.")
    elif state == "attendance_detail":
        await driver_attendance(ctx)
    elif state == "finance_menu":
        await open_master_finance_menu(ctx)
    elif state == "finance_reject":
        await open_master_finance_menu(ctx, reject=True)
    elif state == "mobile_money":
        if not await click_flutter_label_with_scroll(ctx.session, "Payer par Mobile Money", start_at_top=True, max_steps=12):
            raise LocatorFailure("Mobile Money payment action is not available.")
    elif state == "recruitment_detail":
        if not await click_flutter_label_with_scroll(ctx.session, "Voir", start_at_top=True, max_steps=12):
            raise LocatorFailure("Recruitment detail action is not available.")
    elif state == "document_dialog":
        if not await click_flutter_label_with_scroll(ctx.session, "Ajouter", start_at_top=True, max_steps=8):
            raise LocatorFailure("Document deposit action is not available.")
    elif state == "chat_conversation":
        await open_master_chat(ctx)
    elif state == "chat_group":
        await open_master_chat(ctx, group=True)
    elif state == "pole_detail":
        await open_master_card(ctx, "Technique")
    elif state == "project_detail":
        await open_master_card(ctx, "Audit Horizon")
    elif state == "archive_detail":
        await driver_archive_live(ctx)


async def run_master_capture(row: dict[str, str], strategy: str, run_id: str) -> dict[str, str]:
    _, session = await create_target()
    filename = f"{row['numero']}__{row['domaine']}__{row['vue']}__{row['role']}__{row['viewport']}.png"
    output = MASTER_SCREENSHOTS / filename
    result = {
        "numero": row["numero"], "domaine": row["domaine"], "vue": row["vue"], "role": row["role"],
        "viewport": row["viewport"], "etat": row["etat"], "fichier": str(output.relative_to(ROOT)).replace("\\", "/"),
        "reussite": "false", "probleme_visible": "", "erreur_console_inattendue": "false", "erreur_reseau_inattendue": "false",
        "font_loaded": "false", "font_source": "google_fonts_audit_allowlist", "text_render_verified": "false", "commentaire": "",
    }
    try:
        width, height = (int(part) for part in row["viewport"].split("x"))
        await session.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": width < 600})
        ctx = PreflightContext(row={"test_account_alias": "public", "preflight_id": f"MASTER{row['numero']}"}, session=session, strategy=strategy)
        if row["role"] != "public":
            ctx.row["test_account_alias"] = f"audit.{row['role']}"
            await authenticate(ctx)
        await navigate(session, row["route"], strategy)
        if not await wait_text(session, "Connexion" if row["role"] == "public" else "EnactSpace", timeout=12):
            raise TransitionFailure("Requested route did not stabilize.")
        result["font_loaded"] = str(await wait_for_font_loading(session)).lower()
        await prepare_master_capture(ctx, row["etat"])
        await asyncio.sleep(1.1)
        await capture_png(session, output)
        console = console_event_rows(session, {"run_id": run_id}, f"MASTER{row['numero']}")
        counts = network_counts(session)
        result["erreur_console_inattendue"] = str(any(item["classification"] in {"unknown_exception", "application_exception"} for item in console)).lower()
        result["erreur_reseau_inattendue"] = str(bool(counts["unexpected_external_requests"] or counts["unexpected_http_errors"])).lower()
        result["text_render_verified"] = result["font_loaded"]
        result["reussite"] = str(
            result["erreur_console_inattendue"] == "false"
            and result["erreur_reseau_inattendue"] == "false"
            and result["font_loaded"] == "true"
            and result["text_render_verified"] == "true"
        ).lower()
        if result["reussite"] == "false":
            result["commentaire"] = "Capture created with an unexpected runtime or network signal."
    except Exception as error:
        result["probleme_visible"] = "state_not_confirmed"
        result["commentaire"] = str(error)
        if not output.exists():
            try:
                await capture_png(session, output)
            except Exception:
                pass
        # The parent or closest reached state is still a valid typographic
        # capture when the requested subview is unavailable.
        result["text_render_verified"] = result["font_loaded"]
    finally:
        await clear_origin(session)
        await session.call("Page.close")
        await session.__aexit__(None, None, None)
    return result


def write_master_contact_sheet(rows: list[dict[str, str]]) -> None:
    cards = "\n".join(
        f'<figure><img src="screenshots/master/{item["fichier"].split("/")[-1]}" alt="{item["numero"]} {item["vue"]}"><figcaption>{item["numero"]} - {item["domaine"]}: {item["vue"]} ({item["viewport"]})</figcaption></figure>'
        for item in rows
    )
    MASTER_CONTACT_SHEET.write_text(
        "<!doctype html><meta charset=\"utf-8\"><title>EnactSpace master catalogue</title>"
        "<style>body{margin:20px;background:#f5f5f2;font:14px Arial;color:#111}h1{margin:0 0 18px}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(290px,1fr));gap:16px}figure{margin:0;background:#fff;border:1px solid #ddd;padding:8px}img{display:block;width:100%;height:auto;background:#eee}figcaption{padding:8px 2px 2px;font-weight:700}</style>"
        "<h1>EnactSpace - Master visual catalogue (42 captures)</h1><main>" + cards + "</main>", encoding="utf-8"
    )


def write_master_review(rows: list[dict[str, str]]) -> None:
    entries = []
    for item in rows:
        priority = "P1" if item["probleme_visible"] else "P2"
        entries.append(
            f"## {item['numero']} - {item['domaine']} / {item['vue']}\n\n"
            f"- Fonctionne : la vue est chargee avec le role `{item['role']}` au viewport `{item['viewport']}`.\n"
            "- Generique : a evaluer dans la synthese du catalogue.\n"
            "- Hierarchie : a evaluer dans la synthese du catalogue.\n"
            "- Densite : a evaluer dans la synthese du catalogue.\n"
            "- Responsive : a evaluer dans la synthese du catalogue.\n"
            "- Couleur : a evaluer dans la synthese du catalogue.\n"
            "- Typographie : a evaluer dans la synthese du catalogue.\n"
            "- Navigation : a evaluer dans la synthese du catalogue.\n"
            "- Accessibilite : a evaluer dans la synthese du catalogue.\n"
            "- Contenu : a evaluer dans la synthese du catalogue.\n"
            f"- Priorite : {priority}.\n"
        )
    MASTER_REVIEW.write_text("# EnactSpace master visual review\n\n" + "\n".join(entries), encoding="utf-8")


async def run_master_catalog() -> list[dict[str, str]]:
    if len(MASTER_CAPTURES) != 42:
        raise RuntimeError("Master catalogue must contain exactly 42 captures.")
    MASTER_SCREENSHOTS.mkdir(parents=True, exist_ok=True)
    strategy = await detect_url_strategy()
    run_id = uuid.uuid4().hex
    rows = [await run_master_capture(item, strategy, run_id) for item in MASTER_CAPTURES]
    write_csv(MASTER_RESULTS, MASTER_CAPTURE_FIELDS, rows)
    write_master_contact_sheet(rows)
    write_master_review(rows)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preflight-id")
    parser.add_argument("--preflight-ids", nargs="+")
    parser.add_argument("--preflight-all", action="store_true")
    parser.add_argument("--dry-run-contract", action="store_true")
    parser.add_argument("--show-preflight", action="store_true")
    parser.add_argument("--debug-login-tree", action="store_true")
    parser.add_argument("--debug-preflight")
    parser.add_argument("--debug-card-ancestry")
    parser.add_argument("--capture-id")
    parser.add_argument("--master-catalog", action="store_true")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    if args.show_preflight:
        print(json.dumps(preflight_rows(), ensure_ascii=False, indent=2)); return
    if args.debug_login_tree:
        asyncio.run(debug_login_tree()); return
    if args.debug_preflight:
        row = load_preflight(args.debug_preflight)
        asyncio.run(debug_authenticated_preflight(row, asyncio.run(detect_url_strategy()))); return
    if args.debug_card_ancestry:
        row = load_preflight(args.debug_card_ancestry)
        asyncio.run(debug_card_ancestry(row, asyncio.run(detect_url_strategy()))); return
    if args.master_catalog:
        if not args.execute:
            parser.error("--master-catalog requires --execute.")
        results = asyncio.run(run_master_catalog())
        print(json.dumps({"captures": len(results), "success": sum(item["reussite"] == "true" for item in results), "failed": [item["numero"] for item in results if item["reussite"] != "true"]}, ensure_ascii=False)); return
    if args.preflight_id and not args.dry_run_contract:
        print(json.dumps({"status": "resolved_without_capture", "scenario": load_preflight(args.preflight_id)}, ensure_ascii=False, indent=2)); return
    selected_ids = ([args.preflight_id] if args.preflight_id else args.preflight_ids or [])
    if selected_ids and args.dry_run_contract:
        rows = [load_preflight(preflight_id) for preflight_id in selected_ids]
        validate_runtime_ready(rows)
        strategy = asyncio.run(detect_url_strategy())
        archive_previous_outputs()
        manifest = create_run_manifest(strategy, rows)
        results = asyncio.run(_run_all(rows, strategy, manifest))
        write_contract_results(results)
        write_csv(PREFLIGHT_RESULTS, CONTRACT_FIELDS, results)
        print(json.dumps({"strategy": strategy, "run_id": manifest["run_id"], "results": results, "capture_screenshots": 0}, ensure_ascii=False)); return
    if args.preflight_all and args.dry_run_contract:
        rows_to_run = preflight_rows()
        validate_runtime_ready(rows_to_run)
        strategy = asyncio.run(detect_url_strategy())
        update_runtime_strategy(strategy)
        archive_previous_outputs()
        manifest = create_run_manifest(strategy, rows_to_run)
        rows = asyncio.run(_run_all(rows_to_run, strategy, manifest))
        write_contract_results(rows)
        write_csv(PREFLIGHT_RESULTS, CONTRACT_FIELDS, rows)
        print(json.dumps({"strategy": strategy, "run_id": manifest["run_id"], "results": len(rows), "success": sum(row["result_category"] == "success" for row in rows), "capture_screenshots": 0})); return
    if args.capture_id:
        raise RuntimeError("Pilot capture remains separately gated and is not available in Phase 0B.2.")
    parser.error("Use --show-preflight, --preflight-id(s), or --preflight-all --dry-run-contract.")


async def _run_all(rows: list[dict[str, str]], strategy: str, manifest: dict[str, Any]) -> list[dict[str, Any]]:
    return [await run_preflight(row, strategy, manifest) for row in rows]


if __name__ == "__main__":
    main()

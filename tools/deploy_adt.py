#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Deploy mot source ABAP tu repo len he SAP qua ADT REST (bridge ADT-over-RFC).

    LOCK -> PUT source (kem corrNr) -> ACTIVATE -> UNLOCK

Vi sao khong dung MCP: cac tool MCP khong nhan duoc corrNr nen object sua
xong nam ngoai transport, va khong tra ve message activate day du.

Dung:
    python tools/deploy_adt.py <adt_path> <file> [--tr S25K900150] [--no-activate]
    python tools/deploy_adt.py --check <adt_path> <file>      # chi syntax check

<adt_path> viet KHONG co tien to /sap/bc/adt/ va KHONG co dau / dau dong,
de Git Bash khong doi thanh C:/Program Files/Git/... (bug MSYS path conv):

    oo/classes/zcl_hddt_gom
    oo/interfaces/zif_hddt_types
    programs/includes/zin_hddt_integration_f01
    programs/programs/zpg_hddt_integration

Bien moi truong:
    ZPK_BRIDGE   mac dinh http://127.0.0.1:8410 (he MAG_S25_100)
"""
import base64
import os
import re
import sys
import urllib.error
import urllib.request
import urllib.parse as up

BRIDGE = os.environ.get("ZPK_BRIDGE", "http://127.0.0.1:8410")
PREFIX = "/sap/bc/adt/"
DEFAULT_TR = "S25K900150"


def call(method, path, body=None, ctype="application/xml", accept="*/*"):
    data = body.encode("utf-8") if isinstance(body, str) else body
    req = urllib.request.Request(BRIDGE + path, data=data, method=method,
                                 headers={"Content-Type": ctype, "Accept": accept})
    try:
        r = urllib.request.urlopen(req)
        return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")


def short(b):
    m = re.search(r"<message lang=\"EN\">(.*?)</message>", b, re.S)
    return re.sub(r"\s+", " ", m.group(1) if m else b[:400])


def lock(uri):
    c, b = call("POST", uri + "?_action=LOCK&accessMode=MODIFY", "",
                ctype="application/x-www-form-urlencoded",
                accept="application/vnd.sap.as+xml;charset=UTF-8;"
                       "dataname=com.sap.adt.lock.Result")
    if c != 200:
        return None, "%s %s" % (c, short(b))
    m = (re.search(r"<LOCK_HANDLE>(.*?)</LOCK_HANDLE>", b, re.S)
         or re.search(r"lockHandle[^>]*>([^<]+)<", b))
    return (m.group(1) if m else None), b[:300]


def unlock(uri, handle):
    return call("POST", uri + "?_action=UNLOCK&lockHandle="
                + up.quote(handle, safe=""), "")


def put_source(uri, handle, text, tr):
    q = "%s/source/main?lockHandle=%s&corrNr=%s" % (uri, up.quote(handle, safe=""), tr)
    return call("PUT", q, text, ctype="text/plain; charset=utf-8")


def activate(name, uri):
    body = ('<?xml version="1.0" encoding="UTF-8"?>'
            '<adtcore:objectReferences xmlns:adtcore="http://www.sap.com/adt/core">'
            '<adtcore:objectReference adtcore:uri="%s" adtcore:name="%s"/>'
            '</adtcore:objectReferences>' % (uri, name.upper()))
    return call("POST", "/sap/bc/adt/activation?method=activate&preauditRequested=true",
                body, ctype="application/xml", accept="application/xml")


def syntax_check(uri, text):
    """Kiem cu phap MA KHONG ghi gi len he: source di trong body, base64."""
    body = ('<?xml version="1.0" encoding="UTF-8"?>'
            '<chkrun:checkObjectList xmlns:adtcore="http://www.sap.com/adt/core" '
            'xmlns:chkrun="http://www.sap.com/adt/checkrun">'
            '<chkrun:checkObject adtcore:uri="%s" chkrun:version="active">'
            '<chkrun:artifacts><chkrun:artifact '
            'chkrun:contentType="text/plain; charset=utf-8" chkrun:uri="%s/source/main">'
            '<chkrun:content>%s</chkrun:content>'
            '</chkrun:artifact></chkrun:artifacts>'
            '</chkrun:checkObject></chkrun:checkObjectList>'
            % (uri, uri, base64.b64encode(text.encode("utf-8")).decode()))
    return call("POST", "/sap/bc/adt/checkruns?reporters=abapCheckRun", body,
                ctype="application/vnd.sap.adt.checkobjects+xml",
                accept="application/vnd.sap.adt.checkmessages+xml")


def print_msgs(b):
    """In message cua activate / checkrun, tra ve so loi nghiem trong."""
    seen = []
    for m in re.finditer(r'type="([EAWI])"[^>]*?shortText="([^"]*)"', b):
        seen.append((m.group(1), m.group(2)))
    for m in re.finditer(r'<msg[^>]*type="([EAWI])"[^>]*>.*?<txt>(.*?)</txt>', b, re.S):
        seen.append((m.group(1), m.group(2)))
    for t, s in seen:
        print("    %s %s" % (t, re.sub(r"\s+", " ", s)[:200]))
    return len([t for t, _ in seen if t in ("E", "A")])


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    only_check = "--check" in argv
    do_act = "--no-activate" not in argv
    tr = DEFAULT_TR
    if "--tr" in argv:
        tr = argv[argv.index("--tr") + 1]
        args = [a for a in args if a != tr]

    if len(args) < 2:
        print(__doc__)
        return 2

    uri = PREFIX + args[0].lstrip("/")
    path = args[1]
    name = uri.rstrip("/").split("/")[-1]
    text = open(path, encoding="utf-8").read()
    size = len(text.encode("utf-8"))

    if only_check:
        c, b = syntax_check(uri, text)
        print("CHECK %s (%d bytes) -> HTTP %s" % (name, size, c))
        if c != 200:
            print("   ", short(b))
            return 1
        return 1 if print_msgs(b) else 0

    handle, info = lock(uri)
    if not handle:
        print("LOCK that bai:", info)
        return 1
    print("LOCK  %s ok" % name)

    rc = 0
    try:
        c, b = put_source(uri, handle, text, tr)
        print("PUT   %s (%d bytes) -> HTTP %s %s"
              % (name, size, c, "" if c in (200, 201) else short(b)))
        if c not in (200, 201):
            rc = 1
        elif do_act:
            c, b = activate(name, uri)
            print("ACTIV %s -> HTTP %s" % (name, c))
            if print_msgs(b):
                rc = 1
    finally:
        c2, _ = unlock(uri, handle)
        print("UNLOCK %s -> HTTP %s" % (name, c2))

    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

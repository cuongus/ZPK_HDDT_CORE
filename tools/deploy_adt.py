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
DEFAULT_TR = "S25K900131"


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


def enqu_payload(path, package):
    """Doi file abapGit <ten>.enqu.xml sang XML ADT cua lock object.

    Mot nguon su that: DD25V/DD27P trong repo, khong khai lai o day.
    """
    x = open(path, encoding="utf-8").read()

    def one(tag):
        m = re.search(r"<%s>(.*?)</%s>" % (tag, tag), x, re.S)
        return m.group(1).strip() if m else ""

    name = one("VIEWNAME")
    tab = one("ROOTTAB")
    descr = one("DDTEXT")
    # Truong khoa = cac dong DD27P co KEYFLAG; dong FIELDNAME='*' la dong
    # che do khoa, khong phai tham so
    fields = []
    for blk in re.findall(r"<DD27P>(.*?)</DD27P>", x, re.S):
        if "<KEYFLAG>X</KEYFLAG>" not in blk:
            continue
        m = re.search(r"<FIELDNAME>(.*?)</FIELDNAME>", blk, re.S)
        if m and m.group(1).strip() != "*":
            fields.append(m.group(1).strip())

    params = "".join(
        "<enqu:lockParameter>"
        "<enqu:parameterWanted>true</enqu:parameterWanted>"
        "<enqu:parameterName>%s</enqu:parameterName>"
        "<enqu:tableName>%s</enqu:tableName>"
        "<enqu:fieldName>%s</enqu:fieldName>"
        "</enqu:lockParameter>" % (f, tab, f) for f in fields)

    body = ('<?xml version="1.0" encoding="UTF-8"?>'
            '<enqu:lockobject xmlns:enqu="http://www.sap.com/adt/ddic/enqu" '
            'xmlns:adtcore="http://www.sap.com/adt/core" '
            'adtcore:name="%s" adtcore:type="ENQU/DL" '
            'adtcore:description="%s" adtcore:masterLanguage="EN">'
            '<adtcore:packageRef adtcore:name="%s"/>'
            '<enqu:content>'
            '<enqu:allowRFC>false</enqu:allowRFC>'
            '<enqu:primaryTable><enqu:tableName>%s</enqu:tableName>'
            '<enqu:lockMode>E</enqu:lockMode></enqu:primaryTable>'
            '<enqu:secondaryTables/>'
            '<enqu:lockParameters>%s</enqu:lockParameters>'
            '</enqu:content></enqu:lockobject>'
            % (name, descr, package, tab, params))
    return name, body, fields


def dtel_payload(path, package):
    """Doi file abapGit <ten>.dtel.xml sang XML ADT cua data element.

    Mot nguon su that: DD04V trong repo. Chi ho tro DTEL dua tren DOMAIN
    (DOMNAME), la dang duy nhat package nay dung cho co checkbox.
    """
    x = open(path, encoding="utf-8").read()

    def one(tag, default=""):
        m = re.search(r"<%s>(.*?)</%s>" % (tag, tag), x, re.S)
        return m.group(1).strip() if m else default

    name, dom = one("ROLLNAME"), one("DOMNAME")
    if not dom:
        raise ValueError("%s: chi ho tro data element dua tren domain" % name)

    def esc(s):
        return (s.replace("&", "&amp;").replace("<", "&lt;")
                 .replace(">", "&gt;").replace('"', "&quot;"))

    s, m, lg, h = (one("SCRTEXT_S"), one("SCRTEXT_M"),
                   one("SCRTEXT_L"), one("REPTEXT"))

    # Kieu/do dai lay tu chinh DOMAIN tren he, khong doan: ADT bat buoc
    # phai co dataType / dataTypeLength / dataTypeDecimals
    c, d = call("GET", PREFIX + "ddic/domains/" + dom.lower(),
                accept="application/*")
    if c != 200:
        raise ValueError("%s: khong doc duoc domain %s (HTTP %s)" % (name, dom, c))
    dget = lambda t: (re.search(r"<doma:%s>(.*?)</doma:%s>" % (t, t), d, re.S)
                      or re.search(r"<%s>(.*?)</%s>" % (t, t), d, re.S))
    dtype = dget("datatype").group(1).strip()
    dlen = dget("length").group(1).strip()
    ddec = dget("decimals").group(1).strip()

    body = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<blue:wbobj xmlns:blue="http://www.sap.com/wbobj/dictionary/dtel" '
        'xmlns:adtcore="http://www.sap.com/adt/core" '
        'adtcore:name="%s" adtcore:type="DTEL/DE" '
        'adtcore:description="%s" adtcore:masterLanguage="EN">'
        '<adtcore:packageRef adtcore:name="%s"/>'
        '<dtel:dataElement xmlns:dtel="http://www.sap.com/adt/dictionary/dataelements">'
        '<dtel:typeKind>domain</dtel:typeKind>'
        '<dtel:typeName>%s</dtel:typeName>'
        '<dtel:dataType>%s</dtel:dataType>'
        '<dtel:dataTypeLength>%s</dtel:dataTypeLength>'
        '<dtel:dataTypeDecimals>%s</dtel:dataTypeDecimals>'
        '<dtel:shortFieldLabel>%s</dtel:shortFieldLabel>'
        '<dtel:shortFieldLength>%02d</dtel:shortFieldLength>'
        '<dtel:shortFieldMaxLength>10</dtel:shortFieldMaxLength>'
        '<dtel:mediumFieldLabel>%s</dtel:mediumFieldLabel>'
        '<dtel:mediumFieldLength>%02d</dtel:mediumFieldLength>'
        '<dtel:mediumFieldMaxLength>20</dtel:mediumFieldMaxLength>'
        '<dtel:longFieldLabel>%s</dtel:longFieldLabel>'
        '<dtel:longFieldLength>%02d</dtel:longFieldLength>'
        '<dtel:longFieldMaxLength>40</dtel:longFieldMaxLength>'
        '<dtel:headingFieldLabel>%s</dtel:headingFieldLabel>'
        '<dtel:headingFieldLength>%02d</dtel:headingFieldLength>'
        '<dtel:headingFieldMaxLength>55</dtel:headingFieldMaxLength>'
        # Schema ADT bat buoc du ca cac phan tu duoi, ke ca khi rong
        '<dtel:searchHelp/>'
        '<dtel:searchHelpParameter/>'
        '<dtel:setGetParameter/>'
        '<dtel:defaultComponentName/>'
        '<dtel:deactivateInputHistory>false</dtel:deactivateInputHistory>'
        '<dtel:changeDocument>false</dtel:changeDocument>'
        '<dtel:leftToRightDirection>false</dtel:leftToRightDirection>'
        '<dtel:deactivateBIDIFiltering>false</dtel:deactivateBIDIFiltering>'
        '</dtel:dataElement></blue:wbobj>'
        % (name, esc(one("DDTEXT")), package, dom, dtype, dlen, ddec,
           esc(s), len(s), esc(m), len(m), esc(lg), len(lg), esc(h), len(h)))
    return name, body


def deploy_dtel(path, tr, package):
    """Tao data element moi (POST vao collection) roi activate."""
    coll = PREFIX + "ddic/dataelements"
    name, body = dtel_payload(path, package)
    uri = "%s/%s" % (coll, name.lower())

    ct = "application/vnd.sap.adt.dataelements.v2+xml"

    c, _ = call("GET", uri, accept="application/*")
    if c != 200:
        c, b = call("POST", coll + "?corrNr=" + tr, body, ctype=ct,
                    accept="application/*")
        print("DTEL  %-16s CREATE -> HTTP %s %s"
              % (name, c, "" if c in (200, 201) else short(b)))
        if c not in (200, 201):
            return 1

    # POST chi tao KHUNG: nhan truong khong duoc luu (DD04T rong) va
    # description lay theo package. Phai PUT lai noi dung day du.
    handle, info = lock(uri)
    if not handle:
        print("DTEL  %-16s LOCK that bai: %s" % (name, info))
        return 1
    c, b = call("PUT", "%s?lockHandle=%s&corrNr=%s"
                % (uri, up.quote(handle, safe=""), tr), body,
                ctype=ct, accept="application/*")
    print("DTEL  %-16s PUT nhan -> HTTP %s %s"
          % (name, c, "" if c in (200, 201) else short(b)))
    unlock(uri, handle)
    if c not in (200, 201):
        return 1

    c, b = call("POST", PREFIX + "activation?method=activate"
                "&preauditRequested=true",
                '<?xml version="1.0" encoding="UTF-8"?>'
                '<adtcore:objectReferences '
                'xmlns:adtcore="http://www.sap.com/adt/core">'
                '<adtcore:objectReference adtcore:uri="%s" adtcore:name="%s"/>'
                '</adtcore:objectReferences>' % (uri, name),
                ctype="application/xml", accept="application/xml")
    ok = 'activationExecuted="true"' in b
    print("DTEL  %-16s ACTIVATE -> HTTP %s %s"
          % (name, c, "ok" if ok else short(b)))
    return 0 if ok else 1


def deploy_enqu(path, tr, package):
    """Tao lock object moi (POST vao collection) roi activate."""
    coll = PREFIX + "ddic/lockobjects/sources"
    name, body, fields = enqu_payload(path, package)
    uri = "%s/%s" % (coll, name.lower())

    c, _ = call("GET", uri, accept="application/*")
    if c == 200:
        print("ENQU  %-14s da ton tai, bo qua" % name)
        return 0

    # Content-Type lay tu chinh app:accept cua collection trong
    # /sap/bc/adt/discovery — doan ten thi tra 415 Unsupported Media Type
    c, b = call("POST", coll + "?corrNr=" + tr, body,
                ctype="application/vnd.sap.adt.lockobjects.v1+xml",
                accept="application/*")
    print("ENQU  %-14s CREATE -> HTTP %s %s  (doi so: %s)"
          % (name, c, "" if c in (200, 201) else short(b), ", ".join(fields)))
    if c not in (200, 201):
        return 1

    c, b = call("POST", PREFIX + "activation?method=activate"
                "&preauditRequested=true",
                '<?xml version="1.0" encoding="UTF-8"?>'
                '<adtcore:objectReferences '
                'xmlns:adtcore="http://www.sap.com/adt/core">'
                '<adtcore:objectReference adtcore:uri="%s" adtcore:name="%s"/>'
                '</adtcore:objectReferences>' % (uri, name),
                ctype="application/xml", accept="application/xml")
    ok = 'activationExecuted="true"' in b
    print("ENQU  %-14s ACTIVATE -> HTTP %s %s"
          % (name, c, "ok" if ok else short(b)))
    return 0 if ok else 1


def deploy_tabl(path, tr, package):
    """Tao bang moi: POST vao collection de dung khung, roi LOCK -> PUT
    DDL day du -> UNLOCK -> ACTIVATE. Giong duong cua data element: POST
    chi tao vo, noi dung that phai PUT qua /source/main."""
    name = os.path.basename(path).split(".")[0].upper()
    ddl = open(path, encoding="utf-8").read()
    uri = "/sap/bc/adt/ddic/tables/" + name.lower()

    c, b = call("GET", uri, accept="application/*")
    if c == 200:
        print("TABL  %-16s da co, chi cap nhat" % name)
    else:
        body = ('<?xml version="1.0" encoding="UTF-8"?>'
                '<blue:blueSource xmlns:blue="http://www.sap.com/wbobj/blue" '
                'xmlns:adtcore="http://www.sap.com/adt/core" '
                'adtcore:type="TABL/DT" adtcore:name="%s" '
                'adtcore:description="%s" adtcore:masterLanguage="EN">'
                '<adtcore:packageRef adtcore:name="%s"/>'
                '</blue:blueSource>' % (name, _label_of(ddl), package))
        c, b = call("POST", "/sap/bc/adt/ddic/tables?corrNr=" + tr, body,
                    ctype="application/vnd.sap.adt.tables.v2+xml",
                    accept="application/*")
        print("TABL  %-16s CREATE -> HTTP %s %s"
              % (name, c, "" if c in (200, 201) else short(b)))
        if c not in (200, 201):
            return 1

    handle, info = lock(uri)
    if not handle:
        print("LOCK that bai:", info)
        return 1
    try:
        c, b = put_source(uri, handle, ddl, tr)
        print("TABL  %-16s PUT DDL -> HTTP %s %s"
              % (name, c, "" if c in (200, 201) else short(b)))
        rc = 0 if c in (200, 201) else 1
    finally:
        unlock(uri, handle)

    if rc == 0:
        c, b = activate(name, uri)
        print("TABL  %-16s ACTIVATE -> HTTP %s %s"
              % (name, c, "ok" if 'activationExecuted="true"' in b else short(b)))
        if print_msgs(b):
            rc = 1
    return rc


def _label_of(ddl):
    m = re.search(r"@EndUserText\.label\s*:\s*'([^']*)'", ddl)
    return (m.group(1) if m else "").replace("&", "&amp;").replace("<", "&lt;")


def create_clas(name, tr, package, descr):
    """Tao vo class neu chua co. Noi dung that van PUT qua /source/main
    nhu moi object khac."""
    uri = "/sap/bc/adt/oo/classes/" + name.lower()
    c, _ = call("GET", uri, accept="application/*")
    if c == 200:
        return 0
    body = ('<?xml version="1.0" encoding="UTF-8"?>'
            '<class:abapClass xmlns:class="http://www.sap.com/adt/oo/classes" '
            'xmlns:adtcore="http://www.sap.com/adt/core" '
            'adtcore:type="CLAS/OC" adtcore:name="%s" '
            'adtcore:description="%s" adtcore:masterLanguage="EN" '
            'class:final="false" class:visibility="public">'
            '<adtcore:packageRef adtcore:name="%s"/>'
            '</class:abapClass>' % (name, descr, package))
    c, b = call("POST", "/sap/bc/adt/oo/classes?corrNr=" + tr, body,
                ctype="application/vnd.sap.adt.oo.classes.v4+xml",
                accept="application/*")
    print("CLAS  %-18s CREATE -> HTTP %s %s"
          % (name, c, "" if c in (200, 201) else short(b)))
    return 0 if c in (200, 201) else 1


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


def activate_many(paths):
    """Activate NHIEU object trong MOT lan goi.

    Chuong trinh + include phai activate cung nhau: activate rieng thi
    include con inactive, ban active cu van duoc dich -> bao 'Field ...
    is unknown' cua chinh field vua them.
    """
    refs = "".join(
        '<adtcore:objectReference adtcore:uri="%s" adtcore:name="%s"/>'
        % (PREFIX + p.lstrip("/"), p.rstrip("/").split("/")[-1].upper())
        for p in paths)
    body = ('<?xml version="1.0" encoding="UTF-8"?>'
            '<adtcore:objectReferences '
            'xmlns:adtcore="http://www.sap.com/adt/core">%s'
            '</adtcore:objectReferences>' % refs)
    c, b = call("POST", PREFIX + "activation?method=activate"
                "&preauditRequested=true", body,
                ctype="application/xml", accept="application/xml")
    print("ACTIVATE %d object -> HTTP %s" % (len(paths), c))
    bad = print_msgs(b)
    if not bad and 'activationExecuted="true"' in b:
        print("    activationExecuted = true")
        return 0
    # HTTP 200 KHONG co nghia la da activate: sai URI hoac loi cu phap deu
    # tra 200 kem activationExecuted="false". Phai noi ra, khong thi nguoi
    # chay tuong da xong trong khi ban active tren he van la ban cu.
    if 'activationExecuted="true"' not in b:
        print("    CHU Y: activationExecuted khong phai true - CHUA activate."
              " Kiem lai URI (phai la duong day du, vd programs/includes/<ten>)")
    return 1


def deploy_xml(uri_rel, path, ctype, tr):
    """Object ADT luu bang XML chu khong co /source/main (domain, ...):
    LOCK -> PUT nguyen XML -> UNLOCK -> ACTIVATE. XML lay tu GET cua chinh
    object tren he roi sua, de khong mat truong nao he dang giu."""
    uri = PREFIX + uri_rel.lstrip("/")
    name = uri.rstrip("/").split("/")[-1]
    body = open(path, encoding="utf-8").read()
    handle, info = lock(uri)
    if not handle:
        print("LOCK that bai:", info)
        return 1
    try:
        q = "%s?lockHandle=%s&corrNr=%s" % (uri, up.quote(handle, safe=""), tr)
        c, b = call("PUT", q, body, ctype=ctype, accept="application/*")
        print("PUT   %s -> HTTP %s %s" % (name, c, "" if c in (200, 201) else short(b)))
        rc = 0 if c in (200, 201) else 1
    finally:
        unlock(uri, handle)
    if rc == 0:
        c, b = activate(name, uri)
        ok = 'activationExecuted="true"' in b
        print("ACTIV %s -> HTTP %s %s" % (name, c, "ok" if ok else "CHUA activate"))
        if print_msgs(b) or not ok:
            rc = 1
    return rc


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    if args and args[0] == "activate":
        return activate_many(args[1].split(","))
    if args and args[0] == "xml":
        tr = argv[argv.index("--tr") + 1] if "--tr" in argv else DEFAULT_TR
        return deploy_xml(args[1], args[2], args[3], tr)
    only_check = "--check" in argv
    do_act = "--no-activate" not in argv
    tr = DEFAULT_TR
    if "--tr" in argv:
        tr = argv[argv.index("--tr") + 1]
        args = [a for a in args if a != tr]

    if len(args) < 2:
        print(__doc__)
        return 2

    # Lock object khong co /source/main, va tao moi bang POST vao
    # collection -> di duong rieng
    if args[0].rstrip("/").endswith("ddic/lockobjects") or args[1].endswith(".enqu.xml"):
        return deploy_enqu(args[1], tr, args[2] if len(args) > 2 else "ZPK_INT_HDDT")
    if args[1].endswith(".tabl.ddl"):
        return deploy_tabl(args[1], tr,
                           args[2] if len(args) > 2 else "ZPK_INT_HDDT")
    if args[1].endswith(".dtel.xml"):
        return deploy_dtel(args[1], tr, args[2] if len(args) > 2 else "ZPK_INT_HDDT")

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

    if "/oo/classes/" in uri:
        # Mo ta ngan cua class lay dong "Mo ta chung" cua header (toi da 60
        # ky tu). Ban truoc lay nham dong "Ten/Ma" nen mo ta = chinh ten class.
        d = re.search(r"^\* Mô tả chung\s*:\s*(.+)$", text, re.M)
        descr = d.group(1).strip()[:60] if d else name.upper()
        descr = descr.replace("&", "&amp;").replace("<", "&lt;").replace('"', "&quot;")
        if create_clas(name.upper(), tr,
                       args[2] if len(args) > 2 else "ZPK_INT_HDDT",
                       descr):
            return 1

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
    finally:
        c2, _ = unlock(uri, handle)
        print("UNLOCK %s -> HTTP %s" % (name, c2))

    # Activate SAU khi nha khoa: activate trong luc object con khoa tra
    # HTTP 403, khong phai loi quyen.
    if rc == 0 and do_act:
        c, b = activate(name, uri)
        print("ACTIV %s -> HTTP %s" % (name, c))
        if print_msgs(b):
            rc = 1
        elif 'activationExecuted="true"' not in b:
            print("    CHU Y: activationExecuted khong phai true")
            rc = 1

    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

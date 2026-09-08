# -*- coding: utf-8 -*-
"""Kiểm tra tĩnh source ABAP trong src/ trước khi tạo tay trên hệ SAP.

Soát các lỗi mà ADT / SE24 sẽ báo khi activate:
  A. Method khai báo nhưng chưa hiện thực (và ngược lại)
  B. Method của interface chưa hiện thực trong cây thừa kế
  C. Khối lệnh không khớp (IF/ENDIF, LOOP/ENDLOOP, CASE/ENDCASE, TRY/ENDTRY...)
  D. RETURNING / EXPORTING / CHANGING dùng kiểu generic
  E. Comment thường trong phần DEFINITION của class (ADT không lưu được)
  F. CLASS_CONSTRUCTOR không nằm ở PUBLIC SECTION
  G. Ký tự { } chưa escape trong string template
  H. Tham chiếu hằng số / kiểu của interface không tồn tại
  I. Gọi method tĩnh của class trong package nhưng method không tồn tại
  J. ABAP Doc đứng trước khai báo chuỗi (ADT báo sai vị trí)
  K. DATA() suy ra P(8,0) từ biểu thức số học (mất phần thập phân)
  L. POSIX regex đã deprecated, phải dùng PCRE
  M. ORDER BY dùng cột không có trong danh sách SELECT

Chạy: python tools/check_abap.py
"""
import glob
import io
import os
import re
import sys

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FIND = []


def report(kind, path, line, text):
    FIND.append((kind, path.replace("\\", "/"), line, text))


# ---------------------------------------------------------------------------
# Tách câu lệnh: bỏ comment, ghép dòng nối, cắt theo dấu chấm kết thúc lệnh
# ---------------------------------------------------------------------------
def statements(text):
    """[(dòng bắt đầu, câu lệnh 1 dòng)] — bỏ comment, giữ literal nguyên vẹn."""
    out, buf, start = [], "", 1
    line, i, n = 1, 0, len(text)
    quote = None          # "'" hoặc "`" đang mở
    tmpl = False          # đang trong |...|
    depth = 0             # độ sâu { } trong template
    while i < n:
        ch = text[i]
        if ch == "\n":
            line += 1
            buf += " "
            i += 1
            continue
        if ch not in " \t" and not buf.strip():
            start = line                           # dòng của token đầu câu lệnh
        if quote:
            buf += ch
            if ch == quote:
                quote = None
            i += 1
            continue
        if tmpl:
            buf += ch
            if ch == "\\":
                if i + 1 < n:
                    buf += text[i + 1]
                i += 2
                continue
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
            elif ch == "|" and depth <= 0:
                tmpl = False
            i += 1
            continue
        # ngoài literal
        if ch == '"':                                  # comment cuối dòng
            while i < n and text[i] != "\n":
                i += 1
            continue
        if ch == "*" and (not buf.strip()) and (i == 0 or text[i - 1] == "\n"):
            while i < n and text[i] != "\n":           # comment cả dòng
                i += 1
            continue
        if ch in "'`":
            quote = ch
            buf += ch
            i += 1
            continue
        if ch == "|":
            tmpl, depth = True, 0
            buf += ch
            i += 1
            continue
        if ch == ".":
            s = " ".join(buf.split())
            if s:
                out.append((start, s))
            buf, start = "", line
            i += 1
            continue
        buf += ch
        i += 1
    s = " ".join(buf.split())
    if s:
        out.append((start, s))
    return out


def first_word(s):
    return s.split(" ")[0].upper() if s else ""


# ---------------------------------------------------------------------------
# Đọc interface: method, hằng số, kiểu
# ---------------------------------------------------------------------------
INTF = {}       # ZIF_X -> {"methods": set, "consts": set, "types": set}


def read_intf(path):
    name = os.path.basename(path).split(".")[0].upper()
    text = io.open(path, encoding="utf-8").read()
    meth, consts, types = set(), set(), set()
    struct = None
    for _, s in statements(text):
        w = first_word(s)
        u = s.upper()
        if w in ("METHODS", "CLASS-METHODS"):
            meth.add(s.split(" ")[1].lower().rstrip(":"))
        elif w in ("CONSTANTS", "TYPES", "CONSTANTS:", "TYPES:"):
            m = re.match(r"(?:CONSTANTS|TYPES):?\s+BEGIN OF (\w+)", u)
            if m:
                struct = m.group(1).lower()
                (consts if w.startswith("CONSTANTS") else types).add(struct)
                # thành phần khai báo trong cùng câu lệnh (chuỗi dài 1 lệnh)
                for f in re.findall(r"(\w+)\s+TYPE\b", s[m.end():]):
                    (consts if w.startswith("CONSTANTS") else types).add(
                        struct + "-" + f.lower())
                if "END OF" in u:
                    struct = None
            else:
                m = re.match(r"(?:CONSTANTS|TYPES):?\s+(\w+)", s)
                if m:
                    (consts if w.startswith("CONSTANTS") else types).add(
                        m.group(1).lower())
        elif w == "INTERFACES":
            for other in s.split(" ")[1:]:
                key = other.strip(".").upper()
                if key in INTF:
                    meth |= {key.lower() + "~" + x for x in INTF[key]["methods"]}
    INTF[name] = {"methods": meth, "consts": consts, "types": types}


# ---------------------------------------------------------------------------
# Đọc class
# ---------------------------------------------------------------------------
CLS = {}        # ZCL_X -> dict


def read_class(path):
    name = os.path.basename(path).split(".")[0].upper()
    text = io.open(path, encoding="utf-8").read()
    lines = text.split("\n")
    i_end = next(i for i, l in enumerate(lines) if l.strip() == "ENDCLASS.")
    defn = "\n".join(lines[:i_end + 1])
    impl = "\n".join(lines[i_end + 1:])

    info = {
        "path": path, "super": None, "intf": set(), "abstract_m": set(),
        "declared": {}, "static": set(), "implemented": {}, "lines": lines,
        "i_end": i_end, "members": set(),
    }

    section = None
    for ln, s in statements(defn):
        w, u = first_word(s), s.upper()
        if w == "CLASS" and "DEFINITION" in u:
            m = re.search(r"INHERITING FROM (\w+)", u)
            if m:
                info["super"] = m.group(1)
        elif u in ("PUBLIC SECTION", "PROTECTED SECTION", "PRIVATE SECTION"):
            section = u.split(" ")[0]
        elif w == "INTERFACES":
            body = s[len("INTERFACES"):].strip()
            head = re.split(r"\b(?:ABSTRACT|FINAL|ALL)\s+METHODS\b", body,
                            flags=re.I)[0]
            for other in head.split(" "):
                if other.strip():
                    info["intf"].add(other.strip().upper())
            m = re.search(r"\bABSTRACT\s+METHODS\b(.*)$", body, re.I)
            if m:
                for x in m.group(1).split(" "):
                    if x.strip():
                        info["abstract_m"].add(x.strip().lower())
        elif w in ("TYPES", "TYPES:", "CONSTANTS", "CONSTANTS:",
                   "DATA", "DATA:", "CLASS-DATA", "CLASS-DATA:"):
            m = re.match(r"[A-Z-]+:?\s+BEGIN OF (\w+)", s, re.I) \
                or re.match(r"[A-Z-]+:?\s+(\w+)", s, re.I)
            if m:
                info["members"].add(m.group(1).lower())
        elif w in ("METHODS", "CLASS-METHODS"):
            mname = s.split(" ")[1].lower().rstrip(":")
            info["declared"][mname] = {
                "line": ln, "section": section,
                "abstract": bool(re.search(r"\bABSTRACT\b", u)),
                "redef": bool(re.search(r"\bREDEFINITION\b", u)),
            }
            if w == "CLASS-METHODS":
                info["static"].add(mname)
            if mname == "class_constructor" and section != "PUBLIC":
                report("F", path, ln,
                       "CLASS_CONSTRUCTOR ở %s SECTION, phải PUBLIC" % section)
            # D. kiểu generic ở tham số trả về / xuất
            for kw, pname, typ in re.findall(
                    r"\b(RETURNING|EXPORTING|CHANGING)\s+(?:VALUE\()?(\w+)\)?"
                    r"\s+TYPE\s+([A-Za-z_0-9]+)\b", s, re.I):
                if typ.lower() in ("c", "n", "x", "p", "clike", "csequence",
                                   "xsequence", "numeric", "simple", "any",
                                   "data", "table", "decfloat"):
                    report("D", path, ln, "%s.%s: %s %s TYPE %s là kiểu generic"
                           % (name, mname, kw.upper(), pname, typ))

    # E. comment thường trong DEFINITION
    i_hdr = max((i for i, l in enumerate(lines[:i_end])
                 if l.strip().startswith("*=====")), default=-1)
    for i in range(i_hdr + 1, i_end + 1):
        s = lines[i].strip()
        if s.startswith("*") or (s.startswith('"') and not s.startswith('"!')):
            report("E", path, i + 1, "comment thường trong DEFINITION: %s" % s[:50])

    # method đã hiện thực + C. khối lệnh
    OPEN = {"IF": "ENDIF", "LOOP": "ENDLOOP", "DO": "ENDDO",
            "WHILE": "ENDWHILE", "CASE": "ENDCASE", "TRY": "ENDTRY",
            "SELECT": "ENDSELECT"}
    CLOSE = {v: k for k, v in OPEN.items()}
    cur, stack = None, []
    for ln0, s in statements(impl):
        ln = ln0 + i_end + 1                       # số dòng tính theo cả file
        w, u = first_word(s), s.upper()
        if w == "METHOD":
            cur = s.split(" ")[1].lower()
            info["implemented"][cur] = ln
            stack = []
        elif w == "ENDMETHOD":
            if stack:
                report("C", path, stack[-1][1],
                       "%s.%s: thiếu %s (mở ở dòng %d)"
                       % (name, cur, OPEN[stack[-1][0]], stack[-1][1]))
            cur, stack = None, []
        elif cur:
            if w == "SELECT" and ("ENDSELECT" not in u):
                continue                       # SELECT ... INTO TABLE 1 lệnh
            if w in OPEN:
                stack.append((w, ln))
            elif w in CLOSE:
                if not stack:
                    report("C", path, ln, "%s.%s: %s không có lệnh mở"
                           % (name, cur, w))
                elif stack[-1][0] != CLOSE[w]:
                    report("C", path, ln, "%s.%s: %s không khớp %s (dòng %d)"
                           % (name, cur, w, stack[-1][0], stack[-1][1]))
                    stack.pop()
                else:
                    stack.pop()
    CLS[name] = info


# ---------------------------------------------------------------------------
# G. ký tự { } chưa escape trong string template
# ---------------------------------------------------------------------------
def check_template(path):
    for i, line in enumerate(io.open(path, encoding="utf-8"), 1):
        if line.lstrip().startswith(("*", '"')):
            continue
        for m in re.finditer(r"\|[^|]*\|", line):
            body = re.sub(r"\{[^{}]*\}", "", m.group(0)[1:-1])
            body = body.replace("\\{", "").replace("\\}", "")
            if "{" in body or "}" in body:
                report("G", path, i, "template chưa escape { }: %s"
                       % m.group(0)[:60])


# ---------------------------------------------------------------------------
# J. ABAP Doc đứng trước khai báo chuỗi (CONSTANTS:/TYPES: BEGIN OF ...,)
# K. DATA() suy ra P(8,0) khi biểu thức có phép chia / nhân trên số P
# L. POSIX regex đã deprecated, phải dùng PCRE
# ---------------------------------------------------------------------------
def check_style(path):
    lines = io.open(path, encoding="utf-8").read().split("\n")
    for i, line in enumerate(lines, 1):
        if re.match(r"\s*(TYPES|CONSTANTS):\s*BEGIN OF \w+\s*,", line) \
                and i >= 2 and lines[i - 2].strip().startswith('"!'):
            report("J", path, i - 1,
                   "ABAP Doc trước khai báo chuỗi %s" % line.strip()[:40])
        if re.search(r"DATA\((l[vs]_\w+)\)\s*=[^.]*[*/]", line) \
                and "|" not in line and "&&" not in line:
            report("K", path, i,
                   "DATA() từ biểu thức số học suy ra P(8,0): %s" % line.strip()[:50])
        if re.search(r"OCCURRENCES OF REGEX\b|\bFIND\b.*\bREGEX\b|\bregex\s*=", line) \
                and not line.lstrip().startswith(("*", '"')):
            report("L", path, i, "POSIX regex deprecated, dùng PCRE: %s"
                   % line.strip()[:50])


# ---------------------------------------------------------------------------
# M. ORDER BY phải dùng tên cột có trong danh sách SELECT (không dùng alias
#    bảng dạng k~belnr) — nếu không ADT báo Unknown column name
# ---------------------------------------------------------------------------
def check_select(path):
    for ln, s in statements(io.open(path, encoding="utf-8").read()):
        if first_word(s) != "SELECT" or " ORDER BY " not in s.upper():
            continue
        u = s.upper()
        if "ORDER BY PRIMARY KEY" in u:
            continue
        head = s[6:u.find(" FROM ")] if " FROM " in u else ""
        head = re.sub(r"^\s*(?:SINGLE|DISTINCT)\s+", "", head, flags=re.I)
        if "*" in head or not head.strip():
            continue
        outs = set()
        for col in head.split(","):
            col = col.strip()
            m = re.search(r"\bAS\s+(\w+)\s*$", col, re.I)
            outs.add((m.group(1) if m else col.split("~")[-1]).lower())
        tail = re.split(r"\bORDER BY\b", s, flags=re.I)[1]
        tail = re.split(r"\b(?:INTO|UP TO)\b", tail, flags=re.I)[0]
        for item in tail.split(","):
            item = re.sub(r"\b(?:ASCENDING|DESCENDING)\b", "", item,
                          flags=re.I).strip()
            if not item:
                continue
            if "~" in item:
                report("M", path, ln, "ORDER BY %s dùng alias bảng, phải dùng "
                       "tên cột kết quả" % item)
            elif item.lower() not in outs:
                report("M", path, ln, "ORDER BY %s không có trong danh sách "
                       "SELECT" % item)


# ---------------------------------------------------------------------------
# Chạy
# ---------------------------------------------------------------------------
for p in sorted(glob.glob("src/**/*.intf.abap", recursive=True)):
    read_intf(p)
for p in sorted(glob.glob("src/**/*.intf.abap", recursive=True)):
    read_intf(p)                                   # lượt 2: interface lồng nhau
for p in sorted(glob.glob("src/**/*.clas.abap", recursive=True)):
    read_class(p)
for p in sorted(glob.glob("src/**/*.abap", recursive=True)):
    check_template(p)
    check_style(p)
    check_select(p)


def ancestors(name):
    out, cur = [], CLS.get(name, {}).get("super")
    while cur and cur in CLS:
        out.append(cur)
        cur = CLS[cur]["super"]
    return out


# A / B. khai báo và hiện thực
for name, info in CLS.items():
    path = info["path"]
    for mname, d in info["declared"].items():
        if d["abstract"]:
            if mname in info["implemented"]:
                report("A", path, info["implemented"][mname],
                       "%s.%s khai báo ABSTRACT nhưng lại có hiện thực"
                       % (name, mname))
        elif mname not in info["implemented"]:
            report("A", path, d["line"],
                   "%s.%s khai báo nhưng chưa hiện thực" % (name, mname))

    known = set(info["declared"])
    for intf in info["intf"] | {i for a in ancestors(name) for i in CLS[a]["intf"]}:
        known |= {intf.lower() + "~" + m for m in INTF.get(intf, {}).get("methods", set())}
    for a in ancestors(name):
        known |= set(CLS[a]["declared"])
        for intf in CLS[a]["intf"]:
            known |= {intf.lower() + "~" + m
                      for m in INTF.get(intf, {}).get("methods", set())}
    for mname, ln in info["implemented"].items():
        if mname not in known:
            report("A", path, ln, "%s: hiện thực method %s không có khai báo"
                   % (name, mname))

    # B. method interface chưa hiện thực ở đâu trong cây
    for intf in info["intf"]:
        for m in sorted(INTF.get(intf, {}).get("methods", set())):
            if "~" in m:
                continue
            full = intf.lower() + "~" + m
            done = (full in info["implemented"] or m in info["implemented"]
                    or m in info["abstract_m"]
                    or any(full in CLS[a]["implemented"] or m in CLS[a]["abstract_m"]
                           for a in ancestors(name)))
            if not done:
                report("B", path, 1, "%s chưa hiện thực %s của %s"
                       % (name, m, intf))

# H. hằng số / kiểu của interface
for p in sorted(glob.glob("src/**/*.abap", recursive=True)):
    for i, line in enumerate(io.open(p, encoding="utf-8"), 1):
        if line.lstrip().startswith(("*", '"')):
            continue
        for intf, rest in re.findall(r"\b(zif_hddt_\w+)=>([a-z_0-9\-]+)", line, re.I):
            key = intf.upper()
            if key not in INTF:
                continue
            ref = rest.lower().rstrip("-")
            pool = INTF[key]["consts"] | INTF[key]["types"] | INTF[key]["methods"]
            if ref in pool or ref.split("-")[0] in pool:
                continue
            report("H", p, i, "%s=>%s không tìm thấy trong interface" % (intf, ref))

# I. gọi method tĩnh của class trong package
for p in sorted(glob.glob("src/**/*.abap", recursive=True)):
    for i, line in enumerate(io.open(p, encoding="utf-8"), 1):
        if line.lstrip().startswith(("*", '"')):
            continue
        for cname, m in re.findall(r"\b(zcl_hddt_\w+)=>(\w+)", line, re.I):
            key = cname.upper()
            if key not in CLS:
                continue
            mm = m.lower()
            pool = set(CLS[key]["declared"]) | CLS[key]["members"]
            for a in ancestors(key):
                pool |= set(CLS[a]["declared"]) | CLS[a]["members"]
            if mm not in pool:
                report("I", p, i, "%s=>%s không có trong class" % (cname, m))

KIND = {
    "A": "Method khai báo / hiện thực không khớp",
    "B": "Method interface chưa hiện thực",
    "C": "Khối lệnh không khớp",
    "D": "Kiểu generic ở tham số trả về",
    "E": "Comment thường trong DEFINITION",
    "F": "CLASS_CONSTRUCTOR không PUBLIC",
    "G": "String template chưa escape { }",
    "H": "Hằng số / kiểu interface không tồn tại",
    "I": "Method tĩnh không tồn tại",
    "J": "ABAP Doc sai vị trí (trước khai báo chuỗi)",
    "K": "DATA() suy ra P(8,0) từ biểu thức số học",
    "L": "POSIX regex deprecated (dùng PCRE)",
    "M": "ORDER BY không khớp danh sách SELECT",
}
print("Đã đọc: %d interface, %d class" % (len(INTF), len(CLS)))
for k in sorted(KIND):
    rows = [f for f in FIND if f[0] == k]
    print("\n[%s] %s — %d" % (k, KIND[k], len(rows)))
    for _, path, ln, text in rows[:40]:
        print("   %s:%d  %s" % (path, ln, text))
    if len(rows) > 40:
        print("   ... còn %d dòng" % (len(rows) - 40))
print("\nTổng phát hiện:", len(FIND))
sys.exit(1 if FIND else 0)

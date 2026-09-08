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
  N. Gọi method qua biến REF TO interface nhưng interface không có
  O. Dùng field không có trong định nghĩa bảng ở tools/gen_ddic.py
  P. Truyền space / ' ' cho tham số kiểu số hoặc ngày
  Q. Gọi method qua biến REF TO class: phải tồn tại và PUBLIC
  R. Mệnh đề INTO phải đứng sau WHERE / GROUP BY / HAVING / ORDER BY
  S. PERFORM ... USING nhận biểu thức thay vì tên biến
  T. SVAL-FIELDTEXT dài quá 20 ký tự (SE38 cắt bớt)
  U. Dạng ngắn ( name = value ) đi kèm EXCEPTIONS mà thiếu EXPORTING
  V. MESSAGE ... WITH nhận biểu thức thay vì tên biến
  W. Khai báo lại thành phần / method đã có ở lớp cha
  X. Bảng WITH EMPTY KEY truyền vào tham số TABLES của FM cổ điển
  Y. Tham số method dùng kiểu dựng sẵn c/n/x/p, kể cả kèm LENGTH
  Z. Lớp local trong program: method hiện thực nhưng không khai báo

Chạy: python tools/check_abap.py
"""
import glob
import io
import os
import re
import sys

# Thư mục gốc repo: tham số dòng lệnh, hoặc thư mục cha của tools/
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

# Thư mục chứa source ABAP và file định nghĩa DDIC (nếu có)
SRC = "src" if os.path.isdir("src") else "."
GEN_DDIC = os.path.join("tools", "gen_ddic.py")
FIND = []


def sources(pattern):
    return sorted(glob.glob(os.path.join(SRC, "**", pattern), recursive=True))


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


def ancestors(name):
    out, cur = [], CLS.get(name, {}).get("super")
    while cur and cur in CLS:
        out.append(cur)
        cur = CLS[cur]["super"]
    return out

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
def check_local_class(path):
    """Z. Lớp local trong program: method hiện thực mà không có khai báo và
    ngược lại. read_class chỉ soát global class nên chỗ này bù lại."""
    if not path.endswith(".prog.abap"):
        return
    declared, implemented, abstract = {}, {}, set()
    for ln, st in statements(io.open(path, encoding="utf-8").read()):
        w = first_word(st)
        if w in ("METHODS", "CLASS-METHODS"):
            name = st.split(" ")[1].lower().rstrip(":")
            declared[name] = ln
            if re.search(r"\bABSTRACT\b", st, re.I):
                abstract.add(name)
        elif w == "METHOD":
            implemented[st.split(" ")[1].lower().rstrip(".")] = ln
    for name, ln in implemented.items():
        if name not in declared:
            report("Z", path, ln, "method %s có hiện thực nhưng không còn khai "
                   "báo trong lớp local" % name)
    for name, ln in declared.items():
        if name not in implemented and name not in abstract:
            report("Z", path, ln, "method %s khai báo nhưng chưa hiện thực "
                   "trong lớp local" % name)


def check_param_type(path):
    """Y. Tham số method dùng kiểu dựng sẵn c/n/x/p (kể cả kèm LENGTH).

    ADT: "A RETURNING parameter must be fully typed." Kiểu dựng sẵn một chữ
    không dùng được ở tham số method, phải khai kiểu CÓ TÊN.
    """
    for ln, st in statements(io.open(path, encoding="utf-8").read()):
        if first_word(st) not in ("METHODS", "CLASS-METHODS"):
            continue
        for m in re.finditer(r"\bTYPE\s+([cnxp])\b(\s+LENGTH\s+\d+)?", st, re.I):
            report("Y", path, ln, "tham số method dùng TYPE %s%s, phải là kiểu "
                   "có tên" % (m.group(1), m.group(2) or ""))


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
        if first_word(s) != "SELECT":
            continue
        u = s.upper()
        # R. INTO phải đứng sau WHERE / GROUP BY / HAVING / ORDER BY
        mi = re.search(r"\b(INTO|APPENDING)\b", u)
        if mi:
            # sau INTO chỉ được phép UP TO / OFFSET / BYPASSING / %_HINTS...
            late = [k for k in ("WHERE", "GROUP BY", "HAVING", "ORDER BY",
                                "AND", "OR")
                    if re.search(r"\b" + k + r"\b", u[mi.end():])]
            if late:
                report("R", path, ln, "INTO đứng trước %s, phải chuyển xuống cuối"
                       % ", ".join(late))
        if " ORDER BY " not in u:
            continue
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
# N. Gọi method qua biến tham chiếu interface nhưng interface không có method
# ---------------------------------------------------------------------------
def check_iref(path):
    text = io.open(path, encoding="utf-8").read()
    var = {}
    for m in re.finditer(r"\b(?:VALUE\()?(\w+)\)?\s+TYPE REF TO\s+(zif_hddt_\w+)",
                         text, re.I):
        var.setdefault(m.group(1).lower(), set()).add(m.group(2).upper())
    for i, line in enumerate(text.split("\n"), 1):
        if line.lstrip().startswith(("*", '"')):
            continue
        for name, meth in re.findall(r"\b(\w+)->(\w+)\(", line):
            keys = var.get(name.lower())
            if not keys:
                continue
            ok = False
            for k in keys:
                pool = INTF.get(k, {}).get("methods", set())
                if meth.lower() in pool or any(
                        x.endswith("~" + meth.lower()) for x in pool):
                    ok = True
            if not ok:
                report("N", path, i, "%s->%s( ) không có trong %s"
                       % (name, meth, "/".join(sorted(keys))))


# ---------------------------------------------------------------------------
# O. Code dùng field không có trong định nghĩa bảng (tools/gen_ddic.py)
# ---------------------------------------------------------------------------
def ddic_tables():
    if not os.path.isfile(GEN_DDIC):
        return {}                      # repo khac: bo qua nhom O
    g = io.open(GEN_DDIC, encoding="utf-8").read()
    ns = {"K": lambda n, r: (n, r, True), "F": lambda n, r: (n, r, False)}
    tabs = eval(re.search(r"TABLES = (\[.*?\n\])", g, re.S).group(1), ns)
    return {t.upper(): {f[0].lower() for f in fields} for t, _, _, fields in tabs}


TAB = ddic_tables()


def check_ddic_use(path):
    text = io.open(path, encoding="utf-8").read()
    var = {}

    def add(name, tab):
        var.setdefault(name.lower(), set()).add(tab.upper())

    for m in re.finditer(r"\b(?:VALUE\()?(\w+)\)?\s+TYPE\s+(?:(?:STANDARD|SORTED|"
                         r"HASHED)\s+)?(?:TABLE OF\s+)?(ztb_hddt_\w+)\b", text, re.I):
        add(m.group(1), m.group(2))
    # SELECT trên bảng của package: cột phải có thật; biến INTO @DATA() chỉ
    # mang đúng các cột đã chọn
    varcols = {}
    for ln, st in statements(text):
        w = first_word(st)
        m = re.match(r"UPDATE\s+(ztb_hddt_\w+)\s+SET\s+(.*)$", st, re.I)
        if m and m.group(1).upper() in TAB:
            for fld in re.findall(r"(\w+)\s*=", m.group(2)):
                if fld.lower() not in TAB[m.group(1).upper()]:
                    report("O", path, ln, "UPDATE %s SET %s: field không có"
                           % (m.group(1), fld))
            continue
        if w != "SELECT":
            continue
        mt = re.search(r"\bFROM\s+(ztb_hddt_\w+)\b", st, re.I)
        if not mt or mt.group(1).upper() not in TAB or " JOIN " in st.upper():
            continue
        tab = mt.group(1).upper()
        head = re.sub(r"^SELECT\s+(?:SINGLE\s+|DISTINCT\s+)?", "",
                      st[:mt.start()], flags=re.I)
        cols = set()
        if "*" in head:
            cols = set(TAB[tab])
        else:
            for col in head.split(","):
                col = col.strip()
                if not col or "(" in col or col.startswith(("@", "'", "`")):
                    continue          # host expression / literal
                alias = re.search(r"\bAS\s+(\w+)\s*$", col, re.I)
                base = re.sub(r"\s+AS\s+\w+\s*$", "", col, flags=re.I).split("~")[-1]
                if base.lower() not in TAB[tab]:
                    report("O", path, ln, "SELECT %s FROM %s: cột không có"
                           % (base, tab))
                cols.add((alias.group(1) if alias else base).lower())
        for t in re.findall(r"INTO\s+(?:TABLE\s+)?@?(?:DATA\()?(\w+)\)?",
                            st, re.I):
            varcols.setdefault(t.lower(), set()).update(cols)
    # bảng nội bộ kiểu ty_t_* dựng trên bảng DDIC -> field-symbol của LOOP
    for m in re.finditer(r"LOOP AT\s+(\w+)[^.]*?FIELD-SYMBOL\(<(\w+)>\)", text, re.I):
        for t in var.get(m.group(1).lower(), ()):
            add("<" + m.group(2) + ">", t)
    for i, line in enumerate(text.split("\n"), 1):
        if line.lstrip().startswith(("*", '"')):
            continue
        for name, fld in re.findall(r"(<?\w+>?)-(\w+)\b", line):
            low = name.lower()
            if low in varcols and low not in var:
                if fld.lower() not in varcols[low]:
                    report("O", path, i, "%s-%s không nằm trong các cột đã "
                           "SELECT" % (name, fld))
                continue
            keys = {k for k in var.get(low, ()) if k in TAB}
            if not keys:
                continue
            if not any(fld.lower() in TAB[k] for k in keys):
                report("O", path, i, "%s-%s không có trong %s"
                       % (name, fld, "/".join(sorted(keys))))


# ---------------------------------------------------------------------------
# P. Truyền literal ký tự (space, ' ') cho tham số kiểu số / ngày
#    ADT: The literal "' '" is not type-compatible with the formal parameter
# ---------------------------------------------------------------------------
NUM_KIND = ("NUMC", "INT1", "INT2", "INT4", "INT8", "DEC", "CURR", "QUAN",
            "FLTP", "DATS", "TIMS", "TIMESTAMP", "TIMESTAMPL")
NUM_STD = {"gjahr", "monat", "poper", "buzei", "posnr", "kopos", "i", "int1",
           "int2", "int4", "int8", "p", "f", "d", "t", "n", "dats", "tims",
           "timestamp", "timestampl", "decfloat16", "decfloat34", "numc"}


def numeric_types():
    if not os.path.isfile(GEN_DDIC):
        return set(NUM_STD)            # repo khac: chi dung kieu chuan
    g = io.open(GEN_DDIC, encoding="utf-8").read()
    dom = {}
    for m in re.finditer(r'\(\s*"(ZDO_\w+)"\s*,\s*"(\w+)"', g):
        dom[m.group(1)] = m.group(2).upper()
    out = set(NUM_STD)
    for m in re.finditer(r'\(\s*"(ZDE_\w+)"\s*,\s*(?:"(ZDO_\w+)"|\(\s*"(\w+)")', g):
        de, d, builtin = m.group(1), m.group(2), m.group(3)
        kind = dom.get(d, "") if d else (builtin or "").upper()
        if kind in NUM_KIND:
            out.add(de.lower())
    return out


NUM_TYPE = numeric_types()
PARAM_TYPE = {}


def read_params(path):
    text = io.open(path, encoding="utf-8").read()
    for m in re.finditer(r"\b(i_\w+|e_\w+|c_\w+|is_\w+|it_\w+)\s+TYPE\s+"
                         r"(?:REF TO\s+)?([\w~=>-]+)", text, re.I):
        PARAM_TYPE.setdefault(m.group(1).lower(), set()).add(m.group(2).lower())


def check_literal(path):
    for i, line in enumerate(io.open(path, encoding="utf-8"), 1):
        if line.lstrip().startswith(("*", '"')):
            continue
        for name in re.findall(r"\b(i_\w+|e_\w+|c_\w+)\s*=\s*(?:space|' ')\s*[).]*",
                               line, re.I):
            types = PARAM_TYPE.get(name.lower(), set())
            bad = {t for t in types if t in NUM_TYPE}
            if bad:
                report("P", path, i, "%s = space nhưng tham số kiểu %s (số/ngày)"
                       % (name, "/".join(sorted(bad))))


# ---------------------------------------------------------------------------
# Q. Gọi method qua biến REF TO class của package: method phải tồn tại và
#    phải PUBLIC khi gọi từ class khác
# ---------------------------------------------------------------------------
def visible(cls, meth):
    """(tồn tại, là public) — tính cả lớp cha và interface đã implement."""
    exists = public = False
    for k in [cls] + ancestors(cls):
        d = CLS[k]["declared"].get(meth)
        if d:
            exists = True
            public = public or d["section"] == "PUBLIC"
        for intf in CLS[k]["intf"]:
            pool = INTF.get(intf, {}).get("methods", set())
            if meth in pool or any(x.endswith("~" + meth) for x in pool):
                exists = public = True          # thành phần interface là public
    return exists, public


def check_cref(path):
    text = io.open(path, encoding="utf-8").read()
    me = os.path.basename(path).split(".")[0].upper()
    var = {}
    for m in re.finditer(r"\b(?:VALUE\()?(\w+)\)?\s+TYPE REF TO\s+(zcl_hddt_\w+)",
                         text, re.I):
        var.setdefault(m.group(1).lower(), set()).add(m.group(2).upper())
    for i, line in enumerate(text.split("\n"), 1):
        if line.lstrip().startswith(("*", '"')):
            continue
        for name, meth in re.findall(r"\b(\w+)->(\w+)\(", line):
            if name.lower() == "me":
                continue
            keys = {k for k in var.get(name.lower(), ()) if k in CLS}
            if not keys:
                continue
            res = [visible(k, meth.lower()) for k in keys]
            if not any(e for e, _ in res):
                report("Q", path, i, "%s->%s( ) không có trong %s"
                       % (name, meth, "/".join(sorted(keys))))
            elif me not in keys and not any(p for _, p in res):
                report("Q", path, i, "%s->%s( ) không PUBLIC nên %s không gọi được"
                       % (name, meth, me))


# ---------------------------------------------------------------------------
# S. PERFORM ... USING / CHANGING chỉ nhận TÊN BIẾN hoặc literal, không nhận
#    biểu thức (string template, phép ghép, table expression, gọi hàm)
# ---------------------------------------------------------------------------
def check_perform(path):
    for ln, st in statements(io.open(path, encoding="utf-8").read()):
        if first_word(st) != "PERFORM":
            continue
        m = re.search(r"\b(USING|CHANGING|TABLES)\b(.*)$", st, re.I)
        if not m:
            continue
        act = m.group(2)
        bad = []
        if "|" in act:
            bad.append("string template |...|")
        if "&&" in act:
            bad.append("phép ghép &&")
        if re.search(r"\w\s*\[", act):
            bad.append("table expression [ ]")
        if re.search(r"\w\s*\(", act):
            bad.append("gọi hàm ( )")
        if bad:
            report("S", path, ln, "PERFORM USING nhận biểu thức (%s), phải gán "
                   "vào biến trước" % ", ".join(bad))


# ---------------------------------------------------------------------------
# T. SVAL-FIELDTEXT chỉ có C(20); dài hơn thì SE38 cảnh báo và bị cắt
# U. Dạng ngắn "name = value" trong gọi method không đi kèm được EXCEPTIONS /
#    IMPORTING / RECEIVING — phải viết rõ EXPORTING
# ---------------------------------------------------------------------------
def check_ui(path):
    for i, line in enumerate(io.open(path, encoding="utf-8"), 1):
        if line.lstrip().startswith(("*", '"')):
            continue
        for m in re.finditer(r"fieldtext\s*=\s*'([^']*)'", line, re.I):
            if len(m.group(1)) > 20:
                report("T", path, i, "FIELDTEXT %d ký tự (tối đa 20): %s"
                       % (len(m.group(1)), m.group(1)))

    # X. Bảng WITH EMPTY KEY truyền vào tham số TABLES của function module cổ
    #    điển: code chuẩn có thể COLLECT / READ WITH KEY -> dump lúc chạy
    text = io.open(path, encoding="utf-8").read()
    empty = set(re.findall(r"\b(\w+)\s+TYPE\s+(?:STANDARD\s+)?TABLE OF\s+\w+"
                           r"\s+WITH EMPTY KEY", text, re.I))
    if empty:
        for ln, st in statements(text):
            if not st.upper().startswith("CALL FUNCTION"):
                continue
            m = re.search(r"\bTABLES\b(.*)$", st, re.I)
            if not m:
                continue
            for v in sorted(empty):
                if re.search(r"=\s*" + re.escape(v) + r"\b", m.group(1), re.I):
                    report("X", path, ln, "%s khai EMPTY KEY nhưng truyền vào "
                           "TABLES của FM, nên dùng DEFAULT KEY" % v)

    # V. MESSAGE ... WITH chỉ nhận tên biến / literal, không nhận biểu thức
    for ln, st in statements(io.open(path, encoding="utf-8").read()):
        if st.upper().startswith("MESSAGE ") and re.search(r"\bWITH\b", st, re.I):
            tail = re.split(r"\bWITH\b", st, flags=re.I)[1]
            if re.search(r"\w\s*\(", tail) or "|" in tail or "&&" in tail:
                report("V", path, ln, "MESSAGE ... WITH nhận biểu thức, phải gán "
                       "vào biến trước")

    for ln, st in statements(io.open(path, encoding="utf-8").read()):
        if not re.search(r"\bEXCEPTIONS\b", st) or st.upper().startswith("CALL FUNCTION"):
            continue
        head = re.split(r"\bEXCEPTIONS\b", st)[0]
        if "(" not in head:
            continue
        args = head[head.index("(") + 1:]
        if "=" in args and not re.search(
                r"\b(EXPORTING|IMPORTING|CHANGING|RECEIVING|TABLES)\b", args):
            report("U", path, ln, "dạng ngắn ( name = value ) đi kèm EXCEPTIONS, "
                   "phải ghi rõ EXPORTING")


# ---------------------------------------------------------------------------
# Chạy
# ---------------------------------------------------------------------------
for p in sources("*.intf.abap"):
    read_intf(p)
for p in sources("*.intf.abap"):
    read_intf(p)                                   # lượt 2: interface lồng nhau
for p in sources("*.abap"):
    read_params(p)
for p in sources("*.clas.abap"):
    read_class(p)
for p in sources("*.abap"):
    check_template(p)
    check_style(p)
    check_param_type(p)
    check_local_class(p)
    check_select(p)
    check_iref(p)
    check_ddic_use(p)
    check_literal(p)
    check_cref(p)
    check_perform(p)
    check_ui(p)




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

    # W. khai báo lại thành phần / method đã có ở lớp cha
    for a in ancestors(name):
        for mem in sorted(info["members"] & CLS[a]["members"]):
            report("W", path, 1, "%s khai báo lại %s đã có ở lớp cha %s"
                   % (name, mem.upper(), a))
        for mname, d in info["declared"].items():
            if not d["redef"] and mname in CLS[a]["declared"]:
                report("W", path, d["line"], "%s khai báo lại method %s của lớp "
                       "cha %s mà không có REDEFINITION" % (name, mname, a))

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
for p in sources("*.abap"):
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
for p in sources("*.abap"):
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
    "N": "Method không có trong interface được tham chiếu",
    "O": "Field không có trong định nghĩa bảng DDIC",
    "P": "Literal ký tự truyền cho tham số kiểu số / ngày",
    "Q": "Method của class không tồn tại hoặc không PUBLIC",
    "R": "INTO không đứng cuối câu SELECT",
    "S": "PERFORM USING nhận biểu thức",
    "T": "SVAL-FIELDTEXT dài quá 20 ký tự",
    "U": "Dạng ngắn name = value đi kèm EXCEPTIONS",
    "V": "MESSAGE ... WITH nhận biểu thức",
    "W": "Khai báo lại thành phần của lớp cha",
    "X": "Bảng EMPTY KEY truyền vào TABLES của FM",
    "Y": "Tham số method dùng kiểu dựng sẵn c/n/x/p",
    "Z": "Lớp local: khai báo và hiện thực method không khớp",
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

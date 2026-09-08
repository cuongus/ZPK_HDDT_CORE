# -*- coding: utf-8 -*-
import ast, io, os, re, glob
os.chdir(r"D:\Claude\ZPK_HDDT")
g = io.open("tools/gen_ddic.py", encoding="utf-8").read()
DOMAINS = ast.literal_eval(re.search(r"DOMAINS = (\[.*?\n\])", g, re.S).group(1))
DTELS   = ast.literal_eval(re.search(r"DTELS = (\[.*?\n\])", g, re.S).group(1))
ns = {"K": lambda n, r: (n, r, True), "F": lambda n, r: (n, r, False)}
TABLES  = eval(re.search(r"TABLES = (\[.*?\n\])", g, re.S).group(1), ns)
m = io.open("tools/gen_meta.py", encoding="utf-8").read()
MESSAGES = ast.literal_eval(re.search(r"MESSAGES = (\[.*?\n\])", m, re.S).group(1))
PROGS    = ast.literal_eval(re.search(r"PROGS = (\[.*?\n\])", m, re.S).group(1))
TRANS    = ast.literal_eval(re.search(r"TRANS = (\[.*?\n\])", m, re.S).group(1))
CLASSES  = ast.literal_eval(re.search(r"CLASSES = (\[.*?\n\])", m, re.S).group(1))
INTFS    = ast.literal_eval(re.search(r"INTFS = (\[.*?\n\])", m, re.S).group(1))

out = []
w = out.append
w("# ZPK_HDDT_CORE — Source toàn bộ object để tạo tay\n")
w("Sinh từ repo https://github.com/cuongus/ZPK_HDDT_CORE (commit " + os.popen("git rev-parse --short HEAD").read().strip() + "). ")
w("Thứ tự tạo bắt buộc: **1 Domain → 2 Data element → 3 Bảng → 4 Message class → 5 Interface → 6 Class → 7 Program → 8 Tcode**. ")
w("Package đích: `ZPK_MAG_HDDT` (hoặc ZPK_HDDT_CORE + 4 package con DDIC/ENGINE/PROV/UI). ")
w("Mọi text hiển thị đã có dấu tiếng Việt; mô tả object không dấu (được phép).\n")

w("\n---\n\n## 1. Domain (SE11) — 10 object\n")
for name, dtype, leng, dec, text, vals in DOMAINS:
    w(f"\n### {name}\n- Mô tả: `{text}`\n- Kiểu: `{dtype}` độ dài `{leng}`" + (f", số lẻ `{dec}`" if dec else "") + "\n")
    if vals:
        w("- Giá trị cố định (tab Value Range):\n\n| Giá trị | Mô tả |\n|---|---|\n")
        for v, t in vals:
            w(f"| `{v}` | {t} |\n")

w("\n---\n\n## 2. Data element (SE11) — %d object\n" % len(DTELS))
w("\nCột: Domain hoặc kiểu dựng sẵn · Short(10) · Medium(20) · Long(40) · Heading(55) · Mô tả\n\n| Tên | Domain / Kiểu | Short | Medium | Long | Heading | Mô tả |\n|---|---|---|---|---|---|---|\n")
for name, typ, sh, md, lg, hd, text in DTELS:
    t = typ if isinstance(typ, str) else f"{typ[0]} {typ[1]}" + (f",{typ[2]}" if typ[2] else "")
    w(f"| `{name}` | `{t}` | {sh} | {md} | {lg} | {hd} | {text} |\n")

w("\n---\n\n## 3. Bảng trong suốt (SE11) — %d object\n" % len(TABLES))
w("\nKỹ thuật: Delivery class như ghi; Data class APPL1 (C) / APPL0 (A); Size 0; bảng C bật buffer full; Enhancement category: Can be enhanced (character-type or numeric).\n")

# Field kiểu STRG/RSTR: cột Init trong SE11 phải để trống
LONG_DE = {name: typ[0]
           for name, typ, *_ in DTELS
           if not isinstance(typ, str)
           and (typ[0] in ("STRG", "RSTR", "SSTR") or typ[1] > 255)}
w("\n> **Cột `Init` (Initial Values) phải để TRỐNG ở field kiểu `STRG` / `RSTR`.** "
  "Tích vào đó thì activate báo lỗi "
  "`Too long for activation of 'not null' flag (>255)`. "
  "Bảng nào có field như vậy được ghi rõ ngay dưới danh sách field.\n")
for tab, dc, text, fields in TABLES:
    w(f"\n### {tab}\n- Mô tả: `{text}` · Delivery class `{dc}` · Buffer: {'full' if dc == 'C' else 'không'}\n\n| Field | Key | Data element |\n|---|---|---|\n")
    for fn, roll, key in fields:
        w(f"| `{fn}` | {'X' if key else ''} | `{roll}` |\n")
    longs = [(fn, LONG_DE[roll]) for fn, roll, key in fields if roll in LONG_DE]
    if longs:
        w("\n- **Init phải để trống** ở: "
          + ", ".join(f"`{fn}` ({t})" for fn, t in longs) + "\n")

w("\n---\n\n## 4. Message class ZMS_HDDT (SE91)\n\n| Số | Text |\n|---|---|\n")
for no, text in MESSAGES:
    w(f"| {no} | {text} |\n")

def src(path):
    return io.open(path, encoding="utf-8").read().rstrip("\n")

w("\n---\n\n## 5. Interface (SE24 → Source Code-Based) — %d object\n" % len(INTFS))
w("\n> **Activate ngay từng interface trước khi sang class.** Khi tạo object mới, ADT / SE24 sinh sẵn một bản ACTIVE rỗng (`INTERFACE ... PUBLIC. ENDINTERFACE.`). Nếu chỉ Save mà chưa Activate thì bản active vẫn rỗng, và class dùng interface đó sẽ báo `Method \"GET_ID\" is unknown or PROTECTED or PRIVATE` dù source interface đã đúng. Thứ tự: `ZIF_HDDT_TYPES` trước, rồi các interface còn lại.\n")
for folder, name, descr in INTFS:
    w(f"\n### {name}\n- Mô tả: `{descr}`\n\n```abap\n{src(f'src/{folder}/{name.lower()}.intf.abap')}\n```\n")

w("\n---\n\n## 6. Class (SE24 → Source Code-Based) — %d object\n" % len(CLASSES))
w("\n> **Activate từng class ngay sau khi dán.** Class con và class gọi tới nó chỉ thấy bản ACTIVE; class cha chưa activate sẽ làm class con báo thiếu method hoặc thiếu kiểu. Nếu một class không activate được vì phụ thuộc chưa xong thì cứ Save, dán hết rồi Activate cả package một lượt (chọn package → Activate All Inactive).\n")
w("\nThứ tự dưới đây đã theo phụ thuộc (lớp cha / lớp được gọi đứng trước). Exception class: tạo với superclass CX_STATIC_CHECK rồi dán source.\n")
order = ["ZCX_HDDT_ERROR","ZCL_HDDT_JSON","ZCL_HDDT_CONFIG","ZCL_HDDT_PLATFORM","ZCL_HDDT_PLAT_CLASSIC",
         "ZCL_HDDT_SECRET","ZCL_HDDT_FACTORY","ZCL_HDDT_HTTP","ZCL_HDDT_TOKEN","ZCL_HDDT_LOG","ZCL_HDDT_SERVICE",
         "ZCL_HDDT_SRC_BASE","ZCL_HDDT_SRC_FI","ZCL_HDDT_SRC_SD","ZCL_HDDT_GOM","ZCL_HDDT_SRC_GOM",
         "ZCL_HDDT_WRITEBACK_FI","ZCL_HDDT_MAIL","ZCL_HDDT_PROV_BASE","ZCL_HDDT_PROV_VIETTEL",
         "ZCL_HDDT_PROV_FPT","ZCL_HDDT_PROV_TEMPLATE","ZCL_HDDT_PROV_VNPT"]
byname = {c[1]: c for c in CLASSES}
assert set(order) == set(byname), set(byname) ^ set(order)
for name in order:
    folder, _, descr, final, abstract, cat = byname[name]
    w(f"\n### {name}\n- Mô tả: `{descr}`" + (" · FINAL" if final else "") + (" · ABSTRACT" if abstract else "") + (" · Exception class" if cat == "40" else "") + "\n\n```abap\n" + src(f"src/{folder}/{name.lower()}.clas.abap") + "\n```\n")

w("\n---\n\n## 7. Program / Include (SE38)\n")
for folder, name, subc, tpool in PROGS:
    kind = "Executable program (type 1)" if subc == "1" else "Include (type I)"
    w(f"\n### {name}\n- Loại: {kind}" + (" · Message class ZMS_HDDT" if subc == "1" else "") + "\n")
    sel = [(k, e) for i, k, e in tpool if i == "S"]
    sym = [(k, e) for i, k, e in tpool if i == "I"]
    ttl = [e for i, k, e in tpool if i == "R"]
    if ttl: w(f"- Title: `{ttl[0]}`\n")
    if sel:
        w("- Selection texts (Goto → Text elements):\n\n| Tham số | Text |\n|---|---|\n")
        for k, e in sel: w(f"| `{k}` | {e} |\n")
    if sym:
        w("- Text symbols:\n\n| Ký hiệu | Text |\n|---|---|\n")
        for k, e in sym: w(f"| `{k}` | {e} |\n")
    w("\n```abap\n" + src(f"src/{folder}/{name.lower()}.prog.abap") + "\n```\n")

w("\n---\n\n## 8. Transaction (SE93 — Program and selection screen, dynpro 1000)\n\n| Tcode | Program | Text |\n|---|---|---|\n")
for t, p, text in TRANS:
    w(f"| `{t}` | `{p}` | {text} |\n")

w("\n---\n\n## 9. Sau khi tạo\n\n1. Activate theo đúng thứ tự trên; sửa lỗi cú pháp nếu hệ thống báo (code chưa activate trên hệ nào — Code_Review §12).\n2. SE41: tạo GUI status `ZSALV_HDDT` cho `ZPG_HDDT_INTEGRATION`. SALV toàn màn hình không cho thêm nút vào toolbar chuẩn nên 12 nút nghiệp vụ phải lấy từ status này: SE41 → Status → Copy status từ program `SAPLSALV_METADATA_STATUS` status `STANDARD_FULLSCREEN`, đổi tên thành `ZSALV_HDDT`, thêm 12 mã chức năng ZDRAFT ZDELDRF ZISSUE ZUPDATE ZADJREF ZMAIL ZGOM ZUNGOM ZEDIT ZFILE ZJSON ZLOG vào Application toolbar rồi activate.\n3. SE11: sinh Table Maintenance Generator cho 11 bảng cấu hình (trừ `_TPL`, `_TOK`, `_LOG` vì có field STRING) để ZPG_HDDT_CONFIG hoạt động.\n4. Chạy ZPG_HDDT_SETUP (tick Base + FPT + Tham số MAG) để nạp cấu hình mẫu, rồi rà lại theo hệ thống.\n5. SU21: tạo object phân quyền (field BUKRS, ACTVT) và khai vào tham số AUTH_OBJECT nếu cần; SCOT cho email.\n")

os.makedirs("dist", exist_ok=True)
out_path = "dist/ZPK_HDDT_CORE_source_all.md"
io.open(out_path, "w", encoding="utf-8", newline="\n").write("".join(out))
print(out_path, os.path.getsize(out_path), "bytes")

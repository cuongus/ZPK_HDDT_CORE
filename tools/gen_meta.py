# -*- coding: utf-8 -*-
"""Sinh cac file abapGit XML metadata cho class / interface / program /
message class / transaction cua package ZPK_HDDT_CORE.

Chay: python tools/gen_meta.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HDR = ('<?xml version="1.0" encoding="utf-8"?>\n'
       '<abapGit version="v1.0.0" serializer="{ser}" serializer_version="v1.0.0">\n'
       ' <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n'
       '  <asx:values>\n')
FTR = '  </asx:values>\n </asx:abap>\n</abapGit>\n'


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def write(folder, name, ext, ser, body):
    path = os.path.join(ROOT, "src", folder, "%s.%s.xml" % (name.lower(), ext))
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(HDR.format(ser=ser) + body + FTR)


# ---------------------------------------------------------------------------
# INTERFACE
# ---------------------------------------------------------------------------
INTFS = [
    ("engine", "ZFIIF_HDDT_TYPES", "HDDT: Kieu du lieu chuan hoa hoa don dien tu"),
    ("engine", "ZFIIF_HDDT_PROVIDER", "HDDT: Hop dong cho adapter nha cung cap"),
    ("engine", "ZFIIF_HDDT_SOURCE", "HDDT: Hop dong cho lop doc du lieu nguon"),
    ("engine", "ZFIIF_HDDT_SECRET", "HDDT: Diem cam lay secret tu vault"),
    ("engine", "ZFIIF_HDDT_PLATFORM", "HDDT: Tach API co dien vs ABAP Cloud"),
]

for folder, name, descr in INTFS:
    b = "   <VSEOINTERF>\n"
    b += "    <CLSNAME>%s</CLSNAME>\n" % name
    b += "    <LANGU>E</LANGU>\n"
    b += "    <DESCRIPT>%s</DESCRIPT>\n" % esc(descr)
    b += "    <EXPOSURE>2</EXPOSURE>\n"
    b += "    <STATE>1</STATE>\n"
    b += "    <UNICODE>X</UNICODE>\n"
    b += "   </VSEOINTERF>\n"
    write(folder, name, "intf", "LCL_OBJECT_INTF", b)


# ---------------------------------------------------------------------------
# CLASS  (folder, name, descr, final?, abstract?, category)
# ---------------------------------------------------------------------------
CLASSES = [
    ("engine", "ZFICX_HDDT_ERROR", "HDDT: Exception dung chung", False, False, "40"),
    ("engine", "ZFIC_HDDT_CONFIG", "HDDT: Truy cap cau hinh (co buffer)", True, False, None),
    ("engine", "ZFIC_HDDT_JSON", "HDDT: Writer + parser JSON tu chua", True, False, None),
    ("engine", "ZFIC_HDDT_FACTORY", "HDDT: Nha may sinh adapter theo cau hinh", True, False, None),
    ("engine", "ZFIC_HDDT_SECRET", "HDDT: Bo giai quyet secret API", True, False, None),
    ("engine", "ZFIC_HDDT_PLATFORM", "HDDT: Bo giai quyet nen tang", True, False, None),
    ("engine", "ZFIC_HDDT_PLAT_CLASSIC", "HDDT: Nen tang ABAP co dien", True, False, None),
    ("engine", "ZFIC_HDDT_HTTP", "HDDT: Bo goi REST dieu khien bang cau hinh", True, False, None),
    ("engine", "ZFIC_HDDT_TOKEN", "HDDT: Quan ly access token", True, False, None),
    ("engine", "ZFIC_HDDT_LOG", "HDDT: Ghi log API va so dang ky hoa don", True, False, None),
    ("engine", "ZFIC_HDDT_SERVICE", "HDDT: Service facade - cua vao duy nhat", True, False, None),
    ("engine", "ZFIC_HDDT_SRC_FI", "HDDT: Doc du lieu nguon chung tu FI", False, False, None),
    ("prov", "ZFIC_HDDT_PROV_BASE", "HDDT: Lop cha truu tuong cho adapter", False, True, None),
    ("prov", "ZFIC_HDDT_PROV_VIETTEL", "HDDT: Adapter Viettel SInvoice", True, False, None),
    ("prov", "ZFIC_HDDT_PROV_FPT", "HDDT: Adapter FPT eInvoice", True, False, None),
    ("prov", "ZFIC_HDDT_PROV_TEMPLATE", "HDDT: Adapter tong quat theo mau payload", False, False, None),
    ("prov", "ZFIC_HDDT_PROV_VNPT", "HDDT: Adapter VNPT / Vinaphone", True, False, None),
]

for folder, name, descr, final, abstract, category in CLASSES:
    b = "   <VSEOCLASS>\n"
    b += "    <CLSNAME>%s</CLSNAME>\n" % name
    b += "    <LANGU>E</LANGU>\n"
    b += "    <DESCRIPT>%s</DESCRIPT>\n" % esc(descr)
    if category:
        b += "    <CATEGORY>%s</CATEGORY>\n" % category
    b += "    <STATE>1</STATE>\n"
    if abstract:
        b += "    <CLSABSTRCT>X</CLSABSTRCT>\n"
    if final:
        b += "    <CLSFINAL>X</CLSFINAL>\n"
    b += "    <CLSCCINCL>X</CLSCCINCL>\n"
    b += "    <FIXPT>X</FIXPT>\n"
    b += "    <UNICODE>X</UNICODE>\n"
    b += "   </VSEOCLASS>\n"
    write(folder, name, "clas", "LCL_OBJECT_CLAS", b)


# ---------------------------------------------------------------------------
# PROGRAM / INCLUDE
# subc: '1' = executable report, 'I' = include
# tpool: list of (ID, KEY, ENTRY)
# ---------------------------------------------------------------------------
PROGS = [
    ("ui", "ZFIR_HDDT_INTEGRATION", "1", [
        ("R", "", "Tich hop hoa don dien tu"),
        ("I", "B01", "Chung tu nguon"),
        ("I", "B02", "Nha cung cap va trang thai"),
        ("I", "B03", "Tuy chon xu ly"),
        ("S", "P_BUKRS", "Ma cong ty"),
        ("S", "P_GJAHR", "Nam tai chinh"),
        ("S", "S_BELNR", "So chung tu"),
        ("S", "S_BUDAT", "Ngay ghi so"),
        ("S", "S_BLART", "Loai chung tu"),
        ("S", "P_SRCT", "Loai nguon du lieu"),
        ("S", "P_PROV", "Nha cung cap (trong = theo cau hinh)"),
        ("S", "S_STAT", "Trang thai HDDT"),
        ("S", "P_TEST", "Test run (chi dung payload)"),
    ]),
    ("ui", "ZFIR_HDDT_INT_TOP", "I", [("R", "", "Include ZFIR_HDDT_INT_TOP")]),
    ("ui", "ZFIR_HDDT_INT_SEL", "I", [("R", "", "Include ZFIR_HDDT_INT_SEL")]),
    ("ui", "ZFIR_HDDT_INT_CL1", "I", [("R", "", "Include ZFIR_HDDT_INT_CL1")]),
    ("ui", "ZFIR_HDDT_INT_EVT", "I", [("R", "", "Include ZFIR_HDDT_INT_EVT")]),
    ("ui", "ZFIR_HDDT_INT_F01", "I", [("R", "", "Include ZFIR_HDDT_INT_F01")]),
    ("ui", "ZFIR_HDDT_CONFIG", "1", [
        ("R", "", "Cau hinh tich hop hoa don dien tu"),
    ]),
    ("ui", "ZFIR_HDDT_LOG", "1", [
        ("R", "", "Log tich hop hoa don dien tu"),
        ("I", "B01", "Chung tu / thoi diem"),
        ("I", "B02", "Loc theo ket qua"),
        ("S", "P_BUKRS", "Ma cong ty"),
        ("S", "P_GJAHR", "Nam tai chinh"),
        ("S", "S_DOCNO", "So chung tu nguon"),
        ("S", "S_DATE", "Ngay ghi log"),
        ("S", "S_PROV", "Nha cung cap"),
        ("S", "S_ACTION", "Ma nghiep vu"),
        ("S", "S_CODE", "Ma HTTP"),
        ("S", "P_ONLYER", "Chi hien dong loi"),
        ("S", "P_TEST", "Kem ca dong Test run"),
        ("S", "P_MAX", "So dong toi da"),
    ]),
    ("ui", "ZFIR_HDDT_SETUP", "1", [
        ("R", "", "Nap cau hinh khoi tao HDDT"),
        ("I", "B01", "Pham vi nap cau hinh"),
        ("I", "B02", "Che do chay"),
        ("S", "P_BASE", "Danh muc / tham so / nguon du lieu chung"),
        ("S", "P_PROV1", "Cau hinh Viettel SInvoice"),
        ("S", "P_PROV2", "Cau hinh FPT eInvoice"),
        ("S", "P_PROV3", "Cau hinh VNPT (khung)"),
        ("S", "P_OVWRT", "Ghi de ban ghi da ton tai"),
        ("S", "P_TEST", "Chi mo phong, khong ghi bang"),
    ]),
]

for folder, name, subc, tpool in PROGS:
    b = "   <PROGDIR>\n"
    b += "    <NAME>%s</NAME>\n" % name
    b += "    <SUBC>%s</SUBC>\n" % subc
    b += "    <FIXPT>X</FIXPT>\n"
    if subc == "1":
        b += "    <LDBNAME>D$S</LDBNAME>\n"
    b += "    <UCCHECK>X</UCCHECK>\n"
    b += "   </PROGDIR>\n"
    if tpool:
        b += "   <TPOOL>\n"
        for tid, key, entry in tpool:
            b += "    <item>\n"
            b += "     <ID>%s</ID>\n" % tid
            if key:
                b += "     <KEY>%s</KEY>\n" % key
            b += "     <ENTRY>%s</ENTRY>\n" % esc(entry)
            b += "     <LENGTH>%d</LENGTH>\n" % len(entry)
            b += "    </item>\n"
        b += "   </TPOOL>\n"
    write(folder, name, "prog", "LCL_OBJECT_PROG", b)


# ---------------------------------------------------------------------------
# MESSAGE CLASS
# ---------------------------------------------------------------------------
MSAG = "ZFIE_HDDT"
MSAG_TEXT = "HDDT: Thong bao tich hop hoa don dien tu"
MESSAGES = [
    ("000", "&1 &2 &3 &4"),
    ("001", "Không tìm thấy chứng từ nào theo điều kiện chọn"),
    ("002", "Hãy chọn ít nhất một dòng trong danh sách"),
    ("003", "Chưa có log gọi API cho chứng từ này"),
    ("004", "Bạn không có quyền với công ty &1"),
    ("005", "Nhà cung cấp &1 chưa khai báo hoặc đang bị khoá"),
    ("006", "Bảng &1 chưa sinh Table Maintenance Generator (SE11)"),
    ("007", "Bạn không có quyền bảo trì bảng &1"),
    ("008", "Không mở được bảo trì bảng &1 (mã lỗi &2)"),
    ("009", "Đã xử lý &1 chứng từ: &2 thành công, &3 lỗi"),
    ("010", "Chế độ Test run: chỉ dựng payload, không gọi API"),
    ("011", "Chưa cấu hình nhà cung cấp cho công ty &1"),
    ("012", "Hoá đơn của chứng từ &1 đã phát hành, không phát hành lại"),
]

b = "   <T100A>\n"
b += "    <ARBGB>%s</ARBGB>\n" % MSAG
b += "    <STEXT>%s</STEXT>\n" % esc(MSAG_TEXT)
b += "    <MASTERLANG>E</MASTERLANG>\n"
b += "   </T100A>\n"
b += "   <T100_TEXTS>\n"
for msgnr, text in MESSAGES:
    b += "    <T100>\n"
    b += "     <SPRSL>E</SPRSL>\n"
    b += "     <ARBGB>%s</ARBGB>\n" % MSAG
    b += "     <MSGNR>%s</MSGNR>\n" % msgnr
    b += "     <TEXT>%s</TEXT>\n" % esc(text)
    b += "    </T100>\n"
b += "   </T100_TEXTS>\n"
write("engine", MSAG, "msag", "LCL_OBJECT_MSAG", b)


# ---------------------------------------------------------------------------
# TRANSACTION
# ---------------------------------------------------------------------------
TRANS = [
    ("ZFI_HDDT", "ZFIR_HDDT_INTEGRATION", "Tich hop hoa don dien tu"),
    ("ZFI_HDDT_CFG", "ZFIR_HDDT_CONFIG", "Cau hinh hoa don dien tu"),
    ("ZFI_HDDT_LOG", "ZFIR_HDDT_LOG", "Log tich hop hoa don dien tu"),
]

for tcode, prog, text in TRANS:
    b = "   <TSTC>\n"
    b += "    <TCODE>%s</TCODE>\n" % tcode
    b += "    <PGMNA>%s</PGMNA>\n" % prog
    b += "   </TSTC>\n"
    b += "   <TSTCC>\n"
    b += "    <TCODE>%s</TCODE>\n" % tcode
    b += "    <S_WEBGUI>2</S_WEBGUI>\n"
    b += "   </TSTCC>\n"
    b += "   <TSTCT>\n"
    b += "    <SPRSL>E</SPRSL>\n"
    b += "    <TCODE>%s</TCODE>\n" % tcode
    b += "    <TTEXT>%s</TTEXT>\n" % esc(text)
    b += "   </TSTCT>\n"
    write("ui", tcode, "tran", "LCL_OBJECT_TRAN", b)


print("interfaces:", len(INTFS))
print("classes   :", len(CLASSES))
print("programs  :", len(PROGS))
print("messages  :", len(MESSAGES))
print("tcodes    :", len(TRANS))

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
    ("engine", "ZIF_HDDT_TYPES", "HDDT: Kieu du lieu chuan hoa hoa don dien tu"),
    ("engine", "ZIF_HDDT_PROVIDER", "HDDT: Hop dong cho adapter nha cung cap"),
    ("engine", "ZIF_HDDT_SOURCE", "HDDT: Hop dong cho lop doc du lieu nguon"),
    ("engine", "ZIF_HDDT_SECRET", "HDDT: Diem cam lay secret tu vault"),
    ("engine", "ZIF_HDDT_PLATFORM", "HDDT: Tach API co dien vs ABAP Cloud"),
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
    ("engine", "ZCX_HDDT_ERROR", "HDDT: Exception dung chung", False, False, "40"),
    ("engine", "ZCL_HDDT_CONFIG", "HDDT: Truy cap cau hinh (co buffer)", True, False, None),
    ("engine", "ZCL_HDDT_JSON", "HDDT: Writer + parser JSON tu chua", True, False, None),
    ("engine", "ZCL_HDDT_FACTORY", "HDDT: Nha may sinh adapter theo cau hinh", True, False, None),
    ("engine", "ZCL_HDDT_SECRET", "HDDT: Bo giai quyet secret API", True, False, None),
    ("engine", "ZCL_HDDT_PLATFORM", "HDDT: Bo giai quyet nen tang", True, False, None),
    ("engine", "ZCL_HDDT_PLAT_CLASSIC", "HDDT: Nen tang ABAP co dien", True, False, None),
    ("engine", "ZCL_HDDT_HTTP", "HDDT: Bo goi REST dieu khien bang cau hinh", True, False, None),
    ("engine", "ZCL_HDDT_TOKEN", "HDDT: Quan ly access token", True, False, None),
    ("engine", "ZCL_HDDT_LOG", "HDDT: Ghi log API va so dang ky hoa don", True, False, None),
    ("engine", "ZCL_HDDT_SERVICE", "HDDT: Service facade - cua vao duy nhat", True, False, None),
    ("engine", "ZCL_HDDT_SRC_BASE", "HDDT: Lop cha doc du lieu nguon (buyer/seller/thue)", False, True, None),
    ("engine", "ZCL_HDDT_SRC_FI", "HDDT: Doc du lieu nguon chung tu FI", False, False, None),
    ("engine", "ZCL_HDDT_SRC_SD", "HDDT: Doc hoa don billing SD chua co FI", False, False, None),
    ("prov", "ZCL_HDDT_PROV_BASE", "HDDT: Lop cha truu tuong cho adapter", False, True, None),
    ("prov", "ZCL_HDDT_PROV_VIETTEL", "HDDT: Adapter Viettel SInvoice", True, False, None),
    ("prov", "ZCL_HDDT_PROV_FPT", "HDDT: Adapter FPT eInvoice", True, False, None),
    ("prov", "ZCL_HDDT_PROV_TEMPLATE", "HDDT: Adapter tong quat theo mau payload", False, False, None),
    ("prov", "ZCL_HDDT_PROV_VNPT", "HDDT: Adapter VNPT / Vinaphone", True, False, None),
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
    ("ui", "ZPG_HDDT_INTEGRATION", "1", [
        ("R", "", "Tích hợp hoá đơn điện tử"),
        ("I", "B01", "Chứng từ nguồn"),
        ("I", "B02", "Nhà cung cấp và trạng thái"),
        ("I", "B03", "Tuỳ chọn xử lý"),
        ("S", "P_BUKRS", "Mã công ty"),
        ("S", "P_GJAHR", "Năm tài chính"),
        ("S", "S_BELNR", "Số chứng từ"),
        ("S", "S_BUDAT", "Ngày ghi sổ"),
        ("S", "S_BLART", "Loại chứng từ"),
        ("S", "S_BLDAT", "Ngày chứng từ"),
        ("S", "S_VBELN", "Số billing SD"),
        ("S", "S_KUNNR", "Khách hàng"),
        ("S", "S_USNAM", "Người hạch toán"),
        ("S", "P_SRCT", "Loại nguồn dữ liệu"),
        ("S", "P_PROV", "NCC (trống = theo cấu hình)"),
        ("S", "S_STAT", "Trạng thái HĐĐT"),
        ("S", "P_REVER", "Lấy cả CT đã đảo/billing huỷ"),
        ("S", "P_TEST", "Test run (chỉ dựng payload)"),
    ]),
    ("ui", "ZPG_HDDT_INTEGRATION_TOP", "I", [("R", "", "Include ZPG_HDDT_INTEGRATION_TOP")]),
    ("ui", "ZPG_HDDT_INTEGRATION_F01", "I", [("R", "", "Include ZPG_HDDT_INTEGRATION_F01")]),
    ("ui", "ZPG_HDDT_CONFIG", "1", [
        ("R", "", "Cấu hình tích hợp hoá đơn điện tử"),
    ]),
    ("ui", "ZPG_HDDT_LOG", "1", [
        ("R", "", "Log tích hợp hoá đơn điện tử"),
        ("I", "B01", "Chứng từ / thời điểm"),
        ("I", "B02", "Lọc theo kết quả"),
        ("S", "P_BUKRS", "Mã công ty"),
        ("S", "P_GJAHR", "Năm tài chính"),
        ("S", "S_DOCNO", "Số chứng từ nguồn"),
        ("S", "S_DATE", "Ngày ghi log"),
        ("S", "S_PROV", "Nhà cung cấp"),
        ("S", "S_ACTION", "Mã nghiệp vụ"),
        ("S", "S_CODE", "Mã HTTP"),
        ("S", "P_ONLYER", "Chỉ hiện dòng lỗi"),
        ("S", "P_TEST", "Kèm cả dòng Test run"),
        ("S", "P_MAX", "Số dòng tối đa"),
    ]),
    ("ui", "ZPG_HDDT_SETUP", "1", [
        ("R", "", "Nạp cấu hình khởi tạo HĐĐT"),
        ("I", "B01", "Phạm vi nạp cấu hình"),
        ("I", "B02", "Chế độ chạy"),
        ("S", "P_BASE", "Danh mục, tham số, nguồn chung"),
        ("S", "P_PROV1", "Cấu hình Viettel SInvoice"),
        ("S", "P_PROV2", "Cấu hình FPT eInvoice"),
        ("S", "P_PROV3", "Cấu hình VNPT (khung)"),
        ("S", "P_OVWRT", "Ghi đè bản ghi đã tồn tại"),
        ("S", "P_TEST", "Chỉ mô phỏng, không ghi bảng"),
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
MSAG = "ZMS_HDDT"
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
    ("ZFI001", "ZPG_HDDT_INTEGRATION", "Tích hợp hoá đơn điện tử"),
    ("ZFI002", "ZPG_HDDT_CONFIG", "Cấu hình hoá đơn điện tử"),
    ("ZFI003", "ZPG_HDDT_LOG", "Log tích hợp hoá đơn điện tử"),
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

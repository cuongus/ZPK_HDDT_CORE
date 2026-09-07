# -*- coding: utf-8 -*-
"""Sinh cac file abapGit XML cho lop DDIC cua package ZPK_HDDT_CORE.

Chay:   python tools/gen_ddic.py
Ghi ra: src/ddic/<ten>.doma.xml, .dtel.xml, .tabl.xml

DDIC text dung tieng Viet KHONG dau de tranh loi codepage khi master
language cua repo la EN. Tieng Viet co dau nam trong comment ABAP va docs.
"""
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "src", "ddic")
HDR = ('<?xml version="1.0" encoding="utf-8"?>\n'
       '<abapGit version="v1.0.0" serializer="{ser}" serializer_version="v1.0.0">\n'
       ' <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">\n'
       '  <asx:values>\n')
FTR = '  </asx:values>\n </asx:abap>\n</abapGit>\n'


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def write(name, ext, ser, body):
    path = os.path.join(OUT, "%s.%s.xml" % (name.lower(), ext))
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(HDR.format(ser=ser) + body + FTR)


# ---------------------------------------------------------------------------
# 1. DOMAIN  (name, datatype, leng, decimals, text, fixed values)
# ---------------------------------------------------------------------------
DOMAINS = [
    ("ZDO_HDDT_PROV", "CHAR", 10, 0, "HDDT: Nha cung cap hoa don dien tu", []),
    ("ZDO_HDDT_ACTION", "CHAR", 30, 0, "HDDT: Ma nghiep vu (action)", []),
    ("ZDO_HDDT_AUTH", "CHAR", 1, 0, "HDDT: Phuong thuc xac thuc", [
        ("B", "Basic authentication (RFC 7617)"),
        ("H", "Username/password trong HTTP header"),
        ("T", "Bearer token lấy từ API đăng nhập"),
        ("O", "OAuth 2.0 client credentials"),
        ("N", "Không xác thực - destination tự xử lý"),
    ]),
    ("ZDO_HDDT_METHOD", "CHAR", 6, 0, "HDDT: HTTP method", [
        ("GET", "GET"), ("POST", "POST"), ("PUT", "PUT"),
        ("PATCH", "PATCH"), ("DELETE", "DELETE"),
    ]),
    ("ZDO_HDDT_STATUS", "CHAR", 2, 0, "HDDT: Trang thai hoa don trong SAP", [
        ("00", "Chưa tích hợp"),
        ("10", "Đã gửi - chờ phản hồi"),
        ("20", "Chờ cấp số"),
        ("30", "Chờ duyệt"),
        ("40", "Đã phát hành"),
        ("45", "CQT từ chối (kiểm tra không hợp lệ)"),
        ("50", "Đã được CQT cấp mã"),
        ("60", "Đã điều chỉnh"),
        ("70", "Đã thay thế"),
        ("80", "Đã huỷ"),
        ("90", "Lỗi tích hợp"),
    ]),
    ("ZDO_HDDT_ADJTYPE", "CHAR", 1, 0, "HDDT: Loai dieu chinh hoa don", [
        ("1", "Hoá đơn gốc"),
        ("3", "Hoá đơn thay thế"),
        ("5", "Hoá đơn điều chỉnh"),
        ("7", "Hoá đơn xoá bỏ"),
    ]),
    ("ZDO_HDDT_DATESRC", "CHAR", 1, 0, "HDDT: Nguon ngay lap hoa don", [
        ("1", "Posting date (BUDAT)"),
        ("2", "Entry date (CPUDT)"),
        ("3", "System date (SY-DATUM)"),
        ("4", "Document date (BLDAT)"),
    ]),
    ("ZDO_HDDT_MAPTYPE", "CHAR", 20, 0, "HDDT: Loai anh xa gia tri", [
        ("PAYMENT", "Hình thức thanh toán"),
        ("TAXRATE", "Thuế suất"),
        ("UNIT", "Đơn vị tính"),
        ("INVTYPE", "Loại hoá đơn"),
        ("ITEMTYPE", "Hình thức hàng hoá"),
        ("CURRENCY", "Loại tiền"),
        ("GLACCT", "Tài khoản kế toán sinh dòng hàng hoá"),
        ("DOCTYPE", "Loại chứng từ kế toán"),
        ("TAXCODE", "Mã thuế đầu ra được phát hành (mẫu CP)"),
        ("TAXACCT", "Tài khoản thuế GTGT loại khỏi dòng hàng"),
        ("BILLTYPE", "Loại hoá đơn SD được phát hành"),
        ("CONDTYPE", "Loại điều kiện giá SD -> AMT+/AMT-/TAX"),
    ]),
    ("ZDO_HDDT_SRCTYPE", "CHAR", 4, 0, "HDDT: Loai nguon du lieu SAP", [
        ("FI", "FI document (BKPF/BSEG)"),
        ("SD", "SD billing document (VBRK/VBRP)"),
        ("MM", "MM invoice (RBKP/RSEG)"),
        ("GOM", "Chứng từ gom"),
        ("CUST", "Nguồn do khách hàng tự cài đặt"),
    ]),
    ("ZDO_HDDT_ITEMTYPE", "CHAR", 1, 0, "HDDT: Hinh thuc dong hang hoa", [
        ("0", "Hàng hoá / dịch vụ bình thường"),
        ("1", "Khuyến mại"),
        ("2", "Chiết khấu thương mại"),
        ("3", "Ghi chú / diễn giải"),
    ]),
]

for name, dtype, leng, dec, text, vals in DOMAINS:
    b = "   <DD01V>\n"
    b += "    <DOMNAME>%s</DOMNAME>\n" % name
    b += "    <DDLANGUAGE>E</DDLANGUAGE>\n"
    b += "    <DATATYPE>%s</DATATYPE>\n" % dtype
    b += "    <LENG>%06d</LENG>\n" % leng
    if dec:
        b += "    <DECIMALS>%06d</DECIMALS>\n" % dec
    b += "    <OUTPUTLEN>%06d</OUTPUTLEN>\n" % leng
    if vals:
        b += "    <VALEXI>X</VALEXI>\n"
    b += "    <DDTEXT>%s</DDTEXT>\n" % esc(text)
    b += "    <DOMMASTER>E</DOMMASTER>\n"
    b += "   </DD01V>\n"
    if vals:
        b += "   <DD07V_TAB>\n"
        for i, (val, vtext) in enumerate(vals, start=1):
            b += "    <DD07V>\n"
            b += "     <DOMNAME>%s</DOMNAME>\n" % name
            b += "     <VALPOS>%04d</VALPOS>\n" % i
            b += "     <DDLANGUAGE>E</DDLANGUAGE>\n"
            b += "     <DOMVALUE_L>%s</DOMVALUE_L>\n" % esc(val)
            b += "     <DDTEXT>%s</DDTEXT>\n" % esc(vtext)
            b += "    </DD07V>\n"
        b += "   </DD07V_TAB>\n"
    write(name, "doma", "LCL_OBJECT_DOMA", b)


# ---------------------------------------------------------------------------
# 2. DATA ELEMENT (name, domain|(type,len,dec), short, medium, long, head, text)
# ---------------------------------------------------------------------------
DTELS = [
    ("ZDE_HDDT_PROV", "ZDO_HDDT_PROV", "NCC HĐĐT", "Nhà cung cấp", "Nhà cung cấp HĐĐT", "NCC HĐĐT", "Nhà cung cấp hoá đơn điện tử"),
    ("ZDE_HDDT_ACTION", "ZDO_HDDT_ACTION", "Nghiệp vụ", "Mã nghiệp vụ", "Mã nghiệp vụ HĐĐT", "Nghiệp vụ", "Mã nghiệp vụ HĐĐT (action)"),
    ("ZDE_HDDT_AUTH", "ZDO_HDDT_AUTH", "Xác thực", "Ph.thức xác thực", "Phương thức xác thực", "XT", "Phương thức xác thực API"),
    ("ZDE_HDDT_METHOD", "ZDO_HDDT_METHOD", "Method", "HTTP method", "HTTP method", "Method", "HTTP method"),
    ("ZDE_HDDT_STATUS", "ZDO_HDDT_STATUS", "T.thái", "Trạng thái", "Trạng thái HĐĐT", "TT", "Trạng thái hoá đơn điện tử trong SAP"),
    ("ZDE_HDDT_ADJTYPE", "ZDO_HDDT_ADJTYPE", "Loại ĐC", "Loại điều chỉnh", "Loại điều chỉnh hoá đơn", "Loại ĐC", "Loại điều chỉnh hoá đơn"),
    ("ZDE_HDDT_DATESRC", "ZDO_HDDT_DATESRC", "Ngày lập", "Nguồn ngày lập", "Nguồn ngày lập hoá đơn", "Ngày lập", "Nguồn ngày lập hoá đơn"),
    ("ZDE_HDDT_MAPTYPE", "ZDO_HDDT_MAPTYPE", "Loại AX", "Loại ánh xạ", "Loại ánh xạ giá trị", "Loại AX", "Loại ánh xạ giá trị"),
    ("ZDE_HDDT_SRCTYPE", "ZDO_HDDT_SRCTYPE", "Nguồn", "Loại nguồn", "Loại nguồn dữ liệu", "Nguồn", "Loại nguồn dữ liệu SAP"),
    ("ZDE_HDDT_ITEMTYPE", "ZDO_HDDT_ITEMTYPE", "H.thức", "Hình thức dòng", "Hình thức dòng hàng hoá", "HT", "Hình thức dòng hàng hoá"),
    ("ZDE_HDDT_CLASS", ("CHAR", 30, 0), "Lớp ABAP", "Lớp thực thi", "Lớp ABAP thực thi", "Lớp ABAP", "Tên lớp ABAP thực thi (adapter)"),
    ("ZDE_HDDT_CONNID", ("CHAR", 10, 0), "Kết nối", "Mã kết nối", "Mã kết nối API", "Kết nối", "Mã kết nối API"),
    ("ZDE_HDDT_URL", ("CHAR", 255, 0), "URL", "Base URL", "Base URL của API", "URL", "Base URL của API"),
    ("ZDE_HDDT_PATH", ("CHAR", 255, 0), "Path", "Đường dẫn API", "Đường dẫn API", "Path", "Đường dẫn API - hỗ trợ placeholder"),
    ("ZDE_HDDT_TAXCODE", ("CHAR", 20, 0), "MST", "Mã số thuế", "Mã số thuế", "MST", "Mã số thuế"),
    ("ZDE_HDDT_TEMPL", ("CHAR", 20, 0), "Mẫu HĐ", "Mẫu hoá đơn", "Mẫu số hoá đơn", "Mẫu HĐ", "Mẫu số hoá đơn"),
    ("ZDE_HDDT_SERIAL", ("CHAR", 20, 0), "Ký hiệu", "Ký hiệu HĐ", "Ký hiệu hoá đơn", "Ký hiệu", "Ký hiệu (serial) hoá đơn"),
    ("ZDE_HDDT_SEQ", ("CHAR", 20, 0), "Số HĐ", "Số hoá đơn", "Số hoá đơn", "Số HĐ", "Số hoá đơn do NCC cấp"),
    ("ZDE_HDDT_IDKEY", ("CHAR", 40, 0), "IDKey", "Khoá đối chiếu", "Khoá đối chiếu SAP-HĐĐT", "IDKey", "Khoá đối chiếu SAP - HĐĐT"),
    ("ZDE_HDDT_INVTYPE", ("CHAR", 10, 0), "Loại HĐ", "Loại hoá đơn", "Loại hoá đơn", "Loại HĐ", "Loại hoá đơn (01GTKT, 02GTTT)"),
    ("ZDE_HDDT_USER", ("CHAR", 60, 0), "User API", "Tài khoản API", "Tài khoản API", "User API", "Tài khoản đăng nhập API"),
    ("ZDE_HDDT_SECRET", ("CHAR", 128, 0), "Secret", "Mật khẩu API", "Mật khẩu / secret API", "Secret", "Mật khẩu API - nên dùng SECKEY"),
    ("ZDE_HDDT_SECKEY", ("CHAR", 40, 0), "SecKey", "Khoá secure", "Khoá secure store", "SecKey", "Khoá tra cứu trong secure storage"),
    ("ZDE_HDDT_TOKEN", ("STRG", 0, 0), "Token", "Access token", "Access token", "Token", "Access token (JWT)"),
    ("ZDE_HDDT_JSON", ("STRG", 0, 0), "JSON", "Nội dung JSON", "Nội dung JSON", "JSON", "Nội dung payload JSON"),
    ("ZDE_HDDT_MSG", ("CHAR", 255, 0), "Th.điệp", "Thông điệp", "Thông điệp trả về", "Thông điệp", "Thông điệp trả về từ NCC"),
    ("ZDE_HDDT_RCCODE", ("CHAR", 20, 0), "Mã tr.về", "Mã trả về NCC", "Mã trả về của NCC", "Mã tr.về", "Mã trả về của nhà cung cấp"),
    ("ZDE_HDDT_MAPVAL", ("CHAR", 50, 0), "Giá trị", "Giá trị ánh xạ", "Giá trị ánh xạ", "Giá trị", "Giá trị ánh xạ"),
    ("ZDE_HDDT_LOGID", ("CHAR", 32, 0), "Log ID", "ID bản ghi log", "ID bản ghi log", "Log ID", "ID bản ghi log (GUID)"),
    ("ZDE_HDDT_MSCQT", ("CHAR", 40, 0), "Mã CQT", "Mã CQT cấp", "Mã cơ quan thuế cấp", "Mã CQT", "Mã số do cơ quan thuế cấp"),
    ("ZDE_HDDT_SEC", ("CHAR", 20, 0), "Mã tra cứu", "Mã tra cứu HĐ", "Mã tra cứu hoá đơn", "Mã tra cứu", "Mã tra cứu hoá đơn"),
    ("ZDE_HDDT_LINK", ("CHAR", 255, 0), "Link", "Link tra cứu", "Link tra cứu hoá đơn", "Link", "Link tra cứu hoá đơn"),
    ("ZDE_HDDT_PARMKEY", ("CHAR", 40, 0), "Tham số", "Tên tham số", "Tên tham số cấu hình", "Tham số", "Tên tham số cấu hình"),
    ("ZDE_HDDT_PARMVAL", ("CHAR", 255, 0), "Giá trị", "Giá trị tham số", "Giá trị tham số", "Giá trị", "Giá trị tham số cấu hình"),
    ("ZDE_HDDT_TIMEOUT", ("INT4", 10, 0), "Timeout", "Timeout (giây)", "Timeout gọi API (giây)", "Timeout", "Timeout gọi API tính bằng giây"),
    ("ZDE_HDDT_AMOUNT", ("DEC", 23, 6), "Số tiền", "Số tiền", "Số tiền HĐĐT", "Số tiền", "Số tiền trên hoá đơn điện tử"),
    ("ZDE_HDDT_QTY", ("DEC", 23, 6), "Số lượng", "Số lượng", "Số lượng", "Số lượng", "Số lượng hàng hoá"),
    ("ZDE_HDDT_RATE", ("DEC", 7, 2), "T.suất", "Thuế suất", "Thuế suất / tỷ lệ", "TS", "Thuế suất hoặc tỷ lệ phần trăm"),
    ("ZDE_HDDT_DESCR", ("CHAR", 60, 0), "Mô tả", "Mô tả", "Mô tả", "Mô tả", "Mô tả"),
    ("ZDE_HDDT_DOCNO", ("CHAR", 20, 0), "Số CT", "Số chứng từ", "Số chứng từ nguồn", "Số CT", "Số chứng từ nguồn trên SAP"),
    ("ZDE_HDDT_NAME", ("CHAR", 255, 0), "Tên", "Tên / diễn giải", "Tên / diễn giải", "Tên", "Tên hoặc diễn giải dài"),
    ("ZDE_HDDT_LINENO", ("NUMC", 6, 0), "Dòng", "Số dòng", "Số dòng hàng hoá", "Dòng", "Số dòng hàng hoá"),
    ("ZDE_HDDT_RAW", ("RSTR", 0, 0), "Byte", "Nội dung byte", "Nội dung nguyên bản (byte)", "Byte", "Nội dung nguyên bản trên đường truyền"),
    ("ZDE_HDDT_SIZE", ("INT4", 10, 0), "Byte", "Số byte", "Kích thước (byte)", "Byte", "Kích thước nội dung tính bằng byte"),
    ("ZDE_HDDT_CODEPAGE", ("CHAR", 20, 0), "Codepage", "Bảng mã", "Bảng mã của nội dung", "Codepage", "Bảng mã dùng khi ghi byte (vd UTF-8)"),
    ("ZDE_HDDT_ATTEMPT", ("NUMC", 3, 0), "Lần", "Lần gọi thứ", "Lần gọi thứ mấy", "Lần", "Số lần đã gọi cho cùng nghiệp vụ"),
    ("ZDE_HDDT_CALLER", ("CHAR", 40, 0), "Nguồn gọi", "Chương trình gọi", "Chương trình / job gọi", "Nguồn gọi", "Chương trình, transaction hoặc job đã gọi"),
    ("ZDE_HDDT_ADJDIR", ("CHAR", 1, 0), "Hướng ĐC", "Hướng điều chỉnh", "Hướng điều chỉnh (1 tăng/0 giảm/2 TT)", "Hướng ĐC", "1 tang, 0 giam, 2 dieu chinh thong tin"),
    ("ZDE_HDDT_MAILST", ("CHAR", 1, 0), "Email", "Trạng thái email", "Trạng thái gửi email hoá đơn", "Email", "S da gui, E loi, trong = chua gui"),
    ("ZDE_HDDT_DIRECT", ("CHAR", 1, 0), "Chiều", "Chiều gọi API", "Chiều gọi API (O ra / I vào)", "Chiều", "O outbound SAP->NCC, I inbound"),
    ("ZDE_HDDT_OBJTYPE", ("CHAR", 10, 0), "Đối tượng", "Loại đối tượng", "Loại đối tượng nghiệp vụ", "Đối tượng", "Loai doi tuong nghiep vu cua loi goi"),
    ("ZDE_HDDT_APIVER", ("CHAR", 10, 0), "Phiên bản", "Phiên bản API", "Phiên bản tài liệu API", "Phiên bản", "Phien ban tai lieu API cua NCC"),
    ("ZDE_HDDT_HOST", ("CHAR", 40, 0), "Máy chủ", "Máy chủ ứng dụng", "Application server thực thi", "Máy chủ", "Application server thuc thi loi goi"),
]

for name, typ, s, m, lg, h, ddtext in DTELS:
    b = "   <DD04V>\n"
    b += "    <ROLLNAME>%s</ROLLNAME>\n" % name
    b += "    <DDLANGUAGE>E</DDLANGUAGE>\n"
    if isinstance(typ, str):
        b += "    <DOMNAME>%s</DOMNAME>\n" % typ
    else:
        dt, ln, dc = typ
        b += "    <DATATYPE>%s</DATATYPE>\n" % dt
        b += "    <LENG>%06d</LENG>\n" % ln
        if dc:
            b += "    <DECIMALS>%06d</DECIMALS>\n" % dc
        b += "    <OUTPUTLEN>%06d</OUTPUTLEN>\n" % ln
    b += "    <HEADLEN>%02d</HEADLEN>\n" % min(len(h), 55)
    b += "    <SCRLEN1>%02d</SCRLEN1>\n" % min(len(s), 10)
    b += "    <SCRLEN2>%02d</SCRLEN2>\n" % min(len(m), 20)
    b += "    <SCRLEN3>%02d</SCRLEN3>\n" % min(len(lg), 40)
    b += "    <DDTEXT>%s</DDTEXT>\n" % esc(ddtext)
    b += "    <REPTEXT>%s</REPTEXT>\n" % esc(h)
    b += "    <SCRTEXT_S>%s</SCRTEXT_S>\n" % esc(s)
    b += "    <SCRTEXT_M>%s</SCRTEXT_M>\n" % esc(m)
    b += "    <SCRTEXT_L>%s</SCRTEXT_L>\n" % esc(lg)
    b += "    <DTELMASTER>E</DTELMASTER>\n"
    b += "   </DD04V>\n"
    write(name, "dtel", "LCL_OBJECT_DTEL", b)


# ---------------------------------------------------------------------------
# 3. TABLE
# ---------------------------------------------------------------------------
def K(n, r):
    return (n, r, "X")


def F(n, r):
    return (n, r, "")


TABLES = [
    ("ZTB_HDDT_PROV", "C", "HDDT: Danh muc nha cung cap", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"),
        F("CLASSNAME", "ZDE_HDDT_CLASS"), F("DESCR", "ZDE_HDDT_DESCR"),
        F("XACTIVE", "XFELD"),
    ]),
    ("ZTB_HDDT_CONN", "C", "HDDT: Cau hinh ket noi API", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("CONNID", "ZDE_HDDT_CONNID"),
        F("RFCDEST", "RFCDEST"), F("BASE_URL", "ZDE_HDDT_URL"),
        F("AUTH_MODE", "ZDE_HDDT_AUTH"), F("TOKEN_ACTION", "ZDE_HDDT_ACTION"),
        F("TOKEN_TTL", "ZDE_HDDT_TIMEOUT"), F("TIMEOUT", "ZDE_HDDT_TIMEOUT"),
        F("SSL_ID", "SSFAPPLSSL"), F("DESCR", "ZDE_HDDT_DESCR"), F("XACTIVE", "XFELD"),
    ]),
    ("ZTB_HDDT_ACT", "C", "HDDT: Danh muc endpoint theo nghiep vu", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("ACTION", "ZDE_HDDT_ACTION"),
        F("HTTP_METHOD", "ZDE_HDDT_METHOD"), F("API_PATH", "ZDE_HDDT_PATH"),
        F("CONT_TYPE", "ZDE_HDDT_PARMVAL"), F("ACCEPT_TYPE", "ZDE_HDDT_PARMVAL"),
        F("DESCR", "ZDE_HDDT_DESCR"), F("XACTIVE", "XFELD"),
    ]),
    ("ZTB_HDDT_CRED", "C", "HDDT: Tai khoan va dai so theo cong ty", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("BUKRS", "BUKRS"),
        K("INV_TYPE", "ZDE_HDDT_INVTYPE"),
        F("CONNID", "ZDE_HDDT_CONNID"), F("TAXCODE", "ZDE_HDDT_TAXCODE"),
        F("TEMPLATE", "ZDE_HDDT_TEMPL"), F("SERIAL", "ZDE_HDDT_SERIAL"),
        F("APIUSER", "ZDE_HDDT_USER"), F("SECKEY", "ZDE_HDDT_SECKEY"),
        F("APISECRET", "ZDE_HDDT_SECRET"),
        F("VALID_FROM", "DATS"), F("VALID_TO", "DATS"), F("XACTIVE", "XFELD"),
    ]),
    ("ZTB_HDDT_STAT", "C", "HDDT: Anh xa trang thai NCC sang SAP", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("ACTION", "ZDE_HDDT_ACTION"),
        K("RC_CODE", "ZDE_HDDT_RCCODE"),
        F("SAP_STATUS", "ZDE_HDDT_STATUS"), F("MSGTY", "SYMSGTY"),
        F("MSG_TEXT", "ZDE_HDDT_MSG"),
    ]),
    ("ZTB_HDDT_MAP", "C", "HDDT: Anh xa gia tri SAP - NCC", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("MAP_TYPE", "ZDE_HDDT_MAPTYPE"),
        K("SAP_VALUE", "ZDE_HDDT_MAPVAL"),
        F("EXT_VALUE", "ZDE_HDDT_MAPVAL"), F("EXT_TEXT", "ZDE_HDDT_DESCR"),
    ]),
    ("ZTB_HDDT_PARM", "C", "HDDT: Tham so cau hinh chung", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("BUKRS", "BUKRS"),
        K("PARM_KEY", "ZDE_HDDT_PARMKEY"),
        F("PARM_VAL", "ZDE_HDDT_PARMVAL"), F("DESCR", "ZDE_HDDT_DESCR"),
    ]),
    ("ZTB_HDDT_DATE", "C", "HDDT: Nguon ngay lap hoa don theo cong ty", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"),
        F("DATE_SRC", "ZDE_HDDT_DATESRC"), F("TIME_CUT", "UZEIT"),
        F("DESCR", "ZDE_HDDT_DESCR"),
    ]),
    ("ZTB_HDDT_SRC", "C", "HDDT: Lop doc du lieu nguon", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"), K("SRC_TYPE", "ZDE_HDDT_SRCTYPE"),
        F("CLASSNAME", "ZDE_HDDT_CLASS"), F("DESCR", "ZDE_HDDT_DESCR"),
        F("XACTIVE", "XFELD"),
    ]),
    ("ZTB_HDDT_TPL", "C", "HDDT: Mau payload theo nghiep vu", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("ACTION", "ZDE_HDDT_ACTION"),
        F("DESCR", "ZDE_HDDT_DESCR"), F("XACTIVE", "XFELD"),
        F("TPL_BODY", "ZDE_HDDT_JSON"),
    ]),
    ("ZTB_HDDT_TOK", "A", "HDDT: Bo dem access token", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("CONNID", "ZDE_HDDT_CONNID"),
        K("BUKRS", "BUKRS"), K("APIUSER", "ZDE_HDDT_USER"),
        F("VALID_TO", "TIMESTAMPL"), F("CREATED_AT", "TIMESTAMPL"),
        F("TOKEN", "ZDE_HDDT_TOKEN"),
    ]),
    ("ZTB_HDDT_INV", "A", "HDDT: So dang ky hoa don dien tu", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"), K("GJAHR", "GJAHR"),
        K("SRC_TYPE", "ZDE_HDDT_SRCTYPE"), K("SRC_DOCNO", "ZDE_HDDT_DOCNO"),
        F("PROVIDER", "ZDE_HDDT_PROV"), F("IDKEY", "ZDE_HDDT_IDKEY"),
        F("INV_TYPE", "ZDE_HDDT_INVTYPE"), F("TEMPLATE", "ZDE_HDDT_TEMPL"),
        F("SERIAL", "ZDE_HDDT_SERIAL"), F("SEQ", "ZDE_HDDT_SEQ"),
        F("INV_DATE", "DATS"), F("INV_TIME", "UZEIT"),
        F("ISSUE_DATE", "DATS"), F("CANCEL_DATE", "DATS"),
        F("ADJ_TYPE", "ZDE_HDDT_ADJTYPE"),
        F("REF_DOCNO", "ZDE_HDDT_DOCNO"), F("REF_GJAHR", "GJAHR"),
        F("SUPP_TAXCODE", "ZDE_HDDT_TAXCODE"), F("MSCQT", "ZDE_HDDT_MSCQT"),
        F("SEC_CODE", "ZDE_HDDT_SEC"), F("INV_LINK", "ZDE_HDDT_LINK"),
        F("STATUS", "ZDE_HDDT_STATUS"), F("PROV_STATUS", "ZDE_HDDT_RCCODE"),
        F("MESSAGE", "ZDE_HDDT_MSG"),
        F("BUYER_CODE", "KUNNR"), F("BUYER_NAME", "ZDE_HDDT_NAME"),
        F("BUYER_TAX", "ZDE_HDDT_TAXCODE"), F("BUYER_ADDR", "ZDE_HDDT_NAME"),
        F("BUYER_MAIL", "ZDE_HDDT_NAME"),
        F("WAERS", "WAERS"), F("EXRATE", "UKURS_CURR"),
        F("AMOUNT", "ZDE_HDDT_AMOUNT"), F("VAT_AMOUNT", "ZDE_HDDT_AMOUNT"),
        F("TOTAL", "ZDE_HDDT_AMOUNT"),
        # --- FS MAG v0.5
        F("ADJ_DIR", "ZDE_HDDT_ADJDIR"), F("REF_SRCTYPE", "ZDE_HDDT_SRCTYPE"),
        F("TAX_STATUS", "ZDE_HDDT_RCCODE"), F("GOM_NO", "ZDE_HDDT_DOCNO"),
        F("ITEM_TEXT", "ZDE_HDDT_NAME"),
        F("MAIL_STATUS", "ZDE_HDDT_MAILST"), F("MAIL_DATE", "DATS"),
        F("CREATED_BY", "SYUNAME"), F("CREATED_AT", "TIMESTAMPL"),
        F("CHANGED_BY", "SYUNAME"), F("CHANGED_AT", "TIMESTAMPL"),
    ]),
    ("ZTB_HDDT_GOM", "A", "HDDT: Chung tu thanh vien cua hoa don gom", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"), K("GJAHR", "GJAHR"),
        K("GOM_NO", "ZDE_HDDT_DOCNO"),
        K("SRC_TYPE", "ZDE_HDDT_SRCTYPE"), K("SRC_DOCNO", "ZDE_HDDT_DOCNO"),
        F("XCANCEL", "XFELD"),
        F("CREATED_BY", "SYUNAME"), F("CREATED_AT", "TIMESTAMPL"),
        F("CANCEL_BY", "SYUNAME"), F("CANCEL_AT", "TIMESTAMPL"),
    ]),
    ("ZTB_HDDT_ITEM", "A", "HDDT: Chi tiet hang hoa da phat hanh", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"), K("GJAHR", "GJAHR"),
        K("SRC_TYPE", "ZDE_HDDT_SRCTYPE"), K("SRC_DOCNO", "ZDE_HDDT_DOCNO"),
        K("LINE_NO", "ZDE_HDDT_LINENO"),
        F("ITEM_CODE", "ZDE_HDDT_MAPVAL"), F("ITEM_NAME", "ZDE_HDDT_NAME"),
        F("ITEM_TYPE", "ZDE_HDDT_ITEMTYPE"), F("UNIT", "ZDE_HDDT_MAPVAL"),
        F("QUANTITY", "ZDE_HDDT_QTY"), F("PRICE", "ZDE_HDDT_AMOUNT"),
        F("AMOUNT", "ZDE_HDDT_AMOUNT"), F("TAX_RATE", "ZDE_HDDT_RATE"),
        F("TAX_AMOUNT", "ZDE_HDDT_AMOUNT"), F("TOTAL", "ZDE_HDDT_AMOUNT"),
        F("DISC_PCT", "ZDE_HDDT_RATE"), F("DISC_AMT", "ZDE_HDDT_AMOUNT"),
        F("NOTE", "ZDE_HDDT_NAME"),
    ]),
    ("ZTB_HDDT_LOG", "A", "HDDT: Log goi API", [
        K("MANDT", "MANDT"), K("LOG_ID", "ZDE_HDDT_LOGID"),
        # --- dinh danh nghiep vu
        F("PROVIDER", "ZDE_HDDT_PROV"), F("CONNID", "ZDE_HDDT_CONNID"),
        F("ACTION", "ZDE_HDDT_ACTION"),
        F("BUKRS", "BUKRS"), F("GJAHR", "GJAHR"),
        F("SRC_TYPE", "ZDE_HDDT_SRCTYPE"), F("SRC_DOCNO", "ZDE_HDDT_DOCNO"),
        F("IDKEY", "ZDE_HDDT_IDKEY"),
        F("ATTEMPT", "ZDE_HDDT_ATTEMPT"),
        F("TEST_RUN", "XFELD"),
        # --- ket qua
        F("SERIAL", "ZDE_HDDT_SERIAL"), F("SEQ", "ZDE_HDDT_SEQ"),
        F("SAP_STATUS", "ZDE_HDDT_STATUS"),
        F("PROV_STATUS", "ZDE_HDDT_RCCODE"),
        F("MSGTY", "SYMSGTY"), F("MESSAGE", "ZDE_HDDT_MSG"),
        # --- ky thuat HTTP
        F("HTTP_METHOD", "ZDE_HDDT_METHOD"), F("FULL_URL", "ZDE_HDDT_URL"),
        F("CONT_TYPE", "ZDE_HDDT_PARMVAL"),
        F("HTTP_CODE", "ZDE_HDDT_SIZE"), F("HTTP_REASON", "ZDE_HDDT_MSG"),
        F("DURATION_MS", "ZDE_HDDT_SIZE"),
        F("REQ_SIZE", "ZDE_HDDT_SIZE"), F("RES_SIZE", "ZDE_HDDT_SIZE"),
        F("CODEPAGE", "ZDE_HDDT_CODEPAGE"),
        F("MASKED", "XFELD"),
        # --- truy vet nguon goi
        F("CALLER", "ZDE_HDDT_CALLER"), F("TCODE", "TCODE"),
        # --- FS MAG v0.5: khop bang ZTB_INT_LOG
        F("DIRECTION", "ZDE_HDDT_DIRECT"), F("OBJECT_TYPE", "ZDE_HDDT_OBJTYPE"),
        F("API_VERSION", "ZDE_HDDT_APIVER"), F("ERROR_CODE", "ZDE_HDDT_RCCODE"),
        F("SUCCESS", "XFELD"), F("HAS_REQ", "XFELD"), F("HAS_RES", "XFELD"),
        F("HOSTNAME", "ZDE_HDDT_HOST"),
        F("CREATED_BY", "SYUNAME"), F("CREATED_AT", "TIMESTAMPL"),
        # --- noi dung nguyen ban tren duong truyen (byte-exact)
        F("REQ_HEADER", "ZDE_HDDT_RAW"), F("RES_HEADER", "ZDE_HDDT_RAW"),
        F("REQ_BODY", "ZDE_HDDT_RAW"), F("RES_BODY", "ZDE_HDDT_RAW"),
    ]),
]

for tab, delivery, text, fields in TABLES:
    b = "   <DD02V>\n"
    b += "    <TABNAME>%s</TABNAME>\n" % tab
    b += "    <DDLANGUAGE>E</DDLANGUAGE>\n"
    b += "    <TABCLASS>TRANSP</TABCLASS>\n"
    b += "    <CLIDEP>X</CLIDEP>\n"
    b += "    <DDTEXT>%s</DDTEXT>\n" % esc(text)
    b += "    <MASTERLANG>E</MASTERLANG>\n"
    b += "    <CONTFLAG>%s</CONTFLAG>\n" % delivery
    b += "    <EXCLASS>1</EXCLASS>\n"
    b += "   </DD02V>\n"
    b += "   <DD09L>\n"
    b += "    <TABNAME>%s</TABNAME>\n" % tab
    b += "    <AS4LOCAL>A</AS4LOCAL>\n"
    b += "    <TABKAT>0</TABKAT>\n"
    b += "    <TABART>APPL%s</TABART>\n" % ("1" if delivery == "C" else "0")
    if delivery == "C":
        b += "    <BUFALLOW>X</BUFALLOW>\n"
        b += "    <PUFFERUNG>X</PUFFERUNG>\n"
    else:
        b += "    <BUFALLOW>N</BUFALLOW>\n"
    b += "   </DD09L>\n"
    b += "   <DD03P_TABLE>\n"
    for fname, roll, keyflag in fields:
        b += "    <DD03P>\n"
        b += "     <FIELDNAME>%s</FIELDNAME>\n" % fname
        if keyflag:
            b += "     <KEYFLAG>X</KEYFLAG>\n"
        b += "     <ROLLNAME>%s</ROLLNAME>\n" % roll
        b += "     <ADMINFIELD>0</ADMINFIELD>\n"
        if keyflag:
            b += "     <NOTNULL>X</NOTNULL>\n"
        b += "     <COMPTYPE>E</COMPTYPE>\n"
        b += "    </DD03P>\n"
    b += "   </DD03P_TABLE>\n"
    write(tab, "tabl", "LCL_OBJECT_TABL", b)

print("domains :", len(DOMAINS))
print("dtels   :", len(DTELS))
print("tables  :", len(TABLES))
print("files   :", len(os.listdir(OUT)))

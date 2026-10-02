# -*- coding: utf-8 -*-
"""Sinh cac file abapGit XML cho lop DDIC cua package ZPK_HDDT_CORE.

Chay:   python tools/gen_ddic.py
Ghi ra: src/ddic/<ten>.doma.xml, .dtel.xml, .tabl.xml

Nhan bang / data element dung tieng Viet CO DAU, dung nhu tren he (DS4, doi
chieu 30/09/2026). Moi thay doi DDIC tren he phai sua lai o day, khong thi chay
generator se ghi de nguoc len repo.
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
        # FS v0.17 muc 3.3 Nhom 2 - hoa don dau vao tra lai hang NCC
        ("PO", "Trả lại hàng NCC (đơn hàng mua)"),
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
    # Co checkbox: dung lai domain XFELD (CHAR 1) de SM30 van ve o tick,
    # nhung co nhan rieng nen maintenance view sinh ra da co chu san,
    # khong phai vao sua view dien tay.
    ("ZDE_HDDT_ACTIVE", "XFELD", "Kích hoạt", "Đang kích hoạt",
     "Dòng cấu hình đang kích hoạt", "Kích hoạt",
     "Dòng cấu hình đang kích hoạt"),
    # FS v0.17 muc I: nguoi mua cua hoa don dau vao (tra lai hang NCC) la
    # NHA CUNG CAP, nen cot ma doi tac phai chua duoc ca KUNNR lan LIFNR.
    # CHAR 10 khong gan check table de khong keo theo search help / foreign
    # key cua rieng khach hang.
    ("ZDE_HDDT_PARTNER", "CHAR10", "Mã ĐT", "Mã đối tác",
     "Mã khách hàng hoặc nhà cung cấp", "Mã ĐT",
     "Mã đối tác trên hoá đơn: khách hàng (KUNNR) hoặc NCC (LIFNR)"),
    ("ZDE_HDDT_BSART", "BSART", "Loại ĐH", "Loại đơn hàng mua",
     "Loại đơn hàng mua được phát hành HĐ", "Loại ĐH",
     "Loại đơn hàng mua được phép phát hành hoá đơn điện tử"),
    ("ZDE_HDDT_MWSPAT", "CHAR10", "Mẫu thuế", "Mẫu mã thuế vào",
     "Mẫu mã thuế GTGT đầu vào", "Mẫu thuế",
     "Mẫu mã thuế GTGT đầu vào, ví dụ I*"),
    ("ZDE_HDDT_HKONTP", "CHAR10", "TK thuế", "TK thuế GTGT vào",
     "Tài khoản thuế GTGT đầu vào", "TK thuế",
     "Mẫu tài khoản thuế GTGT đầu vào, ví dụ 1331*"),
    ("ZDE_HDDT_DEFAULT", "XFELD", "Mặc định", "Dải số mặc định",
     "Dải số mặc định của đơn vị", "Mặc định",
     "Dải số hoá đơn mặc định của đơn vị"),
    ("ZDE_HDDT_CLASS", ("CHAR", 30, 0), "Lớp ABAP", "Lớp thực thi", "Lớp ABAP thực thi", "Lớp ABAP", "Tên lớp ABAP thực thi (adapter)"),
    ("ZDE_HDDT_CONNID", ("CHAR", 10, 0), "Kết nối", "Mã kết nối", "Mã kết nối API", "Kết nối", "Mã kết nối API"),
    ("ZDE_HDDT_URL", ("CHAR", 255, 0), "URL", "Base URL", "Base URL của API", "URL", "Base URL của API"),
    ("ZDE_HDDT_PATH", ("CHAR", 255, 0), "Path", "Đường dẫn API", "Đường dẫn API", "Path", "Đường dẫn API - hỗ trợ placeholder"),
    ("ZDE_HDDT_TAXCODE", ("CHAR", 20, 0), "MST", "Mã số thuế", "Mã số thuế", "MST", "Mã số thuế"),
    ("ZDE_HDDT_TEMPL", ("CHAR", 20, 0), "Mẫu HĐ", "Mẫu hoá đơn", "Mẫu hoá đơn", "Mẫu HĐ", "Mẫu số hoá đơn"),
    ("ZDE_HDDT_SERIAL", ("CHAR", 20, 0), "Ký hiệu", "Ký hiệu HĐ", "Ký hiệu hoá đơn", "Ký hiệu", "Ký hiệu (serial) hoá đơn"),
    ("ZDE_HDDT_SEQ", ("CHAR", 20, 0), "Số HĐ", "Số hoá đơn", "Số hoá đơn", "Số HĐ", "Số hoá đơn do NCC cấp"),
    ("ZDE_HDDT_IDKEY", ("CHAR", 40, 0), "IDKey", "Khoá đối chiếu", "Khoá đối chiếu SAP-HĐĐT", "IDKey", "Khoá đối chiếu SAP - HĐĐT"),
    ("ZDE_HDDT_INVTYPE", ("CHAR", 10, 0), "Loại HĐ", "Loại hoá đơn", "Loại hoá đơn", "Loại HĐ", "Loại hoá đơn (01GTKT, 02GTTT)"),
    ("ZDE_HDDT_USER", "TEXT60", "User API", "Tài khoản API", "Tài khoản API", "User API", "Tài khoản đăng nhập API"),
    ("ZDE_HDDT_SECRET", "TEXT128", "Secret", "Mật khẩu API", "Mật khẩu / secret API", "Secret", "Mật khẩu API - nên dùng SECKEY"),
    ("ZDE_HDDT_SECKEY", ("CHAR", 40, 0), "SecKey", "Khoá secure", "Khoá secure store", "SecKey", "Khoá tra cứu trong secure storage"),
    ("ZDE_HDDT_TOKEN", ("STRG", 0, 0), "Token", "Access token", "Access token", "Token", "Access token (JWT)"),
    ("ZDE_HDDT_JSON", ("STRG", 0, 0), "JSON", "Nội dung JSON", "Nội dung JSON", "JSON", "Nội dung payload JSON"),
    ("ZDE_HDDT_MSG", ("CHAR", 255, 0), "Th.điệp", "Thông điệp", "Thông điệp trả về", "Thông điệp", "Thông điệp trả về từ NCC"),
    ("ZDE_HDDT_RCCODE", ("CHAR", 20, 0), "Mã tr.về", "Mã trả về NCC", "Mã trả về của NCC", "Mã tr.về", "Mã trả về của nhà cung cấp"),
    ("ZDE_HDDT_MAPVAL", ("CHAR", 50, 0), "Giá trị", "Giá trị ánh xạ", "Giá trị ánh xạ", "Giá trị", "Giá trị ánh xạ"),
    ("ZDE_HDDT_LOGID", ("CHAR", 32, 0), "Log ID", "ID bản ghi log", "ID bản ghi log", "Log ID", "ID bản ghi log (GUID)"),
    ("ZDE_HDDT_MSCQT", ("CHAR", 40, 0), "Mã CQT", "Mã CQT cấp", "Mã cơ quan thuế cấp", "Mã CQT", "Mã số do cơ quan thuế cấp"),
    ("ZDE_HDDT_SEC", ("CHAR", 20, 0), "Mã tra cứu", "Mã tra cứu HĐ", "Mã tra cứu hoá đơn", "Mã tra cứu", "Mã tra cứu hoá đơn"),
    ("ZDE_HDDT_LINK", "CHAR255", "Link", "Link tra cứu", "Link tra cứu hoá đơn", "Link", "Link tra cứu hoá đơn"),
    ("ZDE_HDDT_PARMKEY", ("CHAR", 40, 0), "Tham số", "Tên tham số", "Tên tham số cấu hình", "Tham số", "Tên tham số cấu hình"),
    ("ZDE_HDDT_PARMVAL", ("CHAR", 255, 0), "Giá trị", "Giá trị tham số", "Giá trị tham số", "Giá trị", "Giá trị tham số cấu hình"),
    ("ZDE_HDDT_TIMEOUT", ("INT4", 10, 0), "Timeout", "Timeout (giây)", "Timeout gọi API (giây)", "Timeout", "Timeout gọi API tính bằng giây"),
    ("ZDE_HDDT_AMOUNT", ("DEC", 26, 3), "Số tiền", "Số tiền", "Số tiền HĐĐT", "Số tiền", "Số tiền trên hoá đơn điện tử"),
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

# Do dai nhan (HEADLEN, SCRLEN1, SCRLEN2, SCRLEN3) va OUTPUTLEN cua data
# element lay dung gia tri tren DS4 (DD04L, doi chieu 02/10/2026). SAP luu
# do dai DANH SAN cho nhan, khong phai do dai chu hien co; OUTPUTLEN kieu
# so dung san gom ca dau va dau phan cach (DEC 26,3 -> 34). Data element
# moi chua co o day thi tinh theo do dai chu / LENG nhu truoc.
DTEL_LENS = {
    "ZDE_HDDT_ACTION": (9, 9, 12, 17),
    "ZDE_HDDT_ACTIVE": (9, 9, 14, 28),
    "ZDE_HDDT_ADJDIR": (8, 8, 16, 37),
    "ZDE_HDDT_ADJTYPE": (7, 7, 15, 23),
    "ZDE_HDDT_AMOUNT": (7, 7, 7, 12),
    "ZDE_HDDT_APIVER": (9, 9, 13, 22),
    "ZDE_HDDT_ATTEMPT": (55, 10, 20, 40),
    "ZDE_HDDT_AUTH": (2, 8, 16, 20),
    "ZDE_HDDT_BSART": (7, 7, 17, 35),
    "ZDE_HDDT_CALLER": (40, 10, 20, 40),
    "ZDE_HDDT_CLASS": (30, 10, 20, 40),
    "ZDE_HDDT_CODEPAGE": (20, 10, 20, 40),
    "ZDE_HDDT_CONNID": (7, 7, 10, 14),
    "ZDE_HDDT_DATESRC": (55, 10, 20, 40),
    "ZDE_HDDT_DEFAULT": (8, 8, 15, 26),
    "ZDE_HDDT_DESCR": (5, 5, 5, 5),
    "ZDE_HDDT_DIRECT": (5, 5, 13, 28),
    "ZDE_HDDT_DOCNO": (20, 10, 20, 40),
    "ZDE_HDDT_HKONTP": (7, 7, 16, 27),
    "ZDE_HDDT_HOST": (40, 10, 20, 40),
    "ZDE_HDDT_IDKEY": (5, 5, 14, 23),
    "ZDE_HDDT_INVTYPE": (7, 7, 12, 12),
    "ZDE_HDDT_ITEMTYPE": (2, 6, 14, 23),
    "ZDE_HDDT_JSON": (4, 4, 13, 13),
    "ZDE_HDDT_LINENO": (6, 10, 20, 40),
    "ZDE_HDDT_LINK": (4, 4, 12, 20),
    "ZDE_HDDT_LOGID": (32, 10, 20, 40),
    "ZDE_HDDT_MAILST": (55, 10, 20, 40),
    "ZDE_HDDT_MAPTYPE": (20, 10, 20, 40),
    "ZDE_HDDT_MAPVAL": (50, 10, 20, 40),
    "ZDE_HDDT_METHOD": (6, 6, 11, 11),
    "ZDE_HDDT_MSCQT": (6, 6, 10, 19),
    "ZDE_HDDT_MSG": (10, 7, 10, 17),
    "ZDE_HDDT_MWSPAT": (8, 8, 15, 24),
    "ZDE_HDDT_NAME": (55, 10, 20, 40),
    "ZDE_HDDT_OBJTYPE": (10, 10, 20, 40),
    "ZDE_HDDT_PARMKEY": (7, 7, 11, 20),
    "ZDE_HDDT_PARMVAL": (55, 10, 20, 40),
    "ZDE_HDDT_PARTNER": (5, 5, 10, 31),
    "ZDE_HDDT_PATH": (4, 4, 13, 13),
    "ZDE_HDDT_PROV": (8, 8, 12, 17),
    "ZDE_HDDT_QTY": (29, 10, 20, 40),
    "ZDE_HDDT_RATE": (9, 10, 20, 40),
    "ZDE_HDDT_RAW": (55, 10, 20, 40),
    "ZDE_HDDT_RCCODE": (55, 10, 20, 40),
    "ZDE_HDDT_SEC": (20, 10, 20, 40),
    "ZDE_HDDT_SECKEY": (6, 6, 11, 17),
    "ZDE_HDDT_SECRET": (55, 10, 20, 40),
    "ZDE_HDDT_SEQ": (5, 5, 10, 10),
    "ZDE_HDDT_SERIAL": (20, 10, 20, 40),
    "ZDE_HDDT_SIZE": (11, 10, 20, 40),
    "ZDE_HDDT_SRCTYPE": (5, 5, 10, 18),
    "ZDE_HDDT_STATUS": (55, 10, 20, 40),
    "ZDE_HDDT_TAXCODE": (3, 3, 10, 10),
    "ZDE_HDDT_TEMPL": (6, 6, 11, 11),
    "ZDE_HDDT_TIMEOUT": (11, 10, 20, 40),
    "ZDE_HDDT_TOKEN": (5, 5, 12, 12),
    "ZDE_HDDT_URL": (3, 3, 8, 16),
    "ZDE_HDDT_USER": (55, 10, 20, 40),
}
DTEL_OUTLEN = {
    "ZDE_HDDT_ACTION": 30,
    "ZDE_HDDT_ACTIVE": 1,
    "ZDE_HDDT_ADJDIR": 1,
    "ZDE_HDDT_ADJTYPE": 1,
    "ZDE_HDDT_AMOUNT": 34,
    "ZDE_HDDT_APIVER": 10,
    "ZDE_HDDT_ATTEMPT": 3,
    "ZDE_HDDT_AUTH": 1,
    "ZDE_HDDT_BSART": 4,
    "ZDE_HDDT_CALLER": 40,
    "ZDE_HDDT_CLASS": 30,
    "ZDE_HDDT_CODEPAGE": 20,
    "ZDE_HDDT_CONNID": 10,
    "ZDE_HDDT_DATESRC": 1,
    "ZDE_HDDT_DEFAULT": 1,
    "ZDE_HDDT_DESCR": 60,
    "ZDE_HDDT_DIRECT": 1,
    "ZDE_HDDT_DOCNO": 20,
    "ZDE_HDDT_HKONTP": 10,
    "ZDE_HDDT_HOST": 40,
    "ZDE_HDDT_IDKEY": 40,
    "ZDE_HDDT_INVTYPE": 10,
    "ZDE_HDDT_ITEMTYPE": 1,
    "ZDE_HDDT_JSON": 0,
    "ZDE_HDDT_LINENO": 6,
    "ZDE_HDDT_LINK": 255,
    "ZDE_HDDT_LOGID": 32,
    "ZDE_HDDT_MAILST": 1,
    "ZDE_HDDT_MAPTYPE": 20,
    "ZDE_HDDT_MAPVAL": 50,
    "ZDE_HDDT_METHOD": 6,
    "ZDE_HDDT_MSCQT": 40,
    "ZDE_HDDT_MSG": 255,
    "ZDE_HDDT_MWSPAT": 10,
    "ZDE_HDDT_NAME": 255,
    "ZDE_HDDT_OBJTYPE": 10,
    "ZDE_HDDT_PARMKEY": 40,
    "ZDE_HDDT_PARMVAL": 255,
    "ZDE_HDDT_PARTNER": 10,
    "ZDE_HDDT_PATH": 255,
    "ZDE_HDDT_PROV": 10,
    "ZDE_HDDT_QTY": 29,
    "ZDE_HDDT_RATE": 9,
    "ZDE_HDDT_RAW": 0,
    "ZDE_HDDT_RCCODE": 20,
    "ZDE_HDDT_SEC": 20,
    "ZDE_HDDT_SECKEY": 40,
    "ZDE_HDDT_SECRET": 128,
    "ZDE_HDDT_SEQ": 20,
    "ZDE_HDDT_SERIAL": 20,
    "ZDE_HDDT_SIZE": 11,
    "ZDE_HDDT_SRCTYPE": 4,
    "ZDE_HDDT_STATUS": 2,
    "ZDE_HDDT_TAXCODE": 20,
    "ZDE_HDDT_TEMPL": 20,
    "ZDE_HDDT_TIMEOUT": 11,
    "ZDE_HDDT_TOKEN": 0,
    "ZDE_HDDT_URL": 255,
    "ZDE_HDDT_USER": 60,
}

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
        b += "    <OUTPUTLEN>%06d</OUTPUTLEN>\n" % DTEL_OUTLEN.get(name, ln)
    hl, l1, l2, l3 = DTEL_LENS.get(name, (min(len(h), 55), min(len(s), 10),
                                          min(len(m), 20), min(len(lg), 40)))
    b += "    <HEADLEN>%02d</HEADLEN>\n" % hl
    b += "    <SCRLEN1>%02d</SCRLEN1>\n" % l1
    b += "    <SCRLEN2>%02d</SCRLEN2>\n" % l2
    b += "    <SCRLEN3>%02d</SCRLEN3>\n" % l3
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
    ("ZTB_HDDT_PROV", "C", "HDDT: Danh mục nhà cung cấp", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"),
        F("CLASSNAME", "ZDE_HDDT_CLASS"), F("DESCR", "ZDE_HDDT_DESCR"),
        F("XACTIVE", "ZDE_HDDT_ACTIVE"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_CONN", "C", "HDDT: Cấu hình kết nối API", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("CONNID", "ZDE_HDDT_CONNID"),
        F("RFCDEST", "RFCDEST"), F("BASE_URL", "ZDE_HDDT_URL"),
        F("AUTH_MODE", "ZDE_HDDT_AUTH"), F("TOKEN_ACTION", "ZDE_HDDT_ACTION"),
        F("TOKEN_TTL", "ZDE_HDDT_TIMEOUT"), F("TIMEOUT", "ZDE_HDDT_TIMEOUT"),
        F("SSL_ID", "SSFAPPLSSL"), F("DESCR", "ZDE_HDDT_DESCR"), F("XACTIVE", "ZDE_HDDT_ACTIVE"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_ACT", "C", "HDDT: Danh mục endpoint theo nghiệp vụ", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("ACTION", "ZDE_HDDT_ACTION"),
        F("HTTP_METHOD", "ZDE_HDDT_METHOD"), F("API_PATH", "ZDE_HDDT_PATH"),
        F("CONT_TYPE", "ZDE_HDDT_PARMVAL"), F("ACCEPT_TYPE", "ZDE_HDDT_PARMVAL"),
        F("DESCR", "ZDE_HDDT_DESCR"), F("XACTIVE", "ZDE_HDDT_ACTIVE"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    # SERIAL nam trong KHOA: mot don vi co the dung nhieu dai so trong cung
    # mot nam (moi dai so mot ky hieu). XDEFAULT danh dau dai so duoc man
    # hinh tham so tu chon; chi duoc phep MOT dong X cho moi
    # PROVIDER + BUKRS + INV_TYPE con hieu luc.
    ("ZTB_HDDT_CRED", "C", "HDDT: Tài khoản và dải số theo công ty", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("BUKRS", "BUKRS"),
        # FS v0.17 muc L: mot phap nhan dang ky NHIEU dai so trong CUNG
        # MOT nam, va moi nam lai dang ky dai so khac nhau -> GJAHR vao
        # khoa, co Mac dinh duy nhat theo BUKRS + GJAHR.
        K("GJAHR", "GJAHR"),
        K("INV_TYPE", "ZDE_HDDT_INVTYPE"), K("TEMPLATE", "ZDE_HDDT_TEMPL"),
        K("SERIAL", "ZDE_HDDT_SERIAL"),
        F("CONNID", "ZDE_HDDT_CONNID"), F("TAXCODE", "ZDE_HDDT_TAXCODE"),
        F("APIUSER", "ZDE_HDDT_USER"), F("SECKEY", "ZDE_HDDT_SECKEY"),
        F("APISECRET", "ZDE_HDDT_SECRET"),
        F("VALID_FROM", "DATS"), F("VALID_TO", "DATS"),
        F("XDEFAULT", "ZDE_HDDT_DEFAULT"), F("XACTIVE", "ZDE_HDDT_ACTIVE"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    # FS v0.17 muc I: bang cau hinh loai don hang mua duoc phat hanh hoa
    # don (nghiep vu tra lai hang nha cung cap). Tuong duong ZEINVCONFIPO
    # trong FS. Gia tri khoi tao cho MAG: BSART = ZPO6, MWSKZ_PAT = I*,
    # HKONT_TAX = 1331*.
    ("ZTB_HDDT_PO", "C", "HDDT: Loại đơn hàng mua được phát hành hoá đơn", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"),
        K("BSART", "ZDE_HDDT_BSART"),
        F("MWSKZ_PAT", "ZDE_HDDT_MWSPAT"), F("HKONT_TAX", "ZDE_HDDT_HKONTP"),
        F("SRC_TYPE", "ZDE_HDDT_SRCTYPE"),
        F("DESCR", "ZDE_HDDT_DESCR"), F("XACTIVE", "ZDE_HDDT_ACTIVE"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_STAT", "C", "HDDT: Ánh xạ trạng thái NCC sang SAP", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("ACTION", "ZDE_HDDT_ACTION"),
        K("RC_CODE", "ZDE_HDDT_RCCODE"),
        F("SAP_STATUS", "ZDE_HDDT_STATUS"), F("MSGTY", "SYMSGTY"),
        F("MSG_TEXT", "ZDE_HDDT_MSG"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_MAP", "C", "HDDT: Ánh xạ giá trị SAP - NCC", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("MAP_TYPE", "ZDE_HDDT_MAPTYPE"),
        K("SAP_VALUE", "ZDE_HDDT_MAPVAL"),
        F("EXT_VALUE", "ZDE_HDDT_MAPVAL"), F("EXT_TEXT", "ZDE_HDDT_DESCR"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_PARM", "C", "HDDT: Tham số cấu hình chung", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("BUKRS", "BUKRS"),
        K("PARM_KEY", "ZDE_HDDT_PARMKEY"),
        F("PARM_VAL", "ZDE_HDDT_PARMVAL"), F("DESCR", "ZDE_HDDT_DESCR"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_DATE", "C", "HDDT: Nguồn ngày lập hóa đơn theo công ty", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"),
        F("DATE_SRC", "ZDE_HDDT_DATESRC"), F("TIME_CUT", "UZEIT"),
        F("DESCR", "ZDE_HDDT_DESCR"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_SRC", "C", "HDDT: Lớp đọc dữ liệu nguồn", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"), K("SRC_TYPE", "ZDE_HDDT_SRCTYPE"),
        F("CLASSNAME", "ZDE_HDDT_CLASS"), F("DESCR", "ZDE_HDDT_DESCR"),
        F("XACTIVE", "ZDE_HDDT_ACTIVE"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_TPL", "C", "HDDT: Mẫu payload theo nghiệp vụ", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("ACTION", "ZDE_HDDT_ACTION"),
        F("DESCR", "ZDE_HDDT_DESCR"), F("XACTIVE", "ZDE_HDDT_ACTIVE"),
        F("TPL_BODY", "ZDE_HDDT_JSON"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_TOK", "A", "HDDT: Bộ đệm access token", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZDE_HDDT_PROV"), K("CONNID", "ZDE_HDDT_CONNID"),
        K("BUKRS", "BUKRS"), K("APIUSER", "ZDE_HDDT_USER"),
        F("VALID_TO", "TIMESTAMPL"),
        F("TOKEN", "ZDE_HDDT_TOKEN"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_INV", "A", "HDDT: Sổ đăng ký hóa đơn điện tử", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"), K("GJAHR", "GJAHR"),
        K("SRC_TYPE", "ZDE_HDDT_SRCTYPE"), K("SRC_DOCNO", "ZDE_HDDT_DOCNO"),
        F("PROVIDER", "ZDE_HDDT_PROV"), F("IDKEY", "ZDE_HDDT_IDKEY"),
        F("INV_TYPE", "ZDE_HDDT_INVTYPE"), F("TEMPLATE", "ZDE_HDDT_TEMPL"),
        F("SERIAL", "ZDE_HDDT_SERIAL"), F("SEQ", "ZDE_HDDT_SEQ"),
        F("INV_DATE", "DATS"), F("INV_TIME", "UZEIT"),
        F("ISSUE_DATE", "DATS"), F("CANCEL_DATE", "DATS"),
        F("ADJ_TYPE", "ZDE_HDDT_ADJTYPE"),
        F("REF_DOCNO", "ZDE_HDDT_DOCNO"), F("REF_GJAHR", "GJAHR"),
        F("SUPP_TAXCODE", "ZDE_HDDT_TAXCODE"), F("MSCQT", "ZDE_HDDT_TAXCODE"),
        F("SEC_CODE", "ZDE_HDDT_SEC"), F("INV_LINK", "ZDE_HDDT_LINK"),
        F("STATUS", "ZDE_HDDT_STATUS"), F("PROV_STATUS", "ZDE_HDDT_RCCODE"),
        F("MESSAGE", "ZDE_HDDT_MSG"),
        F("BUYER_CODE", "ZDE_HDDT_PARTNER"), F("BUYER_NAME", "ZDE_HDDT_NAME"),
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
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_GOM", "A", "HDDT: Chứng từ thành viên của hóa đơn gộp", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"), K("GJAHR", "GJAHR"),
        K("GOM_NO", "ZDE_HDDT_DOCNO"),
        K("SRC_TYPE", "ZDE_HDDT_SRCTYPE"), K("SRC_DOCNO", "ZDE_HDDT_DOCNO"),
        F("XCANCEL", "XFELD"),
        F("CANCEL_BY", "SYUNAME"), F("CANCEL_AT", "TIMESTAMPL"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_ITEM", "A", "HDDT: Chi tiết hàng hóa đã phát hành", [
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
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
    ("ZTB_HDDT_LOG", "A", "HDDT: Log gọi API", [
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
        # --- noi dung nguyen ban tren duong truyen (byte-exact)
        F("REQ_HEADER", "ZDE_HDDT_RAW"), F("RES_HEADER", "ZDE_HDDT_RAW"),
        F("REQ_BODY", "ZDE_HDDT_RAW"), F("RES_BODY", "ZDE_HDDT_RAW"),
        F(".INCLUDE", "ZST_ADMIN_DATA"),
    ]),
]

# Co bao tri bang (SE11 "Data Browser/Table View Maint."). Mac dinh theo
# delivery class: C = cho bao tri, A = khong. Ngoai le lay tu he that.
# XML abapGit PHAI ghi MAINFLAG, thieu thi bang ve che do "co han che".
MAINT_OVERRIDE = {"ZTB_HDDT_TOK": "ALLOWED"}


def maint_of(tab, delivery):
    return MAINT_OVERRIDE.get(tab, "ALLOWED" if delivery == "C" else "NOT_ALLOWED")


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
    b += "    <MAINFLAG>%s</MAINFLAG>\n" % (
        "X" if maint_of(tab, delivery) == "ALLOWED" else "N")
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
        if fname == ".INCLUDE":
            # Structure include: ten structure nam o PRECFIELD, khong
            # phai ROLLNAME; COMPTYPE = 'S'
            b += "     <ADMINFIELD>0</ADMINFIELD>\n"
            b += "     <PRECFIELD>%s</PRECFIELD>\n" % roll
            b += "     <COMPTYPE>S</COMPTYPE>\n"
            b += "    </DD03P>\n"
            continue
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

    # Ban DDL de deploy thang qua ADT (deploy_adt.py PUT vao
    # /ddic/tables/<ten>/source/main). dist/ nam trong .gitignore.
    ddl = "@EndUserText.label : '%s'\n" % text.replace("'", "''")
    ddl += "@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE\n"
    ddl += "@AbapCatalog.tableCategory : #TRANSPARENT\n"
    ddl += "@AbapCatalog.deliveryClass : #%s\n" % delivery
    ddl += "@AbapCatalog.dataMaintenance : #%s\n" % maint_of(tab, delivery)
    ddl += "define table %s {\n\n" % tab.lower()
    for fname, roll, keyflag in fields:
        if fname == ".INCLUDE":
            ddl += "  include %s;\n" % roll.lower()
            continue
        ddl += "  %s%s : %s not null;\n" % (
            "key " if keyflag else "", fname.lower(), roll.lower())
    ddl += "\n}\n"
    ddl_dir = os.path.join(os.path.dirname(OUT), "..", "dist", "ddl")
    ddl_dir = os.path.normpath(ddl_dir)
    if not os.path.isdir(ddl_dir):
        os.makedirs(ddl_dir)
    with open(os.path.join(ddl_dir, "%s.tabl.abap" % tab.lower()),
              "w", encoding="utf-8", newline="\n") as fh:
        fh.write(ddl)


# ---------------------------------------------------------------------------
# Lock object (ENQU)
#
# Ten theo dung quy uoc dang chay tren he MAG S25: "E" + ten bang
# (EZTB_MM_PO_MAP cho ZTB_MM_PO_MAP), nen o day la EZTB_HDDT_*.
# Cau truc lay tu mot lock object THAT tren he (DD25L/DD25T/DD26S/DD27S
# cua EZTB_MM_PO_MAP): mot dong DD26E cho bang goc, moi truong KHOA mot
# dong DD27P, va MOT dong cuoi FIELDNAME='*' mang ENQMODE='E' = che do
# khoa ghi (exclusive).
#
# Doi so khoa co tinh TIEN TO: de trong cac truong duoi la khoa ca nhom.
# ENQUEUE_EZTB_HDDT_TOK khong truyen gi = khoa moi dong cua client, dung
# cho cho DELETE FROM ztb_hddt_tok (xoa ca bang).
# ---------------------------------------------------------------------------
LOCKS = [
    ("EZTB_HDDT_TPL", "ZTB_HDDT_TPL", "HDDT: Khoa mau payload khi nap tu file",
     [("MANDT", "MANDT"), ("PROVIDER", "ZDE_HDDT_PROV"),
      ("ACTION", "ZDE_HDDT_ACTION")]),
    ("EZTB_HDDT_TOK", "ZTB_HDDT_TOK", "HDDT: Khoa bo dem access token",
     [("MANDT", "MANDT"), ("PROVIDER", "ZDE_HDDT_PROV"),
      ("CONNID", "ZDE_HDDT_CONNID"), ("BUKRS", "BUKRS"),
      ("APIUSER", "ZDE_HDDT_USER")]),
    # Khoa so dang ky hoa don theo TUNG chung tu. Hai nguoi cung bam
    # "Phat hanh HD" tren mot chung tu ma khong khoa thi ca hai cung doc
    # trang thai 00, ca hai cung goi API => HAI hoa don cho mot chung tu.
    ("EZTB_HDDT_INV", "ZTB_HDDT_INV", "HDDT: Khoa so dang ky hoa don",
     [("MANDT", "MANDT"), ("BUKRS", "BUKRS"), ("GJAHR", "GJAHR"),
      ("SRC_TYPE", "ZDE_HDDT_SRCTYPE"), ("SRC_DOCNO", "ZDE_HDDT_DOCNO")]),
    # Khoa chung tu gom. Cap so gom chi can khoa tien to BUKRS + GJAHR
    # (de trong GOM_NO tro xuong); gom/go gom khoa den tung so gom.
    ("EZTB_HDDT_GOM", "ZTB_HDDT_GOM", "HDDT: Khoa chung tu gom",
     [("MANDT", "MANDT"), ("BUKRS", "BUKRS"), ("GJAHR", "GJAHR"),
      ("GOM_NO", "ZDE_HDDT_DOCNO"), ("SRC_TYPE", "ZDE_HDDT_SRCTYPE"),
      ("SRC_DOCNO", "ZDE_HDDT_DOCNO")]),
]

for lock, roottab, text, keys in LOCKS:
    b = "   <DD25V>\n"
    b += "    <VIEWNAME>%s</VIEWNAME>\n" % lock
    b += "    <AGGTYPE>E</AGGTYPE>\n"
    b += "    <ROOTTAB>%s</ROOTTAB>\n" % roottab
    b += "    <DDLANGUAGE>E</DDLANGUAGE>\n"
    b += "    <AUTHCLASS>00</AUTHCLASS>\n"
    b += "    <DDTEXT>%s</DDTEXT>\n" % esc(text)
    b += "   </DD25V>\n"
    b += "   <DD26E_TABLE>\n"
    b += "    <DD26E>\n"
    b += "     <VIEWNAME>%s</VIEWNAME>\n" % lock
    b += "     <TABNAME>%s</TABNAME>\n" % roottab
    b += "     <TABPOS>0001</TABPOS>\n"
    b += "     <FORTABNAME>%s</FORTABNAME>\n" % roottab
    b += "    </DD26E>\n"
    b += "   </DD26E_TABLE>\n"
    b += "   <DD27P_TABLE>\n"
    pos = 0
    for fname, roll in keys:
        pos += 1
        b += "    <DD27P>\n"
        b += "     <VIEWNAME>%s</VIEWNAME>\n" % lock
        b += "     <OBJPOS>%04d</OBJPOS>\n" % pos
        b += "     <VIEWFIELD>%s</VIEWFIELD>\n" % fname
        b += "     <TABNAME>%s</TABNAME>\n" % roottab
        b += "     <FIELDNAME>%s</FIELDNAME>\n" % fname
        b += "     <KEYFLAG>X</KEYFLAG>\n"
        b += "     <ROLLNAME>%s</ROLLNAME>\n" % roll
        b += "    </DD27P>\n"
    # Dong che do khoa: FIELDNAME='*', ENQMODE='E' (khoa ghi)
    pos += 1
    b += "    <DD27P>\n"
    b += "     <VIEWNAME>%s</VIEWNAME>\n" % lock
    b += "     <OBJPOS>%04d</OBJPOS>\n" % pos
    b += "     <VIEWFIELD>%s</VIEWFIELD>\n" % keys[-1][0]
    b += "     <TABNAME>%s</TABNAME>\n" % roottab
    b += "     <FIELDNAME>*</FIELDNAME>\n"
    b += "     <ROLLNAME>%s</ROLLNAME>\n" % keys[-1][1]
    b += "     <ENQMODE>E</ENQMODE>\n"
    b += "    </DD27P>\n"
    b += "   </DD27P_TABLE>\n"
    write(lock, "enqu", "LCL_OBJECT_ENQU", b)

print("domains :", len(DOMAINS))
print("dtels   :", len(DTELS))
print("tables  :", len(TABLES))
print("locks   :", len(LOCKS))
print("files   :", len(os.listdir(OUT)))

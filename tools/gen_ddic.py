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
    ("ZFIDO_HDDT_PROV", "CHAR", 10, 0, "HDDT: Nha cung cap hoa don dien tu", []),
    ("ZFIDO_HDDT_ACTION", "CHAR", 30, 0, "HDDT: Ma nghiep vu (action)", []),
    ("ZFIDO_HDDT_AUTH", "CHAR", 1, 0, "HDDT: Phuong thuc xac thuc", [
        ("B", "Basic authentication (RFC 7617)"),
        ("H", "Username/password trong HTTP header"),
        ("T", "Bearer token lay tu API dang nhap"),
        ("O", "OAuth 2.0 client credentials"),
        ("N", "Khong xac thuc - destination tu xu ly"),
    ]),
    ("ZFIDO_HDDT_METHOD", "CHAR", 6, 0, "HDDT: HTTP method", [
        ("GET", "GET"), ("POST", "POST"), ("PUT", "PUT"),
        ("PATCH", "PATCH"), ("DELETE", "DELETE"),
    ]),
    ("ZFIDO_HDDT_STATUS", "CHAR", 2, 0, "HDDT: Trang thai hoa don trong SAP", [
        ("00", "Chua tich hop"),
        ("10", "Da gui - cho phan hoi"),
        ("20", "Cho cap so"),
        ("30", "Cho duyet"),
        ("40", "Da phat hanh"),
        ("50", "Da duoc CQT cap ma"),
        ("60", "Da dieu chinh"),
        ("70", "Da thay the"),
        ("80", "Da huy"),
        ("90", "Loi tich hop"),
    ]),
    ("ZFIDO_HDDT_ADJTYPE", "CHAR", 1, 0, "HDDT: Loai dieu chinh hoa don", [
        ("1", "Hoa don goc"),
        ("3", "Hoa don thay the"),
        ("5", "Hoa don dieu chinh"),
        ("7", "Hoa don xoa bo"),
    ]),
    ("ZFIDO_HDDT_DATESRC", "CHAR", 1, 0, "HDDT: Nguon ngay lap hoa don", [
        ("1", "Posting date (BUDAT)"),
        ("2", "Entry date (CPUDT)"),
        ("3", "System date (SY-DATUM)"),
        ("4", "Document date (BLDAT)"),
    ]),
    ("ZFIDO_HDDT_MAPTYPE", "CHAR", 20, 0, "HDDT: Loai anh xa gia tri", [
        ("PAYMENT", "Hinh thuc thanh toan"),
        ("TAXRATE", "Thue suat"),
        ("UNIT", "Don vi tinh"),
        ("INVTYPE", "Loai hoa don"),
        ("ITEMTYPE", "Hinh thuc hang hoa"),
        ("CURRENCY", "Loai tien"),
        ("GLACCT", "Tai khoan ke toan sinh dong hang hoa"),
        ("DOCTYPE", "Loai chung tu ke toan"),
    ]),
    ("ZFIDO_HDDT_SRCTYPE", "CHAR", 4, 0, "HDDT: Loai nguon du lieu SAP", [
        ("FI", "FI document (BKPF/BSEG)"),
        ("SD", "SD billing document (VBRK/VBRP)"),
        ("MM", "MM invoice (RBKP/RSEG)"),
        ("GOM", "Chung tu gom"),
        ("CUST", "Nguon do khach hang tu cai dat"),
    ]),
    ("ZFIDO_HDDT_ITEMTYPE", "CHAR", 1, 0, "HDDT: Hinh thuc dong hang hoa", [
        ("0", "Hang hoa / dich vu binh thuong"),
        ("1", "Khuyen mai"),
        ("2", "Chiet khau thuong mai"),
        ("3", "Ghi chu / dien giai"),
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
    ("ZFIDE_HDDT_PROV", "ZFIDO_HDDT_PROV", "NCC HDDT", "Nha cung cap", "Nha cung cap HDDT", "NCC HDDT", "Nha cung cap hoa don dien tu"),
    ("ZFIDE_HDDT_ACTION", "ZFIDO_HDDT_ACTION", "Nghiep vu", "Ma nghiep vu", "Ma nghiep vu HDDT", "Nghiep vu", "Ma nghiep vu HDDT (action)"),
    ("ZFIDE_HDDT_AUTH", "ZFIDO_HDDT_AUTH", "Xac thuc", "Ph.thuc xac thuc", "Phuong thuc xac thuc", "XT", "Phuong thuc xac thuc API"),
    ("ZFIDE_HDDT_METHOD", "ZFIDO_HDDT_METHOD", "Method", "HTTP method", "HTTP method", "Method", "HTTP method"),
    ("ZFIDE_HDDT_STATUS", "ZFIDO_HDDT_STATUS", "T.thai", "Trang thai", "Trang thai HDDT", "TT", "Trang thai hoa don dien tu trong SAP"),
    ("ZFIDE_HDDT_ADJTYPE", "ZFIDO_HDDT_ADJTYPE", "Loai DC", "Loai dieu chinh", "Loai dieu chinh hoa don", "Loai DC", "Loai dieu chinh hoa don"),
    ("ZFIDE_HDDT_DATESRC", "ZFIDO_HDDT_DATESRC", "Ngay lap", "Nguon ngay lap", "Nguon ngay lap hoa don", "Ngay lap", "Nguon ngay lap hoa don"),
    ("ZFIDE_HDDT_MAPTYPE", "ZFIDO_HDDT_MAPTYPE", "Loai AX", "Loai anh xa", "Loai anh xa gia tri", "Loai AX", "Loai anh xa gia tri"),
    ("ZFIDE_HDDT_SRCTYPE", "ZFIDO_HDDT_SRCTYPE", "Nguon", "Loai nguon", "Loai nguon du lieu", "Nguon", "Loai nguon du lieu SAP"),
    ("ZFIDE_HDDT_ITEMTYPE", "ZFIDO_HDDT_ITEMTYPE", "H.thuc", "Hinh thuc dong", "Hinh thuc dong hang hoa", "HT", "Hinh thuc dong hang hoa"),
    ("ZFIDE_HDDT_CLASS", ("CHAR", 30, 0), "Lop ABAP", "Lop thuc thi", "Lop ABAP thuc thi", "Lop ABAP", "Ten lop ABAP thuc thi (adapter)"),
    ("ZFIDE_HDDT_CONNID", ("CHAR", 10, 0), "Ket noi", "Ma ket noi", "Ma ket noi API", "Ket noi", "Ma ket noi API"),
    ("ZFIDE_HDDT_URL", ("CHAR", 255, 0), "URL", "Base URL", "Base URL cua API", "URL", "Base URL cua API"),
    ("ZFIDE_HDDT_PATH", ("CHAR", 255, 0), "Path", "Duong dan API", "Duong dan API", "Path", "Duong dan API - ho tro placeholder"),
    ("ZFIDE_HDDT_TAXCODE", ("CHAR", 20, 0), "MST", "Ma so thue", "Ma so thue", "MST", "Ma so thue"),
    ("ZFIDE_HDDT_TEMPL", ("CHAR", 20, 0), "Mau HD", "Mau hoa don", "Mau so hoa don", "Mau HD", "Mau so hoa don"),
    ("ZFIDE_HDDT_SERIAL", ("CHAR", 20, 0), "Ky hieu", "Ky hieu HD", "Ky hieu hoa don", "Ky hieu", "Ky hieu (serial) hoa don"),
    ("ZFIDE_HDDT_SEQ", ("CHAR", 20, 0), "So HD", "So hoa don", "So hoa don", "So HD", "So hoa don do NCC cap"),
    ("ZFIDE_HDDT_IDKEY", ("CHAR", 40, 0), "IDKey", "Khoa doi chieu", "Khoa doi chieu SAP-HDDT", "IDKey", "Khoa doi chieu SAP - HDDT"),
    ("ZFIDE_HDDT_INVTYPE", ("CHAR", 10, 0), "Loai HD", "Loai hoa don", "Loai hoa don", "Loai HD", "Loai hoa don (01GTKT, 02GTTT)"),
    ("ZFIDE_HDDT_USER", ("CHAR", 60, 0), "User API", "Tai khoan API", "Tai khoan API", "User API", "Tai khoan dang nhap API"),
    ("ZFIDE_HDDT_SECRET", ("CHAR", 128, 0), "Secret", "Mat khau API", "Mat khau / secret API", "Secret", "Mat khau API - nen dung SECKEY"),
    ("ZFIDE_HDDT_SECKEY", ("CHAR", 40, 0), "SecKey", "Khoa secure", "Khoa secure store", "SecKey", "Khoa tra cuu trong secure storage"),
    ("ZFIDE_HDDT_TOKEN", ("STRG", 0, 0), "Token", "Access token", "Access token", "Token", "Access token (JWT)"),
    ("ZFIDE_HDDT_JSON", ("STRG", 0, 0), "JSON", "Noi dung JSON", "Noi dung JSON", "JSON", "Noi dung payload JSON"),
    ("ZFIDE_HDDT_MSG", ("CHAR", 255, 0), "Th.diep", "Thong diep", "Thong diep tra ve", "Thong diep", "Thong diep tra ve tu NCC"),
    ("ZFIDE_HDDT_RCCODE", ("CHAR", 20, 0), "Ma tr.ve", "Ma tra ve NCC", "Ma tra ve cua NCC", "Ma tr.ve", "Ma tra ve cua nha cung cap"),
    ("ZFIDE_HDDT_MAPVAL", ("CHAR", 50, 0), "Gia tri", "Gia tri anh xa", "Gia tri anh xa", "Gia tri", "Gia tri anh xa"),
    ("ZFIDE_HDDT_LOGID", ("CHAR", 32, 0), "Log ID", "ID ban ghi log", "ID ban ghi log", "Log ID", "ID ban ghi log (GUID)"),
    ("ZFIDE_HDDT_MSCQT", ("CHAR", 40, 0), "Ma CQT", "Ma CQT cap", "Ma co quan thue cap", "Ma CQT", "Ma so do co quan thue cap"),
    ("ZFIDE_HDDT_SEC", ("CHAR", 20, 0), "Ma tra cuu", "Ma tra cuu HD", "Ma tra cuu hoa don", "Ma tra cuu", "Ma tra cuu hoa don"),
    ("ZFIDE_HDDT_LINK", ("CHAR", 255, 0), "Link", "Link tra cuu", "Link tra cuu hoa don", "Link", "Link tra cuu hoa don"),
    ("ZFIDE_HDDT_PARMKEY", ("CHAR", 40, 0), "Tham so", "Ten tham so", "Ten tham so cau hinh", "Tham so", "Ten tham so cau hinh"),
    ("ZFIDE_HDDT_PARMVAL", ("CHAR", 255, 0), "Gia tri", "Gia tri tham so", "Gia tri tham so", "Gia tri", "Gia tri tham so cau hinh"),
    ("ZFIDE_HDDT_TIMEOUT", ("INT4", 10, 0), "Timeout", "Timeout (giay)", "Timeout goi API (giay)", "Timeout", "Timeout goi API tinh bang giay"),
    ("ZFIDE_HDDT_AMOUNT", ("DEC", 23, 6), "So tien", "So tien", "So tien HDDT", "So tien", "So tien tren hoa don dien tu"),
    ("ZFIDE_HDDT_QTY", ("DEC", 23, 6), "So luong", "So luong", "So luong", "So luong", "So luong hang hoa"),
    ("ZFIDE_HDDT_RATE", ("DEC", 7, 2), "T.suat", "Thue suat", "Thue suat / ty le", "TS", "Thue suat hoac ty le phan tram"),
    ("ZFIDE_HDDT_DESCR", ("CHAR", 60, 0), "Mo ta", "Mo ta", "Mo ta", "Mo ta", "Mo ta"),
    ("ZFIDE_HDDT_DOCNO", ("CHAR", 20, 0), "So CT", "So chung tu", "So chung tu nguon", "So CT", "So chung tu nguon tren SAP"),
    ("ZFIDE_HDDT_NAME", ("CHAR", 255, 0), "Ten", "Ten / dien giai", "Ten / dien giai", "Ten", "Ten hoac dien giai dai"),
    ("ZFIDE_HDDT_LINENO", ("NUMC", 6, 0), "Dong", "So dong", "So dong hang hoa", "Dong", "So dong hang hoa"),
    ("ZFIDE_HDDT_RAW", ("RSTR", 0, 0), "Byte", "Noi dung byte", "Noi dung nguyen ban (byte)", "Byte", "Noi dung nguyen ban tren duong truyen"),
    ("ZFIDE_HDDT_SIZE", ("INT4", 10, 0), "Byte", "So byte", "Kich thuoc (byte)", "Byte", "Kich thuoc noi dung tinh bang byte"),
    ("ZFIDE_HDDT_CODEPAGE", ("CHAR", 20, 0), "Codepage", "Bang ma", "Bang ma cua noi dung", "Codepage", "Bang ma dung khi ghi byte (vd UTF-8)"),
    ("ZFIDE_HDDT_ATTEMPT", ("NUMC", 3, 0), "Lan", "Lan goi thu", "Lan goi thu may", "Lan", "So lan da goi cho cung nghiep vu"),
    ("ZFIDE_HDDT_CALLER", ("CHAR", 40, 0), "Nguon goi", "Chuong trinh goi", "Chuong trinh / job goi", "Nguon goi", "Chuong trinh, transaction hoac job da goi"),
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
    ("ZFIT_HDDT_PROV", "C", "HDDT: Danh muc nha cung cap", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZFIDE_HDDT_PROV"),
        F("CLASSNAME", "ZFIDE_HDDT_CLASS"), F("DESCR", "ZFIDE_HDDT_DESCR"),
        F("XACTIVE", "XFELD"),
    ]),
    ("ZFIT_HDDT_CONN", "C", "HDDT: Cau hinh ket noi API", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZFIDE_HDDT_PROV"), K("CONNID", "ZFIDE_HDDT_CONNID"),
        F("RFCDEST", "RFCDEST"), F("BASE_URL", "ZFIDE_HDDT_URL"),
        F("AUTH_MODE", "ZFIDE_HDDT_AUTH"), F("TOKEN_ACTION", "ZFIDE_HDDT_ACTION"),
        F("TOKEN_TTL", "ZFIDE_HDDT_TIMEOUT"), F("TIMEOUT", "ZFIDE_HDDT_TIMEOUT"),
        F("SSL_ID", "SSFAPPLSSL"), F("DESCR", "ZFIDE_HDDT_DESCR"), F("XACTIVE", "XFELD"),
    ]),
    ("ZFIT_HDDT_ACT", "C", "HDDT: Danh muc endpoint theo nghiep vu", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZFIDE_HDDT_PROV"), K("ACTION", "ZFIDE_HDDT_ACTION"),
        F("HTTP_METHOD", "ZFIDE_HDDT_METHOD"), F("API_PATH", "ZFIDE_HDDT_PATH"),
        F("CONT_TYPE", "ZFIDE_HDDT_PARMVAL"), F("ACCEPT_TYPE", "ZFIDE_HDDT_PARMVAL"),
        F("DESCR", "ZFIDE_HDDT_DESCR"), F("XACTIVE", "XFELD"),
    ]),
    ("ZFIT_HDDT_CRED", "C", "HDDT: Tai khoan va dai so theo cong ty", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZFIDE_HDDT_PROV"), K("BUKRS", "BUKRS"),
        K("INV_TYPE", "ZFIDE_HDDT_INVTYPE"),
        F("CONNID", "ZFIDE_HDDT_CONNID"), F("TAXCODE", "ZFIDE_HDDT_TAXCODE"),
        F("TEMPLATE", "ZFIDE_HDDT_TEMPL"), F("SERIAL", "ZFIDE_HDDT_SERIAL"),
        F("APIUSER", "ZFIDE_HDDT_USER"), F("SECKEY", "ZFIDE_HDDT_SECKEY"),
        F("APISECRET", "ZFIDE_HDDT_SECRET"),
        F("VALID_FROM", "DATS"), F("VALID_TO", "DATS"), F("XACTIVE", "XFELD"),
    ]),
    ("ZFIT_HDDT_STAT", "C", "HDDT: Anh xa trang thai NCC sang SAP", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZFIDE_HDDT_PROV"), K("ACTION", "ZFIDE_HDDT_ACTION"),
        K("RC_CODE", "ZFIDE_HDDT_RCCODE"),
        F("SAP_STATUS", "ZFIDE_HDDT_STATUS"), F("MSGTY", "SYMSGTY"),
        F("MSG_TEXT", "ZFIDE_HDDT_MSG"),
    ]),
    ("ZFIT_HDDT_MAP", "C", "HDDT: Anh xa gia tri SAP - NCC", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZFIDE_HDDT_PROV"), K("MAP_TYPE", "ZFIDE_HDDT_MAPTYPE"),
        K("SAP_VALUE", "ZFIDE_HDDT_MAPVAL"),
        F("EXT_VALUE", "ZFIDE_HDDT_MAPVAL"), F("EXT_TEXT", "ZFIDE_HDDT_DESCR"),
    ]),
    ("ZFIT_HDDT_PARM", "C", "HDDT: Tham so cau hinh chung", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZFIDE_HDDT_PROV"), K("BUKRS", "BUKRS"),
        K("PARM_KEY", "ZFIDE_HDDT_PARMKEY"),
        F("PARM_VAL", "ZFIDE_HDDT_PARMVAL"), F("DESCR", "ZFIDE_HDDT_DESCR"),
    ]),
    ("ZFIT_HDDT_DATE", "C", "HDDT: Nguon ngay lap hoa don theo cong ty", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"),
        F("DATE_SRC", "ZFIDE_HDDT_DATESRC"), F("TIME_CUT", "UZEIT"),
        F("DESCR", "ZFIDE_HDDT_DESCR"),
    ]),
    ("ZFIT_HDDT_SRC", "C", "HDDT: Lop doc du lieu nguon", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"), K("SRC_TYPE", "ZFIDE_HDDT_SRCTYPE"),
        F("CLASSNAME", "ZFIDE_HDDT_CLASS"), F("DESCR", "ZFIDE_HDDT_DESCR"),
        F("XACTIVE", "XFELD"),
    ]),
    ("ZFIT_HDDT_TPL", "C", "HDDT: Mau payload theo nghiep vu", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZFIDE_HDDT_PROV"), K("ACTION", "ZFIDE_HDDT_ACTION"),
        F("DESCR", "ZFIDE_HDDT_DESCR"), F("XACTIVE", "XFELD"),
        F("TPL_BODY", "ZFIDE_HDDT_JSON"),
    ]),
    ("ZFIT_HDDT_TOK", "A", "HDDT: Bo dem access token", [
        K("MANDT", "MANDT"), K("PROVIDER", "ZFIDE_HDDT_PROV"), K("CONNID", "ZFIDE_HDDT_CONNID"),
        K("BUKRS", "BUKRS"), K("APIUSER", "ZFIDE_HDDT_USER"),
        F("VALID_TO", "TIMESTAMPL"), F("CREATED_AT", "TIMESTAMPL"),
        F("TOKEN", "ZFIDE_HDDT_TOKEN"),
    ]),
    ("ZFIT_HDDT_INV", "A", "HDDT: So dang ky hoa don dien tu", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"), K("GJAHR", "GJAHR"),
        K("SRC_TYPE", "ZFIDE_HDDT_SRCTYPE"), K("SRC_DOCNO", "ZFIDE_HDDT_DOCNO"),
        F("PROVIDER", "ZFIDE_HDDT_PROV"), F("IDKEY", "ZFIDE_HDDT_IDKEY"),
        F("INV_TYPE", "ZFIDE_HDDT_INVTYPE"), F("TEMPLATE", "ZFIDE_HDDT_TEMPL"),
        F("SERIAL", "ZFIDE_HDDT_SERIAL"), F("SEQ", "ZFIDE_HDDT_SEQ"),
        F("INV_DATE", "DATS"), F("INV_TIME", "UZEIT"),
        F("ISSUE_DATE", "DATS"), F("CANCEL_DATE", "DATS"),
        F("ADJ_TYPE", "ZFIDE_HDDT_ADJTYPE"),
        F("REF_DOCNO", "ZFIDE_HDDT_DOCNO"), F("REF_GJAHR", "GJAHR"),
        F("SUPP_TAXCODE", "ZFIDE_HDDT_TAXCODE"), F("MSCQT", "ZFIDE_HDDT_MSCQT"),
        F("SEC_CODE", "ZFIDE_HDDT_SEC"), F("INV_LINK", "ZFIDE_HDDT_LINK"),
        F("STATUS", "ZFIDE_HDDT_STATUS"), F("PROV_STATUS", "ZFIDE_HDDT_RCCODE"),
        F("MESSAGE", "ZFIDE_HDDT_MSG"),
        F("BUYER_CODE", "KUNNR"), F("BUYER_NAME", "ZFIDE_HDDT_NAME"),
        F("BUYER_TAX", "ZFIDE_HDDT_TAXCODE"), F("BUYER_ADDR", "ZFIDE_HDDT_NAME"),
        F("BUYER_MAIL", "ZFIDE_HDDT_NAME"),
        F("WAERS", "WAERS"), F("EXRATE", "UKURS_CURR"),
        F("AMOUNT", "ZFIDE_HDDT_AMOUNT"), F("VAT_AMOUNT", "ZFIDE_HDDT_AMOUNT"),
        F("TOTAL", "ZFIDE_HDDT_AMOUNT"),
        F("CREATED_BY", "SYUNAME"), F("CREATED_AT", "TIMESTAMPL"),
        F("CHANGED_BY", "SYUNAME"), F("CHANGED_AT", "TIMESTAMPL"),
    ]),
    ("ZFIT_HDDT_ITEM", "A", "HDDT: Chi tiet hang hoa da phat hanh", [
        K("MANDT", "MANDT"), K("BUKRS", "BUKRS"), K("GJAHR", "GJAHR"),
        K("SRC_TYPE", "ZFIDE_HDDT_SRCTYPE"), K("SRC_DOCNO", "ZFIDE_HDDT_DOCNO"),
        K("LINE_NO", "ZFIDE_HDDT_LINENO"),
        F("ITEM_CODE", "ZFIDE_HDDT_MAPVAL"), F("ITEM_NAME", "ZFIDE_HDDT_NAME"),
        F("ITEM_TYPE", "ZFIDE_HDDT_ITEMTYPE"), F("UNIT", "ZFIDE_HDDT_MAPVAL"),
        F("QUANTITY", "ZFIDE_HDDT_QTY"), F("PRICE", "ZFIDE_HDDT_AMOUNT"),
        F("AMOUNT", "ZFIDE_HDDT_AMOUNT"), F("TAX_RATE", "ZFIDE_HDDT_RATE"),
        F("TAX_AMOUNT", "ZFIDE_HDDT_AMOUNT"), F("TOTAL", "ZFIDE_HDDT_AMOUNT"),
        F("DISC_PCT", "ZFIDE_HDDT_RATE"), F("DISC_AMT", "ZFIDE_HDDT_AMOUNT"),
        F("NOTE", "ZFIDE_HDDT_NAME"),
    ]),
    ("ZFIT_HDDT_LOG", "A", "HDDT: Log goi API", [
        K("MANDT", "MANDT"), K("LOG_ID", "ZFIDE_HDDT_LOGID"),
        # --- dinh danh nghiep vu
        F("PROVIDER", "ZFIDE_HDDT_PROV"), F("CONNID", "ZFIDE_HDDT_CONNID"),
        F("ACTION", "ZFIDE_HDDT_ACTION"),
        F("BUKRS", "BUKRS"), F("GJAHR", "GJAHR"),
        F("SRC_TYPE", "ZFIDE_HDDT_SRCTYPE"), F("SRC_DOCNO", "ZFIDE_HDDT_DOCNO"),
        F("IDKEY", "ZFIDE_HDDT_IDKEY"),
        F("ATTEMPT", "ZFIDE_HDDT_ATTEMPT"),
        F("TEST_RUN", "XFELD"),
        # --- ket qua
        F("SERIAL", "ZFIDE_HDDT_SERIAL"), F("SEQ", "ZFIDE_HDDT_SEQ"),
        F("SAP_STATUS", "ZFIDE_HDDT_STATUS"),
        F("PROV_STATUS", "ZFIDE_HDDT_RCCODE"),
        F("MSGTY", "SYMSGTY"), F("MESSAGE", "ZFIDE_HDDT_MSG"),
        # --- ky thuat HTTP
        F("HTTP_METHOD", "ZFIDE_HDDT_METHOD"), F("FULL_URL", "ZFIDE_HDDT_URL"),
        F("CONT_TYPE", "ZFIDE_HDDT_PARMVAL"),
        F("HTTP_CODE", "ZFIDE_HDDT_SIZE"), F("HTTP_REASON", "ZFIDE_HDDT_MSG"),
        F("DURATION_MS", "ZFIDE_HDDT_SIZE"),
        F("REQ_SIZE", "ZFIDE_HDDT_SIZE"), F("RES_SIZE", "ZFIDE_HDDT_SIZE"),
        F("CODEPAGE", "ZFIDE_HDDT_CODEPAGE"),
        F("MASKED", "XFELD"),
        # --- truy vet nguon goi
        F("CALLER", "ZFIDE_HDDT_CALLER"), F("TCODE", "TCODE"),
        F("CREATED_BY", "SYUNAME"), F("CREATED_AT", "TIMESTAMPL"),
        # --- noi dung nguyen ban tren duong truyen (byte-exact)
        F("REQ_HEADER", "ZFIDE_HDDT_RAW"), F("RES_HEADER", "ZFIDE_HDDT_RAW"),
        F("REQ_BODY", "ZFIDE_HDDT_RAW"), F("RES_BODY", "ZFIDE_HDDT_RAW"),
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

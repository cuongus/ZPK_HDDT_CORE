*=====================================================================
* Tên/Mã     : ZFIIF_HDDT_TYPES
* Mô tả chung: Kiểu dữ liệu CHUẨN HOÁ (canonical model) của hoá đơn
*              điện tử — độc lập hoàn toàn với nhà cung cấp.
*              SAP luôn điền vào một cấu trúc duy nhất; việc chuyển
*              cấu trúc này sang payload riêng của Viettel / FPT /
*              VNPT là việc của lớp adapter (ZFIIF_HDDT_PROVIDER).
*              Đổi nhà cung cấp => KHÔNG sửa interface này.
* Tham Số    : Không có (interface chỉ khai báo type + constant)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
INTERFACE zfiif_hddt_types
  PUBLIC .

*---------------------------------------------------------------------*
* 1. Kiểu kỹ thuật dùng chung
*---------------------------------------------------------------------*
  " Cặp tên/giá trị — dùng cho placeholder URL, header HTTP bổ sung,
  " và phần mở rộng payload theo nhà cung cấp.
  TYPES: BEGIN OF ty_kv,
           name  TYPE string,
           value TYPE string,
         END OF ty_kv.
  TYPES ty_t_kv TYPE STANDARD TABLE OF ty_kv WITH DEFAULT KEY.

  TYPES ty_amount TYPE p LENGTH 13 DECIMALS 6.
  TYPES ty_qty    TYPE p LENGTH 13 DECIMALS 6.
  TYPES ty_rate   TYPE p LENGTH 5 DECIMALS 2.

  " Range dùng cho selection screen / lớp đọc dữ liệu nguồn
  TYPES ty_r_docno TYPE RANGE OF zfide_hddt_docno.
  TYPES ty_r_date  TYPE RANGE OF dats.
  TYPES ty_r_kunnr TYPE RANGE OF kunnr.
  TYPES ty_r_blart TYPE RANGE OF blart.
  TYPES ty_r_status TYPE RANGE OF zfide_hddt_status.

*---------------------------------------------------------------------*
* 2. Thông tin người bán
*---------------------------------------------------------------------*
  TYPES: BEGIN OF ty_seller,
           tax_code   TYPE zfide_hddt_taxcode,
           name       TYPE string,
           address    TYPE string,
           phone      TYPE string,
           email      TYPE string,
           bank_name  TYPE string,
           bank_acct  TYPE string,
           branch_code TYPE string,
           branch_name TYPE string,
         END OF ty_seller.

*---------------------------------------------------------------------*
* 3. Thông tin người mua
*---------------------------------------------------------------------*
  TYPES: BEGIN OF ty_buyer,
           code        TYPE kunnr,
           tax_code    TYPE zfide_hddt_taxcode,
           legal_name  TYPE string,   " tên đơn vị (bname)
           person_name TYPE string,   " tên người mua (buyer)
           address     TYPE string,
           phone       TYPE string,
           email       TYPE string,
           bank_name   TYPE string,
           bank_acct   TYPE string,
           id_number   TYPE string,   " CMND/CCCD/hộ chiếu
           budget_code TYPE string,    " mã quan hệ ngân sách
           " '1' = người mua không lấy hoá đơn
           not_get_invoice TYPE abap_bool,
         END OF ty_buyer.

*---------------------------------------------------------------------*
* 4. Dòng hàng hoá / dịch vụ
*---------------------------------------------------------------------*
  TYPES: BEGIN OF ty_item,
           line_no      TYPE zfide_hddt_lineno,
           item_type    TYPE zfide_hddt_itemtype, " 0 thường 1 KM 2 CKTM 3 ghi chú
           item_code    TYPE string,
           item_name    TYPE string,
           unit         TYPE string,
           quantity     TYPE ty_qty,
           price        TYPE ty_amount,
           amount       TYPE ty_amount,           " thành tiền chưa thuế
           " Thuế suất: >= 0 là % ; -1 = không chịu thuế ;
           " -2 = không kê khai nộp thuế ; -3 = KHAC
           tax_rate     TYPE ty_rate,
           tax_rate_txt TYPE string,              " '10%', 'KCT'...
           tax_amount   TYPE ty_amount,
           total        TYPE ty_amount,           " thành tiền sau thuế
           disc_percent TYPE ty_rate,
           disc_amount  TYPE ty_amount,
           note         TYPE string,
           " Điều chỉnh tăng (abap_true) / giảm (abap_false)
           is_increase  TYPE abap_bool,
           " Trường bổ sung riêng của nhà cung cấp (không cần sửa type)
           ext          TYPE ty_t_kv,
         END OF ty_item.
  TYPES ty_t_item TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY.

*---------------------------------------------------------------------*
* 5. Tổng hợp theo từng thuế suất
*---------------------------------------------------------------------*
  TYPES: BEGIN OF ty_tax,
           tax_rate      TYPE ty_rate,
           tax_rate_txt  TYPE string,
           taxable_amt   TYPE ty_amount,   " tiền chưa thuế (nguyên tệ)
           taxable_amt_l TYPE ty_amount,   " tiền chưa thuế (VND)
           tax_amt       TYPE ty_amount,   " tiền thuế (nguyên tệ)
           tax_amt_l     TYPE ty_amount,   " tiền thuế (VND)
           is_increase   TYPE abap_bool,
         END OF ty_tax.
  TYPES ty_t_tax TYPE STANDARD TABLE OF ty_tax WITH DEFAULT KEY.

*---------------------------------------------------------------------*
* 6. Hình thức thanh toán
*---------------------------------------------------------------------*
  TYPES: BEGIN OF ty_payment,
           method_code TYPE string,   " mã đã map sang NCC
           method_name TYPE string,
         END OF ty_payment.
  TYPES ty_t_payment TYPE STANDARD TABLE OF ty_payment WITH DEFAULT KEY.

*---------------------------------------------------------------------*
* 7. Tổng cộng hoá đơn
*---------------------------------------------------------------------*
  TYPES: BEGIN OF ty_summary,
           amount_wo_tax   TYPE ty_amount,   " tổng chưa thuế nguyên tệ
           amount_wo_tax_l TYPE ty_amount,   " tổng chưa thuế VND
           tax_amount      TYPE ty_amount,
           tax_amount_l    TYPE ty_amount,
           disc_amount     TYPE ty_amount,
           disc_amount_l   TYPE ty_amount,
           total           TYPE ty_amount,
           total_l         TYPE ty_amount,
           amount_in_words TYPE string,
           " Dấu của các tổng khi điều chỉnh (tăng = true)
           is_positive     TYPE abap_bool,
         END OF ty_summary.

*---------------------------------------------------------------------*
* 8. Thông tin điều chỉnh / thay thế
*---------------------------------------------------------------------*
  TYPES: BEGIN OF ty_adjust,
           adj_type      TYPE zfide_hddt_adjtype, " 1/3/5/7
           " '1' = điều chỉnh tăng, '0' = điều chỉnh giảm,
           " '2' = điều chỉnh thông tin (không tiền)
           adj_direction TYPE c LENGTH 1,
           org_serial    TYPE zfide_hddt_serial,
           org_seq       TYPE zfide_hddt_seq,
           org_inv_date  TYPE dats,
           org_idkey     TYPE zfide_hddt_idkey,
           " Số & ngày biên bản thoả thuận điều chỉnh
           doc_ref_no    TYPE string,
           doc_ref_date  TYPE dats,
           reason        TYPE string,
         END OF ty_adjust.

*---------------------------------------------------------------------*
* 9. Header hoá đơn
*---------------------------------------------------------------------*
  TYPES: BEGIN OF ty_header,
           idkey       TYPE zfide_hddt_idkey,   " sid / transactionUuid
           inv_type    TYPE zfide_hddt_invtype, " 01GTKT / 02GTTT ...
           template    TYPE zfide_hddt_templ,
           serial      TYPE zfide_hddt_serial,
           seq         TYPE zfide_hddt_seq,
           inv_date    TYPE dats,
           inv_time    TYPE uzeit,
           currency    TYPE waers,
           exch_rate   TYPE ty_amount,
           note        TYPE string,
           place       TYPE string,             " địa danh
           contract_no TYPE string,
           " Phương thức gửi CQT: '0' gửi ngay, '1' gửi theo bảng tổng hợp
           send_type   TYPE c LENGTH 1,
           " Hoá đơn có mã của CQT hay không
           with_code   TYPE abap_bool,
           paid        TYPE abap_bool,
         END OF ty_header.

*---------------------------------------------------------------------*
* 10. Hoá đơn hoàn chỉnh (canonical)
*---------------------------------------------------------------------*
  TYPES: BEGIN OF ty_invoice,
           header   TYPE ty_header,
           seller   TYPE ty_seller,
           buyer    TYPE ty_buyer,
           items    TYPE ty_t_item,
           taxes    TYPE ty_t_tax,
           payments TYPE ty_t_payment,
           summary  TYPE ty_summary,
           adjust   TYPE ty_adjust,
           ext      TYPE ty_t_kv,
         END OF ty_invoice.
  TYPES ty_t_invoice TYPE STANDARD TABLE OF ty_invoice WITH DEFAULT KEY.

*---------------------------------------------------------------------*
* 11. Request / Result của một lần gọi API
*---------------------------------------------------------------------*
  TYPES: BEGIN OF ty_request,
           " Bỏ trống => engine tự đọc nhà cung cấp đang hoạt động từ
           " bảng cấu hình ZFIT_HDDT_PARM / ZFIT_HDDT_CRED
           provider  TYPE zfide_hddt_prov,
           action    TYPE zfide_hddt_action,
           bukrs     TYPE bukrs,
           gjahr     TYPE gjahr,
           src_type  TYPE zfide_hddt_srctype,
           src_docno TYPE zfide_hddt_docno,
           invoice   TYPE ty_invoice,
           " Tham số tự do cho các nghiệp vụ tra cứu / huỷ / lấy file
           params    TYPE ty_t_kv,
         END OF ty_request.
  TYPES ty_t_request TYPE STANDARD TABLE OF ty_request WITH DEFAULT KEY.

  TYPES: BEGIN OF ty_result,
           success       TYPE abap_bool,
           status        TYPE zfide_hddt_status,
           prov_status   TYPE zfide_hddt_rccode,
           msgty         TYPE symsgty,
           message       TYPE zfide_hddt_msg,
           idkey         TYPE zfide_hddt_idkey,
           template      TYPE zfide_hddt_templ,
           serial        TYPE zfide_hddt_serial,
           seq           TYPE zfide_hddt_seq,
           issue_date    TYPE dats,
           mscqt         TYPE zfide_hddt_mscqt,
           sec_code      TYPE zfide_hddt_sec,
           inv_link      TYPE zfide_hddt_link,
           file_name     TYPE string,
           file_content  TYPE xstring,
           http_code     TYPE i,
           request_body  TYPE string,
           response_body TYPE string,
           log_id        TYPE zfide_hddt_logid,
           " Dữ liệu bổ sung do adapter bóc ra từ response
           fields        TYPE ty_t_kv,
         END OF ty_result.
  TYPES ty_t_result TYPE STANDARD TABLE OF ty_result WITH DEFAULT KEY.

*---------------------------------------------------------------------*
* 12. Hằng số nghiệp vụ (action)
*---------------------------------------------------------------------*
  " Mã action là KHOÁ vào bảng ZFIT_HDDT_ACT. Mỗi nhà cung cấp khai
  " báo endpoint riêng cho cùng một mã action => core không đổi.
  CONSTANTS: BEGIN OF gc_action,
               login           TYPE zfide_hddt_action VALUE 'LOGIN',
               create_invoice  TYPE zfide_hddt_action VALUE 'CREATE_INVOICE',
               create_draft    TYPE zfide_hddt_action VALUE 'CREATE_DRAFT',
               preview_draft   TYPE zfide_hddt_action VALUE 'PREVIEW_DRAFT',
               approve_invoice TYPE zfide_hddt_action VALUE 'APPROVE_INVOICE',
               update_invoice  TYPE zfide_hddt_action VALUE 'UPDATE_INVOICE',
               replace_invoice TYPE zfide_hddt_action VALUE 'REPLACE_INVOICE',
               adjust_invoice  TYPE zfide_hddt_action VALUE 'ADJUST_INVOICE',
               cancel_invoice  TYPE zfide_hddt_action VALUE 'CANCEL_INVOICE',
               delete_invoice  TYPE zfide_hddt_action VALUE 'DELETE_INVOICE',
               search_invoice  TYPE zfide_hddt_action VALUE 'SEARCH_INVOICE',
               get_file        TYPE zfide_hddt_action VALUE 'GET_FILE',
               send_mail       TYPE zfide_hddt_action VALUE 'SEND_MAIL',
               get_templates   TYPE zfide_hddt_action VALUE 'GET_TEMPLATES',
               wrong_notice    TYPE zfide_hddt_action VALUE 'WRONG_NOTICE',
             END OF gc_action.

  CONSTANTS: BEGIN OF gc_status,
               not_sent   TYPE zfide_hddt_status VALUE '00',
               sent       TYPE zfide_hddt_status VALUE '10',
               wait_seq   TYPE zfide_hddt_status VALUE '20',
               wait_appr  TYPE zfide_hddt_status VALUE '30',
               issued     TYPE zfide_hddt_status VALUE '40',
               coded      TYPE zfide_hddt_status VALUE '50',
               adjusted   TYPE zfide_hddt_status VALUE '60',
               replaced   TYPE zfide_hddt_status VALUE '70',
               cancelled  TYPE zfide_hddt_status VALUE '80',
               error      TYPE zfide_hddt_status VALUE '90',
             END OF gc_status.

  CONSTANTS: BEGIN OF gc_adj_type,
               original TYPE zfide_hddt_adjtype VALUE '1',
               replace  TYPE zfide_hddt_adjtype VALUE '3',
               adjust   TYPE zfide_hddt_adjtype VALUE '5',
               cancel   TYPE zfide_hddt_adjtype VALUE '7',
             END OF gc_adj_type.

  CONSTANTS: BEGIN OF gc_auth,
               basic  TYPE zfide_hddt_auth VALUE 'B',
               header TYPE zfide_hddt_auth VALUE 'H',
               token  TYPE zfide_hddt_auth VALUE 'T',
               oauth2 TYPE zfide_hddt_auth VALUE 'O',
               none   TYPE zfide_hddt_auth VALUE 'N',
             END OF gc_auth.

  CONSTANTS: BEGIN OF gc_map_type,
               payment   TYPE zfide_hddt_maptype VALUE 'PAYMENT',
               tax_rate  TYPE zfide_hddt_maptype VALUE 'TAXRATE',
               unit      TYPE zfide_hddt_maptype VALUE 'UNIT',
               inv_type  TYPE zfide_hddt_maptype VALUE 'INVTYPE',
               item_type TYPE zfide_hddt_maptype VALUE 'ITEMTYPE',
               currency  TYPE zfide_hddt_maptype VALUE 'CURRENCY',
               gl_acct   TYPE zfide_hddt_maptype VALUE 'GLACCT',
               doc_type  TYPE zfide_hddt_maptype VALUE 'DOCTYPE',
             END OF gc_map_type.

  " Tên tham số trong ZFIT_HDDT_PARM
  CONSTANTS: BEGIN OF gc_parm,
               active_provider TYPE zfide_hddt_parmkey VALUE 'ACTIVE_PROVIDER',
               default_connid  TYPE zfide_hddt_parmkey VALUE 'DEFAULT_CONNID',
               log_payload     TYPE zfide_hddt_parmkey VALUE 'LOG_PAYLOAD',
               local_currency  TYPE zfide_hddt_parmkey VALUE 'LOCAL_CURRENCY',
               round_vat       TYPE zfide_hddt_parmkey VALUE 'ROUND_VAT',
               seller_name     TYPE zfide_hddt_parmkey VALUE 'SELLER_NAME',
               seller_addr     TYPE zfide_hddt_parmkey VALUE 'SELLER_ADDR',
               seller_mail     TYPE zfide_hddt_parmkey VALUE 'SELLER_MAIL',
               seller_tel      TYPE zfide_hddt_parmkey VALUE 'SELLER_TEL',
               seller_bank     TYPE zfide_hddt_parmkey VALUE 'SELLER_BANK',
               seller_acct     TYPE zfide_hddt_parmkey VALUE 'SELLER_ACCT',
             END OF gc_parm.

  " Placeholder được engine thay thế trong ZFIT_HDDT_ACT-API_PATH
  CONSTANTS: BEGIN OF gc_symbol,
               taxcode  TYPE string VALUE 'taxcode',
               template TYPE string VALUE 'template',
               serial   TYPE string VALUE 'serial',
               seq      TYPE string VALUE 'seq',
               idkey    TYPE string VALUE 'idkey',
               bukrs    TYPE string VALUE 'bukrs',
               apiuser  TYPE string VALUE 'apiuser',
             END OF gc_symbol.

ENDINTERFACE.

*=====================================================================
* Tên/Mã     : ZFIR_HDDT_SETUP
* Mô tả chung: Nạp CẤU HÌNH KHỞI TẠO cho HĐĐT Core. Chạy một lần sau
*              khi import package để có ngay bộ endpoint của Viettel
*              SInvoice và FPT eInvoice, danh mục nhà cung cấp, tham số
*              mặc định và lớp đọc dữ liệu nguồn.
*              Sau đó chỉ cần khai bảng ZFIT_HDDT_CRED (tài khoản, MST,
*              mẫu số, ký hiệu) và tham số ACTIVE_PROVIDER là chạy được.
*
*              Chương trình KHÔNG ghi mật khẩu. URL trong bảng CONN là
*              môi trường UAT — phải đổi sang PROD trước khi go-live.
* Tham Số    : p_prov1 - Nạp cấu hình Viettel
*              p_prov2 - Nạp cấu hình FPT
*              p_prov3 - Nạp cấu hình VNPT (chỉ khung, chưa có endpoint)
*              p_base  - Nạp danh mục / tham số / nguồn dữ liệu chung
*              p_ovwrt - Ghi đè bản ghi đã tồn tại
*              p_test  - Chỉ hiển thị, không ghi vào bảng
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
REPORT zfir_hddt_setup MESSAGE-ID zfie_hddt.

TYPE-POOLS icon.

CONSTANTS gc_vt   TYPE zfide_hddt_prov VALUE 'VIETTEL'  ##NO_TEXT.
CONSTANTS gc_fpt  TYPE zfide_hddt_prov VALUE 'FPT'      ##NO_TEXT.
CONSTANTS gc_vnpt TYPE zfide_hddt_prov VALUE 'VNPT'     ##NO_TEXT.
CONSTANTS gc_tpl  TYPE zfide_hddt_prov VALUE 'TEMPLATE' ##NO_TEXT.
CONSTANTS gc_uat  TYPE zfide_hddt_connid VALUE 'UAT'    ##NO_TEXT.

" Base URL của Viettel: chỉ tới HOST, phần /services/... nằm trong
" API_PATH vì endpoint đăng nhập /auth/login KHÔNG cùng tiền tố.
CONSTANTS gc_vt_base  TYPE zfide_hddt_url
  VALUE 'https://api-vinvoice.viettel.vn' ##NO_TEXT.
CONSTANTS gc_vt_api   TYPE string
  VALUE '/services/einvoiceapplication/api/InvoiceAPI' ##NO_TEXT.
CONSTANTS gc_fpt_base TYPE zfide_hddt_url
  VALUE 'https://api-uat.einvoice.fpt.com.vn' ##NO_TEXT.

TYPES: BEGIN OF ty_log,
         light   TYPE c LENGTH 4,
         tabname TYPE tabname,
         keyinfo TYPE c LENGTH 120,
         action  TYPE c LENGTH 20,
         info    TYPE c LENGTH 120,
       END OF ty_log.
DATA gt_log TYPE STANDARD TABLE OF ty_log WITH EMPTY KEY.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
  PARAMETERS p_base  AS CHECKBOX DEFAULT 'X'.
  PARAMETERS p_prov1 AS CHECKBOX DEFAULT 'X'.
  PARAMETERS p_prov2 AS CHECKBOX DEFAULT 'X'.
  PARAMETERS p_prov3 AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
  PARAMETERS p_ovwrt AS CHECKBOX.
  PARAMETERS p_test  AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b2.


*&---------------------------------------------------------------------*
CLASS lcl_setup DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS run.

  PRIVATE SECTION.
    METHODS seed_base.
    METHODS seed_viettel.
    METHODS seed_fpt.
    METHODS seed_vnpt.

    METHODS put_prov IMPORTING is_row TYPE zfit_hddt_prov.
    METHODS put_conn IMPORTING is_row TYPE zfit_hddt_conn.
    METHODS put_act  IMPORTING is_row TYPE zfit_hddt_act.
    METHODS put_parm IMPORTING is_row TYPE zfit_hddt_parm.
    METHODS put_map  IMPORTING is_row TYPE zfit_hddt_map.
    METHODS put_stat IMPORTING is_row TYPE zfit_hddt_stat.
    METHODS put_src  IMPORTING is_row TYPE zfit_hddt_src.

    METHODS act
      IMPORTING iv_provider   TYPE zfide_hddt_prov
                iv_action     TYPE zfide_hddt_action
                iv_method     TYPE zfide_hddt_method DEFAULT 'POST'
                iv_path       TYPE string
                iv_descr      TYPE zfide_hddt_descr
                iv_cont_type  TYPE string OPTIONAL
      RETURNING VALUE(rs_row) TYPE zfit_hddt_act.

    METHODS log
      IMPORTING iv_tab     TYPE tabname
                iv_key     TYPE clike
                iv_action  TYPE clike
                iv_info    TYPE clike OPTIONAL
                iv_ok      TYPE abap_bool DEFAULT abap_true.

    METHODS show.
ENDCLASS.


CLASS lcl_setup IMPLEMENTATION.

  METHOD run.

    IF p_base  = abap_true. seed_base( ).    ENDIF.
    IF p_prov1 = abap_true. seed_viettel( ). ENDIF.
    IF p_prov2 = abap_true. seed_fpt( ).     ENDIF.
    IF p_prov3 = abap_true. seed_vnpt( ).    ENDIF.

    IF p_test = abap_true.
      ROLLBACK WORK.
      MESSAGE s010(zfie_hddt) DISPLAY LIKE 'W'.
    ELSE.
      COMMIT WORK AND WAIT.
      zfic_hddt_factory=>reset( ).
    ENDIF.

    show( ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Danh mục nhà cung cấp + tham số chung + lớp đọc dữ liệu nguồn
*---------------------------------------------------------------------*
  METHOD seed_base.

    put_prov( VALUE #( provider  = gc_vt
                       classname = 'ZFIC_HDDT_PROV_VIETTEL'
                       descr     = 'Viettel SInvoice'
                       xactive   = abap_true ) ).
    put_prov( VALUE #( provider  = gc_fpt
                       classname = 'ZFIC_HDDT_PROV_FPT'
                       descr     = 'FPT eInvoice'
                       xactive   = abap_true ) ).
    put_prov( VALUE #( provider  = gc_vnpt
                       classname = 'ZFIC_HDDT_PROV_VNPT'
                       descr     = 'VNPT / Vinaphone Invoice'
                       xactive   = abap_true ) ).
    put_prov( VALUE #( provider  = gc_tpl
                       classname = 'ZFIC_HDDT_PROV_TEMPLATE'
                       descr     = 'Adapter tong quat theo mau'
                       xactive   = abap_true ) ).

    " Lớp đọc chứng từ FI dùng cho mọi công ty (BUKRS để trống)
    put_src( VALUE #( bukrs     = space
                      src_type  = 'FI'
                      classname = 'ZFIC_HDDT_SRC_FI'
                      descr     = 'Doc chung tu FI BKPF/BSEG/BSET (ke ca FI tu billing SD)'
                      xactive   = abap_true ) ).
    " Billing SD chưa sinh chứng từ FI (VBRK/VBRP)
    put_src( VALUE #( bukrs     = space
                      src_type  = 'SD'
                      classname = 'ZFIC_HDDT_SRC_SD'
                      descr     = 'Doc hoa don billing SD chua co chung tu FI'
                      xactive   = abap_true ) ).

    " Tham số chung — PROVIDER và BUKRS để trống = áp dụng toàn hệ
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-local_currency
                       parm_val = 'VND'
                       descr    = 'Tien te ghi so cua ban' ) ).
    put_parm( VALUE #( parm_key = 'TIME_ZONE'
                       parm_val = 'UTC+7'
                       descr    = 'Mui gio quy doi epoch millis' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-log_payload
                       parm_val = 'X'
                       descr    = 'Luu payload trong log (nghia vu thue)' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-default_connid
                       parm_val = gc_uat
                       descr    = 'Ma ket noi mac dinh' ) ).

    " --- Log tich hop ---
    " Danh sach the can che truoc khi ghi log. Payload FPT co
    " "password" ngay trong body, VNPT co "acpass" -> khong che thi mat
    " khau API nam plaintext trong bang log.
    put_parm( VALUE #( parm_key = 'LOG_MASK_TAGS'
                       parm_val = 'password,acpass,pass,secret,client_secret,token,access_token,authorization,apikey,api_key'
                       descr    = 'The can che trong log (cach nhau dau phay)' ) ).
    put_parm( VALUE #( parm_key = 'LOG_TEST_RUN'
                       parm_val = ''
                       descr    = 'X = ghi log ca lan Test run' ) ).
    " Nen tang: de trong = ABAP co dien. Tren Public Cloud dat
    " ZFIC_HDDT_PLAT_CLOUD.
    put_parm( VALUE #( parm_key = 'PLATFORM_CLASS'
                       parm_val = ''
                       descr    = 'Lop nen tang; trong = ABAP co dien' ) ).

    " --- Tầng đọc dữ liệu nguồn (port từ dự án HĐĐT private cloud) ---
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-inv_date_maxback
                       parm_val = '1'
                       descr    = 'Ngay lap HD lui toi da N ngay so voi hom nay' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-buyer_tax_idtype
                       parm_val = 'VATRU'
                       descr    = 'Loai so dinh danh BP chua ma so thue (BUT0ID-TYPE)' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-buyer_id_idtype
                       parm_val = 'FS0001'
                       descr    = 'Loai so dinh danh BP chua CCCD/ho chieu' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-buyer_name_flds
                       parm_val = 'NAME_ORG1,NAME_ORG2,NAME_ORG3,NAME_ORG4'
                       descr    = 'Truong BUT000 ghep thanh ten nguoi mua' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-addr_country_sfx
                       parm_val = 'Việt Nam'
                       descr    = 'Hau to quoc gia noi vao dia chi VN (- = khong)' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-exch_rate_factor
                       parm_val = '1'
                       descr    = 'He so nhan ty gia BKPF-KURSF (TCURF factor)' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-seller_from_t001
                       parm_val = 'X'
                       descr    = 'X = nguoi ban lay tu T001/ADRC, SELLER_* chi bo sung' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-text_langu
                       parm_val = 'E'
                       descr    = 'Ngon ngu ten don vi tinh / ten vat tu' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-item_text_ids
                       parm_val = 'ZI03:VBBP;GRUN:MATERIAL'
                       descr    = 'Long text lay ten hang (ID:OBJECT;...)' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-item_qty_abs
                       parm_val = 'X'
                       descr    = 'X = so luong luon duong' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-default_payment
                       parm_val = 'TM/CK'
                       descr    = 'Hinh thuc thanh toan khi chung tu khong co ZLSCH' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-tax_cond_type
                       parm_val = 'MWAS'
                       descr    = 'Loai dieu kien thue dau ra (A003/KONP) khi thieu BSET' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-status_check
                       parm_val = 'X'
                       descr    = 'Kiem tra nghiep vu theo trang thai (N = tat)' ) ).
    put_parm( VALUE #( parm_key = zfiif_hddt_types=>gc_parm-cancel_req_rev
                       parm_val = 'X'
                       descr    = 'Phai dao chung tu SAP truoc khi huy HDDT (N = tat)' ) ).

    " Mã thuế đầu ra được phát hành HĐĐT (mẫu CP) — như dự án tham chiếu
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-tax_code
                      sap_value = 'O*'
                      ext_value = 'X'
                      ext_text  = 'Ma thue dau ra' ) ).
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-tax_code
                      sap_value = '**'
                      ext_value = 'X'
                      ext_text  = 'Ma thue tong hop' ) ).
    " Mã thuế đặc biệt -> thuế suất âm (OX = KKKNT, OG = KCT) — như dự án tham chiếu
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-tax_rate
                      sap_value = 'OX'
                      ext_value = '-2'
                      ext_text  = 'KKKNT' ) ).
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-tax_rate
                      sap_value = 'OG'
                      ext_value = '-1'
                      ext_text  = 'KCT' ) ).
    " Tài khoản thuế GTGT đầu ra loại khỏi dòng hàng (VÍ DỤ theo COA VN
    " của dự án tham chiếu — sửa theo hệ thống của bạn)
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-tax_acct
                      sap_value = '3331*'
                      ext_value = 'X'
                      ext_text  = 'Thue GTGT dau ra' ) ).
    " Loại điều kiện giá SD (VÍ DỤ theo dự án tham chiếu ZPR0/ZC04/ZC05/ZMST)
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-cond_type
                      sap_value = 'ZPR0'
                      ext_value = 'AMT+'
                      ext_text  = 'Gia ban' ) ).
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-cond_type
                      sap_value = 'ZC04'
                      ext_value = 'AMT-'
                      ext_text  = 'Chiet khau' ) ).
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-cond_type
                      sap_value = 'ZC05'
                      ext_value = 'AMT-'
                      ext_text  = 'Chiet khau' ) ).
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-cond_type
                      sap_value = 'ZMST'
                      ext_value = 'TAX'
                      ext_text  = 'Thue GTGT' ) ).
    " Loại hoá đơn SD được phát hành khi CHƯA có chứng từ FI (VÍ DỤ)
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-bill_type
                      sap_value = 'ZBT'
                      ext_value = 'X'
                      ext_text  = 'Billing khong sinh FI (vi du du an tham chieu)' ) ).

    " Nhãn thuế suất đặc biệt — dùng khi tax_rate < 0
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-tax_rate
                      sap_value = '-1'
                      ext_value = '-1'
                      ext_text  = 'KCT' ) ).
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-tax_rate
                      sap_value = '-2'
                      ext_value = '-2'
                      ext_text  = 'KKKNT' ) ).

    " Ví dụ ánh xạ hình thức thanh toán (ZLSCH của bạn có thể khác)
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-payment
                      sap_value = 'B'
                      ext_value = '2'
                      ext_text  = 'CK' ) ).
    put_map( VALUE #( map_type  = zfiif_hddt_types=>gc_map_type-payment
                      sap_value = 'C'
                      ext_value = '1'
                      ext_text  = 'TM' ) ).

    " Mã HTTP lỗi chung -> trạng thái lỗi trong SAP (áp cho mọi NCC)
    DATA lt_http TYPE zfiif_hddt_types=>ty_t_kv.
    DATA lt_prov TYPE zfiif_hddt_types=>ty_t_kv.

    lt_http = VALUE #(
      ( name = '400' value = 'Du lieu gui khong hop le' )
      ( name = '401' value = 'Xac thuc that bai' )
      ( name = '403' value = 'Khong co quyen goi API' )
      ( name = '404' value = 'Endpoint khong ton tai' )
      ( name = '500' value = 'Loi he thong nha cung cap' )
      ( name = '999' value = 'Loi ket noi tu SAP' ) ).

    lt_prov = VALUE #( ( name = gc_vt ) ( name = gc_fpt ) ( name = gc_vnpt ) ).

    LOOP AT lt_http ASSIGNING FIELD-SYMBOL(<ls_http>).
      LOOP AT lt_prov ASSIGNING FIELD-SYMBOL(<ls_p>).
        put_stat( VALUE #( provider   = CONV #( <ls_p>-name )
                           action     = '*'
                           rc_code    = CONV #( <ls_http>-name )
                           sap_status = zfiif_hddt_types=>gc_status-error
                           msgty      = 'E'
                           msg_text   = CONV #( <ls_http>-value ) ) ).
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Viettel SInvoice
*---------------------------------------------------------------------*
  METHOD seed_viettel.

    put_conn( VALUE #( provider     = gc_vt
                       connid       = gc_uat
                       base_url     = gc_vt_base
                       auth_mode    = zfiif_hddt_types=>gc_auth-basic
                       token_action = zfiif_hddt_types=>gc_action-login
                       token_ttl    = 3000
                       timeout      = 60
                       descr        = 'Viettel SInvoice UAT'
                       xactive      = abap_true ) ).

    " createInvoice dùng chung cho gốc / điều chỉnh / thay thế —
    " adapter phân biệt bằng thẻ adjustmentType trong payload.
    DATA(lv_create) = |{ gc_vt_api }/InvoiceWS/createInvoice/\{taxcode\}|.

    put_act( act( iv_provider = gc_vt
                  iv_action   = zfiif_hddt_types=>gc_action-login
                  iv_path     = '/auth/login'
                  iv_descr    = 'Dang nhap lay access token' ) ).
    put_act( act( iv_provider = gc_vt
                  iv_action   = zfiif_hddt_types=>gc_action-create_invoice
                  iv_path     = lv_create
                  iv_descr    = 'Phat hanh hoa don' ) ).
    put_act( act( iv_provider = gc_vt
                  iv_action   = zfiif_hddt_types=>gc_action-adjust_invoice
                  iv_path     = lv_create
                  iv_descr    = 'Hoa don dieu chinh' ) ).
    put_act( act( iv_provider = gc_vt
                  iv_action   = zfiif_hddt_types=>gc_action-replace_invoice
                  iv_path     = lv_create
                  iv_descr    = 'Hoa don thay the' ) ).
    put_act( act( iv_provider = gc_vt
                  iv_action   = zfiif_hddt_types=>gc_action-create_draft
                  iv_path     = |{ gc_vt_api }/InvoiceWS/createOrUpdateInvoiceDraft/\{taxcode\}|
                  iv_descr    = 'Tao / sua hoa don nhap' ) ).
    put_act( act( iv_provider = gc_vt
                  iv_action   = zfiif_hddt_types=>gc_action-preview_draft
                  iv_path     = |{ gc_vt_api }/InvoiceUtilsWS/createInvoiceDraftPreview/\{taxcode\}|
                  iv_descr    = 'Xem truoc hoa don nhap' ) ).
    " Muc 7.9 va 7.21: HAI endpoint nay nhan form-urlencoded, KHONG JSON
    put_act( act( iv_provider  = gc_vt
                  iv_action    = zfiif_hddt_types=>gc_action-cancel_invoice
                  iv_path      = |{ gc_vt_api }/InvoiceWS/cancelTransactionInvoice|
                  iv_cont_type = 'application/x-www-form-urlencoded'
                  iv_descr     = 'Huy hoa don (muc 7.9 - form urlencoded)' ) ).
    put_act( act( iv_provider  = gc_vt
                  iv_action    = zfiif_hddt_types=>gc_action-search_invoice
                  iv_path      = |{ gc_vt_api }/InvoiceWS/searchInvoiceByTransactionUuid|
                  iv_cont_type = 'application/x-www-form-urlencoded'
                  iv_descr     = 'Tra cuu transactionUuid (7.21 - form)' ) ).
    put_act( act( iv_provider = gc_vt
                  iv_action   = zfiif_hddt_types=>gc_action-get_file
                  iv_path     = |{ gc_vt_api }/InvoiceUtilsWS/getInvoiceRepresentationFile|
                  iv_descr    = 'Lay file hoa don' ) ).
    put_act( act( iv_provider = gc_vt
                  iv_action   = zfiif_hddt_types=>gc_action-get_templates
                  iv_path     = |{ gc_vt_api }/InvoiceUtilsWS/getAllInvoiceTemplates|
                  iv_descr    = 'Lay danh sach mau va ky hieu' ) ).

    " Anh xa hinh thuc dong hang hoa -> the SELECTION cua Viettel
    " (muc 6.6, cot Thong tu 78). Nap tuong minh de key user thay duoc
    " va sua duoc, thay vi an trong code.
    put_map( VALUE #( provider  = gc_vt
                      map_type  = zfiif_hddt_types=>gc_map_type-item_type
                      sap_value = '0' ext_value = '1'
                      ext_text  = 'Hang hoa / dich vu' ) ).
    put_map( VALUE #( provider  = gc_vt
                      map_type  = zfiif_hddt_types=>gc_map_type-item_type
                      sap_value = '1' ext_value = '5'
                      ext_text  = 'Khuyen mai' ) ).
    put_map( VALUE #( provider  = gc_vt
                      map_type  = zfiif_hddt_types=>gc_map_type-item_type
                      sap_value = '2' ext_value = '3'
                      ext_text  = 'Chiet khau thuong mai' ) ).
    put_map( VALUE #( provider  = gc_vt
                      map_type  = zfiif_hddt_types=>gc_map_type-item_type
                      sap_value = '3' ext_value = '2'
                      ext_text  = 'Ghi chu / dien giai' ) ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* FPT eInvoice
*---------------------------------------------------------------------*
  METHOD seed_fpt.

    " FPT nhận tài khoản trong nút "user" của payload nên AUTH_MODE = 'N'.
    " Muốn dùng Basic auth hoặc JWT: đổi AUTH_MODE và đặt tham số
    " FPT_USER_IN_BODY = 'N'.
    put_conn( VALUE #( provider     = gc_fpt
                       connid       = gc_uat
                       base_url     = gc_fpt_base
                       auth_mode    = zfiif_hddt_types=>gc_auth-none
                       token_action = zfiif_hddt_types=>gc_action-login
                       token_ttl    = 3000
                       timeout      = 60
                       descr        = 'FPT eInvoice UAT'
                       xactive      = abap_true ) ).

    put_act( act( iv_provider = gc_fpt
                  iv_action   = zfiif_hddt_types=>gc_action-login
                  iv_path     = '/c_signin'
                  iv_descr    = 'Dang nhap JWT (muc 3.11)' ) ).
    put_act( act( iv_provider = gc_fpt
                  iv_action   = zfiif_hddt_types=>gc_action-create_invoice
                  iv_path     = '/create-appr-inv'
                  iv_descr    = 'Tao + cap so + ky duyet (muc 3.3)' ) ).
    put_act( act( iv_provider = gc_fpt
                  iv_action   = zfiif_hddt_types=>gc_action-create_draft
                  iv_path     = '/create-invoice'
                  iv_descr    = 'Khoi tao hoa don (muc 3.1)' ) ).
    put_act( act( iv_provider = gc_fpt
                  iv_action   = zfiif_hddt_types=>gc_action-update_invoice
                  iv_path     = '/update-invoice'
                  iv_descr    = 'Update hoa don (muc 3.2)' ) ).
    put_act( act( iv_provider = gc_fpt
                  iv_action   = zfiif_hddt_types=>gc_action-approve_invoice
                  iv_path     = '/apprs'
                  iv_descr    = 'Ky duyet hoa don (muc 3.4)' ) ).
    put_act( act( iv_provider = gc_fpt
                  iv_action   = zfiif_hddt_types=>gc_action-replace_invoice
                  iv_path     = '/replace-invoice'
                  iv_descr    = 'Hoa don thay the (muc 3.5)' ) ).
    put_act( act( iv_provider = gc_fpt
                  iv_action   = zfiif_hddt_types=>gc_action-adjust_invoice
                  iv_path     = '/adjust-invoice'
                  iv_descr    = 'Hoa don dieu chinh (muc 3.8)' ) ).
    put_act( act( iv_provider = gc_fpt
                  iv_action   = zfiif_hddt_types=>gc_action-cancel_invoice
                  iv_path     = '/cancel-invoice'
                  iv_descr    = 'Huy hoa don TT78 (muc 3.7)' ) ).
    put_act( act( iv_provider = gc_fpt
                  iv_action   = zfiif_hddt_types=>gc_action-delete_invoice
                  iv_path     = '/del-invoice'
                  iv_descr    = 'Xoa HD cho cap so (muc 3.10)' ) ).
    put_act( act( iv_provider = gc_fpt
                  iv_action   = zfiif_hddt_types=>gc_action-search_invoice
                  iv_method   = 'GET'
                  iv_path     = '/search-invoice'
                  iv_descr    = 'Tra cuu - tham so trong header (3.9)' ) ).
    put_act( act( iv_provider = gc_fpt
                  iv_action   = zfiif_hddt_types=>gc_action-wrong_notice
                  iv_path     = '/create-wno-list'
                  iv_descr    = 'Tao thong bao sai sot (muc 3.20)' ) ).

    " Tham số riêng của adapter FPT
    put_parm( VALUE #( provider = gc_fpt parm_key = 'FPT_LANG'
                       parm_val = 'vi'
                       descr    = 'Ngon ngu thong bao loi' ) ).
    put_parm( VALUE #( provider = gc_fpt parm_key = 'FPT_AUN'
                       parm_val = '2'
                       descr    = '2 = eInvoice tu cap so hoa don' ) ).
    put_parm( VALUE #( provider = gc_fpt parm_key = 'FPT_USER_IN_BODY'
                       parm_val = 'X'
                       descr    = 'Gui user/password trong payload' ) ).

    " Placeholder giu cho FPT; anh xa trang thai o duoi
    " Trạng thái hoá đơn của FPT (Phụ lục I) -> trạng thái SAP
    put_stat( VALUE #( provider = gc_fpt action = '*' rc_code = '1'
                       sap_status = zfiif_hddt_types=>gc_status-wait_seq
                       msgty = 'S' msg_text = 'Cho cap so' ) ).
    put_stat( VALUE #( provider = gc_fpt action = '*' rc_code = '2'
                       sap_status = zfiif_hddt_types=>gc_status-wait_appr
                       msgty = 'S' msg_text = 'Cho duyet' ) ).
    put_stat( VALUE #( provider = gc_fpt action = '*' rc_code = '3'
                       sap_status = zfiif_hddt_types=>gc_status-issued
                       msgty = 'S' msg_text = 'Da duyet - da phat hanh' ) ).
    put_stat( VALUE #( provider = gc_fpt action = '*' rc_code = '4'
                       sap_status = zfiif_hddt_types=>gc_status-cancelled
                       msgty = 'S' msg_text = 'Da huy' ) ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* VNPT / Vinaphone — chỉ tạo khung, endpoint do khách hàng khai
*---------------------------------------------------------------------*
  METHOD seed_vnpt.

    put_conn( VALUE #( provider  = gc_vnpt
                       connid    = gc_uat
                       auth_mode = zfiif_hddt_types=>gc_auth-basic
                       timeout   = 60
                       descr     = 'VNPT - dien BASE_URL hoac RFCDEST'
                       xactive   = abap_false ) ).

    log( iv_tab    = 'ZFIT_HDDT_ACT'
         iv_key    = 'VNPT'
         iv_action = 'BO QUA'
         iv_info   = 'Chua co tai lieu VNPT - khai endpoint + mau payload thu cong'
         iv_ok     = abap_false ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Ghi bảng
*---------------------------------------------------------------------*
  METHOD act.

    rs_row-provider    = iv_provider.
    rs_row-action      = iv_action.
    rs_row-http_method = iv_method.
    rs_row-api_path    = iv_path.
    rs_row-cont_type   = COND #( WHEN iv_cont_type IS NOT INITIAL
                                 THEN iv_cont_type
                                 ELSE 'application/json' ).
    rs_row-accept_type = '*/*'.
    rs_row-descr       = iv_descr.
    rs_row-xactive     = abap_true.

  ENDMETHOD.


  METHOD put_prov.

    SELECT SINGLE @abap_true FROM zfit_hddt_prov INTO @DATA(lv_ex)
      WHERE provider = @is_row-provider.
    IF lv_ex = abap_true AND p_ovwrt = abap_false.
      log( iv_tab = 'ZFIT_HDDT_PROV' iv_key = is_row-provider
           iv_action = 'DA CO - GIU' iv_info = is_row-classname ).
      RETURN.
    ENDIF.
    MODIFY zfit_hddt_prov FROM is_row.
    log( iv_tab = 'ZFIT_HDDT_PROV' iv_key = is_row-provider
         iv_action = COND #( WHEN lv_ex = abap_true THEN 'GHI DE' ELSE 'TAO MOI' )
         iv_info = is_row-classname ).

  ENDMETHOD.


  METHOD put_conn.

    SELECT SINGLE @abap_true FROM zfit_hddt_conn INTO @DATA(lv_ex)
      WHERE provider = @is_row-provider AND connid = @is_row-connid.
    IF lv_ex = abap_true AND p_ovwrt = abap_false.
      log( iv_tab = 'ZFIT_HDDT_CONN'
           iv_key = |{ is_row-provider }/{ is_row-connid }|
           iv_action = 'DA CO - GIU' iv_info = is_row-base_url ).
      RETURN.
    ENDIF.
    MODIFY zfit_hddt_conn FROM is_row.
    log( iv_tab = 'ZFIT_HDDT_CONN'
         iv_key = |{ is_row-provider }/{ is_row-connid }|
         iv_action = COND #( WHEN lv_ex = abap_true THEN 'GHI DE' ELSE 'TAO MOI' )
         iv_info = is_row-base_url ).

  ENDMETHOD.


  METHOD put_act.

    SELECT SINGLE @abap_true FROM zfit_hddt_act INTO @DATA(lv_ex)
      WHERE provider = @is_row-provider AND action = @is_row-action.
    IF lv_ex = abap_true AND p_ovwrt = abap_false.
      log( iv_tab = 'ZFIT_HDDT_ACT'
           iv_key = |{ is_row-provider }/{ is_row-action }|
           iv_action = 'DA CO - GIU' iv_info = is_row-api_path ).
      RETURN.
    ENDIF.
    MODIFY zfit_hddt_act FROM is_row.
    log( iv_tab = 'ZFIT_HDDT_ACT'
         iv_key = |{ is_row-provider }/{ is_row-action }|
         iv_action = COND #( WHEN lv_ex = abap_true THEN 'GHI DE' ELSE 'TAO MOI' )
         iv_info = is_row-api_path ).

  ENDMETHOD.


  METHOD put_parm.

    SELECT SINGLE @abap_true FROM zfit_hddt_parm INTO @DATA(lv_ex)
      WHERE provider = @is_row-provider AND bukrs = @is_row-bukrs
        AND parm_key = @is_row-parm_key.
    IF lv_ex = abap_true AND p_ovwrt = abap_false.
      log( iv_tab = 'ZFIT_HDDT_PARM' iv_key = is_row-parm_key
           iv_action = 'DA CO - GIU' iv_info = is_row-parm_val ).
      RETURN.
    ENDIF.
    MODIFY zfit_hddt_parm FROM is_row.
    log( iv_tab = 'ZFIT_HDDT_PARM'
         iv_key = |{ is_row-provider }/{ is_row-parm_key }|
         iv_action = COND #( WHEN lv_ex = abap_true THEN 'GHI DE' ELSE 'TAO MOI' )
         iv_info = is_row-parm_val ).

  ENDMETHOD.


  METHOD put_map.

    SELECT SINGLE @abap_true FROM zfit_hddt_map INTO @DATA(lv_ex)
      WHERE provider = @is_row-provider AND map_type = @is_row-map_type
        AND sap_value = @is_row-sap_value.
    IF lv_ex = abap_true AND p_ovwrt = abap_false.
      RETURN.
    ENDIF.
    MODIFY zfit_hddt_map FROM is_row.
    log( iv_tab = 'ZFIT_HDDT_MAP'
         iv_key = |{ is_row-map_type }/{ is_row-sap_value }|
         iv_action = COND #( WHEN lv_ex = abap_true THEN 'GHI DE' ELSE 'TAO MOI' )
         iv_info = |{ is_row-ext_value } { is_row-ext_text }| ).

  ENDMETHOD.


  METHOD put_stat.

    SELECT SINGLE @abap_true FROM zfit_hddt_stat INTO @DATA(lv_ex)
      WHERE provider = @is_row-provider AND action = @is_row-action
        AND rc_code = @is_row-rc_code.
    IF lv_ex = abap_true AND p_ovwrt = abap_false.
      RETURN.
    ENDIF.
    MODIFY zfit_hddt_stat FROM is_row.
    log( iv_tab = 'ZFIT_HDDT_STAT'
         iv_key = |{ is_row-provider }/{ is_row-rc_code }|
         iv_action = COND #( WHEN lv_ex = abap_true THEN 'GHI DE' ELSE 'TAO MOI' )
         iv_info = |-> { is_row-sap_status } { is_row-msg_text }| ).

  ENDMETHOD.


  METHOD put_src.

    SELECT SINGLE @abap_true FROM zfit_hddt_src INTO @DATA(lv_ex)
      WHERE bukrs = @is_row-bukrs AND src_type = @is_row-src_type.
    IF lv_ex = abap_true AND p_ovwrt = abap_false.
      log( iv_tab = 'ZFIT_HDDT_SRC' iv_key = is_row-src_type
           iv_action = 'DA CO - GIU' iv_info = is_row-classname ).
      RETURN.
    ENDIF.
    MODIFY zfit_hddt_src FROM is_row.
    log( iv_tab = 'ZFIT_HDDT_SRC' iv_key = is_row-src_type
         iv_action = COND #( WHEN lv_ex = abap_true THEN 'GHI DE' ELSE 'TAO MOI' )
         iv_info = is_row-classname ).

  ENDMETHOD.


  METHOD log.

    APPEND VALUE #( light   = COND #( WHEN iv_ok = abap_true
                                      THEN icon_green_light
                                      ELSE icon_yellow_light )
                    tabname = iv_tab
                    keyinfo = iv_key
                    action  = iv_action
                    info    = iv_info ) TO gt_log.

  ENDMETHOD.


  METHOD show.

    DATA lo_alv TYPE REF TO cl_salv_table.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                                CHANGING  t_table      = gt_log ).
        lo_alv->get_functions( )->set_all( abap_true ).
        lo_alv->get_columns( )->set_optimize( abap_true ).
        CAST cl_salv_column_table( lo_alv->get_columns( )->get_column( 'LIGHT' )
          )->set_icon( abap_true ).
        DATA lv_title TYPE lvc_title.
        lv_title = COND #( WHEN p_test = abap_true
                           THEN 'MO PHONG - chua ghi vao bang'
                           ELSE 'Da nap cau hinh HDDT' ).
        lo_alv->get_display_settings( )->set_list_header( lv_title ).
        lo_alv->display( ).
      CATCH cx_salv_error INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  DATA(go_setup) = NEW lcl_setup( ).
  go_setup->run( ).

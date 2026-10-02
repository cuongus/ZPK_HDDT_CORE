*=====================================================================
* Tên/Mã     : ZPG_HDDT_SETUP
* Mô tả chung: Nạp CẤU HÌNH KHỞI TẠO cho HĐĐT Core. Chạy một lần sau
*              khi import package để có ngay bộ endpoint của Viettel
*              SInvoice và FPT eInvoice, danh mục nhà cung cấp, tham số
*              mặc định và lớp đọc dữ liệu nguồn.
*              Sau đó chỉ cần khai bảng ZTB_HDDT_CRED (tài khoản, MST,
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
* 1.0       28/08/2026    cuongus - CuongUS        $TMP        Tạo mới
* 1.1       22/09/2026    cuongus - CuongUS        $TMP        Nạp mặc định
*                         EXEC_MANY_CHUNK = 100; sửa 9 warning cắt chuỗi:
*                         COND # suy kiểu C(6) từ nhánh đầu nên 'TAO MOI'
*                         bị cắt thành 'TAO MO' -> COND string; rút gọn 2
*                         dòng DESCR vượt 60 ký tự
* 1.2       22/09/2026    cuongus - CuongUS        $TMP        7 method PUT_*
*                         điền CREATED_BY/AT + CHANGED_BY/AT qua
*                         ZCL_HDDT_LOG=>SET_ADMIN
* 1.3       22/09/2026    cuongus - CuongUS        $TMP        Bỏ hết SELECT
*                         SINGLE + MODIFY dòng đơn: 7 PUT_* chỉ dồn dòng vào bộ
*                         đệm, FLUSH ghi mỗi bảng 1 SELECT khoá + 1 MODIFY ...
*                         FROM TABLE. Từ ~95 lượt DB xuống còn 14
* 1.4       22/09/2026    cuongus - CuongUS        $TMP        Bỏ LOOP lồng LOOP:
*                         phép nhân mã HTTP x nhà cung cấp chuyển vào nested
*                         FOR của VALUE, chỉ còn một vòng lặp phẳng
* 1.5       30/09/2026    cuongus - CuongUS        $TMP        Văn bản nạp
*                         vào bảng cấu hình và ALV kết quả sang tiếng
*                         Việt có dấu; mô tả EXCH_RATE_FACTOR theo bản
*                         sửa tỷ giá DS4K900172
*=====================================================================
REPORT zpg_hddt_setup MESSAGE-ID zms_hddt.

TYPE-POOLS icon.

CONSTANTS gc_vt   TYPE zde_hddt_prov VALUE 'VIETTEL'  ##NO_TEXT.
CONSTANTS gc_fpt  TYPE zde_hddt_prov VALUE 'FPT'      ##NO_TEXT.
CONSTANTS gc_vnpt TYPE zde_hddt_prov VALUE 'VNPT'     ##NO_TEXT.
CONSTANTS gc_tpl  TYPE zde_hddt_prov VALUE 'TEMPLATE' ##NO_TEXT.
CONSTANTS gc_uat  TYPE zde_hddt_connid VALUE 'UAT'    ##NO_TEXT.

" Base URL của Viettel: chỉ tới HOST, phần /services/... nằm trong
" API_PATH vì endpoint đăng nhập /auth/login KHÔNG cùng tiền tố.
CONSTANTS gc_vt_base  TYPE zde_hddt_url
  VALUE 'https://api-vinvoice.viettel.vn' ##NO_TEXT.
CONSTANTS gc_vt_api   TYPE string
  VALUE '/services/einvoiceapplication/api/InvoiceAPI' ##NO_TEXT.
CONSTANTS gc_fpt_base TYPE zde_hddt_url
  VALUE 'https://api-uat.einvoice.fpt.com.vn' ##NO_TEXT.

TYPES ty_t_prov TYPE SORTED TABLE OF ztb_hddt_prov WITH UNIQUE KEY provider.
TYPES ty_t_conn TYPE SORTED TABLE OF ztb_hddt_conn WITH UNIQUE KEY provider connid.
TYPES ty_t_act TYPE SORTED TABLE OF ztb_hddt_act WITH UNIQUE KEY provider action.
TYPES ty_t_parm TYPE SORTED TABLE OF ztb_hddt_parm WITH UNIQUE KEY provider bukrs parm_key.
TYPES ty_t_map TYPE SORTED TABLE OF ztb_hddt_map WITH UNIQUE KEY provider map_type sap_value.
TYPES ty_t_stat TYPE SORTED TABLE OF ztb_hddt_stat WITH UNIQUE KEY provider action rc_code.
TYPES ty_t_src TYPE SORTED TABLE OF ztb_hddt_src WITH UNIQUE KEY bukrs src_type.
TYPES ty_t_po TYPE SORTED TABLE OF ztb_hddt_po WITH UNIQUE KEY bukrs bsart.

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
  " Tham số riêng theo FS MAG v0.5 (docs/10) — ghi ngược BKPF, tên BP,
  " thuế từ TK 3331*, nhà cung cấp FPT
  PARAMETERS p_mag   AS CHECKBOX.
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
    METHODS seed_mag.

    METHODS put_prov IMPORTING is_row TYPE ztb_hddt_prov.
    METHODS put_conn IMPORTING is_row TYPE ztb_hddt_conn.
    METHODS put_act  IMPORTING is_row TYPE ztb_hddt_act.
    METHODS put_parm IMPORTING is_row TYPE ztb_hddt_parm.
    METHODS put_map  IMPORTING is_row TYPE ztb_hddt_map.
    METHODS put_stat IMPORTING is_row TYPE ztb_hddt_stat.

    METHODS put_src  IMPORTING is_row TYPE ztb_hddt_src.
    METHODS put_po   IMPORTING is_row TYPE ztb_hddt_po.

    METHODS act
      IMPORTING i_provider   TYPE zde_hddt_prov
                i_action     TYPE zde_hddt_action
                i_method     TYPE zde_hddt_method DEFAULT 'POST'
                i_path       TYPE string
                i_descr      TYPE zde_hddt_descr
                i_cont_type  TYPE string OPTIONAL
      RETURNING VALUE(rs_row) TYPE ztb_hddt_act.

    METHODS log
      IMPORTING i_tab     TYPE tabname
                i_key     TYPE clike
                i_action  TYPE clike
                i_info    TYPE clike OPTIONAL
                i_ok      TYPE abap_bool DEFAULT abap_true.

    METHODS show.

    "! Ghi toan bo bo dem xuong DB: moi bang doc khoa MOT lan roi
    "! MODIFY ... FROM TABLE MOT lan. Cac PUT_* chi don dong vao bo
    "! dem, khong cham DB, nen goi chung trong vong lap cung khong
    "! sinh lenh DB nao.
    METHODS flush.
    METHODS flush_prov.
    METHODS flush_conn.
    METHODS flush_act.
    METHODS flush_parm.
    METHODS flush_map.
    METHODS flush_stat.
    METHODS flush_src.
    METHODS flush_po.

    DATA mt_prov TYPE STANDARD TABLE OF ztb_hddt_prov WITH EMPTY KEY.
    DATA mt_conn TYPE STANDARD TABLE OF ztb_hddt_conn WITH EMPTY KEY.
    DATA mt_act TYPE STANDARD TABLE OF ztb_hddt_act WITH EMPTY KEY.
    DATA mt_parm TYPE STANDARD TABLE OF ztb_hddt_parm WITH EMPTY KEY.
    DATA mt_map TYPE STANDARD TABLE OF ztb_hddt_map WITH EMPTY KEY.
    DATA mt_stat TYPE STANDARD TABLE OF ztb_hddt_stat WITH EMPTY KEY.
    DATA mt_src TYPE STANDARD TABLE OF ztb_hddt_src WITH EMPTY KEY.
    DATA mt_po TYPE STANDARD TABLE OF ztb_hddt_po WITH EMPTY KEY.
ENDCLASS.


CLASS lcl_setup IMPLEMENTATION.

  METHOD run.

    IF p_base  = abap_true. seed_base( ).    ENDIF.
    IF p_prov1 = abap_true. seed_viettel( ). ENDIF.
    IF p_prov2 = abap_true. seed_fpt( ).     ENDIF.
    IF p_prov3 = abap_true. seed_vnpt( ).    ENDIF.
    IF p_mag   = abap_true. seed_mag( ).     ENDIF.

    " Cac SEED_* chi don dong vao bo dem; toan bo lenh ghi DB nam o day
    flush( ).

    IF p_test = abap_true.
      ROLLBACK WORK.
      MESSAGE s010(zms_hddt) DISPLAY LIKE 'W'.
    ELSE.
      COMMIT WORK AND WAIT.
      zcl_hddt_factory=>reset( ).
    ENDIF.

    show( ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Danh mục nhà cung cấp + tham số chung + lớp đọc dữ liệu nguồn
*---------------------------------------------------------------------*
  METHOD seed_base.

    put_prov( VALUE #( provider  = gc_vt
                       classname = 'ZCL_HDDT_PROV_VIETTEL'
                       descr     = 'Viettel SInvoice'
                       xactive   = abap_true ) ).
    put_prov( VALUE #( provider  = gc_fpt
                       classname = 'ZCL_HDDT_PROV_FPT'
                       descr     = 'FPT eInvoice'
                       xactive   = abap_true ) ).
    put_prov( VALUE #( provider  = gc_vnpt
                       classname = 'ZCL_HDDT_PROV_VNPT'
                       descr     = 'VNPT / Vinaphone Invoice'
                       xactive   = abap_true ) ).
    put_prov( VALUE #( provider  = gc_tpl
                       classname = 'ZCL_HDDT_PROV_TEMPLATE'
                       descr     = 'Adapter tổng quát theo mẫu'
                       xactive   = abap_true ) ).

    " Lớp đọc chứng từ FI dùng cho mọi công ty (BUKRS để trống)
    put_src( VALUE #( bukrs     = space
                      src_type  = 'FI'
                      classname = 'ZCL_HDDT_SRC_FI'
                      descr     = 'Đọc chứng từ FI BKPF/BSEG/BSET (kể cả FI từ billing SD)'
                      xactive   = abap_true ) ).
    " FS v0.17 mục 3.3 Nhóm 2 - hoá đơn đầu vào trả lại hàng NCC. Chỉ
    " đọc được chứng từ khi công ty có dòng ZTB_HDDT_PO (dưới p_mag).
    put_src( VALUE #( bukrs     = space
                      src_type  = 'PO'
                      classname = 'ZCL_HDDT_SRC_PO'
                      descr     = 'Trả lại hàng NCC: mã thuế đầu vào + loại đơn hàng mua'
                      xactive   = abap_true ) ).
    " Hoá đơn gom nhiều chứng từ (FS MAG 3.6.7)
    put_src( VALUE #( bukrs     = space
                      src_type  = 'GOM'
                      classname = 'ZCL_HDDT_SRC_GOM'
                      descr     = 'Hoá đơn gom nhiều chứng từ FI'
                      xactive   = abap_true ) ).
    " Billing SD chưa sinh chứng từ FI (VBRK/VBRP)
    put_src( VALUE #( bukrs     = space
                      src_type  = 'SD'
                      classname = 'ZCL_HDDT_SRC_SD'
                      descr     = 'Đọc hoá đơn billing SD chưa có chứng từ FI'
                      xactive   = abap_true ) ).

    " Tham số chung — PROVIDER và BUKRS để trống = áp dụng toàn hệ
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-local_currency
                       parm_val = 'VND'
                       descr    = 'Tiền tệ ghi sổ của bên bán' ) ).
    put_parm( VALUE #( parm_key = 'TIME_ZONE'
                       parm_val = 'UTC+7'
                       descr    = 'Múi giờ quy đổi epoch millis' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-log_payload
                       parm_val = 'X'
                       descr    = 'Lưu payload trong log (nghĩa vụ thuế)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-default_connid
                       parm_val = gc_uat
                       descr    = 'Mã kết nối mặc định' ) ).

    " --- Log tich hop ---
    " Danh sach the can che truoc khi ghi log. Payload FPT co
    " "password" ngay trong body, VNPT co "acpass" -> khong che thi mat
    " khau API nam plaintext trong bang log.
    put_parm( VALUE #( parm_key = 'LOG_MASK_TAGS'
                       parm_val = 'password,acpass,pass,secret,client_secret,token,access_token,authorization,apikey,api_key'
                       descr    = 'Thẻ cần che trong log (cách nhau dấu phẩy)' ) ).
    put_parm( VALUE #( parm_key = 'LOG_TEST_RUN'
                       parm_val = ''
                       descr    = 'X = ghi log cả lần Test run' ) ).
    " Nen tang: de trong = ABAP co dien. Tren Public Cloud dat
    " ZCL_HDDT_PLAT_CLOUD.
    put_parm( VALUE #( parm_key = 'PLATFORM_CLASS'
                       parm_val = ''
                       descr    = 'Lớp nền tảng; trống = ABAP cổ điển' ) ).

    " --- Tầng đọc dữ liệu nguồn (port từ dự án HĐĐT private cloud) ---
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-inv_date_maxback
                       parm_val = '1'
                       descr    = 'Ngày lập HĐ lùi tối đa N ngày so với hôm nay' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-buyer_tax_idtype
                       parm_val = 'VATRU'
                       descr    = 'Loại số định danh BP chứa mã số thuế (BUT0ID-TYPE)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-buyer_id_idtype
                       parm_val = 'FS0001'
                       descr    = 'Loại số định danh BP chứa CCCD/hộ chiếu' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-buyer_name_flds
                       parm_val = 'NAME_ORG1,NAME_ORG2,NAME_ORG3,NAME_ORG4'
                       descr    = 'Trường BUT000 ghép thành tên người mua' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-addr_country_sfx
                       parm_val = 'Việt Nam'
                       descr    = 'Hậu tố quốc gia nối vào địa chỉ VN (- = không)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-exch_rate_factor
                       parm_val = '1'
                       descr    = 'Hệ số nhân THÊM cho tỷ giá (TCURF đã tự áp) - để 1' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-seller_from_t001
                       parm_val = 'X'
                       descr    = 'X = người bán lấy từ T001/ADRC, SELLER_* chỉ bổ sung' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-text_langu
                       parm_val = 'E'
                       descr    = 'Ngôn ngữ tên đơn vị tính / tên vật tư' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-item_text_ids
                       parm_val = 'ZI03:VBBP;GRUN:MATERIAL'
                       descr    = 'Long text lấy tên hàng (ID:OBJECT;...)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-item_qty_abs
                       parm_val = 'X'
                       descr    = 'X = số lượng luôn dương' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-default_payment
                       parm_val = 'TM/CK'
                       descr    = 'Hình thức thanh toán khi chứng từ không có ZLSCH' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-tax_cond_type
                       parm_val = 'MWAS'
                       descr    = 'Loại điều kiện thuế đầu ra (A003/KONP) khi thiếu BSET' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-status_check
                       parm_val = 'X'
                       descr    = 'Kiểm tra nghiệp vụ theo trạng thái (N = tắt)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-cancel_req_rev
                       parm_val = 'X'
                       descr    = 'Phải đảo chứng từ SAP trước khi huỷ HĐĐT (N = tắt)' ) ).

    " --- FS MAG v0.5 (docs/10) ---
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-writeback_class
                       parm_val = ''
                       descr    = 'Lớp ghi ngược chứng từ FI (trống = không ghi ngược)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-log_sink_class
                       parm_val = ''
                       descr    = 'Lớp đẩy log sang bảng dùng chung (ZIF_HDDT_LOG_SINK)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-tax_source
                       parm_val = 'BSET'
                       descr    = 'BSET = sổ thuế; GLACCT = dòng TK thuế (MAP TAXACCT)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-buyer_person_nm
                       parm_val = 'LAST_FIRST'
                       descr    = 'Thứ tự tên cá nhân: LAST_FIRST / FIRST_LAST' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-inv_time_default
                       parm_val = '080000'
                       descr    = 'Giờ phát hành mặc định (FS: 08:00:00)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-mail_allowed
                       parm_val = '20,50'
                       descr    = 'Trạng thái được gửi email: 20 nháp, 50 CQT cấp mã' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-mail_sender
                       parm_val = ''
                       descr    = 'Email người gửi (trống = user đăng nhập)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-auth_object
                       parm_val = ''
                       descr    = 'Auth object riêng (BUKRS, ACTVT); trống = không kiểm' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-validate_req
                       parm_val = 'X'
                       descr    = 'Kiểm tra trường bắt buộc trước khi gọi API (N = tắt)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-many_chunk
                       parm_val = '100'
                       descr    = 'Số chứng từ mỗi lô của job phát hành (COMMIT theo lô)' ) ).

    " Mã thuế đầu ra được phát hành HĐĐT (mẫu CP) — như dự án tham chiếu
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-tax_code
                      sap_value = 'O*'
                      ext_value = 'X'
                      ext_text  = 'Mã thuế đầu ra' ) ).
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-tax_code
                      sap_value = '**'
                      ext_value = 'X'
                      ext_text  = 'Mã thuế tổng hợp' ) ).
    " Mã thuế đặc biệt -> thuế suất âm (OX = KKKNT, OG = KCT) — như dự án tham chiếu
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-tax_rate
                      sap_value = 'OX'
                      ext_value = '-2'
                      ext_text  = 'KKKNT' ) ).
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-tax_rate
                      sap_value = 'OG'
                      ext_value = '-1'
                      ext_text  = 'KCT' ) ).
    " Tài khoản thuế GTGT đầu ra loại khỏi dòng hàng (VÍ DỤ theo COA VN
    " của dự án tham chiếu — sửa theo hệ thống của bạn)
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-tax_acct
                      sap_value = '3331*'
                      ext_value = 'X'
                      ext_text  = 'Thuế GTGT đầu ra' ) ).
    " Loại điều kiện giá SD (VÍ DỤ theo dự án tham chiếu ZPR0/ZC04/ZC05/ZMST)
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-cond_type
                      sap_value = 'ZPR0'
                      ext_value = 'AMT+'
                      ext_text  = 'Giá bán' ) ).
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-cond_type
                      sap_value = 'ZC04'
                      ext_value = 'AMT-'
                      ext_text  = 'Chiết khấu' ) ).
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-cond_type
                      sap_value = 'ZC05'
                      ext_value = 'AMT-'
                      ext_text  = 'Chiết khấu' ) ).
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-cond_type
                      sap_value = 'ZMST'
                      ext_value = 'TAX'
                      ext_text  = 'Thuế GTGT' ) ).
    " Loại hoá đơn SD được phát hành khi CHƯA có chứng từ FI (VÍ DỤ)
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-bill_type
                      sap_value = 'ZBT'
                      ext_value = 'X'
                      ext_text  = 'Billing không sinh FI (ví dụ dự án tham chiếu)' ) ).

    " Nhãn thuế suất đặc biệt — dùng khi tax_rate < 0
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-tax_rate
                      sap_value = '-1'
                      ext_value = '-1'
                      ext_text  = 'KCT' ) ).
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-tax_rate
                      sap_value = '-2'
                      ext_value = '-2'
                      ext_text  = 'KKKNT' ) ).

    " Ví dụ ánh xạ hình thức thanh toán (ZLSCH của bạn có thể khác)
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-payment
                      sap_value = 'B'
                      ext_value = '2'
                      ext_text  = 'CK' ) ).
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-payment
                      sap_value = 'C'
                      ext_value = '1'
                      ext_text  = 'TM' ) ).

    " Mã HTTP lỗi chung -> trạng thái lỗi trong SAP (áp cho mọi NCC)
    DATA lt_http TYPE zif_hddt_types=>ty_t_kv.
    DATA lt_prov TYPE zif_hddt_types=>ty_t_kv.

    lt_http = VALUE #(
      ( name = '400' value = 'Dữ liệu gửi không hợp lệ' )
      ( name = '401' value = 'Xác thực thất bại' )
      ( name = '403' value = 'Không có quyền gọi API' )
      ( name = '404' value = 'Endpoint không tồn tại' )
      ( name = '500' value = 'Lỗi hệ thống nhà cung cấp' )
      ( name = '999' value = 'Lỗi kết nối từ SAP' ) ).

    lt_prov = VALUE #( ( name = gc_vt ) ( name = gc_fpt ) ( name = gc_vnpt ) ).

    " 6 mã HTTP x 3 nhà cung cấp = 18 dòng. Phép nhân hai danh sách nằm
    " trong nested FOR của VALUE, nên không còn LOOP lồng LOOP; phần lặp
    " còn lại là một vòng phẳng chỉ để gọi PUT_STAT.
    "
    " Bảng tạm khai STANDARD ... EMPTY KEY chứ KHÔNG dùng TY_T_STAT:
    " TY_T_STAT là SORTED WITH UNIQUE KEY, mà thứ tự sinh ra ở đây là
    " VIETTEL/FPT/VNPT — không theo khoá, nạp vào bảng sorted sẽ dump
    " ITAB_ILLEGAL_SORT_ORDER.
    DATA lt_stat TYPE STANDARD TABLE OF ztb_hddt_stat WITH EMPTY KEY.

    lt_stat = VALUE #( FOR <fs_p> IN lt_prov
                       FOR <fs_h> IN lt_http
                       ( provider   = CONV #( <fs_p>-name )
                         action     = '*'
                         rc_code    = CONV #( <fs_h>-name )
                         sap_status = zif_hddt_types=>gc_status-error
                         msgty      = 'E'
                         msg_text   = CONV #( <fs_h>-value ) ) ).

    LOOP AT lt_stat INTO DATA(ls_stat).
      put_stat( ls_stat ).
    ENDLOOP.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Viettel SInvoice
*---------------------------------------------------------------------*
  METHOD seed_viettel.

    put_conn( VALUE #( provider     = gc_vt
                       connid       = gc_uat
                       base_url     = gc_vt_base
                       auth_mode    = zif_hddt_types=>gc_auth-basic
                       token_action = zif_hddt_types=>gc_action-login
                       token_ttl    = 3000
                       timeout      = 60
                       descr        = 'Viettel SInvoice UAT'
                       xactive      = abap_true ) ).

    " createInvoice dùng chung cho gốc / điều chỉnh / thay thế —
    " adapter phân biệt bằng thẻ adjustmentType trong payload.
    DATA(lv_create) = |{ gc_vt_api }/InvoiceWS/createInvoice/\{taxcode\}|.

    put_act( act( i_provider = gc_vt
                  i_action   = zif_hddt_types=>gc_action-login
                  i_path     = '/auth/login'
                  i_descr    = 'Đăng nhập lấy access token' ) ).
    put_act( act( i_provider = gc_vt
                  i_action   = zif_hddt_types=>gc_action-create_invoice
                  i_path     = lv_create
                  i_descr    = 'Phát hành hoá đơn' ) ).
    put_act( act( i_provider = gc_vt
                  i_action   = zif_hddt_types=>gc_action-adjust_invoice
                  i_path     = lv_create
                  i_descr    = 'Hoá đơn điều chỉnh' ) ).
    put_act( act( i_provider = gc_vt
                  i_action   = zif_hddt_types=>gc_action-replace_invoice
                  i_path     = lv_create
                  i_descr    = 'Hoá đơn thay thế' ) ).
    put_act( act( i_provider = gc_vt
                  i_action   = zif_hddt_types=>gc_action-create_draft
                  i_path     = |{ gc_vt_api }/InvoiceWS/createOrUpdateInvoiceDraft/\{taxcode\}|
                  i_descr    = 'Tạo / sửa hoá đơn nháp' ) ).
    put_act( act( i_provider = gc_vt
                  i_action   = zif_hddt_types=>gc_action-preview_draft
                  i_path     = |{ gc_vt_api }/InvoiceUtilsWS/createInvoiceDraftPreview/\{taxcode\}|
                  i_descr    = 'Xem trước hoá đơn nháp' ) ).
    " Muc 7.9 va 7.21: HAI endpoint nay nhan form-urlencoded, KHONG JSON
    put_act( act( i_provider  = gc_vt
                  i_action    = zif_hddt_types=>gc_action-cancel_invoice
                  i_path      = |{ gc_vt_api }/InvoiceWS/cancelTransactionInvoice|
                  i_cont_type = 'application/x-www-form-urlencoded'
                  i_descr     = 'Huỷ hoá đơn (mục 7.9 - form urlencoded)' ) ).
    put_act( act( i_provider  = gc_vt
                  i_action    = zif_hddt_types=>gc_action-search_invoice
                  i_path      = |{ gc_vt_api }/InvoiceWS/searchInvoiceByTransactionUuid|
                  i_cont_type = 'application/x-www-form-urlencoded'
                  i_descr     = 'Tra cứu transactionUuid (7.21 - form)' ) ).
    put_act( act( i_provider = gc_vt
                  i_action   = zif_hddt_types=>gc_action-get_file
                  i_path     = |{ gc_vt_api }/InvoiceUtilsWS/getInvoiceRepresentationFile|
                  i_descr    = 'Lấy file hoá đơn' ) ).
    put_act( act( i_provider = gc_vt
                  i_action   = zif_hddt_types=>gc_action-get_templates
                  i_path     = |{ gc_vt_api }/InvoiceUtilsWS/getAllInvoiceTemplates|
                  i_descr    = 'Lấy danh sách mẫu và ký hiệu' ) ).

    " Anh xa hinh thuc dong hang hoa -> the SELECTION cua Viettel
    " (muc 6.6, cot Thong tu 78). Nap tuong minh de key user thay duoc
    " va sua duoc, thay vi an trong code.
    put_map( VALUE #( provider  = gc_vt
                      map_type  = zif_hddt_types=>gc_map_type-item_type
                      sap_value = '0' ext_value = '1'
                      ext_text  = 'Hàng hoá / dịch vụ' ) ).
    put_map( VALUE #( provider  = gc_vt
                      map_type  = zif_hddt_types=>gc_map_type-item_type
                      sap_value = '1' ext_value = '5'
                      ext_text  = 'Khuyến mại' ) ).
    put_map( VALUE #( provider  = gc_vt
                      map_type  = zif_hddt_types=>gc_map_type-item_type
                      sap_value = '2' ext_value = '3'
                      ext_text  = 'Chiết khấu thương mại' ) ).
    put_map( VALUE #( provider  = gc_vt
                      map_type  = zif_hddt_types=>gc_map_type-item_type
                      sap_value = '3' ext_value = '2'
                      ext_text  = 'Ghi chú / diễn giải' ) ).

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
                       auth_mode    = zif_hddt_types=>gc_auth-none
                       token_action = zif_hddt_types=>gc_action-login
                       token_ttl    = 3000
                       timeout      = 60
                       descr        = 'FPT eInvoice UAT'
                       xactive      = abap_true ) ).

    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-login
                  i_path     = '/c_signin'
                  i_descr    = 'Đăng nhập JWT (mục 3.11)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-create_invoice
                  i_path     = '/create-appr-inv'
                  i_descr    = 'Tạo + cấp số + ký duyệt (mục 3.3)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-create_draft
                  i_path     = '/create-invoice'
                  i_descr    = 'Khởi tạo hoá đơn (mục 3.1)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-update_invoice
                  i_path     = '/update-invoice'
                  i_descr    = 'Cập nhật hoá đơn (mục 3.2)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-approve_invoice
                  i_path     = '/apprs'
                  i_descr    = 'Ký duyệt hoá đơn (mục 3.4)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-replace_invoice
                  i_path     = '/replace-invoice'
                  i_descr    = 'Hoá đơn thay thế (mục 3.5)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-adjust_invoice
                  i_path     = '/adjust-invoice'
                  i_descr    = 'Hoá đơn điều chỉnh (mục 3.8)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-cancel_invoice
                  i_path     = '/cancel-invoice'
                  i_descr    = 'Huỷ hoá đơn TT78 (mục 3.7)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-delete_invoice
                  i_path     = '/del-invoice'
                  i_descr    = 'Xoá HĐ chờ cấp số (mục 3.10)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-search_invoice
                  i_method   = 'GET'
                  i_path     = '/search-invoice'
                  i_descr    = 'Tra cứu - tham số trong header (3.9)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-get_file
                  i_method   = 'GET'
                  i_path     = '/search-invoice'
                  i_descr    = 'Lấy file PDF/XML (search-invoice type=pdf)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-issue_invoice
                  i_path     = '/issue-invoice'
                  i_descr    = 'Cấp số + ký duyệt bản nháp (FS MAG 3.7.3)' ) ).
    put_act( act( i_provider = gc_fpt
                  i_action   = zif_hddt_types=>gc_action-wrong_notice
                  i_path     = '/create-wno-list'
                  i_descr    = 'Tạo thông báo sai sót (mục 3.20)' ) ).

    " Tham số riêng của adapter FPT
    put_parm( VALUE #( provider = gc_fpt parm_key = 'FPT_LANG'
                       parm_val = 'vi'
                       descr    = 'Ngôn ngữ thông báo lỗi' ) ).
    put_parm( VALUE #( provider = gc_fpt parm_key = 'FPT_AUN'
                       parm_val = '2'
                       descr    = '2 = eInvoice tự cấp số hoá đơn' ) ).
    put_parm( VALUE #( provider = gc_fpt parm_key = 'FPT_USER_IN_BODY'
                       parm_val = 'X'
                       descr    = 'Gửi user/password trong payload' ) ).
    put_parm( VALUE #( provider = gc_fpt parm_key = zif_hddt_types=>gc_parm-api_version
                       parm_val = '3.2'
                       descr    = 'Tài liệu API FPT: 3.2 (NĐ70) -> adjtype/ref; 2.4.7 -> adj/ud' ) ).
    " FS v0.17 mục 3.7.7 điểm 3: KHÔNG gọi apprs sau replace-invoice - hoá
    " đơn thay thế dừng ở nháp, cấp số + ký duyệt bằng issue-invoice.
    put_parm( VALUE #( provider = gc_fpt parm_key = zif_hddt_types=>gc_parm-auto_appr_repl
                       parm_val = space
                       descr    = 'FS v0.17: không apprs sau replace (thay thế qua nháp)' ) ).

    " Placeholder giu cho FPT; anh xa trang thai o duoi
    " Trạng thái hoá đơn của FPT (Phụ lục I) -> trạng thái SAP
    put_stat( VALUE #( provider = gc_fpt action = '*' rc_code = '1'
                       sap_status = zif_hddt_types=>gc_status-wait_seq
                       msgty = 'S' msg_text = 'Chờ cấp số' ) ).
    put_stat( VALUE #( provider = gc_fpt action = '*' rc_code = '2'
                       sap_status = zif_hddt_types=>gc_status-wait_appr
                       msgty = 'S' msg_text = 'Chờ duyệt' ) ).
    put_stat( VALUE #( provider = gc_fpt action = '*' rc_code = '3'
                       sap_status = zif_hddt_types=>gc_status-issued
                       msgty = 'S' msg_text = 'Đã duyệt - đã phát hành' ) ).
    put_stat( VALUE #( provider = gc_fpt action = '*' rc_code = '4'
                       sap_status = zif_hddt_types=>gc_status-cancelled
                       msgty = 'S' msg_text = 'Đã huỷ' ) ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* VNPT / Vinaphone — chỉ tạo khung, endpoint do khách hàng khai
*---------------------------------------------------------------------*
  METHOD seed_vnpt.

    put_conn( VALUE #( provider  = gc_vnpt
                       connid    = gc_uat
                       auth_mode = zif_hddt_types=>gc_auth-basic
                       timeout   = 60
                       descr     = 'VNPT - điền BASE_URL hoặc RFCDEST'
                       xactive   = abap_false ) ).

    log( i_tab    = 'ZTB_HDDT_ACT'
         i_key    = 'VNPT'
         i_action = 'BỎ QUA'
         i_info   = 'Chưa có tài liệu VNPT - khai endpoint + mẫu payload thủ công'
         i_ok     = abap_false ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Ghi bảng
*---------------------------------------------------------------------*
  METHOD act.

    rs_row-provider    = i_provider.
    rs_row-action      = i_action.
    rs_row-http_method = i_method.
    rs_row-api_path    = i_path.
    rs_row-cont_type   = COND #( WHEN i_cont_type IS NOT INITIAL
                                 THEN i_cont_type
                                 ELSE 'application/json' ).
    rs_row-accept_type = '*/*'.
    rs_row-descr       = i_descr.
    rs_row-xactive     = abap_true.

  ENDMETHOD.


  METHOD put_prov.
    APPEND is_row TO mt_prov.
  ENDMETHOD.


  METHOD put_conn.
    APPEND is_row TO mt_conn.
  ENDMETHOD.


  METHOD put_act.
    APPEND is_row TO mt_act.
  ENDMETHOD.


  METHOD put_parm.
    APPEND is_row TO mt_parm.
  ENDMETHOD.


  METHOD put_map.
    APPEND is_row TO mt_map.
  ENDMETHOD.


  METHOD put_stat.
    APPEND is_row TO mt_stat.
  ENDMETHOD.


  METHOD put_src.
    APPEND is_row TO mt_src.
  ENDMETHOD.


  METHOD put_po.
    APPEND is_row TO mt_po.
  ENDMETHOD.


  METHOD flush.

    flush_prov( ).
    flush_conn( ).
    flush_act( ).
    flush_parm( ).
    flush_map( ).
    flush_stat( ).
    flush_src( ).
    flush_po( ).

  ENDMETHOD.


  METHOD flush_prov.

    IF mt_prov IS INITIAL.
      RETURN.
    ENDIF.

    " Doc khoa hien co DUNG MOT LAN cho ca lo, thay vi SELECT SINGLE
    " tung dong nhu truoc
    SELECT provider
      FROM ztb_hddt_prov
      INTO TABLE @DATA(lt_db).

    DATA lt_upd TYPE ty_t_prov.

    LOOP AT mt_prov INTO DATA(ls_row).

      READ TABLE lt_db TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider.
      DATA(lv_ex) = xsdbool( sy-subrc = 0 ).
      IF lv_ex = abap_false.
        " Da ghi trong chinh lan chay nay -> cung tinh la da co
      READ TABLE lt_upd TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider.
        lv_ex = xsdbool( sy-subrc = 0 ).
      ENDIF.

      IF lv_ex = abap_true AND p_ovwrt = abap_false.
        log( i_tab = 'ZTB_HDDT_PROV' i_key = ls_row-provider
             i_action = 'ĐÃ CÓ - GIỮ' i_info = ls_row-classname ).
        CONTINUE.
      ENDIF.

      zcl_hddt_log=>set_admin( EXPORTING i_new  = xsdbool( lv_ex = abap_false )
                               CHANGING  cs_row = ls_row ).

      INSERT ls_row INTO TABLE lt_upd.
      IF sy-subrc <> 0.
        MODIFY TABLE lt_upd FROM ls_row.      " dong sau de len dong truoc
      ENDIF.

      log( i_tab = 'ZTB_HDDT_PROV' i_key = ls_row-provider
           i_action = COND string( WHEN lv_ex = abap_true THEN 'GHI ĐÈ' ELSE 'TẠO MỚI' )
           i_info = ls_row-classname ).

    ENDLOOP.

    " MOT lenh ghi cho ca bang
    IF lt_upd IS NOT INITIAL.
      MODIFY ztb_hddt_prov FROM TABLE lt_upd.
    ENDIF.

  ENDMETHOD.


  METHOD flush_conn.

    IF mt_conn IS INITIAL.
      RETURN.
    ENDIF.

    " Doc khoa hien co DUNG MOT LAN cho ca lo, thay vi SELECT SINGLE
    " tung dong nhu truoc
    SELECT provider, connid
      FROM ztb_hddt_conn
      INTO TABLE @DATA(lt_db).

    DATA lt_upd TYPE ty_t_conn.

    LOOP AT mt_conn INTO DATA(ls_row).

      READ TABLE lt_db TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider
                    connid = ls_row-connid.
      DATA(lv_ex) = xsdbool( sy-subrc = 0 ).
      IF lv_ex = abap_false.
        " Da ghi trong chinh lan chay nay -> cung tinh la da co
      READ TABLE lt_upd TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider
                    connid = ls_row-connid.
        lv_ex = xsdbool( sy-subrc = 0 ).
      ENDIF.

      IF lv_ex = abap_true AND p_ovwrt = abap_false.
        log( i_tab = 'ZTB_HDDT_CONN' i_key = |{ ls_row-provider }/{ ls_row-connid }|
             i_action = 'ĐÃ CÓ - GIỮ' i_info = ls_row-base_url ).
        CONTINUE.
      ENDIF.

      zcl_hddt_log=>set_admin( EXPORTING i_new  = xsdbool( lv_ex = abap_false )
                               CHANGING  cs_row = ls_row ).

      INSERT ls_row INTO TABLE lt_upd.
      IF sy-subrc <> 0.
        MODIFY TABLE lt_upd FROM ls_row.      " dong sau de len dong truoc
      ENDIF.

      log( i_tab = 'ZTB_HDDT_CONN' i_key = |{ ls_row-provider }/{ ls_row-connid }|
           i_action = COND string( WHEN lv_ex = abap_true THEN 'GHI ĐÈ' ELSE 'TẠO MỚI' )
           i_info = ls_row-base_url ).

    ENDLOOP.

    " MOT lenh ghi cho ca bang
    IF lt_upd IS NOT INITIAL.
      MODIFY ztb_hddt_conn FROM TABLE lt_upd.
    ENDIF.

  ENDMETHOD.


  METHOD flush_act.

    IF mt_act IS INITIAL.
      RETURN.
    ENDIF.

    " Doc khoa hien co DUNG MOT LAN cho ca lo, thay vi SELECT SINGLE
    " tung dong nhu truoc
    SELECT provider, action
      FROM ztb_hddt_act
      INTO TABLE @DATA(lt_db).

    DATA lt_upd TYPE ty_t_act.

    LOOP AT mt_act INTO DATA(ls_row).

      READ TABLE lt_db TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider
                    action = ls_row-action.
      DATA(lv_ex) = xsdbool( sy-subrc = 0 ).
      IF lv_ex = abap_false.
        " Da ghi trong chinh lan chay nay -> cung tinh la da co
      READ TABLE lt_upd TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider
                    action = ls_row-action.
        lv_ex = xsdbool( sy-subrc = 0 ).
      ENDIF.

      IF lv_ex = abap_true AND p_ovwrt = abap_false.
        log( i_tab = 'ZTB_HDDT_ACT' i_key = |{ ls_row-provider }/{ ls_row-action }|
             i_action = 'ĐÃ CÓ - GIỮ' i_info = ls_row-api_path ).
        CONTINUE.
      ENDIF.

      zcl_hddt_log=>set_admin( EXPORTING i_new  = xsdbool( lv_ex = abap_false )
                               CHANGING  cs_row = ls_row ).

      INSERT ls_row INTO TABLE lt_upd.
      IF sy-subrc <> 0.
        MODIFY TABLE lt_upd FROM ls_row.      " dong sau de len dong truoc
      ENDIF.

      log( i_tab = 'ZTB_HDDT_ACT' i_key = |{ ls_row-provider }/{ ls_row-action }|
           i_action = COND string( WHEN lv_ex = abap_true THEN 'GHI ĐÈ' ELSE 'TẠO MỚI' )
           i_info = ls_row-api_path ).

    ENDLOOP.

    " MOT lenh ghi cho ca bang
    IF lt_upd IS NOT INITIAL.
      MODIFY ztb_hddt_act FROM TABLE lt_upd.
    ENDIF.

  ENDMETHOD.


  METHOD flush_parm.

    IF mt_parm IS INITIAL.
      RETURN.
    ENDIF.

    " Doc khoa hien co DUNG MOT LAN cho ca lo, thay vi SELECT SINGLE
    " tung dong nhu truoc
    SELECT provider, bukrs, parm_key
      FROM ztb_hddt_parm
      INTO TABLE @DATA(lt_db).

    DATA lt_upd TYPE ty_t_parm.

    LOOP AT mt_parm INTO DATA(ls_row).

      READ TABLE lt_db TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider
                    bukrs = ls_row-bukrs
                    parm_key = ls_row-parm_key.
      DATA(lv_ex) = xsdbool( sy-subrc = 0 ).
      IF lv_ex = abap_false.
        " Da ghi trong chinh lan chay nay -> cung tinh la da co
      READ TABLE lt_upd TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider
                    bukrs = ls_row-bukrs
                    parm_key = ls_row-parm_key.
        lv_ex = xsdbool( sy-subrc = 0 ).
      ENDIF.

      IF lv_ex = abap_true AND p_ovwrt = abap_false.
        log( i_tab = 'ZTB_HDDT_PARM' i_key = |{ ls_row-provider }/{ ls_row-parm_key }|
             i_action = 'ĐÃ CÓ - GIỮ' i_info = ls_row-parm_val ).
        CONTINUE.
      ENDIF.

      zcl_hddt_log=>set_admin( EXPORTING i_new  = xsdbool( lv_ex = abap_false )
                               CHANGING  cs_row = ls_row ).

      INSERT ls_row INTO TABLE lt_upd.
      IF sy-subrc <> 0.
        MODIFY TABLE lt_upd FROM ls_row.      " dong sau de len dong truoc
      ENDIF.

      log( i_tab = 'ZTB_HDDT_PARM' i_key = |{ ls_row-provider }/{ ls_row-parm_key }|
           i_action = COND string( WHEN lv_ex = abap_true THEN 'GHI ĐÈ' ELSE 'TẠO MỚI' )
           i_info = ls_row-parm_val ).

    ENDLOOP.

    " MOT lenh ghi cho ca bang
    IF lt_upd IS NOT INITIAL.
      MODIFY ztb_hddt_parm FROM TABLE lt_upd.
    ENDIF.

  ENDMETHOD.


  METHOD flush_map.

    IF mt_map IS INITIAL.
      RETURN.
    ENDIF.

    " Doc khoa hien co DUNG MOT LAN cho ca lo, thay vi SELECT SINGLE
    " tung dong nhu truoc
    SELECT provider, map_type, sap_value
      FROM ztb_hddt_map
      INTO TABLE @DATA(lt_db).

    DATA lt_upd TYPE ty_t_map.

    LOOP AT mt_map INTO DATA(ls_row).

      READ TABLE lt_db TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider
                    map_type = ls_row-map_type
                    sap_value = ls_row-sap_value.
      DATA(lv_ex) = xsdbool( sy-subrc = 0 ).
      IF lv_ex = abap_false.
        " Da ghi trong chinh lan chay nay -> cung tinh la da co
      READ TABLE lt_upd TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider
                    map_type = ls_row-map_type
                    sap_value = ls_row-sap_value.
        lv_ex = xsdbool( sy-subrc = 0 ).
      ENDIF.

      IF lv_ex = abap_true AND p_ovwrt = abap_false.
        log( i_tab = 'ZTB_HDDT_MAP' i_key = |{ ls_row-map_type }/{ ls_row-sap_value }|
             i_action = 'ĐÃ CÓ - GIỮ' i_info = |{ ls_row-ext_value } { ls_row-ext_text }| ).
        CONTINUE.
      ENDIF.

      zcl_hddt_log=>set_admin( EXPORTING i_new  = xsdbool( lv_ex = abap_false )
                               CHANGING  cs_row = ls_row ).

      INSERT ls_row INTO TABLE lt_upd.
      IF sy-subrc <> 0.
        MODIFY TABLE lt_upd FROM ls_row.      " dong sau de len dong truoc
      ENDIF.

      log( i_tab = 'ZTB_HDDT_MAP' i_key = |{ ls_row-map_type }/{ ls_row-sap_value }|
           i_action = COND string( WHEN lv_ex = abap_true THEN 'GHI ĐÈ' ELSE 'TẠO MỚI' )
           i_info = |{ ls_row-ext_value } { ls_row-ext_text }| ).

    ENDLOOP.

    " MOT lenh ghi cho ca bang
    IF lt_upd IS NOT INITIAL.
      MODIFY ztb_hddt_map FROM TABLE lt_upd.
    ENDIF.

  ENDMETHOD.


  METHOD flush_stat.

    IF mt_stat IS INITIAL.
      RETURN.
    ENDIF.

    " Doc khoa hien co DUNG MOT LAN cho ca lo, thay vi SELECT SINGLE
    " tung dong nhu truoc
    SELECT provider, action, rc_code
      FROM ztb_hddt_stat
      INTO TABLE @DATA(lt_db).

    DATA lt_upd TYPE ty_t_stat.

    LOOP AT mt_stat INTO DATA(ls_row).

      READ TABLE lt_db TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider
                    action = ls_row-action
                    rc_code = ls_row-rc_code.
      DATA(lv_ex) = xsdbool( sy-subrc = 0 ).
      IF lv_ex = abap_false.
        " Da ghi trong chinh lan chay nay -> cung tinh la da co
      READ TABLE lt_upd TRANSPORTING NO FIELDS
           WITH KEY provider = ls_row-provider
                    action = ls_row-action
                    rc_code = ls_row-rc_code.
        lv_ex = xsdbool( sy-subrc = 0 ).
      ENDIF.

      IF lv_ex = abap_true AND p_ovwrt = abap_false.
        log( i_tab = 'ZTB_HDDT_STAT' i_key = |{ ls_row-provider }/{ ls_row-rc_code }|
             i_action = 'ĐÃ CÓ - GIỮ' i_info = |-> { ls_row-sap_status } { ls_row-msg_text }| ).
        CONTINUE.
      ENDIF.

      zcl_hddt_log=>set_admin( EXPORTING i_new  = xsdbool( lv_ex = abap_false )
                               CHANGING  cs_row = ls_row ).

      INSERT ls_row INTO TABLE lt_upd.
      IF sy-subrc <> 0.
        MODIFY TABLE lt_upd FROM ls_row.      " dong sau de len dong truoc
      ENDIF.

      log( i_tab = 'ZTB_HDDT_STAT' i_key = |{ ls_row-provider }/{ ls_row-rc_code }|
           i_action = COND string( WHEN lv_ex = abap_true THEN 'GHI ĐÈ' ELSE 'TẠO MỚI' )
           i_info = |-> { ls_row-sap_status } { ls_row-msg_text }| ).

    ENDLOOP.

    " MOT lenh ghi cho ca bang
    IF lt_upd IS NOT INITIAL.
      MODIFY ztb_hddt_stat FROM TABLE lt_upd.
    ENDIF.

  ENDMETHOD.


  METHOD flush_src.

    IF mt_src IS INITIAL.
      RETURN.
    ENDIF.

    " Doc khoa hien co DUNG MOT LAN cho ca lo, thay vi SELECT SINGLE
    " tung dong nhu truoc
    SELECT bukrs, src_type
      FROM ztb_hddt_src
      INTO TABLE @DATA(lt_db).

    DATA lt_upd TYPE ty_t_src.

    LOOP AT mt_src INTO DATA(ls_row).

      READ TABLE lt_db TRANSPORTING NO FIELDS
           WITH KEY bukrs = ls_row-bukrs
                    src_type = ls_row-src_type.
      DATA(lv_ex) = xsdbool( sy-subrc = 0 ).
      IF lv_ex = abap_false.
        " Da ghi trong chinh lan chay nay -> cung tinh la da co
      READ TABLE lt_upd TRANSPORTING NO FIELDS
           WITH KEY bukrs = ls_row-bukrs
                    src_type = ls_row-src_type.
        lv_ex = xsdbool( sy-subrc = 0 ).
      ENDIF.

      IF lv_ex = abap_true AND p_ovwrt = abap_false.
        log( i_tab = 'ZTB_HDDT_SRC' i_key = ls_row-src_type
             i_action = 'ĐÃ CÓ - GIỮ' i_info = ls_row-classname ).
        CONTINUE.
      ENDIF.

      zcl_hddt_log=>set_admin( EXPORTING i_new  = xsdbool( lv_ex = abap_false )
                               CHANGING  cs_row = ls_row ).

      INSERT ls_row INTO TABLE lt_upd.
      IF sy-subrc <> 0.
        MODIFY TABLE lt_upd FROM ls_row.      " dong sau de len dong truoc
      ENDIF.

      log( i_tab = 'ZTB_HDDT_SRC' i_key = ls_row-src_type
           i_action = COND string( WHEN lv_ex = abap_true THEN 'GHI ĐÈ' ELSE 'TẠO MỚI' )
           i_info = ls_row-classname ).

    ENDLOOP.

    " MOT lenh ghi cho ca bang
    IF lt_upd IS NOT INITIAL.
      MODIFY ztb_hddt_src FROM TABLE lt_upd.
    ENDIF.

  ENDMETHOD.


  METHOD flush_po.

    IF mt_po IS INITIAL.
      RETURN.
    ENDIF.

    " Doc khoa hien co MOT LAN cho ca lo
    SELECT bukrs, bsart
      FROM ztb_hddt_po
      INTO TABLE @DATA(lt_db).

    DATA lt_upd TYPE ty_t_po.

    LOOP AT mt_po INTO DATA(ls_row).

      READ TABLE lt_db TRANSPORTING NO FIELDS
           WITH KEY bukrs = ls_row-bukrs
                    bsart = ls_row-bsart.
      DATA(lv_ex) = xsdbool( sy-subrc = 0 ).
      IF lv_ex = abap_false.
        READ TABLE lt_upd TRANSPORTING NO FIELDS
             WITH KEY bukrs = ls_row-bukrs
                      bsart = ls_row-bsart.
        lv_ex = xsdbool( sy-subrc = 0 ).
      ENDIF.

      IF lv_ex = abap_true AND p_ovwrt = abap_false.
        log( i_tab = 'ZTB_HDDT_PO' i_key = ls_row-bsart
             i_action = 'ĐÃ CÓ - GIỮ' i_info = ls_row-descr ).
        CONTINUE.
      ENDIF.

      zcl_hddt_log=>set_admin( EXPORTING i_new  = xsdbool( lv_ex = abap_false )
                               CHANGING  cs_row = ls_row ).

      INSERT ls_row INTO TABLE lt_upd.
      IF sy-subrc <> 0.
        MODIFY TABLE lt_upd FROM ls_row.
      ENDIF.

      log( i_tab = 'ZTB_HDDT_PO' i_key = ls_row-bsart
           i_action = COND string( WHEN lv_ex = abap_true THEN 'GHI ĐÈ' ELSE 'TẠO MỚI' )
           i_info = ls_row-descr ).

    ENDLOOP.

    IF lt_upd IS NOT INITIAL.
      MODIFY ztb_hddt_po FROM TABLE lt_upd.
    ENDIF.

  ENDMETHOD.


  METHOD log.

    APPEND VALUE #( light   = COND #( WHEN i_ok = abap_true
                                      THEN icon_green_light
                                      ELSE icon_yellow_light )
                    tabname = i_tab
                    keyinfo = i_key
                    action  = i_action
                    info    = i_info ) TO gt_log.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Tham số riêng theo FS MAG_SAP_2026_PM_FS_Tich hop HDDT v0.5
* (nhà cung cấp FPT eInvoice, hoá đơn có mã CQT)
*---------------------------------------------------------------------*
  METHOD seed_mag.

    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-active_provider
                       parm_val = gc_fpt
                       descr    = 'MAG: nhà cung cấp FPT eInvoice' ) ).
    " FS 3.6.3/3.6.5: ghi "Mau + Ky hieu # So" vao BKPF-XBLNR, HD goc vao XREF2_HD
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-writeback_class
                       parm_val = 'ZCL_HDDT_WRITEBACK_FI'
                       descr    = 'MAG: ghi ngược BKPF-XBLNR / XREF2_HD' ) ).
    " FS 3.5 Ten don vi: NAME_ORG2+3+4, khong co thi NAME_ORG1
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-buyer_name_flds
                       parm_val = 'NAME_ORG2,NAME_ORG3,NAME_ORG4'
                       descr    = 'MAG: tên tổ chức = ORG2+ORG3+ORG4, fallback ORG1' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-buyer_person_nm
                       parm_val = 'LAST_FIRST'
                       descr    = 'MAG: tên cá nhân = NAME_LAST + NAME_FIRST' ) ).
    " FS 3.5 Tien thue = tong dong BSEG co HKONT 3331*
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-tax_source
                       parm_val = 'GLACCT'
                       descr    = 'MAG: tiền thuế từ dòng TK 3331* (MAP TAXACCT)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-inv_time_default
                       parm_val = '080000'
                       descr    = 'MAG: giờ phát hành mặc định 08:00:00' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-mail_subj_draft
                       parm_val = '[MẪU HOÁ ĐƠN NHÁP - chưa có giá trị pháp lý] Chứng từ {DOCNO} - {COMPANY}'
                       descr    = 'MAG: tiêu đề email hoá đơn nháp' ) ).
    " FS v0.17 mục 3.2 ZEINVCONFIPO - loại đơn hàng mua được phát hành hoá
    " đơn (trả lại hàng NCC). BUKRS trống = dùng cho mọi pháp nhân MAG;
    " khai thêm dòng có BUKRS nếu một pháp nhân cần giá trị riêng.
    put_po( VALUE #( bukrs     = space
                     bsart     = 'ZPO6'
                     mwskz_pat = 'I*'
                     hkont_tax = '1331*'
                     src_type  = 'PO'
                     descr     = 'MAG: trả lại hàng NCC'
                     xactive   = abap_true ) ).
    " FS v0.17 mục 3.3 Nhóm 3 - Billing chưa có chứng từ FI. ZF04 / ZF05
    " TẠM theo dự án EEMC, MAG sẽ cấp giá trị thật sau.
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-bill_type
                      sap_value = 'ZF04'
                      ext_value = 'X'
                      ext_text  = 'MAG: billing không sinh FI (tạm theo EEMC)' ) ).
    put_map( VALUE #( map_type  = zif_hddt_types=>gc_map_type-bill_type
                      sap_value = 'ZF05'
                      ext_value = 'X'
                      ext_text  = 'MAG: billing không sinh FI (tạm theo EEMC)' ) ).
    put_parm( VALUE #( parm_key = zif_hddt_types=>gc_parm-mail_subj_final
                       parm_val = 'Hoá đơn điện tử {SERIAL} {SEQ} - {COMPANY}'
                       descr    = 'MAG: tiêu đề email hoá đơn chính thức' ) ).

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
        " Tiêu đề cột tiếng Việt: các cột kiểu C trần không có nhãn DDIC nên
        " mặc định ALV hiện tên trường tiếng Anh
        DATA(lo_cols) = lo_alv->get_columns( ).
        lo_cols->get_column( 'LIGHT' )->set_short_text( 'TT' ).
        lo_cols->get_column( 'LIGHT' )->set_medium_text( 'Trạng thái' ).
        lo_cols->get_column( 'TABNAME' )->set_medium_text( 'Bảng cấu hình' ).
        lo_cols->get_column( 'TABNAME' )->set_long_text( 'Bảng cấu hình' ).
        lo_cols->get_column( 'KEYINFO' )->set_medium_text( 'Khoá dòng' ).
        lo_cols->get_column( 'KEYINFO' )->set_long_text( 'Khoá dòng' ).
        lo_cols->get_column( 'ACTION' )->set_medium_text( 'Xử lý' ).
        lo_cols->get_column( 'ACTION' )->set_long_text( 'Xử lý' ).
        lo_cols->get_column( 'INFO' )->set_medium_text( 'Thông tin' ).
        lo_cols->get_column( 'INFO' )->set_long_text( 'Thông tin' ).
        DATA lv_title TYPE lvc_title.
        lv_title = COND #( WHEN p_test = abap_true
                           THEN 'MÔ PHỎNG - chưa ghi vào bảng'
                           ELSE 'Đã nạp cấu hình HĐĐT' ).
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

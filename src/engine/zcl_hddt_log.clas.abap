*=====================================================================
* Tên/Mã     : ZCL_HDDT_LOG
* Mô tả chung: Ghi log lời gọi API (ZTB_HDDT_LOG) và cập nhật sổ đăng
*              ký hoá đơn (ZTB_HDDT_INV + ZTB_HDDT_ITEM).
*
*              [Vì sao lưu payload dạng XSTRING chứ không phải STRING]
*              Log HĐĐT là bằng chứng đối chiếu với cơ quan thuế và với
*              nhà cung cấp khi có tranh chấp. XSTRING lưu ĐÚNG TỪNG
*              BYTE đã đi trên đường truyền — kể cả cách encode UTF-8
*              của tiếng Việt — nên không có một lượt chuyển codepage
*              nào chen vào giữa "cái đã gửi" và "cái đã lưu".
*              Trường CODEPAGE ghi lại bảng mã đã dùng để giải mã lại
*              đúng khi xem log.
*              (Ghi chú: field kiểu STRING trong bảng DDIC KHÔNG bị
*              giới hạn độ dài — nó là LOB. Việc đổi sang xstring ở đây
*              là vì tính toàn vẹn byte, không phải vì giới hạn độ dài.)
*
*              [Che secret — BẮT BUỘC]
*              Payload của một số nhà cung cấp chứa tài khoản NGAY
*              TRONG BODY: FPT có nút "user":{"username","password"},
*              VNPT có "acpass". Nếu ghi nguyên văn thì mật khẩu API
*              nằm plaintext trong bảng log, ai đọc được bảng là đọc
*              được mật khẩu. Lớp này che TRƯỚC khi ghi, cả body lẫn
*              header Authorization. Danh sách thẻ cần che khai được
*              trong ZTB_HDDT_PARM key LOG_MASK_TAGS.
* Tham Số    : LOG_CALL / SAVE_INVOICE / SAVE_ITEMS / READ_PAYLOAD
* Kiểu       : TY_PAYLOAD - nội dung log đã giải mã lại thành text,
*              dùng cho màn hình xem log.
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       28/08/2026    cuongus - CuongUS        abapGit     20260828_01 Lưu
*                                                             payload dạng
*                                                             xstring, che
*                                                             secret, bổ sung
*                                                             field truy vết
* 1.2       22/09/2026    cuongus - CuongUS        abapGit     Bộ helper khoá
*                                                             sổ đăng ký
*                                                             (LOCK_INVOICE(S) /
*                                                             KEY_OF); khoá
*                                                             trong SAVE_EDIT
*                                                             và MARK_ORIGINAL
*                                                             (hoá đơn GỐC)
* 1.3       22/09/2026    cuongus - CuongUS        abapGit     SET_ADMIN điền
*                                                             CREATED_BY/AT +
*                                                             CHANGED_BY/AT cho
*                                                             mọi bảng; SAVE_ITEMS
*                                                             dùng nó
* 1.4       28/09/2026    F-DUBV                   S25K900131  20260928_30 R06:
*                                                             them
*                                                             SET_GOM_NO_MULTI,
*                                                             SAVE_EDIT_MULTI,
*                                                             RETIRE_INVOICE_MULTI
*                                                             (1 lan doc FAE +
*                                                             1 MODIFY FROM TABLE
*                                                             thay cho doc/ghi
*                                                             tung dong trong
*                                                             vong lap)
*=====================================================================
CLASS zcl_hddt_log DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_parm_mask_tags TYPE zde_hddt_parmkey
                                VALUE 'LOG_MASK_TAGS' ##NO_TEXT.
    CONSTANTS gc_codepage       TYPE zde_hddt_codepage
                                VALUE 'UTF-8' ##NO_TEXT.
    CONSTANTS gc_mask           TYPE string
                                VALUE '********' ##NO_TEXT.

    TYPES: BEGIN OF ty_inv_key,
             bukrs     TYPE bukrs,
             gjahr     TYPE gjahr,
             src_type  TYPE zde_hddt_srctype,
             src_docno TYPE zde_hddt_docno,
           END OF ty_inv_key.
    TYPES ty_t_inv_key TYPE STANDARD TABLE OF ty_inv_key WITH DEFAULT KEY.

    "! Khoá một dòng sổ đăng ký hoá đơn; TY_INV_KEY chính là đối số của
    "! lock object EZTB_HDDT_INV (BUKRS/GJAHR/SRC_TYPE/SRC_DOCNO).
    "! Trả về false khi người khác đang giữ; tên người giữ nằm ở
    "! SY-MSGV1 do ENQUEUE đặt.
    "! Lớp này là nơi duy nhất ghi ZTB_HDDT_INV nên lời gọi
    "! ENQUEUE_EZTB_HDDT_INV cũng chỉ nằm ở ĐÂY, không rải mỗi nơi một bản.
    CLASS-METHODS lock_invoice
      IMPORTING is_key      TYPE ty_inv_key
      RETURNING VALUE(r_ok) TYPE abap_bool .

    CLASS-METHODS unlock_invoice
      IMPORTING is_key TYPE ty_inv_key .

    "! Khoá cả danh sách. Hụt một dòng thì NHẢ LẠI toàn bộ dòng đã lấy
    "! rồi báo false — không để nửa vời, vì khoá còn treo sẽ chặn người
    "! khác cho tới hết transaction.
    CLASS-METHODS lock_invoices
      IMPORTING it_keys   TYPE ty_t_inv_key
      EXPORTING e_ok      TYPE abap_bool
                es_failed TYPE ty_inv_key
                e_user    TYPE syuname .

    CLASS-METHODS unlock_invoices
      IMPORTING it_keys TYPE ty_t_inv_key .

    "! Rút khoá sổ đăng ký ra từ một request.
    CLASS-METHODS key_of
      IMPORTING is_request    TYPE zif_hddt_types=>ty_request
      RETURNING VALUE(rs_key) TYPE ty_inv_key .

    "! Điền 4 trường vết CREATED_BY / CREATED_AT / CHANGED_BY /
    "! CHANGED_AT cho MỘT dòng bảng bất kỳ của package. Dùng ASSIGN
    "! COMPONENT nên nhận mọi kiểu dòng, bảng nào không có các trường
    "! này thì lặng lẽ bỏ qua — khỏi phải viết lại ở 11 chỗ.
    "! Timestamp là TIMESTAMPL giờ UTC (GET TIME STAMP), không phải
    "! SY-DATUM/SY-UZEIT giờ máy chủ.
    "! CỐ Ý giữ UTC, ĐừNG đổi sang giờ VN ở đây: cùng bốn cột này còn
    "! được routine event 01 của SM30 ghi, lệch quy ước giữa hai nơi là
    "! hỏng dữ liệu. Đổi múi giờ ở chỗ HIỂN THỊ (xem ZPG_HDDT_LOG:
    "! CONVERT TIME STAMP ... TIME ZONE sy-zonlo).
    "! @parameter i_new | X = dòng mới (điền CREATED_*), ' ' = sửa dòng
    "!                    cũ (chỉ điền CHANGED_*)
    "! generic OK: CS_ROW phải TYPE any vì 11 bảng có kiểu dòng khác
    "! nhau, thân method dò trường bằng ASSIGN COMPONENT.
    CLASS-METHODS set_admin
      IMPORTING i_new  TYPE abap_bool DEFAULT abap_true
      CHANGING  cs_row TYPE any .

    TYPES: BEGIN OF ty_call_info,
             connid      TYPE zde_hddt_connid,
             method      TYPE zde_hddt_method,
             full_url    TYPE zde_hddt_url,
             cont_type   TYPE zde_hddt_parmval,
             http_code   TYPE i,
             reason      TYPE string,
             duration_ms TYPE i,
             attempt     TYPE zde_hddt_attempt,
             test_run    TYPE abap_bool,
             req_body    TYPE string,
             res_body    TYPE string,
             req_header  TYPE string,
             res_header  TYPE string,
           END OF ty_call_info.

    TYPES: BEGIN OF ty_payload,
             log_id     TYPE zde_hddt_logid,
             codepage   TYPE zde_hddt_codepage,
             req_header TYPE string,
             res_header TYPE string,
             req_body   TYPE string,
             res_body   TYPE string,
           END OF ty_payload.

    "! Ghi 1 dòng log; trả về LOG_ID để gắn vào kết quả.
    METHODS log_call
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                i_action        TYPE zde_hddt_action
                i_provider      TYPE zde_hddt_prov
                is_call          TYPE ty_call_info
                is_result        TYPE zif_hddt_types=>ty_result OPTIONAL
      RETURNING VALUE(r_log_id) TYPE zde_hddt_logid .

    "! Đọc lại payload của một dòng log và giải mã về text.
    CLASS-METHODS read_payload
      IMPORTING i_log_id         TYPE zde_hddt_logid
      RETURNING VALUE(rs_payload) TYPE ty_payload .

    METHODS save_invoice
      IMPORTING is_request  TYPE zif_hddt_types=>ty_request
                is_result   TYPE zif_hddt_types=>ty_result
                i_provider TYPE zde_hddt_prov .

    METHODS save_items
      IMPORTING is_request TYPE zif_hddt_types=>ty_request .

    "! Đọc sổ đăng ký của 1 chứng từ (dùng cho điều chỉnh/thay thế).
    "! Đánh dấu hoá đơn GỐC đã bị điều chỉnh / thay thế sau khi HĐ điều
    "! chỉnh phát hành thành công (dự án tham chiếu ghi XREF2_HD 06/07).
    "! @parameter e_ok | ' ' = không khoá được hoá đơn gốc nên KHÔNG đổi
    "!                    trạng thái. Chỗ gọi phải báo lên cho người dùng,
    "!                    đừng bỏ qua: hoá đơn gốc sẽ thiếu dấu đã bị
    "!                    điều chỉnh / thay thế.
    METHODS mark_original
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_status  TYPE zde_hddt_status
      EXPORTING e_ok       TYPE abap_bool .

    "! FS MAG: đánh dấu chứng từ thành viên thuộc hoá đơn gom (trống = gỡ)
    METHODS set_gom_no
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_gom_no   TYPE zde_hddt_docno .

    "! FS MAG: người dùng sửa ngày/giờ phát hành, tên hàng trước khi gửi
    METHODS save_edit
      IMPORTING is_request  TYPE zif_hddt_types=>ty_request
                i_inv_date  TYPE dats
                i_inv_time  TYPE uzeit
                i_item_text TYPE string
      RAISING   zcx_hddt_error .

    "! FS MAG 3.6.4: gắn (hoặc gỡ khi docno trống) hoá đơn gốc cho chứng từ
    METHODS attach_original
      IMPORTING is_request    TYPE zif_hddt_types=>ty_request
                i_org_docno   TYPE zde_hddt_docno
                i_org_gjahr   TYPE gjahr
                i_org_srctype TYPE zde_hddt_srctype
                i_adj_type    TYPE zde_hddt_adjtype
                i_adj_dir     TYPE zde_hddt_adjdir .

    METHODS set_mail_status
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_status   TYPE zde_hddt_mailst .

    "! Ghi thẳng trạng thái và thông báo cho một chứng từ, không gọi API.
    "! Dùng khi nghiệp vụ dừng giữa chừng ở phía SAP - ví dụ FS v0.17 mục
    "! 3.6.5: huỷ chứng từ gốc bằng FB08/MR8M lỗi nên không phát hành hoá
    "! đơn thay thế, bản ghi phải chuyển sang Lỗi tích hợp để người dùng
    "! thấy và xử lý lại.
    METHODS set_status
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_status   TYPE zde_hddt_status
                i_message  TYPE clike OPTIONAL .

    "! Xoá thông tin hoá đơn (mẫu, ký hiệu, số, mã tra cứu, link) nhưng
    "! đặt trạng thái cho trước - khác RESET_REGISTRY luôn về 'chưa tích
    "! hợp'. FS v0.17 mục 3.6.5: thay thế hoá đơn gom thì các chứng từ
    "! thành phần chuyển 08 và bị xoá thông tin hoá đơn.
    METHODS retire_invoice
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_status   TYPE zde_hddt_status
                i_message  TYPE clike OPTIONAL .

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    "! Ban nhieu dong cua SET_GOM_NO: doc so dang ky cua ca danh sach 1
    "! lan (FOR ALL ENTRIES), tao dong toi thieu cho chung tu chua co dong
    "! so (nhu ENSURE_ROW), ghi 1 lan MODIFY FROM TABLE. KHONG khoa - cung
    "! quy uoc voi SET_GOM_NO: ZCL_HDDT_GOM->CREATE / ->CANCEL da khoa so
    "! dang ky cua toan bo thanh vien truoc khi goi.
    METHODS set_gom_no_multi
      IMPORTING it_requests TYPE zif_hddt_types=>ty_t_request
                i_gom_no    TYPE zde_hddt_docno .

    "! Ban nhieu dong cua SAVE_EDIT (nut Sua ngay/gio/ten hang). Khoa tung
    "! chung tu nhu SAVE_EDIT; chung tu dang bi nguoi khac giu thi bo qua
    "! dung dong do va noi message (cung van ban cu, ngan cach ' / ') vao
    "! E_ERROR; cac dong con lai: 1 lan doc FAE, 1 MODIFY FROM TABLE, roi
    "! nha khoa - nha TRUOC COMMIT cua cho goi, giong SAVE_EDIT hien tai.
    "! @parameter e_count | so dong da ghi (= so lan SAVE_EDIT thanh cong)
    "! @parameter e_error | message cac dong khong khoa duoc
    METHODS save_edit_multi
      IMPORTING it_requests TYPE zif_hddt_types=>ty_t_request
                i_inv_date  TYPE dats
                i_inv_time  TYPE uzeit
                i_item_text TYPE string
      EXPORTING e_count     TYPE i
                e_error     TYPE string .

    "! Ban nhieu dong cua RETIRE_INVOICE (thanh vien hoa don gom bi thay
    "! the). KHONG khoa - giong RETIRE_INVOICE (cho goi duy nhat
    "! ZCL_HDDT_SERVICE->MARK_GOM_REPLACED khong khoa thanh vien).
    METHODS retire_invoice_multi
      IMPORTING it_keys    TYPE ty_t_inv_key
                i_status   TYPE zde_hddt_status
                i_message  TYPE clike OPTIONAL .
*   <<< End of change 20260928_30

    "! Đưa chứng từ về 'chưa tích hợp' (huỷ nháp thành công / NCC không
    "! còn hoá đơn): xoá số, ký hiệu, link, trạng thái NCC.
    METHODS reset_registry
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_message  TYPE string OPTIONAL .

    CLASS-METHODS read_invoice
      IMPORTING i_bukrs      TYPE bukrs
                i_gjahr      TYPE gjahr
                i_src_type   TYPE zde_hddt_srctype OPTIONAL
                i_src_docno  TYPE zde_hddt_docno
      RETURNING VALUE(rs_inv) TYPE ztb_hddt_inv .

    "! Đếm số lần đã gọi cho cùng chứng từ + nghiệp vụ, để điền ATTEMPT.
    CLASS-METHODS count_attempts
      IMPORTING is_request      TYPE zif_hddt_types=>ty_request
                i_action       TYPE zde_hddt_action
      RETURNING VALUE(r_count) TYPE zde_hddt_attempt .

    "! Che secret trong text. Public để màn hình xem log dùng lại được
    "! khi hiển thị dữ liệu từ nguồn khác (ví dụ payload test run).
    CLASS-METHODS mask_secrets
      IMPORTING i_text        TYPE string
      RETURNING VALUE(r_text) TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    TYPES ty_t_inv_hash TYPE HASHED TABLE OF ztb_hddt_inv
                        WITH UNIQUE KEY bukrs gjahr src_type src_docno.
*   <<< End of change 20260928_30

    "! Thẻ mặc định cần che nếu chưa khai LOG_MASK_TAGS.
    "! Gồm cả tên thẻ của FPT (password), VNPT (acpass) và chuẩn OAuth.
    CONSTANTS gc_default_tags TYPE string
      VALUE 'password,acpass,pass,secret,client_secret,token,access_token,authorization,apikey,api_key' ##NO_TEXT.

    METHODS new_guid
      RETURNING VALUE(r_guid) TYPE zde_hddt_logid .

    METHODS to_raw
      IMPORTING i_text        TYPE string
      RETURNING VALUE(r_data) TYPE xstring .

    "! Đọc dòng sổ, tạo dòng tối thiểu nếu chưa có
    METHODS ensure_row
      IMPORTING is_request    TYPE zif_hddt_types=>ty_request
      RETURNING VALUE(rs_inv) TYPE ztb_hddt_inv .

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    "! Dong so toi thieu cho chung tu chua co dong (phan sau SELECT cua
    "! ENSURE_ROW, tach ra de cac ban *_MULTI dung chung, khong doc DB).
    METHODS init_row
      IMPORTING is_request    TYPE zif_hddt_types=>ty_request
      RETURNING VALUE(rs_inv) TYPE ztb_hddt_inv .

    "! Doc so dang ky cua ca danh sach khoa trong 1 lan FOR ALL ENTRIES.
    "! Chi goi NGOAI vong lap.
    METHODS read_rows
      IMPORTING it_keys       TYPE ty_t_inv_key
      RETURNING VALUE(rt_inv) TYPE ty_t_inv_hash .
*   <<< End of change 20260928_30

    METHODS object_type_of
      IMPORTING i_action      TYPE zde_hddt_action
                is_request    TYPE zif_hddt_types=>ty_request
      RETURNING VALUE(r_type) TYPE zde_hddt_objtype .

    METHODS call_sink
      IMPORTING is_log     TYPE ztb_hddt_log
                is_request TYPE zif_hddt_types=>ty_request
                is_result  TYPE zif_hddt_types=>ty_result .

    METHODS keep_payload
      IMPORTING i_provider    TYPE zde_hddt_prov
                i_bukrs       TYPE bukrs
      RETURNING VALUE(r_keep) TYPE abap_bool .

ENDCLASS.



CLASS ZCL_HDDT_LOG IMPLEMENTATION.


  METHOD attach_original.

    DATA(ls_inv) = ensure_row( is_request ).
    ls_inv-ref_docno   = i_org_docno.
    ls_inv-ref_gjahr   = COND #( WHEN i_org_docno IS INITIAL THEN space ELSE i_org_gjahr ).
    ls_inv-ref_srctype = COND #( WHEN i_org_docno IS INITIAL THEN space ELSE i_org_srctype ).
    ls_inv-adj_type    = COND #( WHEN i_org_docno IS INITIAL THEN space ELSE i_adj_type ).
    ls_inv-adj_dir     = COND #( WHEN i_org_docno IS INITIAL THEN space ELSE i_adj_dir ).
    ls_inv-changed_by  = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.
    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD call_sink.

    " Lớp sink của khách hàng (vd ánh xạ sang ZTB_INT_LOG của MAG).
    " Lỗi ở sink không được làm hỏng nghiệp vụ -> bắt hết.
    DATA(lv_class) = zcl_hddt_config=>get_instance( )->get_param(
                       i_key = zif_hddt_types=>gc_parm-log_sink_class
                       i_bukrs = is_request-bukrs ).
    CONDENSE lv_class.
    IF lv_class IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        DATA(lo_sink) = CAST zif_hddt_log_sink(
                          zcl_hddt_factory=>create_object( CONV #( lv_class ) ) ).
        lo_sink->write( is_log = is_log is_request = is_request is_result = is_result ).
      CATCH cx_root.
        " bỏ qua có chủ ý
    ENDTRY.

  ENDMETHOD.


  METHOD count_attempts.

    SELECT COUNT( * )
      FROM ztb_hddt_log
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @is_request-gjahr
        AND src_type  = @is_request-src_type
        AND src_docno = @is_request-src_docno
        AND action    = @i_action
        AND test_run  = @space
      INTO @DATA(lv_count).

    r_count = lv_count + 1.

  ENDMETHOD.


  METHOD ensure_row.

    SELECT SINGLE * FROM ztb_hddt_inv
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @is_request-gjahr
        AND src_type  = @is_request-src_type
        AND src_docno = @is_request-src_docno
      INTO @rs_inv.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    " Phan tao dong toi thieu chuyen sang INIT_ROW (dung chung voi *_MULTI)
*    CLEAR rs_inv.
*    rs_inv-bukrs      = is_request-bukrs.
*    rs_inv-gjahr      = is_request-gjahr.
*    rs_inv-src_type   = is_request-src_type.
*    rs_inv-src_docno  = is_request-src_docno.
*    rs_inv-status     = zif_hddt_types=>gc_status-not_sent.
*    rs_inv-buyer_code = is_request-invoice-buyer-code.
*    rs_inv-buyer_name = is_request-invoice-buyer-legal_name.
*    rs_inv-waers      = is_request-invoice-header-currency.
*    rs_inv-inv_date   = is_request-invoice-header-inv_date.
*    rs_inv-inv_time   = is_request-invoice-header-inv_time.
*    rs_inv-created_by = sy-uname.
*    GET TIME STAMP FIELD rs_inv-created_at.
    rs_inv = init_row( is_request ).
*   <<< End of change 20260928_30

  ENDMETHOD.


  METHOD init_row.

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    CLEAR rs_inv.
    rs_inv-bukrs      = is_request-bukrs.
    rs_inv-gjahr      = is_request-gjahr.
    rs_inv-src_type   = is_request-src_type.
    rs_inv-src_docno  = is_request-src_docno.
    rs_inv-status     = zif_hddt_types=>gc_status-not_sent.
    rs_inv-buyer_code = is_request-invoice-buyer-code.
    rs_inv-buyer_name = is_request-invoice-buyer-legal_name.
    rs_inv-waers      = is_request-invoice-header-currency.
    rs_inv-inv_date   = is_request-invoice-header-inv_date.
    rs_inv-inv_time   = is_request-invoice-header-inv_time.
    rs_inv-created_by = sy-uname.
    GET TIME STAMP FIELD rs_inv-created_at.
*   <<< End of change 20260928_30

  ENDMETHOD.


  METHOD keep_payload.

    DATA(lo_config) = zcl_hddt_config=>get_instance( ).

    " Mặc định LUÔN lưu payload — đây là nghĩa vụ đối chiếu thuế.
    " Chỉ tắt khi tham số LOG_PAYLOAD được khai tường minh là false.
    r_keep = abap_true.

    IF lo_config->get_param( i_key      = zif_hddt_types=>gc_parm-log_payload
                             i_provider = i_provider
                             i_bukrs    = i_bukrs ) IS NOT INITIAL.
      r_keep = lo_config->get_param_bool(
                  i_key      = zif_hddt_types=>gc_parm-log_payload
                  i_provider = i_provider
                  i_bukrs    = i_bukrs ).
    ENDIF.

  ENDMETHOD.


  METHOD key_of.

    rs_key = VALUE #( bukrs     = is_request-bukrs
                      gjahr     = is_request-gjahr
                      src_type  = is_request-src_type
                      src_docno = is_request-src_docno ).

  ENDMETHOD.


  METHOD lock_invoice.

    CALL FUNCTION 'ENQUEUE_EZTB_HDDT_INV'
      EXPORTING
        mode_ztb_hddt_inv = 'E'
        mandt             = sy-mandt
        bukrs             = is_key-bukrs
        gjahr             = is_key-gjahr
        src_type          = is_key-src_type
        src_docno         = is_key-src_docno
        _scope            = '1'
      EXCEPTIONS
        foreign_lock      = 1
        system_failure    = 2
        OTHERS            = 3.
    r_ok = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD lock_invoices.

    DATA lt_done TYPE ty_t_inv_key.

    CLEAR: e_ok, es_failed, e_user.

    LOOP AT it_keys INTO DATA(ls_key).
      IF ls_key-src_docno IS INITIAL.
        CONTINUE.
      ENDIF.
      IF lock_invoice( ls_key ) = abap_false.
        es_failed = ls_key.
        e_user    = sy-msgv1.
        " Nhả lại đúng những dòng vừa lấy. Không dùng DEQUEUE_ALL vì nó
        " nhả cả khoá mà chỗ gọi đang giữ cho việc khác.
        unlock_invoices( lt_done ).
        RETURN.
      ENDIF.
      APPEND ls_key TO lt_done.
    ENDLOOP.

    e_ok = abap_true.

  ENDMETHOD.


  METHOD log_call.

    DATA ls_log TYPE ztb_hddt_log.

    r_log_id = new_guid( ).

    ls_log-log_id      = r_log_id.
    ls_log-provider    = i_provider.
    ls_log-connid      = is_call-connid.
    ls_log-action      = i_action.
    ls_log-bukrs       = is_request-bukrs.
    ls_log-gjahr       = is_request-gjahr.
    ls_log-src_type    = is_request-src_type.
    ls_log-src_docno   = is_request-src_docno.
    ls_log-idkey       = is_request-invoice-header-idkey.
    ls_log-test_run    = is_call-test_run.
    ls_log-attempt     = is_call-attempt.

    ls_log-serial      = is_result-serial.
    ls_log-seq         = is_result-seq.
    ls_log-sap_status  = is_result-status.
    ls_log-prov_status = is_result-prov_status.
    ls_log-msgty       = is_result-msgty.
    ls_log-message     = is_result-message.

    ls_log-http_method = is_call-method.
    ls_log-full_url    = is_call-full_url.
    ls_log-cont_type   = is_call-cont_type.
    ls_log-http_code   = is_call-http_code.
    ls_log-http_reason = is_call-reason.
    ls_log-duration_ms = is_call-duration_ms.

    " Kích thước tính theo SỐ BYTE thật đã ghi, không phải số ký tự
    ls_log-codepage    = gc_codepage.

    " Truy vết nguồn gọi: giúp phân biệt phát hành từ màn hình, từ job
    " nền hay từ enhancement khi cùng một chứng từ có nhiều dòng log.
    ls_log-caller      = sy-cprog.
    ls_log-tcode       = sy-tcode.
    ls_log-created_by  = sy-uname.
    GET TIME STAMP FIELD ls_log-created_at.

    " FS MAG: các trường khớp bảng log dùng chung ZTB_INT_LOG
    ls_log-direction   = 'O'.
    ls_log-object_type = object_type_of( i_action = i_action is_request = is_request ).
    ls_log-api_version = zcl_hddt_config=>get_instance( )->get_param(
                           i_key = zif_hddt_types=>gc_parm-api_version
                           i_provider = i_provider i_bukrs = is_request-bukrs ).
    ls_log-success     = is_result-success.
    IF is_result-success = abap_false.
      ls_log-error_code = is_result-prov_status.
    ENDIF.
    ls_log-hostname    = sy-host.
    ls_log-has_req     = xsdbool( is_call-req_body IS NOT INITIAL ).
    ls_log-has_res     = xsdbool( is_call-res_body IS NOT INITIAL ).

    IF keep_payload( i_provider = i_provider
                     i_bukrs    = is_request-bukrs ) = abap_true.

      " Che secret TRƯỚC khi ghi. Payload FPT/VNPT chứa mật khẩu ngay
      " trong body; header có Authorization.
      DATA(lv_req) = mask_secrets( is_call-req_body ).
      DATA(lv_res) = mask_secrets( is_call-res_body ).

      ls_log-req_header = to_raw( mask_secrets( is_call-req_header ) ).
      ls_log-res_header = to_raw( mask_secrets( is_call-res_header ) ).
      ls_log-req_body   = to_raw( lv_req ).
      ls_log-res_body   = to_raw( lv_res ).
      ls_log-req_size   = xstrlen( ls_log-req_body ).
      ls_log-res_size   = xstrlen( ls_log-res_body ).
      ls_log-masked     = xsdbool( lv_req <> is_call-req_body
                                OR lv_res <> is_call-res_body ).
    ELSE.
      " Không lưu nội dung nhưng VẪN ghi kích thước để biết đã gửi gì
      ls_log-req_size = strlen( is_call-req_body ).
      ls_log-res_size = strlen( is_call-res_body ).
    ENDIF.

    INSERT ztb_hddt_log FROM ls_log.
    IF sy-subrc <> 0.
      " Không được để lỗi ghi log làm hỏng nghiệp vụ phát hành
      CLEAR r_log_id.
      RETURN.
    ENDIF.

    call_sink( is_log = ls_log is_request = is_request is_result = is_result ).

  ENDMETHOD.


  METHOD mark_original.

    CLEAR e_ok.

    DATA(ls_adj) = is_request-invoice-adjust.
    IF ls_adj-org_docno IS INITIAL.
      e_ok = abap_true.            " không có hoá đơn gốc -> không có gì phải đánh dấu
      RETURN.
    ENDIF.

    DATA(lv_gjahr) = COND gjahr( WHEN ls_adj-org_gjahr IS NOT INITIAL
                                 THEN ls_adj-org_gjahr ELSE is_request-gjahr ).
    DATA(lv_type)  = COND zde_hddt_srctype( WHEN ls_adj-org_src_type IS NOT INITIAL
                                              THEN ls_adj-org_src_type ELSE is_request-src_type ).
    DATA lv_ts  TYPE timestampl.
    DATA lv_msg TYPE zde_hddt_msg.
    GET TIME STAMP FIELD lv_ts.
    lv_msg = |Đã { COND string( WHEN i_status = zif_hddt_types=>gc_status-replaced
                                THEN 'thay thế' ELSE 'điều chỉnh' ) }| &&
             | bởi chứng từ { is_request-src_docno }/{ is_request-gjahr }|.

    " Dòng bị ghi ở đây là hoá đơn GỐC — khoá khác với khoá chứng từ
    " điều chỉnh mà ZCL_HDDT_SERVICE->EXECUTE đang giữ, nên phải khoá
    " riêng. Khoá hụt thì KHÔNG ghi: đổi trạng thái hoá đơn gốc trong
    " lúc người khác đang xử lý chính nó là ghi đè mù.
    DATA(ls_org_key) = VALUE ty_inv_key( bukrs     = is_request-bukrs
                                         gjahr     = lv_gjahr
                                         src_type  = lv_type
                                         src_docno = ls_adj-org_docno ).
    IF lock_invoice( ls_org_key ) = abap_false.
      RETURN.
    ENDIF.

    UPDATE ztb_hddt_inv
      SET status     = @i_status,
          message    = @lv_msg,
          changed_by = @sy-uname,
          changed_at = @lv_ts
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @lv_gjahr
        AND src_type  = @lv_type
        AND src_docno = @ls_adj-org_docno.

    unlock_invoice( ls_org_key ).
    e_ok = abap_true.

  ENDMETHOD.


  METHOD mask_secrets.

    r_text = i_text.
    IF r_text IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_tags) = |{ zcl_hddt_config=>get_instance( )->get_param( gc_parm_mask_tags ) }|.
    CONDENSE lv_tags NO-GAPS.
    IF lv_tags IS INITIAL.
      lv_tags = gc_default_tags.
    ENDIF.

    SPLIT lv_tags AT ',' INTO TABLE DATA(lt_tags).

    LOOP AT lt_tags INTO DATA(lv_tag).
      CONDENSE lv_tag NO-GAPS.
      IF lv_tag IS INITIAL.
        CONTINUE.
      ENDIF.

      " (1) JSON:  "password" : "gia tri"   ->  "password":"********"
      REPLACE ALL OCCURRENCES OF PCRE
              |"{ lv_tag }"\\s*:\\s*"[^"]*"|
              IN r_text WITH |"{ lv_tag }":"{ gc_mask }"| IGNORING CASE.

      " (2) JSON số / không ngoặc kép: "token": abc123
      REPLACE ALL OCCURRENCES OF PCRE
              |"{ lv_tag }"\\s*:\\s*[^",\{\}\\[\\]]+|
              IN r_text WITH |"{ lv_tag }":"{ gc_mask }"| IGNORING CASE.

      " (3) form-urlencoded:  password=abc&  ->  password=********&
      REPLACE ALL OCCURRENCES OF PCRE
              |(^\|&){ lv_tag }=[^&]*|
              IN r_text WITH |$1{ lv_tag }={ gc_mask }| IGNORING CASE.

      " (4) HTTP header:  Authorization: Basic xxx  ->  Authorization: ********
      REPLACE ALL OCCURRENCES OF PCRE
              |(^\|\\n){ lv_tag }\\s*:\\s*[^\\n]*|
              IN r_text WITH |$1{ lv_tag }: { gc_mask }| IGNORING CASE.
    ENDLOOP.

  ENDMETHOD.


  METHOD new_guid.

    TRY.
        r_guid = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        " Rất khó xảy ra; dự phòng bằng timestamp + user
        DATA lv_ts TYPE timestampl.
        GET TIME STAMP FIELD lv_ts.
        r_guid = |{ lv_ts }{ sy-uname }|.
        TRANSLATE r_guid TO UPPER CASE.
    ENDTRY.

  ENDMETHOD.


  METHOD object_type_of.

    CASE i_action.
      WHEN zif_hddt_types=>gc_action-create_draft
        OR zif_hddt_types=>gc_action-preview_draft
        OR zif_hddt_types=>gc_action-delete_invoice.
        r_type = 'DRAFT'.
      WHEN zif_hddt_types=>gc_action-adjust_invoice.
        r_type = 'ADJUST'.
      WHEN zif_hddt_types=>gc_action-replace_invoice.
        r_type = 'REPLACE'.
      WHEN zif_hddt_types=>gc_action-search_invoice
        OR zif_hddt_types=>gc_action-get_file.
        r_type = 'SEARCH'.
      WHEN zif_hddt_types=>gc_action-cancel_invoice
        OR zif_hddt_types=>gc_action-wrong_notice.
        r_type = 'CANCEL'.
      WHEN OTHERS.
        r_type = 'INVOICE'.
    ENDCASE.
    IF is_request-src_type = 'GOM'.
      r_type = |{ r_type }_GOM|.
    ENDIF.

  ENDMETHOD.


  METHOD read_invoice.

    IF i_src_type IS NOT INITIAL.
      SELECT SINGLE * FROM ztb_hddt_inv
        WHERE bukrs     = @i_bukrs
          AND gjahr     = @i_gjahr
          AND src_type  = @i_src_type
          AND src_docno = @i_src_docno
        INTO @rs_inv.
    ELSE.
      SELECT SINGLE * FROM ztb_hddt_inv
        WHERE bukrs     = @i_bukrs
          AND gjahr     = @i_gjahr
          AND src_docno = @i_src_docno
        INTO @rs_inv.
    ENDIF.

    IF sy-subrc <> 0.
      CLEAR rs_inv.
    ENDIF.

  ENDMETHOD.


  METHOD read_payload.

    SELECT SINGLE log_id, codepage, req_header, res_header, req_body, res_body
      FROM ztb_hddt_log
      WHERE log_id = @i_log_id
      INTO @DATA(ls_db).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lo_plat) = zcl_hddt_platform=>get( ).
    DATA(lv_cp)   = |{ ls_db-codepage }|.
    CONDENSE lv_cp.
    IF lv_cp IS INITIAL.
      lv_cp = |{ gc_codepage }|.
    ENDIF.

    rs_payload-log_id     = ls_db-log_id.
    rs_payload-codepage   = ls_db-codepage.
    rs_payload-req_header = lo_plat->xstring_to_string( i_data     = ls_db-req_header
                                                        i_encoding = lv_cp ).
    rs_payload-res_header = lo_plat->xstring_to_string( i_data     = ls_db-res_header
                                                        i_encoding = lv_cp ).
    rs_payload-req_body   = lo_plat->xstring_to_string( i_data     = ls_db-req_body
                                                        i_encoding = lv_cp ).
    rs_payload-res_body   = lo_plat->xstring_to_string( i_data     = ls_db-res_body
                                                        i_encoding = lv_cp ).

  ENDMETHOD.


  METHOD read_rows.

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    " Doc dung khoa day du nhu SELECT SINGLE cua ENSURE_ROW (ke ca
    " SRC_TYPE rong -> so sanh bang space, giong ENSURE_ROW)
    DATA lt_key TYPE ty_t_inv_key.
    lt_key = it_keys.
    SORT lt_key BY bukrs gjahr src_type src_docno.
    DELETE ADJACENT DUPLICATES FROM lt_key COMPARING bukrs gjahr src_type src_docno.
    IF lt_key IS INITIAL.
      RETURN.
    ENDIF.
    SELECT * FROM ztb_hddt_inv
      FOR ALL ENTRIES IN @lt_key
      WHERE bukrs     = @lt_key-bukrs
        AND gjahr     = @lt_key-gjahr
        AND src_type  = @lt_key-src_type
        AND src_docno = @lt_key-src_docno
      INTO TABLE @rt_inv.
*   <<< End of change 20260928_30

  ENDMETHOD.


  METHOD reset_registry.

    DATA(ls_inv) = ensure_row( is_request ).
    CLEAR: ls_inv-template, ls_inv-serial, ls_inv-seq, ls_inv-issue_date,
           ls_inv-cancel_date, ls_inv-mscqt, ls_inv-sec_code, ls_inv-inv_link,
           ls_inv-prov_status, ls_inv-tax_status, ls_inv-mail_status, ls_inv-mail_date.
    ls_inv-status     = zif_hddt_types=>gc_status-not_sent.
    ls_inv-message    = i_message.
    ls_inv-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.
    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD retire_invoice.

    DATA(ls_inv) = ensure_row( is_request ).
    CLEAR: ls_inv-template, ls_inv-serial, ls_inv-seq, ls_inv-mscqt,
           ls_inv-sec_code, ls_inv-inv_link.
    ls_inv-status = i_status.
    IF i_message IS SUPPLIED AND i_message IS NOT INITIAL.
      ls_inv-message = i_message.
    ENDIF.
    set_admin( EXPORTING i_new  = abap_false
               CHANGING  cs_row = ls_inv ).
    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD retire_invoice_multi.

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    " Cung ket qua voi goi RETIRE_INVOICE lan luot tung khoa (khong khoa,
    " doc dong so / tao dong toi thieu, xoa thong tin hoa don, doi trang
    " thai). Khoa trung: lan sau thay dong lan truoc vua sua.
    DATA ls_inv TYPE ztb_hddt_inv.

    DATA(lt_inv) = read_rows( it_keys ).

    LOOP AT it_keys ASSIGNING FIELD-SYMBOL(<fs_key>).
      READ TABLE lt_inv INTO ls_inv
           WITH TABLE KEY bukrs     = <fs_key>-bukrs
                          gjahr     = <fs_key>-gjahr
                          src_type  = <fs_key>-src_type
                          src_docno = <fs_key>-src_docno.
      DATA(lv_found) = xsdbool( sy-subrc = 0 ).
      IF lv_found = abap_false.
        ls_inv = init_row( VALUE #( bukrs     = <fs_key>-bukrs
                                    gjahr     = <fs_key>-gjahr
                                    src_type  = <fs_key>-src_type
                                    src_docno = <fs_key>-src_docno ) ).
      ENDIF.
      CLEAR: ls_inv-template, ls_inv-serial, ls_inv-seq, ls_inv-mscqt,
             ls_inv-sec_code, ls_inv-inv_link.
      ls_inv-status = i_status.
      IF i_message IS SUPPLIED AND i_message IS NOT INITIAL.
        ls_inv-message = i_message.
      ENDIF.
      set_admin( EXPORTING i_new  = abap_false
                 CHANGING  cs_row = ls_inv ).
      IF lv_found = abap_true.
        MODIFY TABLE lt_inv FROM ls_inv.
      ELSE.
        INSERT ls_inv INTO TABLE lt_inv.
      ENDIF.
    ENDLOOP.

    " RETIRE_INVOICE cu cung khong kiem SY-SUBRC cua MODIFY (giu nguyen hanh vi)
    IF lt_inv IS NOT INITIAL.
      MODIFY ztb_hddt_inv FROM TABLE @lt_inv.
    ENDIF.
*   <<< End of change 20260928_30

  ENDMETHOD.


  METHOD save_edit.

    " Gọi thẳng từ màn hình (sửa ngày/giờ/tên hàng), không nằm trong khoá
    " của ZCL_HDDT_SERVICE, mà ENSURE_ROW là đọc-rồi-ghi. Không khoá thì
    " sửa ngày của người này ghi đè tên hàng người kia vừa lưu.
    DATA(ls_key) = key_of( is_request ).
    IF lock_invoice( ls_key ) = abap_false.
      zcx_hddt_error=>raise_text(
        |Chứng từ { is_request-src_docno ALPHA = OUT } đang được user | &&
        |{ sy-msgv1 } xử lý, chưa lưu được ngày/giờ/tên hàng.| ).
    ENDIF.

    DATA(ls_inv) = ensure_row( is_request ).
    IF i_inv_date IS NOT INITIAL.
      ls_inv-inv_date = i_inv_date.
    ENDIF.
    IF i_inv_time IS NOT INITIAL.
      ls_inv-inv_time = i_inv_time.
    ENDIF.
    ls_inv-item_text  = i_item_text.
    ls_inv-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.
    MODIFY ztb_hddt_inv FROM ls_inv.

    unlock_invoice( ls_key ).

  ENDMETHOD.


  METHOD save_edit_multi.

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    " Thu tu nhu SAVE_EDIT: KHOA truoc, DOC sau khi khoa, GHI, NHA khoa
    " (nha truoc COMMIT cua cho goi - nhu SAVE_EDIT hien tai). Chi khac:
    " khoa ca danh sach truoc, doc 1 lan, ghi 1 lan roi nha tat ca.
    DATA lt_locked TYPE ty_t_inv_key.
    DATA lt_req    TYPE zif_hddt_types=>ty_t_request.
    DATA ls_inv    TYPE ztb_hddt_inv.
    DATA lv_ts     TYPE timestampl.

    CLEAR: e_count, e_error.

    LOOP AT it_requests ASSIGNING FIELD-SYMBOL(<fs_req>).
      DATA(ls_key) = key_of( <fs_req> ).
      IF lock_invoice( ls_key ) = abap_false.
        " Giu nguyen van ban message cua SAVE_EDIT (qua GET_TEXT_LONG nhu
        " cho goi cu lam), bo qua dung dong nay, cac dong khac van luu
        TRY.
            zcx_hddt_error=>raise_text(
              |Chứng từ { <fs_req>-src_docno ALPHA = OUT } đang được user | &&
              |{ sy-msgv1 } xử lý, chưa lưu được ngày/giờ/tên hàng.| ).
          CATCH zcx_hddt_error INTO DATA(lx_lock).
            e_error = COND #( WHEN e_error IS INITIAL
                              THEN lx_lock->get_text_long( )
                              ELSE |{ e_error } / { lx_lock->get_text_long( ) }| ).
        ENDTRY.
        CONTINUE.
      ENDIF.
      APPEND ls_key   TO lt_locked.
      APPEND <fs_req> TO lt_req.
    ENDLOOP.

    IF lt_req IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_inv) = read_rows( lt_locked ).

    GET TIME STAMP FIELD lv_ts.
    LOOP AT lt_req ASSIGNING <fs_req>.
      READ TABLE lt_inv INTO ls_inv
           WITH TABLE KEY bukrs     = <fs_req>-bukrs
                          gjahr     = <fs_req>-gjahr
                          src_type  = <fs_req>-src_type
                          src_docno = <fs_req>-src_docno.
      DATA(lv_found) = xsdbool( sy-subrc = 0 ).
      IF lv_found = abap_false.
        ls_inv = init_row( <fs_req> ).
      ENDIF.
      IF i_inv_date IS NOT INITIAL.
        ls_inv-inv_date = i_inv_date.
      ENDIF.
      IF i_inv_time IS NOT INITIAL.
        ls_inv-inv_time = i_inv_time.
      ENDIF.
      ls_inv-item_text  = i_item_text.
      ls_inv-changed_by = sy-uname.
      ls_inv-changed_at = lv_ts.
      IF lv_found = abap_true.
        MODIFY TABLE lt_inv FROM ls_inv.
      ELSE.
        INSERT ls_inv INTO TABLE lt_inv.
      ENDIF.
      e_count = e_count + 1.
    ENDLOOP.

    " SAVE_EDIT cu cung khong kiem SY-SUBRC cua MODIFY (giu nguyen hanh vi)
    MODIFY ztb_hddt_inv FROM TABLE @lt_inv.

    " Nha dung tung khoa da lay (UNLOCK_INVOICE nhu SAVE_EDIT, ke ca khoa
    " trung lap - ENQUEUE cong don)
    LOOP AT lt_locked INTO ls_key.
      unlock_invoice( ls_key ).
    ENDLOOP.
*   <<< End of change 20260928_30

  ENDMETHOD.


  METHOD save_invoice.

    DATA ls_inv TYPE ztb_hddt_inv.

    SELECT SINGLE * FROM ztb_hddt_inv
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @is_request-gjahr
        AND src_type  = @is_request-src_type
        AND src_docno = @is_request-src_docno
      INTO @ls_inv.
    DATA(lv_exists) = xsdbool( sy-subrc = 0 ).

    IF lv_exists = abap_false.
      ls_inv-bukrs      = is_request-bukrs.
      ls_inv-gjahr      = is_request-gjahr.
      ls_inv-src_type   = is_request-src_type.
      ls_inv-src_docno  = is_request-src_docno.
      ls_inv-created_by = sy-uname.
      GET TIME STAMP FIELD ls_inv-created_at.
    ENDIF.

    DATA(ls_hdr) = is_request-invoice-header.
    DATA(ls_buy) = is_request-invoice-buyer.
    DATA(ls_sum) = is_request-invoice-summary.

    ls_inv-provider     = i_provider.
    ls_inv-idkey        = ls_hdr-idkey.
    ls_inv-inv_type     = ls_hdr-inv_type.
    ls_inv-inv_date     = ls_hdr-inv_date.
    ls_inv-inv_time     = ls_hdr-inv_time.
    ls_inv-waers        = ls_hdr-currency.
    ls_inv-exrate       = ls_hdr-exch_rate.
    ls_inv-adj_type     = is_request-invoice-adjust-adj_type.
    " Tham chiếu HĐ gốc: ưu tiên số chứng từ SAP (để kiểm tra trạng thái
    " và đảo), fallback idkey như bản 1.0
    IF is_request-invoice-adjust-org_docno IS NOT INITIAL.
      ls_inv-ref_docno = is_request-invoice-adjust-org_docno.
      ls_inv-ref_gjahr = is_request-invoice-adjust-org_gjahr.
    ELSEIF is_request-invoice-adjust-org_idkey IS NOT INITIAL.
      ls_inv-ref_docno = is_request-invoice-adjust-org_idkey.
    ENDIF.
    ls_inv-supp_taxcode = is_request-invoice-seller-tax_code.

    ls_inv-buyer_code = ls_buy-code.
    ls_inv-buyer_name = ls_buy-legal_name.
    ls_inv-buyer_tax  = ls_buy-tax_code.
    ls_inv-buyer_addr = ls_buy-address.
    ls_inv-buyer_mail = ls_buy-email.

    ls_inv-amount     = ls_sum-amount_wo_tax.
    ls_inv-vat_amount = ls_sum-tax_amount.
    ls_inv-total      = ls_sum-total.

    " Chỉ ghi đè các trường do nhà cung cấp trả về khi thực sự có giá
    " trị, để lần gọi lỗi không xoá mất số hoá đơn đã cấp trước đó.
    IF is_result-template IS NOT INITIAL.
      ls_inv-template = is_result-template.
    ELSEIF ls_inv-template IS INITIAL.
      ls_inv-template = ls_hdr-template.
    ENDIF.
    IF is_result-serial IS NOT INITIAL.
      ls_inv-serial = is_result-serial.
    ELSEIF ls_inv-serial IS INITIAL.
      ls_inv-serial = ls_hdr-serial.
    ENDIF.
    IF is_result-seq IS NOT INITIAL.
      ls_inv-seq = is_result-seq.
    ENDIF.
    IF is_result-issue_date IS NOT INITIAL.
      ls_inv-issue_date = is_result-issue_date.
    ENDIF.
    IF is_result-mscqt IS NOT INITIAL.
      ls_inv-mscqt = is_result-mscqt.
    ENDIF.
    IF is_result-sec_code IS NOT INITIAL.
      ls_inv-sec_code = is_result-sec_code.
    ENDIF.
    IF is_result-inv_link IS NOT INITIAL.
      ls_inv-inv_link = is_result-inv_link.
    ENDIF.

    ls_inv-status      = is_result-status.
    ls_inv-prov_status = is_result-prov_status.
    ls_inv-message     = is_result-message.
    IF is_result-tax_status IS NOT INITIAL.
      ls_inv-tax_status = is_result-tax_status.
    ENDIF.
    IF is_request-invoice-adjust-org_docno IS NOT INITIAL.
      ls_inv-ref_srctype = is_request-invoice-adjust-org_src_type.
      ls_inv-adj_dir     = is_request-invoice-adjust-adj_direction.
    ENDIF.

    IF is_result-status = zif_hddt_types=>gc_status-cancelled.
      ls_inv-cancel_date = sy-datum.
    ENDIF.

    ls_inv-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.

    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD save_items.

    DATA lt_item TYPE STANDARD TABLE OF ztb_hddt_item WITH EMPTY KEY.

    DELETE FROM ztb_hddt_item
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @is_request-gjahr
        AND src_type  = @is_request-src_type
        AND src_docno = @is_request-src_docno.

    LOOP AT is_request-invoice-items ASSIGNING FIELD-SYMBOL(<fs_src>).
      APPEND VALUE #( bukrs      = is_request-bukrs
                      gjahr      = is_request-gjahr
                      src_type   = is_request-src_type
                      src_docno  = is_request-src_docno
                      line_no    = <fs_src>-line_no
                      item_code  = <fs_src>-item_code
                      item_name  = <fs_src>-item_name
                      item_type  = <fs_src>-item_type
                      unit       = <fs_src>-unit
                      quantity   = <fs_src>-quantity
                      price      = <fs_src>-price
                      amount     = <fs_src>-amount
                      tax_rate   = <fs_src>-tax_rate
                      tax_amount = <fs_src>-tax_amount
                      total      = <fs_src>-total
                      disc_pct   = <fs_src>-disc_percent
                      disc_amt   = <fs_src>-disc_amount
                      note       = <fs_src>-note ) TO lt_item.
    ENDLOOP.

    IF lt_item IS NOT INITIAL.
      " Dòng hàng sinh ra từ một lần gọi API (hoặc job nền chạy hàng loạt)
    LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<fs_adm>).
      set_admin( CHANGING cs_row = <fs_adm> ).
    ENDLOOP.

    INSERT ztb_hddt_item FROM TABLE @lt_item.
    ENDIF.

  ENDMETHOD.


  METHOD set_admin.

    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    FIELD-SYMBOLS <fs> TYPE any.

    IF i_new = abap_true.
      ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE cs_row TO <fs>.
      IF sy-subrc = 0 AND <fs> IS INITIAL.
        <fs> = sy-uname.
      ENDIF.
      ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE cs_row TO <fs>.
      IF sy-subrc = 0 AND <fs> IS INITIAL.
        <fs> = lv_ts.
      ENDIF.
    ENDIF.

    " Dòng sửa: luôn ghi đè người/lúc sửa gần nhất
    ASSIGN COMPONENT 'CHANGED_BY' OF STRUCTURE cs_row TO <fs>.
    IF sy-subrc = 0.
      <fs> = sy-uname.
    ENDIF.
    ASSIGN COMPONENT 'CHANGED_AT' OF STRUCTURE cs_row TO <fs>.
    IF sy-subrc = 0.
      <fs> = lv_ts.
    ENDIF.

  ENDMETHOD.


  METHOD set_gom_no.

    " KHÔNG khoá ở đây: hai chỗ gọi duy nhất là ZCL_HDDT_GOM->CREATE và
    " ->CANCEL, cả hai đã khoá sổ đăng ký của toàn bộ thành viên trước
    " khi gọi. Thêm khoá nữa chỉ dựa vào cơ chế cộng dồn của ENQUEUE mà
    " không cần thiết.
    DATA(ls_inv) = ensure_row( is_request ).
    ls_inv-gom_no     = i_gom_no.
    ls_inv-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.
    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD set_gom_no_multi.

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    " Cung ket qua voi goi SET_GOM_NO lan luot tung request: dong da co
    " -> giu nguyen, chi doi GOM_NO + CHANGED_*; dong chua co -> INIT_ROW.
    " Request trung khoa: lan sau thay dong lan truoc vua sua (bang HASHED).
    DATA lt_key TYPE ty_t_inv_key.
    DATA ls_inv TYPE ztb_hddt_inv.
    DATA lv_ts  TYPE timestampl.

    LOOP AT it_requests ASSIGNING FIELD-SYMBOL(<fs_req>).
      APPEND key_of( <fs_req> ) TO lt_key.
    ENDLOOP.
    DATA(lt_inv) = read_rows( lt_key ).

    GET TIME STAMP FIELD lv_ts.
    LOOP AT it_requests ASSIGNING <fs_req>.
      READ TABLE lt_inv INTO ls_inv
           WITH TABLE KEY bukrs     = <fs_req>-bukrs
                          gjahr     = <fs_req>-gjahr
                          src_type  = <fs_req>-src_type
                          src_docno = <fs_req>-src_docno.
      DATA(lv_found) = xsdbool( sy-subrc = 0 ).
      IF lv_found = abap_false.
        ls_inv = init_row( <fs_req> ).
      ENDIF.
      ls_inv-gom_no     = i_gom_no.
      ls_inv-changed_by = sy-uname.
      ls_inv-changed_at = lv_ts.
      IF lv_found = abap_true.
        MODIFY TABLE lt_inv FROM ls_inv.
      ELSE.
        INSERT ls_inv INTO TABLE lt_inv.
      ENDIF.
    ENDLOOP.

    " SET_GOM_NO cu cung khong kiem SY-SUBRC cua MODIFY (giu nguyen hanh vi)
    IF lt_inv IS NOT INITIAL.
      MODIFY ztb_hddt_inv FROM TABLE @lt_inv.
    ENDIF.
*   <<< End of change 20260928_30

  ENDMETHOD.


  METHOD set_mail_status.

    DATA(ls_inv) = ensure_row( is_request ).
    ls_inv-mail_status = i_status.
    ls_inv-mail_date   = sy-datum.
    ls_inv-changed_by  = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.
    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD set_status.

    DATA(ls_inv) = ensure_row( is_request ).
    ls_inv-status = i_status.
    IF i_message IS SUPPLIED AND i_message IS NOT INITIAL.
      ls_inv-message = i_message.
    ENDIF.
    set_admin( EXPORTING i_new  = abap_false
               CHANGING  cs_row = ls_inv ).
    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD to_raw.

    IF i_text IS INITIAL.
      RETURN.
    ENDIF.
    r_data = zcl_hddt_platform=>get( )->string_to_xstring(
                i_text     = i_text
                i_encoding = CONV string( gc_codepage ) ).

  ENDMETHOD.


  METHOD unlock_invoice.

    " _SCOPE = '1': COMMIT WORK không tự nhả, phải gọi tường minh
    CALL FUNCTION 'DEQUEUE_EZTB_HDDT_INV'
      EXPORTING
        mode_ztb_hddt_inv = 'E'
        mandt             = sy-mandt
        bukrs             = is_key-bukrs
        gjahr             = is_key-gjahr
        src_type          = is_key-src_type
        src_docno         = is_key-src_docno
        _scope            = '1'.

  ENDMETHOD.


  METHOD unlock_invoices.

    LOOP AT it_keys INTO DATA(ls_key).
      IF ls_key-src_docno IS INITIAL.
        CONTINUE.
      ENDIF.
      unlock_invoice( ls_key ).
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.

*=====================================================================
* Tên/Mã     : ZCL_HDDT_REVERSAL
* Mô tả chung: Huỷ chứng từ kế toán bằng CHỨC NĂNG CHUẨN của SAP theo
*              FS v0.17 mục 3.6.2 (nút "Hủy HĐ nháp", phương án 2) và
*              mục 3.6.5 (nút "Thay thế").
*              Chương trình KHÔNG tự viết logic đảo chứng từ — chọn
*              chức năng chuẩn nào là căn cứ NGUỒN GỐC CHỨNG TỪ:
*                TH1  cột Billing Document khác trống (kể cả bản ghi
*                     Nhóm 3 chưa có chứng từ kế toán, và chứng từ kế
*                     toán có BKPF-AWTYP = 'VBRK')
*                     -> VF11  BAPI_BILLINGDOC_CANCEL1
*                TH2  hoá đơn mua hàng từ MIRO (AWTYP = 'RMRP')
*                     -> MR8M  BAPI_INCOMINGINVOICE_CANCEL
*                TH3  chứng từ kế toán FI hạch toán trực tiếp
*                     (AWTYP = 'BKPF') -> FB08  BAPI_ACC_DOCUMENT_REV_POST
*
*              [Vì sao không dùng FB08 cho chứng từ từ Billing]
*              Chứng từ kế toán sinh ra từ Billing không đảo được bằng
*              FB08; phải huỷ từ chứng từ Billing thì SAP mới đảo đồng
*              thời chứng từ bán hàng, chứng từ kế toán và các cập nhật
*              liên quan (SD, CO-PA).
*
*              [Message lỗi]
*              FS bắt buộc TRẢ LẠI NGUYÊN VĂN message lỗi chuẩn. Cả ba
*              BAPI đều trả bảng message (BAPIRET2 với MR8M/FB08,
*              BAPIRETURN1 với VF11) nên lấy thẳng trường MESSAGE, kèm
*              ID/NUMBER để phát lại được bằng MESSAGE ID ... NUMBER.
*
*              [Lý do huỷ]
*              Mặc định '01' (huỷ cùng kỳ ghi âm) nhưng CHO SỬA: lý do
*              01 chỉ huỷ được khi kỳ kế toán của chứng từ gốc còn mở.
*              Kỳ đã đóng thì người dùng phải chọn lý do cho phép đảo
*              sang kỳ khác và nhập Ngày huỷ thuộc kỳ còn mở.
*              VF11 KHÔNG nhận lý do huỷ — chạy ngầm để chức năng chuẩn
*              tự xử lý theo cấu hình sẵn có, đúng FS.
*
*              [COMMIT]
*              Cả ba BAPI đều cần BAPI_TRANSACTION_COMMIT. Lớp này tự
*              COMMIT khi thành công và ROLLBACK khi lỗi, để caller chỉ
*              phải quan tâm kết quả.
* Tham Số    : CANCEL( is_reversal ) -> ty_rev_result
*              MODE_OF( is_src_info ) -> chế độ huỷ suy từ nguồn gốc
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       22/09/2026    cuongus - CuongUS        abapGit     Tạo mới
*                         theo FS v0.17 mục 3.6.2 / 3.6.5
* 1.1       25/09/2026    F-DUBV                   S25K900131  Bổ sung
*                         BUS_ACT = RFBU khi gọi BAPI_ACC_DOCUMENT_REV_*
*                         (review code S25 25/09, ATC P1 SLIN)
* 1.2       27/09/2026    F-DUBV                   S25K900131  R06: them
*                         TARGET_FROM (khong SELECT) de caller doc BKPF 1 lan
*                         truoc vong lap huy chung tu (review S25 27/09)
*=====================================================================
CLASS zcl_hddt_reversal DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    "! Suy chế độ huỷ từ nguồn gốc chứng từ. Trả về rỗng khi không xác
    "! định được — caller báo lỗi ZMS_HDDT 069 chứ không đoán bừa.
    CLASS-METHODS mode_of
      IMPORTING is_src_info   TYPE zif_hddt_types=>ty_src_info
      RETURNING VALUE(r_mode) TYPE zif_hddt_types=>ty_rev_mode .

    "! Huỷ một chứng từ bằng đúng chức năng chuẩn tương ứng.
    "! Không raise exception: mọi lỗi trả về trong E_RESULT để caller
    "! hiển thị nguyên văn và tự quyết định dừng hay đi tiếp.
    CLASS-METHODS cancel
      IMPORTING is_reversal     TYPE zif_hddt_types=>ty_reversal
      RETURNING VALUE(r_result) TYPE zif_hddt_types=>ty_rev_result .

    "! Dựng thông tin chứng từ cần huỷ từ BKPF: AWTYP / AWKEY để suy ra
    "! chức năng chuẩn tương ứng, và số Billing khi chứng từ phát sinh từ
    "! SD. Trả về cấu trúc đã điền sẵn MODE - caller chỉ cần bổ sung Lý do
    "! huỷ và Ngày huỷ rồi gọi CANCEL.
    "! @parameter i_bill_doc | Số Billing khi đã biết - bản ghi Nhóm 3
    "!                          chưa có chứng từ kế toán nên không có BKPF
    CLASS-METHODS target_of
      IMPORTING i_bukrs          TYPE bukrs
                i_belnr          TYPE belnr_d
                i_gjahr          TYPE gjahr
                i_bill_doc       TYPE vbeln_vf OPTIONAL
      RETURNING VALUE(rs_target) TYPE zif_hddt_types=>ty_reversal .

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    "! Nhu TARGET_OF nhung KHONG doc DB: caller da doc BKPF (AWTYP/AWKEY)
    "! MOT lan cho ca danh sach truoc vong lap roi truyen vao day.
    "! @parameter i_found    | X = co dong BKPF cua chung tu
    "! @parameter i_awtyp    | BKPF-AWTYP (khi i_found = X)
    "! @parameter i_awkey    | BKPF-AWKEY (khi i_found = X)
    "! @parameter i_bill_doc | So Billing khi da biet (nhu TARGET_OF)
    CLASS-METHODS target_from
      IMPORTING i_bukrs          TYPE bukrs
                i_belnr          TYPE belnr_d
                i_gjahr          TYPE gjahr
                i_found          TYPE abap_bool
                i_awtyp          TYPE awtyp OPTIONAL
                i_awkey          TYPE awkey OPTIONAL
                i_bill_doc       TYPE vbeln_vf OPTIONAL
      RETURNING VALUE(rs_target) TYPE zif_hddt_types=>ty_reversal .
*   <<< End of change 20260927_20

    "! Kiểm trước khi huỷ thật (chỉ FB08 — BAPI_ACC_DOCUMENT_REV_CHECK).
    "! Dùng để bắt lỗi kỳ đã đóng trước khi gọi API sang nhà cung cấp.
    CLASS-METHODS check
      IMPORTING is_reversal     TYPE zif_hddt_types=>ty_reversal
      RETURNING VALUE(r_result) TYPE zif_hddt_types=>ty_rev_result .

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES ty_t_ret2 TYPE STANDARD TABLE OF bapiret2 WITH DEFAULT KEY .
    TYPES ty_t_ret1 TYPE STANDARD TABLE OF bapireturn1 WITH DEFAULT KEY .

    "! Mã lỗi SAP báo khi kỳ kế toán đã đóng, dùng để gợi ý người dùng
    "! chọn lại Lý do huỷ / Ngày huỷ (message ZMS_HDDT 064). Khai rời
    "! từng hằng chứ không dùng CONSTANTS: BEGIN OF vì ABAP Doc không
    "! đứng trước khai báo chuỗi được.
    CONSTANTS gc_closed_id1 TYPE symsgid VALUE 'F5' ##NO_TEXT.
    CONSTANTS gc_closed_no1 TYPE symsgno VALUE '201' ##NO_TEXT.
    CONSTANTS gc_closed_id2 TYPE symsgid VALUE 'FGV' ##NO_TEXT.
    CONSTANTS gc_closed_no2 TYPE symsgno VALUE '002' ##NO_TEXT.

    CLASS-METHODS cancel_billing
      IMPORTING is_reversal     TYPE zif_hddt_types=>ty_reversal
      RETURNING VALUE(r_result) TYPE zif_hddt_types=>ty_rev_result .

    CLASS-METHODS cancel_miro
      IMPORTING is_reversal     TYPE zif_hddt_types=>ty_reversal
      RETURNING VALUE(r_result) TYPE zif_hddt_types=>ty_rev_result .

    CLASS-METHODS cancel_fi
      IMPORTING is_reversal     TYPE zif_hddt_types=>ty_reversal
                i_test          TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(r_result) TYPE zif_hddt_types=>ty_rev_result .

    "! Gom bảng BAPIRET2 thành kết quả: lấy message lỗi ĐẦU TIÊN nguyên
    "! văn, vì đó là nguyên nhân gốc; các message sau thường là hệ quả.
    CLASS-METHODS from_ret2
      IMPORTING it_return       TYPE ty_t_ret2
      RETURNING VALUE(r_result) TYPE zif_hddt_types=>ty_rev_result .

    CLASS-METHODS from_ret1
      IMPORTING it_return       TYPE ty_t_ret1
      RETURNING VALUE(r_result) TYPE zif_hddt_types=>ty_rev_result .

    CLASS-METHODS commit_or_rollback
      IMPORTING i_ok TYPE abap_bool .

    "! Khoá đối tượng của BAPI_ACC_DOCUMENT_REV_POST là AWTYP/AWKEY chứ
    "! không phải BUKRS/BELNR/GJAHR. Chứng từ hạch toán thẳng trong FI có
    "! AWTYP = 'BKPF' và AWKEY = BELNR + BUKRS + GJAHR.
    CLASS-METHODS obj_key_of
      IMPORTING is_reversal  TYPE zif_hddt_types=>ty_reversal
      RETURNING VALUE(r_key) TYPE awkey .

ENDCLASS.



CLASS ZCL_HDDT_REVERSAL IMPLEMENTATION.


  METHOD cancel.

    CASE is_reversal-mode.
      WHEN zif_hddt_types=>gc_rev_mode-vf11.
        r_result = cancel_billing( is_reversal ).
      WHEN zif_hddt_types=>gc_rev_mode-mr8m.
        r_result = cancel_miro( is_reversal ).
      WHEN zif_hddt_types=>gc_rev_mode-fb08.
        r_result = cancel_fi( is_reversal ).
      WHEN OTHERS.
        r_result-success = abap_false.
        MESSAGE e069(zms_hddt) INTO r_result-message.
        r_result-msgid = 'ZMS_HDDT'.
        r_result-msgno = '069'.
    ENDCASE.

  ENDMETHOD.


  METHOD cancel_billing.

    DATA lt_return  TYPE ty_t_ret1.
    DATA lt_success TYPE STANDARD TABLE OF bapivbrksuccess WITH DEFAULT KEY.

    " FS: goi VF11 CHAY NGAM, de chuc nang chuan tu xu ly theo dung cau
    " hinh san co (loai chung tu huy, ngay chung tu huy, ky hach toan).
    " KHONG truyen ly do huy va KHONG ghi de tham so nao.
    CALL FUNCTION 'BAPI_BILLINGDOC_CANCEL1'
      EXPORTING
        billingdocument = is_reversal-bill_doc
      TABLES
        return          = lt_return
        success         = lt_success.

    r_result = from_ret1( lt_return ).
    IF r_result-success = abap_true.
      READ TABLE lt_success INTO DATA(ls_ok) INDEX 1.
      IF sy-subrc = 0.
        r_result-rev_doc = ls_ok-bill_doc.
      ENDIF.
    ENDIF.
    commit_or_rollback( r_result-success ).

  ENDMETHOD.


  METHOD cancel_fi.

    DATA lt_return TYPE ty_t_ret2.
    DATA ls_rev    TYPE bapiacrev.

    ls_rev-obj_type   = COND #( WHEN is_reversal-awtyp IS NOT INITIAL
                                THEN is_reversal-awtyp ELSE 'BKPF' ).
    ls_rev-obj_key    = obj_key_of( is_reversal ).
    ls_rev-obj_key_r  = ls_rev-obj_key.
    ls_rev-obj_sys    = sy-sysid.
    ls_rev-comp_code  = is_reversal-bukrs.
    ls_rev-reason_rev = is_reversal-reason.
    IF is_reversal-post_date IS NOT INITIAL.
      ls_rev-pstng_date = is_reversal-post_date.
    ENDIF.

*   >>> Begin of change 20260925_01 F-DUBV TR S25K900131 - Review S25 25/09 (ATC P1 SLIN)
*   BUS_ACT la tham so BAT BUOC cua BAPI_ACC_DOCUMENT_REV_CHECK/_REV_POST.
*   TH3 chi xu ly chung tu FI hach toan truc tiep (AWTYP = BKPF) nen
*   nghiep vu la RFBU (FI posting). Truoc day thieu tham so nay.
    CONSTANTS lc_bus_act TYPE bapiache09-bus_act VALUE 'RFBU'.
*   <<< End of change 20260925_01

    IF i_test = abap_true.
      CALL FUNCTION 'BAPI_ACC_DOCUMENT_REV_CHECK'
        EXPORTING reversal = ls_rev
                  bus_act  = lc_bus_act
        TABLES    return   = lt_return.
      r_result = from_ret2( lt_return ).
      " Kiem thu thi KHONG duoc COMMIT - chi doc ket qua
      RETURN.
    ENDIF.

    CALL FUNCTION 'BAPI_ACC_DOCUMENT_REV_POST'
      EXPORTING reversal = ls_rev
                bus_act  = lc_bus_act
      TABLES    return   = lt_return.

    r_result = from_ret2( lt_return ).
    commit_or_rollback( r_result-success ).

  ENDMETHOD.


  METHOD cancel_miro.

    DATA lt_return TYPE ty_t_ret2.
    DATA lv_doc    TYPE bapi_incinv_fld-inv_doc_no.
    DATA lv_year   TYPE bapi_incinv_fld-fisc_year.

    CALL FUNCTION 'BAPI_INCOMINGINVOICE_CANCEL'
      EXPORTING
        invoicedocnumber          = is_reversal-belnr
        fiscalyear                = is_reversal-gjahr
        reasonreversal            = is_reversal-reason
        postingdate               = is_reversal-post_date
      IMPORTING
        invoicedocnumber_reversal = lv_doc
        fiscalyear_reversal       = lv_year
      TABLES
        return                    = lt_return.

    r_result = from_ret2( lt_return ).
    IF r_result-success = abap_true.
      r_result-rev_doc = lv_doc.
      r_result-rev_yr  = lv_year.
    ENDIF.
    commit_or_rollback( r_result-success ).

  ENDMETHOD.


  METHOD check.

    " Chi FB08 co BAPI kiem rieng. Hai truong hop con lai tra ve "OK" de
    " caller di tiep - loi that se hien ra o buoc CANCEL.
    IF is_reversal-mode = zif_hddt_types=>gc_rev_mode-fb08.
      r_result = cancel_fi( is_reversal = is_reversal i_test = abap_true ).
    ELSE.
      r_result-success = abap_true.
    ENDIF.

  ENDMETHOD.


  METHOD commit_or_rollback.

    IF i_ok = abap_true.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING wait = abap_true.
    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ENDIF.

  ENDMETHOD.


  METHOD from_ret1.

    r_result-success = abap_true.
    LOOP AT it_return INTO DATA(ls_ret) WHERE type CA 'EAX'.
      r_result-success = abap_false.
      r_result-message = ls_ret-message.
      r_result-msgid   = ls_ret-id.
      r_result-msgno   = ls_ret-number.
      EXIT.
    ENDLOOP.

  ENDMETHOD.


  METHOD from_ret2.

    r_result-success = abap_true.
    LOOP AT it_return INTO DATA(ls_ret) WHERE type CA 'EAX'.
      r_result-success = abap_false.
      r_result-message = ls_ret-message.
      r_result-msgid   = ls_ret-id.
      r_result-msgno   = ls_ret-number.
      IF ( ls_ret-id = gc_closed_id1 AND ls_ret-number = gc_closed_no1 )
         OR ( ls_ret-id = gc_closed_id2 AND ls_ret-number = gc_closed_no2 ).
        r_result-closed = abap_true.
      ENDIF.
      EXIT.
    ENDLOOP.

    " Mot so BAPI tra chung tu dao trong message thanh cong - khong doc
    " nguoc o day, caller da co IMPORTING rieng.

  ENDMETHOD.


  METHOD mode_of.

    " Thu tu kiem QUAN TRONG: Billing truoc. Chung tu ke toan sinh ra tu
    " Billing van phai huy bang VF11 chu khong phai FB08, nen co Billing
    " Document la du ket luan, khong xet AWTYP nua.
    IF is_src_info-bill_doc IS NOT INITIAL.
      r_mode = zif_hddt_types=>gc_rev_mode-vf11.
      RETURN.
    ENDIF.

    CASE is_src_info-awtyp.
      WHEN 'VBRK'.
        r_mode = zif_hddt_types=>gc_rev_mode-vf11.
      WHEN 'RMRP'.
        r_mode = zif_hddt_types=>gc_rev_mode-mr8m.
      WHEN 'BKPF'.
        r_mode = zif_hddt_types=>gc_rev_mode-fb08.
      WHEN OTHERS.
        CLEAR r_mode.
    ENDCASE.

  ENDMETHOD.


  METHOD obj_key_of.

    IF is_reversal-awkey IS NOT INITIAL.
      r_key = is_reversal-awkey.
      RETURN.
    ENDIF.
    " AWKEY cua chung tu FI = BELNR(10) + BUKRS(4) + GJAHR(4)
    r_key = |{ is_reversal-belnr }{ is_reversal-bukrs }{ is_reversal-gjahr }|.

  ENDMETHOD.


  METHOD target_from.

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   Chuyen nguyen van phan xu ly sau SELECT cua TARGET_OF sang day,
*   KHONG doc DB. I_FOUND thay cho sy-subrc cua SELECT SINGLE BKPF.
    rs_target-bukrs = i_bukrs.
    rs_target-belnr = i_belnr.
    rs_target-gjahr = i_gjahr.

    IF i_found = abap_false.
      " Nhom 3 - Billing chua co chung tu FI: khong co BKPF, huy bang VF11
      IF i_bill_doc IS NOT INITIAL.
        rs_target-bill_doc = i_bill_doc.
        rs_target-mode     = zif_hddt_types=>gc_rev_mode-vf11.
      ENDIF.
      RETURN.
    ENDIF.
    rs_target-awtyp = i_awtyp.
    rs_target-awkey = i_awkey.

    " Chung tu ke toan sinh ra tu Billing: AWKEY mang so Billing o 10 ky
    " tu dau. Co so Billing thi phai huy bang VF11, khong phai FB08.
    IF i_awtyp = 'VBRK' AND i_awkey IS NOT INITIAL.
      rs_target-bill_doc = i_awkey(10).
    ENDIF.

    rs_target-mode = mode_of( VALUE #( awtyp    = rs_target-awtyp
                                       awkey    = rs_target-awkey
                                       bill_doc = rs_target-bill_doc ) ).
*   <<< End of change 20260927_20

  ENDMETHOD.


  METHOD target_of.

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   Goi le (ngoai vong lap): doc BKPF 1 dong roi dung chung logic voi
*   TARGET_FROM. Vong lap (SERVICE CANCEL_SOURCE_DOCS) goi TARGET_FROM.
*    rs_target-bukrs = i_bukrs.
*    rs_target-belnr = i_belnr.
*    rs_target-gjahr = i_gjahr.
*   <<< End of change 20260927_20

    SELECT SINGLE awtyp, awkey
      FROM bkpf
      WHERE bukrs = @i_bukrs
        AND belnr = @i_belnr
        AND gjahr = @i_gjahr
      INTO @DATA(ls_bkpf).
*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    rs_target = target_from( i_bukrs    = i_bukrs
                             i_belnr    = i_belnr
                             i_gjahr    = i_gjahr
                             i_found    = xsdbool( sy-subrc = 0 )
                             i_awtyp    = ls_bkpf-awtyp
                             i_awkey    = ls_bkpf-awkey
                             i_bill_doc = i_bill_doc ).
*    IF sy-subrc <> 0.
*      " Nhóm 3 - Billing chưa có chứng từ FI: không có BKPF, huỷ bằng VF11
*      IF i_bill_doc IS NOT INITIAL.
*        rs_target-bill_doc = i_bill_doc.
*        rs_target-mode     = zif_hddt_types=>gc_rev_mode-vf11.
*      ENDIF.
*      RETURN.
*    ENDIF.
*    rs_target-awtyp = ls_bkpf-awtyp.
*    rs_target-awkey = ls_bkpf-awkey.
*
*    " Chung tu ke toan sinh ra tu Billing: AWKEY mang so Billing o 10 ky
*    " tu dau. Co so Billing thi phai huy bang VF11, khong phai FB08.
*    IF ls_bkpf-awtyp = 'VBRK' AND ls_bkpf-awkey IS NOT INITIAL.
*      rs_target-bill_doc = ls_bkpf-awkey(10).
*    ENDIF.
*
*    rs_target-mode = mode_of( VALUE #( awtyp    = rs_target-awtyp
*                                       awkey    = rs_target-awkey
*                                       bill_doc = rs_target-bill_doc ) ).
*   <<< End of change 20260927_20

  ENDMETHOD.
ENDCLASS.

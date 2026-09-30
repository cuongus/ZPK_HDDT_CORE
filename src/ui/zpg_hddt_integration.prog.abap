*=====================================================================
* Tên/Mã     : ZPG_HDDT_INTEGRATION  (transaction ZFI001)
* Mô tả chung: Chương trình SAP GUI tích hợp hoá đơn điện tử theo FS
*              MAG_SAP_2026_PM_FS_Tich hop HDDT v0.5 (quy trình AR.10).
*              Chọn chứng từ nguồn -> danh sách ALV -> 8 nút chức năng:
*              Tích hợp HĐ (nháp) · Hủy HĐ nháp · Phát hành HĐ · Cập
*              nhật HĐ · HĐ Điều chỉnh · Send Email · Gom HĐ · Huỷ Gom
*              HĐ; kèm Sửa ngày/giờ/tên hàng, Lấy file, Xem payload,
*              Log. Chạy background job với "Phát hành tự động" thì phát
*              hành một bước (create-appr-inv) cho chứng từ chưa tích
*              hợp và cấp số + ký duyệt cho chứng từ đã có nháp.
*              Chương trình KHÔNG chứa logic nhà cung cấp: mọi thứ đi
*              qua ZCL_HDDT_SERVICE nên đổi Viettel/FPT/VNPT bằng
*              cấu hình là chạy được ngay, không sửa chương trình.
* Tham Số    : p_bukrs  - Mã công ty (bắt buộc)
*              p_gjahr  - Năm tài chính (bắt buộc)
*              s_belnr  - Khoảng số chứng từ
*              s_budat  - Khoảng ngày ghi sổ
*              s_bldat  - Khoảng ngày chứng từ
*              s_cpudt  - Khoảng ngày nhập chứng từ
*              s_blart  - Loại chứng từ
*              s_vbeln  - Số billing SD tham chiếu
*              s_kunnr  - Khách hàng
*              s_usnam  - Người hạch toán
*              s_seq    - Số hoá đơn điện tử đã cấp
*              s_gom    - Số chứng từ gom
*              s_srct   - Loại nguồn dữ liệu (FI/SD/GOM/...), để trống
*                         là lấy mọi loại đã cấu hình
*              p_prov   - Nhà cung cấp (để trống = theo cấu hình)
*              p_ityp   - Mẫu hoá đơn phát hành (01GTKT...)
*              p_seri   - Dải số (ký hiệu) hoá đơn; tự điền dòng tích
*                         Mặc định trong ZTB_HDDT_CRED, F4 liệt kê các
*                         dải còn hiệu lực của công ty
*              s_stat   - Trạng thái HĐĐT cần lọc
*              p_rever  - Lấy cả chứng từ đã đảo / billing đã huỷ
*              p_test   - Test run: chỉ dựng payload, không gọi API
*              p_auto   - Phát hành tự động (chỉ khi chạy background job)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       03/09/2026    cuongus - CuongUS        abapGit     Đổi tên theo
*                         chuẩn Private Cloud 03.09.2026; gộp include
*                         _SEL/_CL1/_EVT vào _TOP/_F01/chương trình chính
* 1.2       07/09/2026    cuongus - CuongUS        abapGit     FS MAG v0.5:
*                         8 nút chức năng, phát hành tự động (job),
*                         kiểm quyền theo chức năng
* 1.3       16/09/2026    cuongus - CuongUS        abapGit     Nhiều dải số
*                         trong một năm cho một đơn vị: tham số p_seri,
*                         tự điền theo cờ Mặc định (ZTB_HDDT_CRED-XDEFAULT),
*                         F4 danh sách dải số, kiểm tra giá trị gõ tay
* 1.4       23/09/2026    cuongus - CuongUS        S25K900131  FS v0.17:
*                         dải số theo Company code + năm (năm của Posting
*                         date), nút Thay thế tách riêng, huỷ chứng từ
*                         chuẩn VF11/MR8M/FB08, tham số Billing Document
*=====================================================================
REPORT zpg_hddt_integration MESSAGE-ID zms_hddt.

INCLUDE zin_hddt_integration_top.          " khai báo + màn hình chọn
INCLUDE zin_hddt_integration_f01.          " lớp local ALV + form routine

*---------------------------------------------------------------------*
* Sự kiện
*---------------------------------------------------------------------*
INITIALIZATION.
  p_gjahr = sy-datum(4).

AT SELECTION-SCREEN ON p_bukrs.
  " Không cho phát hành hoá đơn của công ty người dùng không có quyền
  AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
    ID 'BUKRS' FIELD p_bukrs
    ID 'ACTVT' FIELD '03'.
  IF sy-subrc <> 0.
    MESSAGE e004(zms_hddt) WITH p_bukrs.
  ENDIF.

AT SELECTION-SCREEN ON p_prov.
  IF p_prov IS INITIAL.
    RETURN.
  ENDIF.
  " Biến khai trong event là biến TOÀN CỤC của chương trình: phải xoá
  " trước, không thì SELECT hụt giữ nguyên X của lần kiểm trước và một
  " nhà cung cấp sai vẫn lọt qua.
  DATA lv_exists TYPE abap_bool.
  CLEAR lv_exists.
  SELECT SINGLE @abap_true FROM ztb_hddt_prov
    WHERE provider = @p_prov
      AND xactive  = @abap_true
    INTO @lv_exists.
  IF lv_exists <> abap_true.
    MESSAGE e005(zms_hddt) WITH p_prov.
  ENDIF.

AT SELECTION-SCREEN OUTPUT.
  " Một đơn vị có thể khai nhiều dải số hoá đơn cùng hiệu lực trong một
  " năm, nên màn hình tự điền dải đã tích Mặc định trong ZTB_HDDT_CRED.
  " CHỈ điền khi ô còn trống: người dùng xoá đi để chọn dải khác thì
  " không được đè lại, nếu không họ không bao giờ đổi được dải số.
  " FS v0.17 mục 3.2: dải số mặc định theo Company code VÀ NĂM - năm
  " lấy theo Posting date (giá trị From), trống thì năm hiện hành.
  IF p_seri IS INITIAL AND p_bukrs IS NOT INITIAL.
    PERFORM serial_date CHANGING gv_serial_date.
    p_seri = zcl_hddt_config=>get_instance( )->get_default_serial(
               i_provider = p_prov
               i_bukrs    = p_bukrs
               i_inv_type = p_ityp
               i_date     = gv_serial_date ).
  ENDIF.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_seri.
  PERFORM f4_serial.

AT SELECTION-SCREEN ON p_seri.
  " Gõ tay một dải số không có trong cấu hình thì chặn ngay tại màn hình
  " tham số, đừng để chạy tới lúc gọi API mới báo.
  IF p_seri IS NOT INITIAL AND p_bukrs IS NOT INITIAL.
    PERFORM serial_date CHANGING gv_serial_date.
    DATA(lt_cred) = zcl_hddt_config=>get_instance( )->get_cred_list(
                      i_provider = p_prov
                      i_bukrs    = p_bukrs
                      i_inv_type = p_ityp
                      i_date     = gv_serial_date ).
    IF NOT line_exists( lt_cred[ serial = p_seri ] ).
      MESSAGE e050(zms_hddt) WITH p_seri p_bukrs.
    ENDIF.
  ENDIF.

START-OF-SELECTION.
  go_app = NEW lcl_app( ).

  " FS 3.6.9: "Phát hành tự động" chỉ có hiệu lực ở background job;
  " chạy online thì bỏ qua và chỉ hiển thị danh sách
  IF p_auto = abap_true AND sy-batch = abap_true.
    go_app->run_auto( ).
  ELSE.
    IF p_auto = abap_true.
      MESSAGE s033(zms_hddt) DISPLAY LIKE 'W'.
    ENDIF.
    go_app->run( ).
  ENDIF.

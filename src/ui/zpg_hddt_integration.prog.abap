*=====================================================================
* Tên/Mã     : ZPG_HDDT_INTEGRATION  (transaction ZFI001)
* Mô tả chung: Chương trình SAP GUI tích hợp hoá đơn điện tử.
*              Chọn chứng từ nguồn -> xem danh sách ALV -> phát hành /
*              điều chỉnh / thay thế / huỷ / tra cứu / lấy file, hoặc
*              chỉ xem trước payload JSON (Test run) mà không gọi API.
*              Chương trình KHÔNG chứa logic nhà cung cấp: mọi thứ đi
*              qua ZCL_HDDT_SERVICE nên đổi Viettel/FPT/VNPT bằng
*              cấu hình là chạy được ngay, không sửa chương trình.
* Tham Số    : p_bukrs  - Mã công ty (bắt buộc)
*              p_gjahr  - Năm tài chính (bắt buộc)
*              s_belnr  - Khoảng số chứng từ
*              s_budat  - Khoảng ngày ghi sổ
*              s_bldat  - Khoảng ngày chứng từ
*              s_blart  - Loại chứng từ
*              s_vbeln  - Số billing SD tham chiếu
*              s_kunnr  - Khách hàng
*              s_usnam  - Người hạch toán
*              p_rever  - Lấy cả chứng từ đã đảo / billing đã huỷ
*              p_srct   - Loại nguồn dữ liệu (FI/SD/MM/GOM/CUST)
*              p_prov   - Nhà cung cấp (để trống = theo cấu hình)
*              s_stat   - Trạng thái HĐĐT cần lọc
*              p_test   - Test run: chỉ dựng payload, không gọi API
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       03/09/2026    cuongus - CuongUS        abapGit     Đổi tên theo
*                         chuẩn Private Cloud 03.09.2026; gộp include
*                         _SEL/_CL1/_EVT vào _TOP/_F01/chương trình chính
*=====================================================================
REPORT zpg_hddt_integration MESSAGE-ID zms_hddt.

INCLUDE zpg_hddt_integration_top.          " khai báo + màn hình chọn
INCLUDE zpg_hddt_integration_f01.          " lớp local ALV + form routine

*---------------------------------------------------------------------*
* Sự kiện (gộp include _EVT cũ theo chuẩn include _TOP/_F01)
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
  SELECT SINGLE @abap_true FROM ztb_hddt_prov
    INTO @DATA(lv_exists)
    WHERE provider = @p_prov
      AND xactive  = @abap_true.
  IF lv_exists <> abap_true.
    MESSAGE e005(zms_hddt) WITH p_prov.
  ENDIF.

START-OF-SELECTION.
  DATA(go_app) = NEW lcl_app( ).
  go_app->run( ).

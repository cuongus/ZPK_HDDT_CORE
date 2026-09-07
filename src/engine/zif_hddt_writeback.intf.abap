*=====================================================================
* Tên/Mã     : ZIF_HDDT_WRITEBACK
* Mô tả chung: Hợp đồng GHI NGƯỢC thông tin hoá đơn đã phát hành vào
*              chứng từ nguồn trên SAP (FS MAG mục 3.6.3 / 3.6.5: đẩy
*              "Mẫu hoá đơn + Ký hiệu # Số hoá đơn" vào BKPF-XBLNR,
*              hoá đơn điều chỉnh ghi thêm chuỗi của HĐ gốc vào
*              BKPF-XREF2_HD).
*              Engine không biết BKPF; lớp thực thi được khai trong
*              tham số WRITEBACK_CLASS (trống = không ghi ngược).
* Tham Số    : Không có (interface)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       07/09/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
INTERFACE zif_hddt_writeback
  PUBLIC .

  "! Ghi ngược sau khi nghiệp vụ thành công và đã có số hoá đơn.
  "! IS_REG là dòng sổ đăng ký sau khi đã cập nhật kết quả.
  METHODS write
    IMPORTING is_request TYPE zif_hddt_types=>ty_request
              is_result  TYPE zif_hddt_types=>ty_result
              is_reg     TYPE ztb_hddt_inv
    RAISING   zcx_hddt_error.

ENDINTERFACE.

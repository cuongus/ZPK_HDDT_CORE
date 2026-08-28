*=====================================================================
* Tên/Mã     : ZFIIF_HDDT_SOURCE
* Mô tả chung: Hợp đồng cho lớp ĐỌC DỮ LIỆU NGUỒN trên SAP và dựng
*              canonical model. Tách riêng khỏi engine vì phần này
*              phụ thuộc nghiệp vụ từng khách hàng (FI/SD/MM/gom).
*              Lớp thực thi được khai báo trong bảng ZFIT_HDDT_SRC
*              theo công ty + loại nguồn => thay đổi bằng cấu hình.
* Tham Số    : Không có (interface)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
INTERFACE zfiif_hddt_source
  PUBLIC .

  TYPES: BEGIN OF ty_selection,
           bukrs    TYPE bukrs,
           gjahr    TYPE gjahr,
           r_docno  TYPE zfiif_hddt_types=>ty_r_docno,
           r_budat  TYPE zfiif_hddt_types=>ty_r_date,
           r_kunnr  TYPE zfiif_hddt_types=>ty_r_kunnr,
           r_blart  TYPE zfiif_hddt_types=>ty_r_blart,
           r_status TYPE zfiif_hddt_types=>ty_r_status,
         END OF ty_selection.

  "! Đọc chứng từ nguồn, dựng danh sách request đã chuẩn hoá.
  METHODS select_documents
    IMPORTING is_selection      TYPE ty_selection
    RETURNING VALUE(rt_request) TYPE zfiif_hddt_types=>ty_t_request
    RAISING   zficx_hddt_error.

ENDINTERFACE.

*=====================================================================
* Tên/Mã     : ZFIIF_HDDT_SOURCE
* Mô tả chung: Hợp đồng cho lớp ĐỌC DỮ LIỆU NGUỒN trên SAP và dựng
*              canonical model. Tách riêng khỏi engine vì phần này
*              phụ thuộc nghiệp vụ từng khách hàng (FI/SD/MM/gom).
*              Lớp thực thi được khai báo trong bảng ZFIT_HDDT_SRC
*              theo công ty + loại nguồn => thay đổi bằng cấu hình.
*              Lớp nguồn cũng là nơi DUY NHẤT biết bảng nghiệp vụ SAP
*              (BKPF/BSEG/VBRK...), nên GET_DOC_STATE được engine gọi
*              khi cần kiểm tra chứng từ đã đảo/huỷ hay chưa.
* Tham Số    : Không có (interface)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       03/09/2026    cuongus - CuongUS        abapGit     Thêm range
*                         BLDAT/VBELN/USNAM, cờ lấy CT đã đảo,
*                         GET_DOC_STATE (port từ ZPG_INT_E_INVOICE)
*=====================================================================
INTERFACE zfiif_hddt_source
  PUBLIC .

  TYPES: BEGIN OF ty_selection,
           bukrs     TYPE bukrs,
           gjahr     TYPE gjahr,
           r_docno   TYPE zfiif_hddt_types=>ty_r_docno,
           r_budat   TYPE zfiif_hddt_types=>ty_r_date,
           r_bldat   TYPE zfiif_hddt_types=>ty_r_date,
           r_kunnr   TYPE zfiif_hddt_types=>ty_r_kunnr,
           r_blart   TYPE zfiif_hddt_types=>ty_r_blart,
           r_status  TYPE zfiif_hddt_types=>ty_r_status,
           " Chứng từ tham chiếu SD (BKPF-AWKEY / VBRK-VBELN)
           r_vbeln   TYPE zfiif_hddt_types=>ty_r_docno,
           r_usnam   TYPE zfiif_hddt_types=>ty_r_usnam,
           " abap_true = lấy cả chứng từ đã bị đảo / hoá đơn SD đã huỷ
           " (mặc định chỉ lấy khi đã phát hành HĐĐT để người dùng huỷ)
           xreversed TYPE abap_bool,
         END OF ty_selection.

  " Trạng thái chứng từ nguồn dùng cho kiểm tra nghiệp vụ của engine
  TYPES: BEGIN OF ty_doc_state,
           exists    TYPE abap_bool,
           xreversed TYPE abap_bool,   " FI: BKPF-XREVERSED / SD: VBRK-FKSTO
           stblg     TYPE belnr_d,     " chứng từ đảo
           stjah     TYPE gjahr,
           waers     TYPE waers,
           kunnr     TYPE kunnr,
         END OF ty_doc_state.

  "! Đọc chứng từ nguồn, dựng danh sách request đã chuẩn hoá.
  METHODS select_documents
    IMPORTING is_selection      TYPE ty_selection
    RETURNING VALUE(rt_request) TYPE zfiif_hddt_types=>ty_t_request
    RAISING   zficx_hddt_error.

  "! Trạng thái hiện tại của MỘT chứng từ nguồn (đảo/huỷ, tiền tệ,
  "! khách hàng) — engine dùng khi kiểm tra điều kiện huỷ / thay thế.
  METHODS get_doc_state
    IMPORTING iv_bukrs        TYPE bukrs
              iv_gjahr        TYPE gjahr
              iv_docno        TYPE zfide_hddt_docno
    RETURNING VALUE(rs_state) TYPE ty_doc_state.

ENDINTERFACE.

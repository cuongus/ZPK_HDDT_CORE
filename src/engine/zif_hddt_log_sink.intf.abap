*=====================================================================
* Tên/Mã     : ZIF_HDDT_LOG_SINK
* Mô tả chung: Hợp đồng ĐẨY LOG sang bảng log tích hợp dùng chung của
*              khách hàng (FS MAG: ZTB_INT_LOG, 30 trường, khoá
*              MANDT + LOG_ID, ORIG_LOG_ID = FKEY của chứng từ).
*              ZCL_HDDT_LOG luôn ghi ZTB_HDDT_LOG (chi tiết, payload
*              byte-exact); sau đó gọi lớp sink khai trong tham số
*              LOG_SINK_CLASS để ánh xạ sang bảng dùng chung. Lớp sink
*              thuộc dự án khách hàng, không nằm trong package này.
* Tham Số    : Không có (interface)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       07/09/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
INTERFACE zif_hddt_log_sink
  PUBLIC .

  "! IS_LOG là dòng vừa ghi vào ZTB_HDDT_LOG (payload đã che secret).
  "! Không được raise: lỗi sink không được làm hỏng nghiệp vụ.
  METHODS write
    IMPORTING is_log     TYPE ztb_hddt_log
              is_request TYPE zif_hddt_types=>ty_request
              is_result  TYPE zif_hddt_types=>ty_result.

ENDINTERFACE.

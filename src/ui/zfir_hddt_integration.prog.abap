*=====================================================================
* Tên/Mã     : ZFIR_HDDT_INTEGRATION  (transaction ZFI_HDDT)
* Mô tả chung: Chương trình SAP GUI tích hợp hoá đơn điện tử.
*              Chọn chứng từ nguồn -> xem danh sách ALV -> phát hành /
*              điều chỉnh / thay thế / huỷ / tra cứu / lấy file, hoặc
*              chỉ xem trước payload JSON (Test run) mà không gọi API.
*              Chương trình KHÔNG chứa logic nhà cung cấp: mọi thứ đi
*              qua ZFIC_HDDT_SERVICE nên đổi Viettel/FPT/VNPT bằng
*              cấu hình là chạy được ngay, không sửa chương trình.
* Tham Số    : p_bukrs  - Mã công ty (bắt buộc)
*              p_gjahr  - Năm tài chính (bắt buộc)
*              s_belnr  - Khoảng số chứng từ
*              s_budat  - Khoảng ngày ghi sổ
*              s_blart  - Loại chứng từ
*              p_srct   - Loại nguồn dữ liệu (FI/SD/MM/GOM/CUST)
*              p_prov   - Nhà cung cấp (để trống = theo cấu hình)
*              s_stat   - Trạng thái HĐĐT cần lọc
*              p_test   - Test run: chỉ dựng payload, không gọi API
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
REPORT zfir_hddt_integration MESSAGE-ID zfie_hddt.

INCLUDE zfir_hddt_int_top.
INCLUDE zfir_hddt_int_sel.
INCLUDE zfir_hddt_int_cl1.
INCLUDE zfir_hddt_int_evt.
INCLUDE zfir_hddt_int_f01.

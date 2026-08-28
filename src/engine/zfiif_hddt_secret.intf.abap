*=====================================================================
* Tên/Mã     : ZFIIF_HDDT_SECRET
* Mô tả chung: Điểm cắm (plug-in) để lấy mật khẩu / secret API từ nơi
*              lưu trữ an toàn của khách hàng (SSFS, HashiCorp Vault,
*              CyberArk, bảng mã hoá riêng...).
*              Khai báo lớp thực thi qua tham số SECRET_CLASS trong
*              bảng ZFIT_HDDT_PARM. Không khai báo thì core lấy từ
*              trường ZFIT_HDDT_CRED-APISECRET.
* Tham Số    : Không có (interface)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
INTERFACE zfiif_hddt_secret
  PUBLIC .

  "! Trả về secret ứng với khoá SECKEY của dòng cấu hình tài khoản.
  METHODS get_secret
    IMPORTING is_cred          TYPE zfit_hddt_cred
    RETURNING VALUE(rv_secret) TYPE string
    RAISING   zficx_hddt_error .

ENDINTERFACE.

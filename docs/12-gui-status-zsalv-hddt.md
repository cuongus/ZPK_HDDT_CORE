# 12 — GUI status ZSALV_HDDT: tạo 12 nút nghiệp vụ

`CL_SALV_TABLE` ở chế độ toàn màn hình không cho thêm nút vào toolbar chuẩn
(`ADD_FUNCTION` ném `CX_SALV_WRONG_CALL`), nên 12 nút của `ZPG_HDDT_INTEGRATION`
lấy từ GUI status riêng. Chương trình gọi:

```abap
      mo_alv->set_screen_status( pfstatus      = gc_pfstatus        " ZSALV_HDDT
                                 report        = sy-repid
                                 set_functions = cl_salv_table=>c_functions_all ).
```

## 1. Chỗ đặt 12 nút

Application Toolbar chỉ có 35 ô. Status copy từ `STANDARD_FULLSCREEN` đã dùng
khoảng 25 ô, còn trống khoảng 10 ô nên phải dọn thêm 2 ô.

Cách gọn nhất: xoá 4 mã phân trang ở dòng `Items 29 – 35` là `&CRB` `&CRL`
`&CRR` `&CRE`. Bốn chức năng này đã có sẵn trên Standard Toolbar dưới dạng
`P--` `P-` `P+` `P++` nên không mất gì. Sau khi xoá còn 14 ô trống, đủ cho 12 nút.

Đặt 7 nút đầu vào dòng `Items 29 – 35`, 5 nút còn lại vào các ô trống của bốn
dòng trên. Thứ tự trên toolbar không ảnh hưởng chức năng, mỗi nút đã có icon và
tooltip riêng.

Muốn toolbar gọn hơn thì làm thêm Menu Bar: tạo một menu tên `Hoá đơn` chứa đủ
12 mục, và chỉ để 6 nút hay dùng nhất trên toolbar (`ZDRAFT`, `ZISSUE`,
`ZUPDATE`, `ZADJREF`, `ZJSON`, `ZLOG`).

## 2. Cách thêm một nút

```
SE41 → Program ZPG_HDDT_INTEGRATION → Status ZSALV_HDDT → Change
  Khối Application Toolbar → nhấn đôi vào một ô TRỐNG
  Nhập mã chức năng, ví dụ ZDRAFT → Enter
  Nhấn đôi vào mã vừa nhập để mở thuộc tính chức năng, điền:
    Function Text : nhãn khi hiện dạng chữ
    Icon Name     : ICON_CREATE
    Icon Text     : nhãn cạnh icon (ngắn, tối đa 20 ký tự)
    Info Text     : tooltip khi trỏ chuột
    Function Type : để trống (chức năng thường)
  Enter → ô toolbar hiện icon kèm nhãn
```

Nhanh hơn khi làm cả 12 mã: mở danh sách chức năng của status (nút
**Function Code** trên thanh công cụ SE41, hoặc Goto → Function List) rồi điền
Text, Icon, Info cho từng mã trong một danh sách.

Xong 12 nút thì **Activate** status. Chạy lại `ZFI001`, các nút sẽ hiện ngay bên
phải nhóm nút chuẩn của ALV.

## 3. Bảng 12 mã chức năng

| # | Mã | Icon Name | Icon Text / nhãn | Info Text (tooltip) |
|---|---|---|---|---|
| 1 | `ZDRAFT` | `ICON_CREATE` | Tích hợp HĐ | Tạo hoá đơn nháp trên hệ thống HĐĐT (chờ cấp số) |
| 2 | `ZDELDRF` | `ICON_DELETE` | Hủy HĐ nháp | Xoá hoá đơn nháp trên hệ thống HĐĐT, về trạng thái chưa tích hợp |
| 3 | `ZISSUE` | `ICON_EXECUTE_OBJECT` | Phát hành HĐ | Cấp số và ký duyệt trên chính bản nháp, gửi Cơ quan thuế |
| 4 | `ZUPDATE` | `ICON_REFRESH` | Cập nhật HĐ | Tra cứu và đồng bộ trạng thái hoá đơn / Cơ quan thuế về SAP |
| 5 | `ZADJREF` | `ICON_CHANGE` | HĐ Điều chỉnh | Gắn hoá đơn gốc và loại điều chỉnh / thay thế cho chứng từ |
| 6 | `ZMAIL` | `ICON_MAIL` | Send Email | Gửi email hoá đơn (PDF) cho khách hàng |
| 7 | `ZGOM` | `ICON_COLLAPSE` | Gom HĐ | Gom các chứng từ đã chọn thành một hoá đơn |
| 8 | `ZUNGOM` | `ICON_EXPAND` | Huỷ Gom HĐ | Gỡ toàn bộ chứng từ khỏi chứng từ gom |
| 9 | `ZEDIT` | `ICON_EDIT_FILE` | Sửa ngày/giờ | Sửa ngày, giờ phát hành và tên hàng trước khi tích hợp |
| 10 | `ZFILE` | `ICON_PDF` | Lấy file | Tải file PDF hoá đơn từ nhà cung cấp |
| 11 | `ZJSON` | `ICON_XML_DOC` | Xem payload | Xem payload sẽ gửi cho nhà cung cấp (không gọi API) |
| 12 | `ZLOG` | `ICON_PROTOCOL` | Log | Xem log gọi API của chứng từ |

Mã phải viết **đúng từng ký tự**: chương trình so bằng hằng số `gc_fcode` trong
`ZIN_HDDT_INTEGRATION_TOP`. Sai một chữ thì nút hiện ra nhưng bấm không có gì
xảy ra, vì mã không khớp nhánh nào trong `on_function`.

Nhãn nút giữ dưới 20 ký tự. Nút số 9 vì vậy rút còn `Sửa ngày/giờ`, ý nghĩa đầy
đủ nằm ở tooltip.

## 4. Phím tắt (không bắt buộc)

Nếu muốn gán phím tắt, tránh các phím SAP đã dành riêng: `F4` trợ giúp giá trị,
`F2` chọn, `F9` select, `Shift+F2` xoá, `Shift+F10` context menu, `F3` back,
`F12` cancel. An toàn là dùng `Shift+F5` trở lên.

## 5. Kiểm tra sau khi activate

1. Chạy `ZFI001`, chọn công ty và năm, Execute.
2. Toolbar phải có 12 nút mới bên phải nhóm nút chuẩn.
3. Chọn một dòng rồi bấm `Xem payload`: hiện pop-up nội dung JSON, không gọi API.
4. Nếu bấm nút mà không có gì xảy ra thì mã chức năng trong status khác `gc_fcode`.
5. Nếu toolbar chỉ có nút chuẩn thì status chưa activate hoặc tên khác
   `ZSALV_HDDT`; chương trình có hiện một cảnh báo nêu tên status nó cần.

[Unverified] Đường đi menu trong SE41 mô tả theo bản Eclipse / SAP GUI của hệ
MAG S25; nhãn menu có thể khác chút giữa các release.

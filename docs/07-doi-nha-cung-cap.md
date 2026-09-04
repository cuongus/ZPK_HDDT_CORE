# 07 — Runbook: đổi nhà cung cấp HĐĐT

Tình huống: đang dùng Viettel SInvoice, hợp đồng mới chuyển sang FPT eInvoice từ
**01/09/2026**, công ty `1000`.

Toàn bộ thao tác dưới đây làm **trên hệ PRD**, **không cần transport**, vì tất cả
đều là dữ liệu customizing.

---

## 1. Chuẩn bị (trước ngày cắt chuyển)

### 1.1 Kết nối

```
STRUST → import chain CA của api.einvoice.fpt.com.vn (PROD, không phải UAT)
       → SSL Client (Anonymous) → Save → SMICM restart ICM

SM59  → tạo destination G  ZHDDT_FPT
        host = api.einvoice.fpt.com.vn, port 443, SSL Active
```

### 1.2 Bảng `ZTB_HDDT_CONN`

```
PROVIDER=FPT  CONNID=PRD  RFCDEST=ZHDDT_FPT
AUTH_MODE=N   TIMEOUT=60  XACTIVE=X
DESCR=FPT eInvoice PROD
```

### 1.3 Bảng `ZTB_HDDT_ACT`

Đã có sẵn (do `ZPG_HDDT_SETUP` nạp) nhưng trỏ URL **UAT** nằm trong `BASE_URL`
của kết nối UAT. Vì `CONNID=PRD` dùng `RFCDEST`, các `API_PATH` tương đối dùng
lại được nguyên vẹn — **không phải sửa gì**.

### 1.4 Bảng `ZTB_HDDT_CRED`

```
Dòng mới:
  PROVIDER=FPT   BUKRS=1000  INV_TYPE=(trống)  CONNID=PRD
  TAXCODE=<MST công ty>   TEMPLATE=<mẫu đã đăng ký>
  SERIAL=<ký hiệu đã đăng ký với CQT>
  APIUSER=<MST>.<user>    APISECRET=<mật khẩu>   (hoặc SECKEY nếu dùng vault)
  VALID_FROM=01.09.2026   VALID_TO=31.12.9999    XACTIVE=X

Dòng Viettel cũ — KHÔNG xoá, chỉ đóng hiệu lực:
  PROVIDER=VIETTEL  BUKRS=1000  VALID_TO=31.08.2026
```

> Giữ dòng Viettel là **bắt buộc**: hoá đơn đã phát hành bằng Viettel vẫn cần
> tra cứu / huỷ / điều chỉnh trong 10 năm theo quy định lưu trữ.

### 1.5 Ánh xạ riêng của FPT

```
ZTB_HDDT_PARM
  PROVIDER=FPT  PARM_KEY=FPT_LANG          PARM_VAL=vi
  PROVIDER=FPT  PARM_KEY=FPT_AUN           PARM_VAL=2
  PROVIDER=FPT  PARM_KEY=FPT_USER_IN_BODY  PARM_VAL=X
  PROVIDER=FPT  BUKRS=1000
                PARM_KEY=FPT_PLACE         PARM_VAL=Hà Nội
  PROVIDER=FPT  PARM_KEY=DEFAULT_CONNID    PARM_VAL=PRD
```

Ánh xạ thuế suất / hình thức thanh toán ở `ZTB_HDDT_MAP` với `PROVIDER` để
trống là **dùng chung**, không phải khai lại cho FPT.

---

## 2. Kiểm thử song song (khuyến nghị 1–2 tuần trước cắt chuyển)

```
ZFI001
  Mã công ty  : 1000
  Nhà cung cấp: FPT          ← ghi đè cấu hình, chỉ trong lần chạy này
  ☑ Test run

→ Chọn 5–10 chứng từ đại diện (1 thuế suất, nhiều thuế suất, ngoại tệ,
  hàng KCT, có chiết khấu)
→ "Xem payload" từng cái, đối chiếu với tài liệu FPT v2.4.7 mục 3.3
→ Bỏ Test run, phát hành lên môi trường UAT của FPT (CONNID=UAT)
→ Đối chiếu số hoá đơn, tổng tiền, thuế trên portal của FPT
```

Tham số `Nhà cung cấp` trên selection screen tồn tại đúng để làm việc này:
thử nhà cung cấp mới **mà không đổi cấu hình toàn hệ**.

---

## 3. Ngày cắt chuyển

```
1. Đóng sổ nghiệp vụ HĐĐT của ngày cuối cùng với Viettel:
   ZFI001 → lọc s_stat = 00 (chưa tích hợp) → phát hành hết
   → kiểm tra không còn dòng đèn vàng / đỏ

2. Đổi tham số ACTIVE_PROVIDER:
   ZFI002 → ZTB_HDDT_PARM
     PROVIDER=(trống)  BUKRS=1000
     PARM_KEY=ACTIVE_PROVIDER   PARM_VAL=FPT

3. Xoá bộ đệm cấu hình của các session đang mở:
   - Người dùng thoát và vào lại ZFI001, HOẶC
   - ZFI002 tự gọi ZCL_HDDT_FACTORY=>RESET( ) sau mỗi lần bảo trì

4. Phát hành 1 hoá đơn thật, kiểm tra:
   - ZTB_HDDT_INV: PROVIDER = FPT, SERIAL/SEQ có giá trị, STATUS = 40
   - ZTB_HDDT_LOG: HTTP 200, response có link tra cứu
   - Mở link tra cứu từ ALV (nhấn vào cột "Link")
```

**Không phải làm:** không transport, không activate, không restart hệ thống,
không sửa chương trình nào.

---

## 4. Rollback

Nếu FPT có sự cố trong ngày đầu:

```
ZTB_HDDT_PARM → ACTIVE_PROVIDER = VIETTEL
ZTB_HDDT_CRED → dòng VIETTEL: VALID_TO = 31.12.9999
```

Hoá đơn đã phát hành qua FPT vẫn nguyên trong `ZTB_HDDT_INV` với
`PROVIDER = FPT`, và mọi nghiệp vụ tiếp theo trên các hoá đơn đó (huỷ, điều
chỉnh) vẫn đi qua adapter FPT — vì `ZCL_HDDT_SERVICE` lấy provider từ request,
và request điều chỉnh lấy provider từ sổ đăng ký của chứng từ gốc.

---

## 5. Checklist go-live

### Kỹ thuật

- [ ] Toàn bộ object active, `SLIN`/ATC không còn lỗi mức Error
- [ ] Table Maintenance Generator đã sinh cho 14 bảng
- [ ] STRUST đã có chain CA của môi trường **PROD** của nhà cung cấp
- [ ] SM59 destination test connection thành công (nút "Connection Test")
- [ ] Không còn `abapGit` ở cột Transport trong header các object
- [ ] `ZTB_HDDT_CONN` PROD dùng URL **PROD**, không phải `api-uat…`

### Nghiệp vụ

- [ ] Mẫu số và ký hiệu hoá đơn trong `ZTB_HDDT_CRED` **khớp thông báo phát
      hành đã được CQT chấp nhận**
- [ ] `ZTB_HDDT_MAP` `TAXRATE` phủ hết mã thuế `MWSKZ` đang dùng
- [ ] `ZTB_HDDT_MAP` `PAYMENT` phủ hết `ZLSCH` đang dùng
- [ ] `ZTB_HDDT_DATE` đúng chính sách kế toán (ngày lập hoá đơn không được nhỏ
      hơn ngày hiệu lực thông báo phát hành)
- [ ] Đối chiếu 10 hoá đơn UAT: tổng tiền, tiền thuế, tổng cộng khớp SAP
      **đến từng đồng** (bảng thuế lấy trực tiếp từ `BSET` nên phải khớp)
- [ ] Test hoá đơn ngoại tệ: cặp `sum`/`sumv` và `vat`/`vatv` đúng tỷ giá
- [ ] Test hoá đơn điều chỉnh tăng và điều chỉnh giảm
- [ ] Test huỷ hoá đơn + thông báo sai sót

### Bảo mật

- [ ] Mật khẩu API **không** nằm trong `ZTB_HDDT_CRED-APISECRET` ở PRD, hoặc
      bảng đã có authorization group riêng
- [ ] Developer **không** có `SE16`/`SE16N`/`S_TABU_NAM` trên `ZTB_HDDT_CRED` ở PRD
- [ ] `LOG_PAYLOAD = 'X'` (giữ log để đối chiếu thuế)
- [ ] Đã có kế hoạch lưu trữ / archiving cho `ZTB_HDDT_LOG` (bảng này lớn nhanh)

### Vận hành

- [ ] Job nền phát hành hàng ngày (nếu có) đã lên SM37 kèm cảnh báo khi lỗi
- [ ] Người vận hành biết dùng nút "Log" để tự đọc lỗi trước khi mở ticket
- [ ] Đã thống nhất với nhà cung cấp về hạn mức số lượng request / phút

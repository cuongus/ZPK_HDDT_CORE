# 14 — Chuyển package ZPK_MAG_HDDT sang ZPK_INT_HDDT

Hệ MAG S25 client 100, transport `S25K900150`. Đổi **package**, KHÔNG đổi
tên object: tiền tố `ZCL_HDDT_*` / `ZTB_HDDT_*` / `ZPG_HDDT_*` / `ZIN_HDDT_*`
giữ nguyên. Chuyển package là sửa TADIR nên không phải activate lại và không
sửa một dòng code nào.

## 1. Năm package phải tạo

Tên **bắt buộc đúng** như bảng dưới: `.abapgit.xml` khai
`FOLDER_LOGIC = PREFIX`, tên thư mục trong repo suy ra từ tên sub-package sau
khi bỏ tiền tố package cha. Đặt tên khác là abapGit tính ra thư mục khác và
coi toàn bộ object là mới, lần pull sau sinh trùng.

| Package mới | Thư mục repo | Mô tả (CTEXT trong repo) |
|---|---|---|
| `ZPK_INT_HDDT` | `/src/` | HDDT Core - Tich hop hoa don dien tu Viet Nam |
| `ZPK_INT_HDDT_DDIC` | `/src/ddic/` | HDDT Core - DDIC (bang cau hinh, log, kieu du lieu) |
| `ZPK_INT_HDDT_ENGINE` | `/src/engine/` | HDDT Core - Engine (service, http, config, log, factory) |
| `ZPK_INT_HDDT_PROV` | `/src/prov/` | HDDT Core - Provider adapters (Viettel / FPT / VNPT) |
| `ZPK_INT_HDDT_UI` | `/src/ui/` | HDDT Core - SAP GUI (report, ALV, config cockpit) |

Cha `ZPK_INT_HDDT` tạo trước, bốn package con khai Superpackage là cha.
Software component và transport layer copy y từ `ZPK_MAG_HDDT` — lệch là SAP
không cho gán object vào `S25K900150`.

## 2. Các bước

**Bước 1.** SE01 xem `S25K900150`: phải là **Workbench request**, còn mở,
owner là bạn.

**Bước 2.** SE21 hoặc SE80 tạo 5 package ở mục 1, gán vào `S25K900150`.

**Bước 3.** SE03 → **Change Object Directory Entries** → chọn theo package
nguồn → điền package đích → TR `S25K900150`. Làm lần lượt từng package con
theo thứ tự DDIC → ENGINE → PROV → UI, cuối cùng là các object nằm trực tiếp
ở package cha. Object nào đang khoá trong TR khác thì SE03 từ chối: release TR
đó hoặc dùng chính TR đó.

**Bước 4.** SE80 mở 5 package cũ, phải không còn object nào. Xong thì xoá 5
package cũ, cũng vào TR đó.

**Bước 5.** abapGit: mở repo → **Advanced → Remove** (chỉ bỏ liên kết) → Clone
lại vào `ZPK_INT_HDDT`. Đọc kỹ chữ trước khi bấm: **Remove** bỏ liên kết,
**Uninstall** XOÁ object khỏi hệ. Sau khi clone lại, diff phải bằng 0.

Repo không phải sửa gì: `.abapgit.xml` và 5 file `package.devc.xml` chỉ chứa
`CTEXT`, không chỗ nào ghi tên package.

## 3. Danh sách đối chiếu

Đếm theo repo tại commit hiện tại. Sau khi chuyển, số object trong package mới
phải khớp từng dòng.

| Loại | Số lượng |
|---|---|
| DEVC — Package | 5 |
| DOMA — Domain | 10 |
| DTEL — Data element | 53 |
| TABL — Table | 15 |
| INTF — Interface | 7 |
| CLAS — Class | 23 |
| PROG — Program / include | 6 |
| MSAG — Message class | 1 |
| TRAN — Transaction | 3 |
| **Tổng** | **123** |

### DOMA — Domain

`ZPK_INT_HDDT_DDIC` (10):

```
ZDO_HDDT_ACTION  ZDO_HDDT_ADJTYPE  ZDO_HDDT_AUTH
ZDO_HDDT_DATESRC  ZDO_HDDT_ITEMTYPE  ZDO_HDDT_MAPTYPE
ZDO_HDDT_METHOD  ZDO_HDDT_PROV  ZDO_HDDT_SRCTYPE
ZDO_HDDT_STATUS
```

### DTEL — Data element

`ZPK_INT_HDDT_DDIC` (53):

```
ZDE_HDDT_ACTION  ZDE_HDDT_ADJDIR  ZDE_HDDT_ADJTYPE
ZDE_HDDT_AMOUNT  ZDE_HDDT_APIVER  ZDE_HDDT_ATTEMPT
ZDE_HDDT_AUTH  ZDE_HDDT_CALLER  ZDE_HDDT_CLASS
ZDE_HDDT_CODEPAGE  ZDE_HDDT_CONNID  ZDE_HDDT_DATESRC
ZDE_HDDT_DESCR  ZDE_HDDT_DIRECT  ZDE_HDDT_DOCNO
ZDE_HDDT_HOST  ZDE_HDDT_IDKEY  ZDE_HDDT_INVTYPE
ZDE_HDDT_ITEMTYPE  ZDE_HDDT_JSON  ZDE_HDDT_LINENO
ZDE_HDDT_LINK  ZDE_HDDT_LOGID  ZDE_HDDT_MAILST
ZDE_HDDT_MAPTYPE  ZDE_HDDT_MAPVAL  ZDE_HDDT_METHOD
ZDE_HDDT_MSCQT  ZDE_HDDT_MSG  ZDE_HDDT_NAME
ZDE_HDDT_OBJTYPE  ZDE_HDDT_PARMKEY  ZDE_HDDT_PARMVAL
ZDE_HDDT_PATH  ZDE_HDDT_PROV  ZDE_HDDT_QTY
ZDE_HDDT_RATE  ZDE_HDDT_RAW  ZDE_HDDT_RCCODE
ZDE_HDDT_SEC  ZDE_HDDT_SECKEY  ZDE_HDDT_SECRET
ZDE_HDDT_SEQ  ZDE_HDDT_SERIAL  ZDE_HDDT_SIZE
ZDE_HDDT_SRCTYPE  ZDE_HDDT_STATUS  ZDE_HDDT_TAXCODE
ZDE_HDDT_TEMPL  ZDE_HDDT_TIMEOUT  ZDE_HDDT_TOKEN
ZDE_HDDT_URL  ZDE_HDDT_USER
```

### TABL — Table

`ZPK_INT_HDDT_DDIC` (15):

```
ZTB_HDDT_ACT  ZTB_HDDT_CONN  ZTB_HDDT_CRED
ZTB_HDDT_DATE  ZTB_HDDT_GOM  ZTB_HDDT_INV
ZTB_HDDT_ITEM  ZTB_HDDT_LOG  ZTB_HDDT_MAP
ZTB_HDDT_PARM  ZTB_HDDT_PROV  ZTB_HDDT_SRC
ZTB_HDDT_STAT  ZTB_HDDT_TOK  ZTB_HDDT_TPL
```

### INTF — Interface

`ZPK_INT_HDDT_ENGINE` (7):

```
ZIF_HDDT_LOG_SINK  ZIF_HDDT_PLATFORM  ZIF_HDDT_PROVIDER
ZIF_HDDT_SECRET  ZIF_HDDT_SOURCE  ZIF_HDDT_TYPES
ZIF_HDDT_WRITEBACK
```

### CLAS — Class

`ZPK_INT_HDDT_ENGINE` (18):

```
ZCL_HDDT_CONFIG  ZCL_HDDT_FACTORY  ZCL_HDDT_GOM
ZCL_HDDT_HTTP  ZCL_HDDT_JSON  ZCL_HDDT_LOG
ZCL_HDDT_MAIL  ZCL_HDDT_PLATFORM  ZCL_HDDT_PLAT_CLASSIC
ZCL_HDDT_SECRET  ZCL_HDDT_SERVICE  ZCL_HDDT_SRC_BASE
ZCL_HDDT_SRC_FI  ZCL_HDDT_SRC_GOM  ZCL_HDDT_SRC_SD
ZCL_HDDT_TOKEN  ZCL_HDDT_WRITEBACK_FI  ZCX_HDDT_ERROR
```

`ZPK_INT_HDDT_PROV` (5):

```
ZCL_HDDT_PROV_BASE  ZCL_HDDT_PROV_FPT  ZCL_HDDT_PROV_TEMPLATE
ZCL_HDDT_PROV_VIETTEL  ZCL_HDDT_PROV_VNPT
```

### PROG — Program / include

`ZPK_INT_HDDT_UI` (6):

```
ZIN_HDDT_INTEGRATION_F01  ZIN_HDDT_INTEGRATION_TOP  ZPG_HDDT_CONFIG
ZPG_HDDT_INTEGRATION  ZPG_HDDT_LOG  ZPG_HDDT_SETUP
```

### MSAG — Message class

`ZPK_INT_HDDT_ENGINE` (1):

```
ZMS_HDDT
```

### TRAN — Transaction

`ZPK_INT_HDDT_UI` (3):

```
ZFI001  ZFI002  ZFI003
```

## 4. Câu kiểm sau khi chuyển

Chạy trong SE16 trên `TADIR` hoặc qua MCP:

```sql
SELECT devclass, object, COUNT(*) AS cnt FROM tadir
  WHERE devclass LIKE 'ZPK_INT_HDDT%'
  GROUP BY devclass, object ORDER BY devclass ASCENDING, object ASCENDING
```

Và câu này phải trả về **0 dòng**:

```sql
SELECT devclass, object, obj_name FROM tadir
  WHERE devclass LIKE 'ZPK_MAG_HDDT%'
```

Kiểm TR đã gom đủ object:

```sql
SELECT pgmid, object, obj_name FROM e071
  WHERE trkorr = 'S25K900150' ORDER BY object ASCENDING, obj_name ASCENDING
```

[Unverified] Số dòng trong `E071` thường nhiều hơn 118 vì class và program
kéo theo sub-object (include, CLAS/OC + CLAS/OM...), và 5 dòng DEVC của package.


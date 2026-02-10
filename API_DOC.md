# EpusdtPay API 接口文档

> **Base URL**: `https://bocail.com`
> **Content-Type**: `application/json`
> **编码**: UTF-8

---

## 目录

1. [通用说明](#通用说明)
2. [商家认证 API](#商家认证-api)
3. [商家业务 API](#商家业务-api)
4. [授权支付 API](#授权支付-api)
5. [订单 API](#订单-api)
6. [钱包 API](#钱包-api)
7. [工具 API](#工具-api)
8. [管理后台 API](#管理后台-api)

---

## 通用说明

### 统一响应格式

所有接口返回 HTTP 200，通过 `status_code` 区分成功/失败：

```json
{
  "status_code": 200,
  "message": "success",
  "data": { ... },
  "request_id": ""
}
```

**失败响应：**
```json
{
  "status_code": 400,
  "message": "错误原因",
  "data": null,
  "request_id": ""
}
```

### 认证方式

#### 1. 商家 JWT 认证（Bearer Token）

商家登录后获取 token，在需要认证的接口中添加请求头：

```
Authorization: Bearer <token>
```

#### 2. 管理员 JWT 认证（Bearer Token）

管理员登录后获取 token，请求头同上。

#### 3. API 签名认证（HMAC-SHA256 / MD5）

用于订单、钱包、工具等 API 接口。请求体必须包含：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| signature | string | 是 | 签名值 |
| timestamp | int64 | 是 | Unix 秒级时间戳，±5分钟内有效 |
| nonce | string | 是 | 随机字符串，5分钟内不可重复 |
| sign_version | string | 否 | `"v2"` 使用 HMAC-SHA256（推荐），不传则用 MD5 |

**签名算法（v2 HMAC-SHA256）：**

```
1. 将请求参数（除 signature 外）按 key 字母升序排列
2. 拼接为 "key1=value1&key2=value2&..." 格式（空值不参与）
3. 使用 api_auth_token 作为密钥进行 HMAC-SHA256 签名
4. 结果为 hex 编码字符串
```

**Swift 示例：**
```swift
import CryptoKit

func generateSignature(params: [String: Any], apiToken: String) -> String {
    let filtered = params.filter { $0.key != "signature" && "\($0.value)" != "" }
    let sorted = filtered.sorted { $0.key < $1.key }
    let signStr = sorted.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    let key = SymmetricKey(data: Data(apiToken.utf8))
    let signature = HMAC<SHA256>.authenticationCode(for: Data(signStr.utf8), using: key)
    return Data(signature).map { String(format: "%02x", $0) }.joined()
}
```

---

## 商家认证 API

### POST /api/v1/merchant/register

商家注册（无需认证）

**请求体：**
```json
{
  "username": "merchant001",
  "password": "password123",
  "email": "merchant@example.com",
  "merchant_name": "我的商店",
  "wallet_token": "TRC20钱包地址"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| username | string | 是 | 用户名（3-32字符） |
| password | string | 是 | 密码（≥6字符） |
| email | string | 否 | 邮箱 |
| merchant_name | string | 是 | 商户名称 |
| wallet_token | string | 是 | 钱包地址 |

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "merchant": {
      "id": 1,
      "username": "merchant001",
      "email": "merchant@example.com",
      "merchant_name": "我的商店",
      "wallet_token": "TXxxxx...",
      "status": 1,
      "balance": 0,
      "usdt_rate": 7.2
    },
    "token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

---

### POST /api/v1/merchant/login

商家登录（无需认证）

**请求体：**
```json
{
  "username": "merchant001",
  "password": "password123"
}
```

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "merchant": {
      "id": 1,
      "username": "merchant001",
      "email": "merchant@example.com",
      "merchant_name": "我的商店",
      "wallet_token": "TXxxxx...",
      "status": 1,
      "balance": 100.5,
      "usdt_rate": 7.2,
      "last_login_at": "2026-02-10T12:00:00Z"
    },
    "token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

---

## 商家业务 API

> 以下接口均需 `Authorization: Bearer <merchant_token>`

### GET /api/v1/merchant/profile

获取商家信息

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "id": 1,
    "username": "merchant001",
    "email": "merchant@example.com",
    "merchant_name": "我的商店",
    "wallet_token": "TXxxxx...",
    "status": 1,
    "balance": 100.5,
    "usdt_rate": 7.2,
    "api_token": "xxxxx",
    "last_login_at": "2026-02-10T12:00:00Z"
  }
}
```

---

### POST /api/v1/merchant/qrcode

生成授权二维码

**请求体：**
```json
{
  "amount_usdt": 100.00,
  "table_no": "A01",
  "customer_name": "张三",
  "expire_minutes": 1440
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| amount_usdt | float | 是 | 授权 USDT 金额（>0） |
| table_no | string | 否 | 桌号/编号 |
| customer_name | string | 否 | 客户名称 |
| expire_minutes | int | 否 | 有效期分钟数（默认1440=24小时） |

---

### GET /api/v1/merchant/authorizations

获取授权列表（分页）

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| page | int | 否 | 页码（默认1） |
| page_size | int | 否 | 每页条数（默认20） |
| status | int | 否 | 0:全部 1:等待授权 2:授权有效 3:已撤销 4:额度已用尽 |

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "list": [...],
    "total": 50,
    "page": 1,
    "page_size": 20
  }
}
```

---

### GET /api/v1/merchant/authorizations/:id

获取授权详情

**路径参数：** `id` — 授权记录 ID

---

### DELETE /api/v1/merchant/authorizations/:id

撤销授权

**路径参数：** `id` — 授权记录 ID

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": "授权已撤销"
}
```

---

### GET /api/v1/merchant/deductions

获取扣款记录（分页）

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| page | int | 否 | 页码（默认1） |
| page_size | int | 否 | 每页条数（默认20） |
| status | int | 否 | 0:全部 1:处理中 2:成功 3:失败 |
| start_date | string | 否 | 起始日期 YYYY-MM-DD |
| end_date | string | 否 | 结束日期 YYYY-MM-DD |

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "list": [...],
    "total": 100,
    "page": 1,
    "page_size": 20
  }
}
```

---

### POST /api/v1/merchant/deductions

发起扣款

**请求体：**
```json
{
  "password": "授权密码",
  "amount_cny": 50.00,
  "product_info": "商品描述"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| password | string | 是 | 授权密码 |
| amount_cny | float | 是 | 扣款金额（CNY，>0） |
| product_info | string | 否 | 商品/服务描述 |

---

### GET /api/v1/merchant/deductions/:id

获取扣款详情

**路径参数：** `id` — 扣款记录编号

---

### GET /api/v1/merchant/stats/summary

获取统计汇总

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| period | string | 否 | `today` / `week` / `month`（默认 today） |

---

### GET /api/v1/merchant/stats/chart

获取图表数据

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| start_date | string | 是 | 起始日期 YYYY-MM-DD |
| end_date | string | 是 | 结束日期 YYYY-MM-DD |

---

### GET /api/v1/merchant/wallets

获取商家钱包列表

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": [
    {
      "id": 1,
      "token": "TXxxxx...",
      "chain": "TRON",
      "chain_id": 0,
      "merchant_id": 1,
      "status": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

---

### POST /api/v1/merchant/wallets

添加商家钱包

**请求体：**
```json
{
  "token": "0x1234...abcd",
  "chain": "BSC"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| token | string | 是 | 钱包地址 |
| chain | string | 是 | 链标识：`TRON` / `BSC` / `ETH` / `POLYGON` |

---

### DELETE /api/v1/merchant/wallets/:id

删除商家钱包

**路径参数：** `id` — 钱包记录 ID

---

### PUT /api/v1/merchant/wallets/status

更新商家钱包状态

**请求体：**
```json
{
  "id": 1,
  "status": 1
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | uint64 | 是 | 钱包 ID |
| status | int | 是 | 1:启用 2:禁用 |

---

## 授权支付 API

> 以下接口无需认证

### POST /api/v1/auth/create

创建授权请求

**请求体：**
```json
{
  "amount_usdt": 100.00,
  "table_no": "A01",
  "customer_name": "张三",
  "remark": "备注信息",
  "chain": "TRON"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| amount_usdt | float | 是 | 授权金额 USDT（>0） |
| table_no | string | 否 | 桌号 |
| customer_name | string | 否 | 客户名称 |
| remark | string | 否 | 备注 |
| chain | string | 否 | 链标识 |

---

### POST /api/v1/auth/confirm

确认授权（手动提交 tx_hash）

**请求体：**
```json
{
  "auth_no": "AUTH202602100001",
  "customer_wallet": "TXxxxx...",
  "tx_hash": "0xabc123..."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| auth_no | string | 是 | 授权编号 |
| customer_wallet | string | 是 | 客户钱包地址 |
| tx_hash | string | 是 | 区块链交易哈希 |

---

### POST /api/v1/auth/confirm-auto

自动确认授权（系统自动验证链上交易）

**请求体：**
```json
{
  "auth_no": "AUTH202602100001",
  "customer_wallet": "TXxxxx..."
}
```

---

### POST /api/v1/auth/deduct

从授权中扣款

**请求体：**
```json
{
  "password": "授权密码",
  "amount_cny": 50.00,
  "product_info": "商品描述",
  "operator_id": "operator001"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| password | string | 是 | 授权密码 |
| amount_cny | float | 是 | 扣款金额 CNY（>0） |
| product_info | string | 否 | 商品信息 |
| operator_id | string | 否 | 操作员 ID |

---

### GET /api/v1/auth/info/:password

获取授权信息

**路径参数：** `password` — 授权密码

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "auth_no": "AUTH202602100001",
    "password": "xxxx",
    "customer_wallet": "TXxxxx...",
    "authorized_usdt": 100.00,
    "used_usdt": 30.00,
    "remaining_usdt": 70.00,
    "status": 2,
    "table_no": "A01",
    "customer_name": "张三"
  }
}
```

---

### GET /api/v1/auth/history/:password

获取扣款历史

**路径参数：** `password` — 授权密码

---

### GET /api/v1/auth/list

获取所有有效授权列表

---

## 订单 API

### POST /api/v1/order/create-transaction

创建支付订单（需 API 签名认证）

**请求体：**
```json
{
  "order_id": "ORDER2026021001",
  "amount": 100.50,
  "notify_url": "https://your-site.com/callback",
  "redirect_url": "https://your-site.com/success",
  "chain": "TRON",
  "timestamp": 1739203200,
  "nonce": "random_string_abc123",
  "sign_version": "v2",
  "signature": "hmac_sha256_hex_string"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| order_id | string | 是 | 商户订单号（≤32字符） |
| amount | float | 是 | 支付金额（>0.01，≤1000000，最多2位小数） |
| notify_url | string | 是 | 异步回调地址 |
| redirect_url | string | 否 | 支付完成跳转地址 |
| chain | string | 否 | 指定链：`TRON`/`BSC`/`ETH`/`POLYGON` |
| timestamp | int64 | 是 | Unix 秒级时间戳 |
| nonce | string | 是 | 随机字符串 |
| sign_version | string | 否 | `"v2"` 推荐 |
| signature | string | 是 | 签名 |

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "trade_id": "EP202602100001",
    "order_id": "ORDER2026021001",
    "amount": 100.50,
    "actual_amount": 100.5000,
    "token": "TXxxxx...",
    "chain": "TRON",
    "expiration_time": 1739203800,
    "payment_url": "https://bocail.com/pay/checkout-counter/EP202602100001"
  }
}
```

---

### GET /pay/check-status/:trade_id

检查支付状态（无需认证）

**路径参数：** `trade_id` — epusdt 订单号

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "trade_id": "EP202602100001",
    "status": 1
  }
}
```

**status 值说明：** 1:等待支付 2:支付成功 3:已过期

---

## 钱包 API

> 以下接口均需 API 签名认证（timestamp + nonce + signature）

### POST /api/v1/wallet/add

添加钱包地址

**请求体：**
```json
{
  "token": "TXxxxx...",
  "chain": "TRON",
  "timestamp": 1739203200,
  "nonce": "random123",
  "sign_version": "v2",
  "signature": "..."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| token | string | 是 | 钱包地址 |
| chain | string | 否 | 链标识（默认 TRON），支持：`TRON`/`BSC`/`ETH`/`POLYGON` |

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "wallet": { "id": 1, "token": "TXxxxx...", "chain": "TRON", "status": 1, ... },
    "qrcode_content": "TXxxxx...",
    "qrcode_stream_url": "/qrcode?content=TXxxxx..."
  }
}
```

---

### POST /api/v1/wallet/list

获取钱包列表

---

### POST /api/v1/wallet/update-status

更新钱包状态

**请求体：**
```json
{
  "id": 1,
  "status": 2,
  "timestamp": 1739203200,
  "nonce": "random123",
  "signature": "..."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | uint64 | 是 | 钱包 ID |
| status | int | 是 | 1:启用 2:禁用 |

---

### POST /api/v1/wallet/delete

删除钱包

**请求体：**
```json
{
  "id": 1,
  "timestamp": 1739203200,
  "nonce": "random123",
  "signature": "..."
}
```

---

## 工具 API

### POST /api/v1/tool/qrcode

生成二维码（需 API 签名认证）

**请求体：**
```json
{
  "content": "https://example.com",
  "size": 256,
  "timestamp": 1739203200,
  "nonce": "random123",
  "signature": "..."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| content | string | 是 | 二维码内容 |
| size | int | 否 | 尺寸 128~1024（默认256） |

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "content": "https://example.com",
    "size": 256,
    "image": "base64编码的PNG图片..."
  }
}
```

---

### GET /qrcode

二维码图片流（无需认证，直接返回 PNG 图片）

**Query 参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| content | string | 是 | 二维码内容 |
| size | int | 否 | 尺寸 128~1024（默认256） |

**响应：** `Content-Type: image/png`（二进制图片流）

---

## 管理后台 API

### POST /admin/api/login

管理员登录（无需认证）

**请求体：**
```json
{
  "username": "admin",
  "password": "admin123"
}
```

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

---

> 以下接口均需 `Authorization: Bearer <admin_token>`

### GET /admin/api/me

获取当前管理员信息

---

### GET /admin/api/users

获取管理员列表

---

### POST /admin/api/users

创建管理员

**请求体：**
```json
{
  "username": "newadmin",
  "password": "password123",
  "role_id": 1
}
```

---

### PUT /admin/api/users

更新管理员

**请求体：**
```json
{
  "id": 1,
  "password": "newpassword",
  "status": 1,
  "role_id": 1
}
```

---

### GET /admin/api/roles

获取角色列表

---

### GET /admin/api/orders

获取订单列表（最近200条）

---

### GET /admin/api/order/:trade_id

获取订单详情

**成功响应：**
```json
{
  "status_code": 200,
  "message": "success",
  "data": {
    "trade_id": "EP202602100001",
    "order_id": "ORDER001",
    "amount": 100.50,
    "actual_amount": 100.5000,
    "token": "TXxxxx...",
    "chain": "TRON",
    "status": 2,
    "status_text": "支付成功",
    "block_transaction_id": "0xabc...",
    "notify_url": "https://...",
    "redirect_url": "https://...",
    "callback_num": 1,
    "callback_confirm": 1,
    "callback_text": "已确认",
    "block_explorer_url": "https://tronscan.org/#/transaction/...",
    "wallet_explorer_url": "https://tronscan.org/#/address/...",
    "created_at": "2026-02-10 12:00:00",
    "updated_at": "2026-02-10 12:05:00",
    "callback_logs": [...]
  }
}
```

---

### GET /admin/api/authorizations

获取授权列表

### GET /admin/api/deductions

获取扣款列表

### GET /admin/api/callbacks

获取回调日志

### GET /admin/api/merchants

获取商家列表

### PUT /admin/api/merchants/ban

封禁/解封商家

**请求体：**
```json
{
  "id": 1,
  "status": 2
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | uint64 | 是 | 商家 ID |
| status | int | 是 | 1:解封 2:封禁 |

---

### GET /admin/api/wallets

获取所有钱包

### POST /admin/api/wallets/add

添加钱包（同 `/api/v1/wallet/add`）

### POST /admin/api/wallets/update-status

更新钱包状态

### POST /admin/api/wallets/delete

删除钱包

---

## 支持的链标识

| 链标识 | 说明 | 区块链浏览器 |
|--------|------|-------------|
| `TRON` | 波场 TRC20 | tronscan.org |
| `BSC` | 币安智能链 BEP20 | bscscan.com |
| `ETH` / `EVM` | 以太坊 ERC20 | etherscan.io |
| `POLYGON` | Polygon | polygonscan.com |

---

## 异步回调通知

当订单支付成功后，系统会向 `notify_url` 发送 POST 请求：

```json
{
  "trade_id": "EP202602100001",
  "order_id": "ORDER001",
  "amount": 100.50,
  "actual_amount": 100.5000,
  "token": "TXxxxx...",
  "chain": "TRON",
  "block_transaction_id": "0xabc...",
  "signature": "签名值",
  "status": 2
}
```

商户收到回调后需返回 `ok` 字符串表示确认。

---

## iOS 接入快速参考

### 1. 网络层配置

```swift
// BaseURL
let baseURL = "https://bocail.com"

// 商家登录获取 Token
func login(username: String, password: String) async throws -> String {
    let url = URL(string: "\(baseURL)/api/v1/merchant/login")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode([
        "username": username,
        "password": password
    ])
    let (data, _) = try await URLSession.shared.data(for: request)
    let resp = try JSONDecoder().decode(APIResponse<LoginData>.self, from: data)
    return resp.data.token
}
```

### 2. 通用响应模型

```swift
struct APIResponse<T: Codable>: Codable {
    let statusCode: Int
    let message: String
    let data: T
    let requestId: String

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case message
        case data
        case requestId = "request_id"
    }
}
```

### 3. 认证请求封装

```swift
class APIClient {
    static let shared = APIClient()
    var token: String = ""

    func request<T: Codable>(_ method: String, path: String, body: [String: Any]? = nil) async throws -> T {
        let url = URL(string: "https://bocail.com\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(APIResponse<T>.self, from: data).data
    }
}
```

---

## 错误码参考

| status_code | 说明 |
|-------------|------|
| 200 | 成功 |
| 400 | 请求参数错误 / 业务错误 |
| 401 | 未认证 / Token 无效或过期 |
| 403 | 账户被封禁 |
| 500 | 服务器内部错误 |

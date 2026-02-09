-- auto-generated definition
create table orders
(
    id                   int auto_increment
        primary key,
    trade_id             varchar(32)    not null comment 'epusdt订单号',
    order_id             varchar(32)    not null comment '客户交易id',
    block_transaction_id varchar(128)   null comment '区块唯一编号',
    actual_amount        decimal(19, 4) not null comment '订单实际需要支付的金额，保留4位小数',
    amount               decimal(19, 4) not null comment '订单金额，保留4位小数',
    token                varchar(50)    not null comment '所属钱包地址',
    status               int default 1  not null comment '1：等待支付，2：支付成功，3：已过期',
    notify_url           varchar(128)   not null comment '异步回调地址',
    redirect_url         varchar(128)   null comment '同步回调地址',
    callback_num         int default 0  null comment '回调次数',
    callback_confirm     int default 2  null comment '回调是否已确认？ 1是 2否',
    created_at           timestamp      null,
    updated_at           timestamp      null,
    deleted_at           timestamp      null,
    constraint orders_order_id_uindex
        unique (order_id),
    constraint orders_trade_id_uindex
        unique (trade_id)
);

create index orders_block_transaction_id_index
    on orders (block_transaction_id);

-- auto-generated definition
create table wallet_address
(
    id         int auto_increment
        primary key,
    token      varchar(50)   not null comment '钱包token',
    status     int default 1 not null comment '1:启用 2:禁用',
    created_at timestamp     null,
    updated_at timestamp     null,
    deleted_at timestamp     null
)
    comment '钱包表';

create index wallet_address_token_index
    on wallet_address (token);

-- KTV授权支付表
create table ktv_authorizes
(
    id                  int auto_increment
        primary key,
    auth_no             varchar(50)    not null comment '授权编号',
    password            varchar(20)    not null comment '密码凭证',
    encrypted_password  blob           null comment '加密后的密码',
    password_nonce      binary(12)     null comment 'AES-GCM nonce',
    password_salt       binary(16)     null comment 'Argon2id salt',
    customer_wallet     varchar(100)   null comment '客户钱包地址',
    merchant_wallet     varchar(100)   not null comment '商家收款钱包',
    chain               varchar(20)    default 'TRON' not null comment '链标识（TRON/BSC/ETH/POLYGON）',
    authorized_usdt     decimal(19, 6) not null comment '授权额度(USDT)',
    used_usdt           decimal(19, 6) default 0 not null comment '已使用额度(USDT)',
    remaining_usdt      decimal(19, 6) not null comment '剩余额度(USDT)',
    status              int            default 1 not null comment '1:等待授权 2:授权有效 3:已撤销 4:额度已用尽',
    table_no            varchar(50)    null comment '桌号',
    customer_name       varchar(100)   null comment '客户名称',
    tx_hash             varchar(128)   null comment '授权交易哈希',
    authorize_time      bigint         null comment '授权时间戳',
    expire_time         bigint         not null comment '过期时间戳',
    remark              varchar(255)   null comment '备注',
    created_at          timestamp      null,
    updated_at          timestamp      null,
    deleted_at          timestamp      null,
    constraint ktv_authorizes_auth_no_uindex
        unique (auth_no),
    constraint ktv_authorizes_password_uindex
        unique (password)
)
    comment 'KTV授权支付表';

create index ktv_authorizes_customer_wallet_index
    on ktv_authorizes (customer_wallet);

create index ktv_authorizes_status_index
    on ktv_authorizes (status);

-- KTV扣款记录表
create table ktv_deductions
(
    id           int auto_increment
        primary key,
    deduct_no    varchar(50)    not null comment '扣款单号',
    auth_id      bigint         not null comment '授权ID',
    auth_no      varchar(50)    not null comment '授权编号',
    password     varchar(20)    not null comment '密码凭证',
    amount_usdt  decimal(19, 6) not null comment '扣款金额(USDT)',
    amount_cny   decimal(19, 2) not null comment '扣款金额(CNY)',
    tx_hash      varchar(128)   null comment '扣款交易哈希',
    status       int            default 1 not null comment '1:处理中 2:成功 3:失败',
    fail_reason  varchar(255)   null comment '失败原因',
    product_info varchar(500)   null comment '消费内容',
    operator_id  varchar(50)    null comment '操作员',
    deduct_time  bigint         not null comment '扣款时间戳',
    created_at   timestamp      null,
    updated_at   timestamp      null,
    deleted_at   timestamp      null,
    constraint ktv_deductions_deduct_no_uindex
        unique (deduct_no)
)
    comment 'KTV扣款记录表';

create index ktv_deductions_auth_id_index
    on ktv_deductions (auth_id);

create index ktv_deductions_password_index
    on ktv_deductions (password);

create index ktv_deductions_status_index
    on ktv_deductions (status);

-- 管理员角色表
create table admin_roles
(
    id          int auto_increment
        primary key,
    name        varchar(50)  not null comment '角色名称',
    description varchar(255) null comment '角色描述',
    created_at  timestamp    null,
    updated_at  timestamp    null,
    deleted_at  timestamp    null,
    constraint admin_roles_name_uindex
        unique (name)
)
    comment '管理员角色表';

-- 管理员用户表
create table admin_users
(
    id         int auto_increment
        primary key,
    username   varchar(50)  not null comment '用户名',
    password   varchar(255) not null comment '密码（哈希）',
    role_id    int          default 0 not null comment '角色ID',
    email      varchar(100) null comment '邮箱',
    status     int          default 1 not null comment '1:启用 2:禁用',
    created_at timestamp    null,
    updated_at timestamp    null,
    deleted_at timestamp    null,
    constraint admin_users_username_uindex
        unique (username)
)
    comment '管理员用户表';

create index admin_users_role_id_index
    on admin_users (role_id);

-- 回调日志表
create table callback_logs
(
    id               int auto_increment
        primary key,
    trade_id         varchar(32)  not null comment '订单交易号',
    notify_url       varchar(128) not null comment '回调地址',
    request_body     text         null comment '请求内容',
    response_body    text         null comment '响应内容',
    status_code      int          null comment 'HTTP状态码',
    retry_count      int          default 0 not null comment '重试次数',
    success          int          default 2 not null comment '1:成功 2:失败',
    error_message    varchar(500) null comment '错误信息',
    created_at       timestamp    null,
    updated_at       timestamp    null,
    deleted_at       timestamp    null
)
    comment '回调日志表';

create index callback_logs_trade_id_index
    on callback_logs (trade_id);

create index callback_logs_success_index
    on callback_logs (success);


-- 商家表
create table merchants
(
    id            int auto_increment
        primary key,
    username      varchar(64)     not null comment '商家用户名',
    password_hash varchar(128)    not null comment '密码哈希',
    email         varchar(128)    null comment '邮箱',
    merchant_name varchar(128)    not null comment '商家名称',
    wallet_token  varchar(100)    not null comment '关联钱包地址',
    status        int             default 1 not null comment '1:启用 2:禁用',
    api_token     varchar(128)    not null comment 'API令牌',
    usdt_rate     decimal(10, 4)  default 6.5 not null comment 'USDT汇率',
    balance       decimal(19, 6)  default 0 not null comment '商家余额（USDT）',
    last_login_at bigint          null comment '最后登录时间',
    created_at    timestamp       null,
    updated_at    timestamp       null,
    deleted_at    timestamp       null,
    constraint merchants_username_uindex
        unique (username),
    constraint merchants_api_token_uindex
        unique (api_token)
)
    comment '商家表';

create index merchants_wallet_token_index
    on merchants (wallet_token);

create index merchants_status_index
    on merchants (status);


-- 审计日志表
create table audit_logs
(
    id              bigint auto_increment
        primary key,
    event_type      varchar(50)  not null comment '事件类型',
    auth_no         varchar(50)  null comment '授权编号',
    customer_wallet varchar(100) null comment '客户钱包',
    operator_id     varchar(50)  null comment '操作员',
    ip_address      varchar(50)  null comment 'IP 地址',
    user_agent      varchar(255) null comment '客户端信息',
    request_data    text         null comment '请求数据（脱敏）',
    response_status int          null comment '响应状态码',
    error_message   varchar(500) null comment '错误信息',
    timestamp       bigint       not null comment '时间戳',
    tx_hash         varchar(128) null comment '交易哈希',
    created_at      timestamp    null
)
    comment '安全审计日志';

create index audit_logs_event_type_index
    on audit_logs (event_type);

create index audit_logs_auth_no_index
    on audit_logs (auth_no);

create index audit_logs_customer_wallet_index
    on audit_logs (customer_wallet);

create index audit_logs_timestamp_index
    on audit_logs (timestamp);

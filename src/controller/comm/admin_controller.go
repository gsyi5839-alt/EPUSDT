package comm

import (
	"errors"

	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/assimon/luuu/model/service"
	"github.com/gookit/goutil/mathutil"
	"github.com/labstack/echo/v4"
	"golang.org/x/crypto/bcrypt"
)

// AdminLogin 管理员登录
func (c *BaseCommController) AdminLogin(ctx echo.Context) error {
	type LoginRequest struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	req := new(LoginRequest)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}
	if req.Username == "" || req.Password == "" {
		return c.FailJson(ctx, errors.New("用户名和密码不能为空"))
	}
	token, err := service.AdminLogin(req.Username, req.Password)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, map[string]interface{}{
		"token": token,
	})
}

// AdminMe 当前管理员
func (c *BaseCommController) AdminMe(ctx echo.Context) error {
	idRaw := ctx.Get("admin_user_id")
	id := uint64(mathutil.MustUint(idRaw))
	user, err := service.GetAdminUserById(id)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, user)
}

// AdminListUsers 列出管理员
func (c *BaseCommController) AdminListUsers(ctx echo.Context) error {
	users, err := data.ListAdminUsers()
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, users)
}

// AdminCreateUser 创建管理员
func (c *BaseCommController) AdminCreateUser(ctx echo.Context) error {
	type Request struct {
		Username string `json:"username" validate:"required"`
		Password string `json:"password" validate:"required"`
		RoleID   uint64 `json:"role_id"`
	}
	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}
	if err := c.ValidateStruct(ctx, req); err != nil {
		return c.FailJson(ctx, err)
	}
	exist, err := data.GetAdminUserByUsername(req.Username)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	if exist.ID > 0 {
		return c.FailJson(ctx, errors.New("账号已存在"))
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	roleID := req.RoleID
	if roleID == 0 {
		role, _ := data.GetAdminRoleByName("admin")
		if role.ID == 0 {
			role = &mdb.AdminRole{Name: "admin"}
			_ = data.CreateAdminRole(role)
		}
		roleID = role.ID
	}
	user := &mdb.AdminUser{
		Username:     req.Username,
		PasswordHash: string(hash),
		RoleID:       roleID,
		Status:       1,
	}
	if err := data.CreateAdminUser(user); err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, user)
}

// AdminUpdateUser 更新管理员
func (c *BaseCommController) AdminUpdateUser(ctx echo.Context) error {
	type Request struct {
		ID       uint64 `json:"id" validate:"required|gt:0"`
		Password string `json:"password"`
		Status   int    `json:"status"`
		RoleID   uint64 `json:"role_id"`
	}
	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}
	if err := c.ValidateStruct(ctx, req); err != nil {
		return c.FailJson(ctx, err)
	}
	user, err := data.GetAdminUserById(req.ID)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	if user.ID == 0 {
		return c.FailJson(ctx, errors.New("用户不存在"))
	}
	if req.Password != "" {
		hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			return c.FailJson(ctx, err)
		}
		user.PasswordHash = string(hash)
	}
	if req.Status != 0 {
		user.Status = req.Status
	}
	if req.RoleID != 0 {
		user.RoleID = req.RoleID
	}
	if err := data.UpdateAdminUser(user); err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, "ok")
}

// AdminListRoles 列出角色
func (c *BaseCommController) AdminListRoles(ctx echo.Context) error {
	roles, err := data.ListAdminRoles()
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, roles)
}

// AdminListOrders 订单列表
func (c *BaseCommController) AdminListOrders(ctx echo.Context) error {
	orders, err := data.ListOrders(200)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, orders)
}

// AdminListAuthorizations 授权列表
func (c *BaseCommController) AdminListAuthorizations(ctx echo.Context) error {
	auths, err := data.ListAuthorizations(200)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, auths)
}

// AdminListDeductions 扣款列表
func (c *BaseCommController) AdminListDeductions(ctx echo.Context) error {
	deducts, err := data.ListDeductions(200)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, deducts)
}

// AdminListCallbacks 回调日志
func (c *BaseCommController) AdminListCallbacks(ctx echo.Context) error {
	logs, err := data.ListCallbackLogs()
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, logs)
}

// OrderDetailAPI 订单详情接口（返回JSON）
func (c *BaseCommController) OrderDetailAPI(ctx echo.Context) error {
	tradeId := ctx.Param("trade_id")
	if tradeId == "" {
		return c.FailJson(ctx, errors.New("trade_id不能为空"))
	}
	detail, err := service.GetOrderDetailByTradeId(tradeId)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, detail)
}

// AdminOrderDetailAPI 管理后台订单详情接口（需要登录）
func (c *BaseCommController) AdminOrderDetailAPI(ctx echo.Context) error {
	tradeId := ctx.Param("trade_id")
	if tradeId == "" {
		return c.FailJson(ctx, errors.New("trade_id不能为空"))
	}
	detail, err := service.GetOrderDetailByTradeId(tradeId)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, detail)
}

// ==================== 商家管理 ====================

// AdminListMerchants 列出所有商家
func (c *BaseCommController) AdminListMerchants(ctx echo.Context) error {
	merchants, err := data.ListMerchants(500)
	if err != nil {
		return c.FailJson(ctx, err)
	}
	return c.SucJson(ctx, merchants)
}

// AdminBanMerchant 封禁/解封商家
func (c *BaseCommController) AdminBanMerchant(ctx echo.Context) error {
	type Request struct {
		ID     uint64 `json:"id" validate:"required|gt:0"`
		Status int    `json:"status" validate:"required|in:1,2"` // 1:解封 2:封禁
	}
	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}
	if err := c.ValidateStruct(ctx, req); err != nil {
		return c.FailJson(ctx, err)
	}

	// 检查商家是否存在
	merchant, err := data.GetMerchantByID(req.ID)
	if err != nil || merchant.ID == 0 {
		return c.FailJson(ctx, errors.New("商家不存在"))
	}

	// 更新状态
	if err := data.UpdateMerchantStatus(req.ID, req.Status); err != nil {
		return c.FailJson(ctx, err)
	}

	action := "解封"
	if req.Status == 2 {
		action = "封禁"
	}
	return c.SucJson(ctx, action+"成功")
}

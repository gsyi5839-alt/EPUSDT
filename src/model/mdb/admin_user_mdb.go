package mdb

// AdminUser 管理员表
type AdminUser struct {
	Username     string `gorm:"column:username;type:varchar(64);uniqueIndex" json:"username"`
	PasswordHash string `gorm:"column:password_hash;type:varchar(128)" json:"-"`
	RoleID       uint64 `gorm:"column:role_id" json:"role_id"`
	Status       int    `gorm:"column:status;default:1" json:"status"` // 1启用 2禁用
	BaseModel
}

func (a *AdminUser) TableName() string {
	return "admin_users"
}

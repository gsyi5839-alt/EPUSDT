package mdb

// AdminRole 管理角色表（不做权限分级，仅用于标识）
type AdminRole struct {
	Name string `gorm:"column:name;type:varchar(50);uniqueIndex" json:"name"`
	BaseModel
}

func (a *AdminRole) TableName() string {
	return "admin_roles"
}

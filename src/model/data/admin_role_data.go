package data

import (
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/mdb"
)

func GetAdminRoleByName(name string) (*mdb.AdminRole, error) {
	role := new(mdb.AdminRole)
	err := dao.Mdb.Model(role).Limit(1).Find(role, "name = ?", name).Error
	return role, err
}

func CreateAdminRole(role *mdb.AdminRole) error {
	return dao.Mdb.Create(role).Error
}

func ListAdminRoles() ([]mdb.AdminRole, error) {
	var roles []mdb.AdminRole
	err := dao.Mdb.Model(&mdb.AdminRole{}).Order("id asc").Find(&roles).Error
	return roles, err
}

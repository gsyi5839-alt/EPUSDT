package data

import (
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/mdb"
)

func GetAdminUserByUsername(username string) (*mdb.AdminUser, error) {
	user := new(mdb.AdminUser)
	err := dao.Mdb.Model(user).Limit(1).Find(user, "username = ?", username).Error
	return user, err
}

func GetAdminUserById(id uint64) (*mdb.AdminUser, error) {
	user := new(mdb.AdminUser)
	err := dao.Mdb.Model(user).Limit(1).Find(user, "id = ?", id).Error
	return user, err
}

func CreateAdminUser(user *mdb.AdminUser) error {
	return dao.Mdb.Create(user).Error
}

func UpdateAdminUser(user *mdb.AdminUser) error {
	return dao.Mdb.Model(&mdb.AdminUser{}).Where("id = ?", user.ID).Updates(map[string]interface{}{
		"username":      user.Username,
		"password_hash": user.PasswordHash,
		"role_id":       user.RoleID,
		"status":        user.Status,
	}).Error
}

func ListAdminUsers() ([]mdb.AdminUser, error) {
	var users []mdb.AdminUser
	err := dao.Mdb.Model(&mdb.AdminUser{}).Order("id desc").Find(&users).Error
	return users, err
}

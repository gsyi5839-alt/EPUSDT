package service

import (
	"errors"
	"time"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/golang-jwt/jwt"
	"golang.org/x/crypto/bcrypt"
)

func EnsureDefaultAdmin() error {
	username := config.GetAdminInitUsername()
	password := config.GetAdminInitPassword()
	if username == "" || password == "" {
		return nil
	}
	exist, err := data.GetAdminUserByUsername(username)
	if err != nil {
		return err
	}
	if exist.ID > 0 {
		return nil
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	role, err := data.GetAdminRoleByName("admin")
	if err != nil {
		return err
	}
	if role.ID == 0 {
		role = &mdb.AdminRole{Name: "admin"}
		if err := data.CreateAdminRole(role); err != nil {
			return err
		}
	}
	return data.CreateAdminUser(&mdb.AdminUser{
		Username:     username,
		PasswordHash: string(hash),
		RoleID:       role.ID,
		Status:       1,
	})
}

func AdminLogin(username, password string) (string, error) {
	user, err := data.GetAdminUserByUsername(username)
	if err != nil {
		return "", err
	}
	if user.ID == 0 || user.Status != 1 {
		return "", errors.New("账号不存在或已禁用")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return "", errors.New("账号或密码错误")
	}

	claims := jwt.MapClaims{
		"user_id":  user.ID,
		"username": user.Username,
		"exp":      time.Now().Add(24 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(config.GetAdminJwtSecret()))
}

func GetAdminUserById(id uint64) (*mdb.AdminUser, error) {
	return data.GetAdminUserById(id)
}

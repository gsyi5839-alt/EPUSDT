package data

import (
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/mdb"
)

func ListOrders(limit int) ([]mdb.Orders, error) {
	var orders []mdb.Orders
	if limit <= 0 {
		limit = 200
	}
	err := dao.Mdb.Model(&mdb.Orders{}).Order("id desc").Limit(limit).Find(&orders).Error
	return orders, err
}

func ListAuthorizations(limit int) ([]mdb.KtvAuthorize, error) {
	var auths []mdb.KtvAuthorize
	if limit <= 0 {
		limit = 200
	}
	err := dao.Mdb.Model(&mdb.KtvAuthorize{}).Order("id desc").Limit(limit).Find(&auths).Error
	return auths, err
}

func ListDeductions(limit int) ([]mdb.KtvDeduction, error) {
	var deducts []mdb.KtvDeduction
	if limit <= 0 {
		limit = 200
	}
	err := dao.Mdb.Model(&mdb.KtvDeduction{}).Order("id desc").Limit(limit).Find(&deducts).Error
	return deducts, err
}

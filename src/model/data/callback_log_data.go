package data

import (
	"github.com/assimon/luuu/model/dao"
	"github.com/assimon/luuu/model/mdb"
)

func CreateCallbackLog(log *mdb.CallbackLog) error {
	return dao.Mdb.Create(log).Error
}

func ListCallbackLogs() ([]mdb.CallbackLog, error) {
	var logs []mdb.CallbackLog
	err := dao.Mdb.Model(&mdb.CallbackLog{}).Order("id desc").Limit(200).Find(&logs).Error
	return logs, err
}

package mdb

// CallbackLog 回调日志
type CallbackLog struct {
	TradeId       string `gorm:"column:trade_id;index" json:"trade_id"`
	OrderId       string `gorm:"column:order_id;index" json:"order_id"`
	NotifyUrl     string `gorm:"column:notify_url;type:varchar(255)" json:"notify_url"`
	RequestBody   string `gorm:"column:request_body;type:text" json:"request_body"`
	ResponseBody  string `gorm:"column:response_body;type:text" json:"response_body"`
	StatusCode    int    `gorm:"column:status_code" json:"status_code"`
	Success       int    `gorm:"column:success;default:0" json:"success"` // 1成功 0失败
	ErrorMessage  string `gorm:"column:error_message;type:varchar(255)" json:"error_message"`
	BaseModel
}

func (c *CallbackLog) TableName() string {
	return "callback_logs"
}

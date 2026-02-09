package handle

import (
	"context"
	"errors"

	"github.com/assimon/luuu/config"
	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/model/mdb"
	"github.com/assimon/luuu/model/response"
	"github.com/assimon/luuu/util/http_client"
	"github.com/assimon/luuu/util/json"
	"github.com/assimon/luuu/util/log"
	"github.com/assimon/luuu/util/sign"
	"github.com/hibiken/asynq"
)

const QueueOrderCallback = "order:callback"

func NewOrderCallbackQueue(order *mdb.Orders) (*asynq.Task, error) {
	payload, err := json.Cjson.Marshal(order)
	if err != nil {
		return nil, err
	}
	return asynq.NewTask(QueueOrderCallback, payload,
		asynq.Retention(config.GetOrderExpirationTimeDuration()),
	), nil
}

func OrderCallbackHandle(ctx context.Context, t *asynq.Task) error {
	var order mdb.Orders
	err := json.Cjson.Unmarshal(t.Payload(), &order)
	if err != nil {
		return err
	}
	defer func() {
		if err := recover(); err != nil {
			log.Sugar.Error(err)
		}
	}()
	defer func() {
		data.SaveCallBackOrdersResp(&order)
	}()
	client := http_client.GetHttpClient()
	orderResp := response.OrderNotifyResponse{
		TradeId:            order.TradeId,
		OrderId:            order.OrderId,
		Amount:             order.Amount,
		ActualAmount:       order.ActualAmount,
		Token:              order.Token,
		Chain:              order.Chain,
		BlockTransactionId: order.BlockTransactionId,
		Status:             mdb.StatusPaySuccess,
	}
	signature, err := sign.Get(orderResp, config.GetApiAuthToken())
	if err != nil {
		return err
	}
	orderResp.Signature = signature
	resp, err := client.R().SetHeader("powered-by", "Epusdt(https://github.com/assimon/epusdt)").SetBody(orderResp).Post(order.NotifyUrl)
	if err != nil {
		_ = data.CreateCallbackLog(&mdb.CallbackLog{
			TradeId:      order.TradeId,
			OrderId:      order.OrderId,
			NotifyUrl:    order.NotifyUrl,
			RequestBody:  string(jsonBytes(orderResp)),
			ResponseBody: "",
			StatusCode:   0,
			Success:      0,
			ErrorMessage: err.Error(),
		})
		return err
	}
	body := string(resp.Body())
	_ = data.CreateCallbackLog(&mdb.CallbackLog{
		TradeId:      order.TradeId,
		OrderId:      order.OrderId,
		NotifyUrl:    order.NotifyUrl,
		RequestBody:  string(jsonBytes(orderResp)),
		ResponseBody: body,
		StatusCode:   resp.StatusCode(),
		Success:      boolToInt(body == "ok"),
		ErrorMessage: "",
	})
	if body != "ok" {
		order.CallBackConfirm = mdb.CallBackConfirmNo
		return errors.New("not ok")
	}
	order.CallBackConfirm = mdb.CallBackConfirmOk
	return nil
}

func boolToInt(v bool) int {
	if v {
		return 1
	}
	return 0
}

func jsonBytes(v interface{}) []byte {
	b, _ := json.Cjson.Marshal(v)
	return b
}

package service

import (
	"sync"
	"time"
	
	"github.com/assimon/luuu/model/data"
	"github.com/assimon/luuu/util/log"
)

// InstantMonitor 即时监控服务
type InstantMonitor struct {
	activeMonitors map[string]*MonitorSession
	mutex          sync.RWMutex
}

// MonitorSession 监控会话
type MonitorSession struct {
	tradeId     string
	token       string
	isActive    bool
	stopChan    chan struct{}
	wg          sync.WaitGroup
}

var instantMonitor *InstantMonitor
var once sync.Once

// GetInstantMonitor 获取即时监控实例
func GetInstantMonitor() *InstantMonitor {
	once.Do(func() {
		instantMonitor = &InstantMonitor{
			activeMonitors: make(map[string]*MonitorSession),
		}
	})
	return instantMonitor
}

// StartMonitoringForOrder 为特定订单启动即时监控
func (im *InstantMonitor) StartMonitoringForOrder(tradeId, token string) error {
	im.mutex.Lock()
	defer im.mutex.Unlock()
	
	// 检查是否已经在监控
	if session, exists := im.activeMonitors[tradeId]; exists && session.isActive {
		log.Sugar.Infof("订单 %s 已在监控中", tradeId)
		return nil
	}
	
	// 创建新的监控会话
	session := &MonitorSession{
		tradeId:  tradeId,
		token:    token,
		isActive: true,
		stopChan: make(chan struct{}),
	}
	
	im.activeMonitors[tradeId] = session
	
	// 启动监控协程
	session.wg.Add(1)
	go im.monitorOrder(session)
	
	log.Sugar.Infof("开始监控订单: %s, 钱包地址: %s", tradeId, token)
	return nil
}

// StopMonitoringForOrder 停止特定订单的监控
func (im *InstantMonitor) StopMonitoringForOrder(tradeId string) {
	im.mutex.Lock()
	defer im.mutex.Unlock()
	
	if session, exists := im.activeMonitors[tradeId]; exists {
		session.isActive = false
		close(session.stopChan)
		delete(im.activeMonitors, tradeId)
		log.Sugar.Infof("停止监控订单: %s", tradeId)
	}
}

// monitorOrder 监控单个订单
func (im *InstantMonitor) monitorOrder(session *MonitorSession) {
	defer session.wg.Done()
	
	ticker := time.NewTicker(2 * time.Second) // 每2秒检查一次
	defer ticker.Stop()
	
	for {
		select {
		case <-ticker.C:
			if !session.isActive {
				return
			}
			
			// 执行即时检查
			im.checkOrderPayment(session.tradeId, session.token)
			
		case <-session.stopChan:
			return
		}
	}
}

// checkOrderPayment 检查订单支付状态
func (im *InstantMonitor) checkOrderPayment(tradeId, token string) {
	// 调用现有的 TRC20 回调检查
	var wg sync.WaitGroup
	wg.Add(1)
	go Trc20CallBack(token, &wg)
	wg.Wait()
	
	// 检查订单状态，如果已完成则停止监控
	order, err := data.GetOrderInfoByTradeId(tradeId)
	if err != nil {
		log.Sugar.Errorf("检查订单状态失败: %v", err)
		return
	}
	
	// 如果订单已完成支付，停止监控
	if order.Status == 2 { // 假设 2 表示支付成功
		im.StopMonitoringForOrder(tradeId)
		log.Sugar.Infof("订单 %s 支付完成，停止监控", tradeId)
	}
}

// GetActiveMonitorCount 获取当前活跃监控数量
func (im *InstantMonitor) GetActiveMonitorCount() int {
	im.mutex.RLock()
	defer im.mutex.RUnlock()
	return len(im.activeMonitors)
}
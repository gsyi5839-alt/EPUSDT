package sign

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"github.com/assimon/luuu/util/json"
	"github.com/gookit/goutil/strutil"
	"reflect"
	"sort"
	"strconv"
)

// GetHMAC 使用 HMAC-SHA256 生成签名（推荐）
// 参数:
//   - data: 要签名的数据（支持 map 或 struct）
//   - bizKey: 业务密钥
// 返回:
//   - 签名字符串（hex编码）
func GetHMAC(data interface{}, bizKey string) (string, error) {
	var err error
	signStr := ""
	switch v := reflect.ValueOf(data); v.Kind() {
	case reflect.Map:
		signStr, err = MapToParams(data.(map[string]interface{}))
		if err != nil {
			return "", err
		}
	case reflect.Struct:
		signStr, err = Struct2map(v.Interface())
		if err != nil {
			return "", err
		}
	default:
		return "", errors.New("type err")
	}

	// 使用 HMAC-SHA256 替代 MD5
	h := hmac.New(sha256.New, []byte(bizKey))
	h.Write([]byte(signStr))
	sign := hex.EncodeToString(h.Sum(nil))
	return sign, nil
}

// Get 获取签名（MD5，已废弃，保留用于向后兼容）
// Deprecated: 请使用 GetHMAC 方法，MD5 算法已不安全
func Get(data interface{}, bizKey string) (string, error) {
	var err error
	signStr := ""
	switch v := reflect.ValueOf(data); v.Kind() {
	case reflect.Map:
		signStr, err = MapToParams(data.(map[string]interface{}))
		if err != nil {
			return "", err
		}
	case reflect.Struct:
		signStr, err = Struct2map(v.Interface())
		if err != nil {
			return "", err
		}
	default:
		return "", errors.New("type err")
	}
	sign := strutil.Md5(signStr + bizKey)
	return sign, nil
}

func Struct2map(content interface{}) (string, error) {
	var params map[string]interface{}
	marshal, err := json.Cjson.Marshal(content)
	if err != nil {
		return "", err
	}
	if err = json.Cjson.Unmarshal(marshal, &params); err != nil {
		return "", err
	}
	paramsUrl, err := MapToParams(params)
	return paramsUrl, err
}

func MapToParams(params map[string]interface{}) (string, error) {
	var tempArr []string
	temString := ""
	for k, v := range params {
		if k == "signature" {
			continue
		}
		if v == nil {
			continue
		}
		fv := ""
		switch v.(type) {
		case float64:
			ft := v.(float64)
			fv = strconv.FormatFloat(ft, 'f', -1, 64)
		case float32:
			ft := v.(float32)
			fv = strconv.FormatFloat(float64(ft), 'f', -1, 64)
		case int:
			it := v.(int)
			fv = strconv.Itoa(it)
		case uint:
			it := v.(uint)
			fv = strconv.Itoa(int(it))
		case int8:
			it := v.(int8)
			fv = strconv.Itoa(int(it))
		case uint8:
			it := v.(uint8)
			fv = strconv.Itoa(int(it))
		case int16:
			it := v.(int16)
			fv = strconv.Itoa(int(it))
		case uint16:
			it := v.(uint16)
			fv = strconv.Itoa(int(it))
		case int32:
			it := v.(int32)
			fv = strconv.Itoa(int(it))
		case uint32:
			it := v.(uint32)
			fv = strconv.Itoa(int(it))
		case int64:
			it := v.(int64)
			fv = strconv.FormatInt(it, 10)
		case uint64:
			it := v.(uint64)
			fv = strconv.FormatUint(it, 10)
		case string:
			fv = v.(string)
		case []byte:
			fv = string(v.([]byte))
		default:
			return "", errors.New("signature marshal error")
		}
		// 空值不参与签名
		if fv == "" {
			continue
		}
		tempArr = append(tempArr, k+"="+fv)
	}
	sort.Strings(tempArr)
	for n, v := range tempArr {
		if n+1 < len(tempArr) {
			temString = temString + v + "&"
		} else {
			temString = temString + v
		}
	}
	return temString, nil
}

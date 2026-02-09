package comm

import (
	"encoding/base64"
	"errors"
	"fmt"
	"net/http"
	"net/url"

	"github.com/labstack/echo/v4"
	"github.com/skip2/go-qrcode"
)

// GenerateQrCode 生成二维码（base64 PNG）
func (c *BaseCommController) GenerateQrCode(ctx echo.Context) error {
	type Request struct {
		Content string `json:"content" validate:"required"`
		Size    int    `json:"size"`
	}

	req := new(Request)
	if err := ctx.Bind(req); err != nil {
		return c.FailJson(ctx, err)
	}
	if err := c.ValidateStruct(ctx, req); err != nil {
		return c.FailJson(ctx, err)
	}
	if req.Size <= 0 {
		req.Size = 256
	}
	if req.Size < 128 || req.Size > 1024 {
		return c.FailJson(ctx, errors.New("size范围应在128~1024"))
	}

	pngBytes, err := generateQrPng(req.Content, req.Size)
	if err != nil {
		return c.FailJson(ctx, err)
	}

	return c.SucJson(ctx, map[string]interface{}{
		"content": req.Content,
		"size":    req.Size,
		"image":   base64.StdEncoding.EncodeToString(pngBytes),
	})
}

// GenerateQrCodeStream 生成二维码图片流
func (c *BaseCommController) GenerateQrCodeStream(ctx echo.Context) error {
	content := ctx.QueryParam("content")
	if content == "" {
		return ctx.String(http.StatusBadRequest, "content required")
	}
	sizeStr := ctx.QueryParam("size")
	size := 256
	if sizeStr != "" {
		if v, err := parseSize(sizeStr); err == nil {
			size = v
		}
	}
	if size < 128 || size > 1024 {
		return ctx.String(http.StatusBadRequest, "size out of range")
	}

	pngBytes, err := generateQrPng(content, size)
	if err != nil {
		return ctx.String(http.StatusInternalServerError, "qr generate failed")
	}

	return ctx.Blob(http.StatusOK, "image/png", pngBytes)
}

func generateQrPng(content string, size int) ([]byte, error) {
	return qrcode.Encode(content, qrcode.Medium, size)
}

func parseSize(sizeStr string) (int, error) {
	sizeStr, err := url.QueryUnescape(sizeStr)
	if err != nil {
		return 0, err
	}
	var size int
	_, err = fmt.Sscanf(sizeStr, "%d", &size)
	return size, err
}

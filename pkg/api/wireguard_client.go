package api

import (
	"context"
	"fmt"
	"time"
)

// WireGuardClient расширяет базовый Client для WireGuard операций
type WireGuardClient struct {
	*Client
}

// NewWireGuardClient создает новый WireGuard клиент
func NewWireGuardClient(baseClient *Client) *WireGuardClient {
	return &WireGuardClient{
		Client: baseClient,
	}
}

// WireGuardTunnelRequest запрос на создание WireGuard туннеля
type WireGuardTunnelRequest struct {
	TenantID  string            `json:"tenant_id"`
	RequestID string            `json:"request_id"`
	Metadata  map[string]string `json:"metadata,omitempty"`
}

// WireGuardTunnelResponse ответ на создание WireGuard туннеля
type WireGuardTunnelResponse struct {
	Success      bool   `json:"success"`
	Message      string `json:"message"`
	RequestID    string `json:"request_id"`
	PublicKey    string `json:"public_key"`
	Endpoint     string `json:"endpoint"`
	Port         int32  `json:"port"`
	ClientConfig string `json:"client_config"`
}

// WireGuardTunnelInfo информация о WireGuard туннеле
type WireGuardTunnelInfo struct {
	TenantID      string `json:"tenant_id"`
	PublicKey     string `json:"public_key"`
	Endpoint      string `json:"endpoint"`
	Port          int32  `json:"port"`
	IsActive      bool   `json:"is_active"`
	BytesReceived int64  `json:"bytes_received"`
	BytesSent     int64  `json:"bytes_sent"`
	LastConnected int64  `json:"last_connected"`
}

// WireGuardStatusResponse ответ со статусом WireGuard
type WireGuardStatusResponse struct {
	Success   bool                   `json:"success"`
	Message   string                 `json:"message"`
	RequestID string                 `json:"request_id"`
	Status    map[string]interface{} `json:"status"`
}

// WireGuardMetricsResponse ответ с метриками WireGuard
type WireGuardMetricsResponse struct {
	Success   bool                   `json:"success"`
	Message   string                 `json:"message"`
	RequestID string                 `json:"request_id"`
	Metrics   map[string]interface{} `json:"metrics"`
}

// CreateWireGuardTunnel создает WireGuard туннель для tenant'а
func (wgc *WireGuardClient) CreateWireGuardTunnel(ctx context.Context, token, tenantID string) (*WireGuardTunnelResponse, error) {
	requestID := fmt.Sprintf("wg-create-%d", time.Now().Unix())

	req := &WireGuardTunnelRequest{
		TenantID:  tenantID,
		RequestID: requestID,
		Metadata: map[string]string{
			"client_version": "1.0.0",
			"platform":       "linux",
		},
	}

	url := fmt.Sprintf("%s/api/v1/wireguard/tunnels", wgc.baseURL)

	var resp WireGuardTunnelResponse
	_, err := wgc.doRequestWithRetry(ctx, "POST", url, token, req, &resp)
	if err != nil {
		return nil, fmt.Errorf("failed to create WireGuard tunnel: %w", err)
	}

	return &resp, nil
}

// DeleteWireGuardTunnel удаляет WireGuard туннель
func (wgc *WireGuardClient) DeleteWireGuardTunnel(ctx context.Context, token, tenantID string) error {
	requestID := fmt.Sprintf("wg-delete-%d", time.Now().Unix())

	url := fmt.Sprintf("%s/api/v1/wireguard/tunnels/%s", wgc.baseURL, tenantID)

	req := map[string]string{
		"request_id": requestID,
	}

	var resp map[string]interface{}
	_, err := wgc.doRequestWithRetry(ctx, "DELETE", url, token, req, &resp)
	if err != nil {
		return fmt.Errorf("failed to delete WireGuard tunnel: %w", err)
	}

	return nil
}

// GetWireGuardTunnel получает информацию о WireGuard туннеле
func (wgc *WireGuardClient) GetWireGuardTunnel(ctx context.Context, token, tenantID string) (*WireGuardTunnelInfo, error) {
	requestID := fmt.Sprintf("wg-get-%d", time.Now().Unix())

	url := fmt.Sprintf("%s/api/v1/wireguard/tunnels/%s", wgc.baseURL, tenantID)

	req := map[string]string{
		"request_id": requestID,
	}

	var resp struct {
		Success   bool                 `json:"success"`
		Message   string               `json:"message"`
		RequestID string               `json:"request_id"`
		Tunnel    *WireGuardTunnelInfo `json:"tunnel"`
	}

	_, err := wgc.doRequestWithRetry(ctx, "GET", url, token, req, &resp)
	if err != nil {
		return nil, fmt.Errorf("failed to get WireGuard tunnel: %w", err)
	}

	if !resp.Success {
		return nil, fmt.Errorf("failed to get tunnel: %s", resp.Message)
	}

	return resp.Tunnel, nil
}

// ListWireGuardTunnels получает список всех WireGuard туннелей
func (wgc *WireGuardClient) ListWireGuardTunnels(ctx context.Context, token string) ([]*WireGuardTunnelInfo, error) {
	requestID := fmt.Sprintf("wg-list-%d", time.Now().Unix())

	url := fmt.Sprintf("%s/api/v1/wireguard/tunnels", wgc.baseURL)

	req := map[string]string{
		"request_id": requestID,
	}

	var resp struct {
		Success   bool                   `json:"success"`
		Message   string                 `json:"message"`
		RequestID string                 `json:"request_id"`
		Tunnels   []*WireGuardTunnelInfo `json:"tunnels"`
	}

	_, err := wgc.doRequestWithRetry(ctx, "GET", url, token, req, &resp)
	if err != nil {
		return nil, fmt.Errorf("failed to list WireGuard tunnels: %w", err)
	}

	if !resp.Success {
		return nil, fmt.Errorf("failed to list tunnels: %s", resp.Message)
	}

	return resp.Tunnels, nil
}

// GetWireGuardStatus получает статус WireGuard сервера
func (wgc *WireGuardClient) GetWireGuardStatus(ctx context.Context, token string) (*WireGuardStatusResponse, error) {
	requestID := fmt.Sprintf("wg-status-%d", time.Now().Unix())

	url := fmt.Sprintf("%s/api/v1/wireguard/status", wgc.baseURL)

	req := map[string]string{
		"request_id": requestID,
	}

	var resp WireGuardStatusResponse
	_, err := wgc.doRequestWithRetry(ctx, "GET", url, token, req, &resp)
	if err != nil {
		return nil, fmt.Errorf("failed to get WireGuard status: %w", err)
	}

	return &resp, nil
}

// GetWireGuardMetrics получает метрики WireGuard
func (wgc *WireGuardClient) GetWireGuardMetrics(ctx context.Context, token string) (*WireGuardMetricsResponse, error) {
	requestID := fmt.Sprintf("wg-metrics-%d", time.Now().Unix())

	url := fmt.Sprintf("%s/api/v1/wireguard/metrics", wgc.baseURL)

	req := map[string]string{
		"request_id": requestID,
	}

	var resp WireGuardMetricsResponse
	_, err := wgc.doRequestWithRetry(ctx, "GET", url, token, req, &resp)
	if err != nil {
		return nil, fmt.Errorf("failed to get WireGuard metrics: %w", err)
	}

	return &resp, nil
}

// UpdateWireGuardConfig обновляет конфигурацию WireGuard сервера
func (wgc *WireGuardClient) UpdateWireGuardConfig(ctx context.Context, token string, forceReload bool) error {
	requestID := fmt.Sprintf("wg-update-%d", time.Now().Unix())

	url := fmt.Sprintf("%s/api/v1/wireguard/config", wgc.baseURL)

	req := map[string]interface{}{
		"request_id":   requestID,
		"force_reload": forceReload,
	}

	var resp map[string]interface{}
	_, err := wgc.doRequestWithRetry(ctx, "PUT", url, token, req, &resp)
	if err != nil {
		return fmt.Errorf("failed to update WireGuard config: %w", err)
	}

	return nil
}

// SaveWireGuardConfig сохраняет конфигурацию клиента в файл
func (wgc *WireGuardClient) SaveWireGuardConfig(config, filename string) error {
	// Простая реализация сохранения конфигурации
	// В production должна быть более надежная обработка файлов
	return fmt.Errorf("SaveWireGuardConfig not implemented yet")
}

// ApplyWireGuardConfig применяет WireGuard конфигурацию
func (wgc *WireGuardClient) ApplyWireGuardConfig(config string) error {
	// Простая реализация применения конфигурации
	// В production должна быть интеграция с wg-quick
	return fmt.Errorf("ApplyWireGuardConfig not implemented yet")
}


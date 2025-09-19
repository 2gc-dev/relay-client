package main

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func main() {
	// Основной JWT secret от DevOps команды
	secret := "eozy96a8+j125pOpIhCyytge1rR0MTiG4wBi/J9zpew="

	// Создаем claims с правильными данными
	claims := jwt.MapClaims{
		"protocol_type":    "p2p-mesh",
		"scope":           "p2p-mesh-claims",
		"org_id":          "tenant-216420165",
		"tenant_id":       "tenant-216420165",
		"server_id":       "server-1758051692753",
		"connection_type": "wireguard",
		"max_peers":       "10",
		"permissions":     []string{"mesh_join", "mesh_manage"},
		"network_config": map[string]interface{}{
			"subnet":         "10.0.0.0/24",
			"gateway":        "10.0.0.1",
			"dns":            []string{"8.8.8.8", "1.1.1.1"},
			"mtu":            1420,
			"firewall_rules": []string{"allow_ssh", "allow_http"},
			"enable_ipv6":    false,
		},
		"wireguard_config": map[string]interface{}{
			"interface_name": "wg0",
			"listen_port":    51820,
			"address":        "10.0.0.100/24",
			"mtu":            1420,
			"allowed_ips":    []string{"10.0.0.0/24", "192.168.1.0/24"},
		},
		"mesh_config": map[string]interface{}{
			"network_id":            "mesh-network-001",
			"subnet":                "10.0.0.0/16",
			"registry_url":          "https://mesh-registry.2gc.ru",
			"heartbeat_interval":    "30s",
			"max_peers":             10,
			"routing_strategy":      "performance_optimal",
			"enable_auto_discovery": true,
			"trust_level":           "basic",
		},
		"peer_whitelist": []string{"peer-001", "peer-002", "peer-003"},
		"iat":            time.Now().Unix(),
		"iss":            "https://auth.2gc.ru/realms/cloudbridge",
		"aud":            "account",
		"sub":            "server-client-server-1758051692753",
		"jti":            fmt.Sprintf("jwt_%d_%s", time.Now().Unix(), "updated"),
		"exp":            time.Now().Add(24 * time.Hour).Unix(),
	}

	// Создаем токен
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	// Подписываем токен
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		fmt.Printf("Error generating token: %v\n", err)
		return
	}

	fmt.Println("Generated JWT Token:")
	fmt.Println("===================")
	fmt.Println(tokenString)
	fmt.Println()
	fmt.Println("Token expires in 24 hours")
	fmt.Println("Use this token for testing with the updated API")
}





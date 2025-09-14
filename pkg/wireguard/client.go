package wireguard

import (
	"encoding/json"
	"fmt"
	"net"
	"time"
)

// WireGuardClient представляет P2P клиент с автоматическим определением режима
type WireGuardClient struct {
	config     *Config
	connection net.Conn
	mode       ConnectionMode
	peers      map[string]*Peer
}

// Config конфигурация WireGuard клиента
type Config struct {
	PrivateKey    string `json:"private_key"`
	PublicKey     string `json:"public_key"`
	ListenPort    int    `json:"listen_port"`
	RelayServer   string `json:"relay_server"`
	RelayPort     int    `json:"relay_port"`
	Peers         []Peer `json:"peers"`
	AutoDiscovery bool   `json:"auto_discovery"`
	Mode          string `json:"mode"` // "auto", "client-server", "server-server"
}

// Peer информация о пире
type Peer struct {
	PublicKey  string   `json:"public_key"`
	AllowedIPs []string `json:"allowed_ips"`
	Endpoint   string   `json:"endpoint"`
	Persistent bool     `json:"persistent"` // true для постоянного трафика
}

// ConnectionMode режим соединения
type ConnectionMode int

const (
	ModeAuto ConnectionMode = iota
	ModeClientServer
	ModeServerServer
)

// NewWireGuardClient создает новый WireGuard P2P клиент
func NewWireGuardClient(config *Config) *WireGuardClient {
	return &WireGuardClient{
		config: config,
		peers:  make(map[string]*Peer),
	}
}

// Connect подключается к relay серверу и определяет режим
func (c *WireGuardClient) Connect() error {
	fmt.Println("🔌 Подключение к WireGuard P2P relay серверу...")

	// Подключение к relay серверу
	conn, err := net.DialTimeout("udp", fmt.Sprintf("%s:%d", c.config.RelayServer, c.config.RelayPort), 10*time.Second)
	if err != nil {
		return fmt.Errorf("ошибка подключения к relay серверу: %v", err)
	}
	c.connection = conn

	// Определяем режим работы
	if err := c.determineMode(); err != nil {
		return fmt.Errorf("ошибка определения режима: %v", err)
	}

	fmt.Printf("✅ Режим определен: %s\n", c.getModeString())

	// Инициализируем соответствующий режим
	return c.initializeMode()
}

// determineMode автоматически определяет режим работы
func (c *WireGuardClient) determineMode() error {
	fmt.Println("🔍 Определение режима работы...")

	// Анализируем конфигурацию
	if c.config.Mode == "auto" {
		// Автоматическое определение по конфигурации
		if len(c.config.Peers) == 0 {
			c.mode = ModeClientServer
			fmt.Println("   📊 Режим: Клиент-Сервер (нет пиров)")
		} else {
			// Проверяем тип пиров
			persistentCount := 0
			for _, peer := range c.config.Peers {
				if peer.Persistent {
					persistentCount++
				}
			}

			if persistentCount > 0 {
				c.mode = ModeServerServer
				fmt.Printf("   📊 Режим: Сервер-Сервер (%d постоянных пиров)\n", persistentCount)
			} else {
				c.mode = ModeClientServer
				fmt.Println("   📊 Режим: Клиент-Сервер (временные пиры)")
			}
		}
	} else {
		// Ручное определение
		switch c.config.Mode {
		case "client-server":
			c.mode = ModeClientServer
		case "server-server":
			c.mode = ModeServerServer
		default:
			return fmt.Errorf("неизвестный режим: %s", c.config.Mode)
		}
	}

	return nil
}

// initializeMode инициализирует соответствующий режим
func (c *WireGuardClient) initializeMode() error {
	switch c.mode {
	case ModeClientServer:
		return c.initializeClientServerMode()
	case ModeServerServer:
		return c.initializeServerServerMode()
	default:
		return fmt.Errorf("неизвестный режим: %d", c.mode)
	}
}

// initializeClientServerMode инициализирует клиент-сервер режим
func (c *WireGuardClient) initializeClientServerMode() error {
	fmt.Println("🖥️  Инициализация клиент-сервер режима...")

	// Отправляем handshake для клиент-сервер соединения
	handshake := &WireGuardHandshake{
		Type:       "client_handshake",
		PublicKey:  c.config.PublicKey,
		ListenPort: c.config.ListenPort,
		Mode:       "client-server",
		Timestamp:  time.Now().Unix(),
	}

	return c.sendHandshake(handshake)
}

// initializeServerServerMode инициализирует сервер-сервер режим
func (c *WireGuardClient) initializeServerServerMode() error {
	fmt.Println("🔄 Инициализация сервер-сервер режима...")

	// Отправляем handshake для сервер-сервер соединения
	handshake := &WireGuardHandshake{
		Type:       "server_handshake",
		PublicKey:  c.config.PublicKey,
		ListenPort: c.config.ListenPort,
		Mode:       "server-server",
		Peers:      c.config.Peers,
		Timestamp:  time.Now().Unix(),
	}

	return c.sendHandshake(handshake)
}

// WireGuardHandshake структура handshake сообщения
type WireGuardHandshake struct {
	Type       string `json:"type"`
	PublicKey  string `json:"public_key"`
	ListenPort int    `json:"listen_port"`
	Mode       string `json:"mode"`
	Peers      []Peer `json:"peers,omitempty"`
	Timestamp  int64  `json:"timestamp"`
}

// sendHandshake отправляет handshake сообщение
func (c *WireGuardClient) sendHandshake(handshake *WireGuardHandshake) error {
	data, err := json.Marshal(handshake)
	if err != nil {
		return fmt.Errorf("ошибка маршалинга handshake: %v", err)
	}

	fmt.Printf("📤 Отправляем %s handshake\n", handshake.Type)

	_, err = c.connection.Write(data)
	if err != nil {
		return fmt.Errorf("ошибка отправки handshake: %v", err)
	}

	// Ожидаем ответ
	return c.waitForHandshakeResponse()
}

// waitForHandshakeResponse ожидает ответ на handshake
func (c *WireGuardClient) waitForHandshakeResponse() error {
	if err := c.connection.SetReadDeadline(time.Now().Add(10 * time.Second)); err != nil {
		return fmt.Errorf("ошибка установки таймаута чтения: %v", err)
	}

	buffer := make([]byte, 1024)
	n, err := c.connection.Read(buffer)
	if err != nil {
		return fmt.Errorf("ошибка получения handshake ответа: %v", err)
	}

	var response map[string]interface{}
	if err := json.Unmarshal(buffer[:n], &response); err != nil {
		return fmt.Errorf("ошибка парсинга handshake ответа: %v", err)
	}

	fmt.Printf("📨 Получен handshake ответ: %+v\n", response)

	// Проверяем статус
	if status, ok := response["status"].(string); ok && status == "ok" {
		fmt.Println("✅ Handshake успешен!")
		return nil
	}

	return fmt.Errorf("handshake не удался: %v", response)
}

// getModeString возвращает строковое представление режима
func (c *WireGuardClient) getModeString() string {
	switch c.mode {
	case ModeClientServer:
		return "Клиент-Сервер"
	case ModeServerServer:
		return "Сервер-Сервер"
	default:
		return "Неизвестно"
	}
}

// Close закрывает соединение
func (c *WireGuardClient) Close() error {
	if c.connection != nil {
		return c.connection.Close()
	}
	return nil
}


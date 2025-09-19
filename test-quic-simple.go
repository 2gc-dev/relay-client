package main

import (
	"context"
	"crypto/tls"
	"log"
	"time"

	"github.com/quic-go/quic-go"
)

func main() {
	// Минимальная конфигурация для тестирования
	addr := "95.163.250.190:5553"
	
	// Простейшая TLS конфигурация
	tlsConf := &tls.Config{
		InsecureSkipVerify: true,
		NextProtos:         []string{"h3-27"},
	}
	
	// Простейшая QUIC конфигурация
	quicConf := &quic.Config{
		HandshakeIdleTimeout: 60 * time.Second,
		KeepAlivePeriod:      30 * time.Second,
		MaxIdleTimeout:       60 * time.Second,
	}

	log.Printf("🧪 Простой QUIC тест к %s", addr)
	log.Printf("📋 TLS: InsecureSkipVerify=true, NextProtos=[h3-27]")
	log.Printf("📋 QUIC: HandshakeIdleTimeout=60s")

	// Попытка подключения
	ctx, cancel := context.WithTimeout(context.Background(), 70*time.Second)
	defer cancel()

	log.Printf("🔌 Устанавливаем QUIC соединение...")
	start := time.Now()
	
	conn, err := quic.DialAddr(ctx, addr, tlsConf, quicConf)
	if err != nil {
		log.Printf("❌ Ошибка подключения: %v", err)
		log.Printf("⏱️  Время попытки: %v", time.Since(start))
		return
	}
	defer conn.CloseWithError(0, "test done")

	duration := time.Since(start)
	log.Printf("✅ QUIC соединение установлено!")
	log.Printf("⏱️  Время handshake: %v", duration)
	log.Printf("🌐 Локальный адрес: %s", conn.LocalAddr())
	log.Printf("🌐 Удаленный адрес: %s", conn.RemoteAddr())
	
	// Проверяем TLS состояние
	tlsState := conn.ConnectionState().TLS
	log.Printf("🔐 TLS версия: %x", tlsState.Version)
	log.Printf("🔐 ALPN протокол: %q", tlsState.NegotiatedProtocol)
	log.Printf("🔐 Cipher suite: %x", tlsState.CipherSuite)

	log.Printf("🎉 Тест завершен успешно!")
}

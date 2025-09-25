package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"time"

	quic "github.com/quic-go/quic-go"
)

const (
	defaultHost       = "edge.2gc.ru"
	defaultPort       = 9091
	defaultServerName = "edge.2gc.ru"
	authPrefix        = "AUTH "
	authOK            = "AUTH_OK"
)

type modeType string

const (
	modeSend modeType = "send"
	modeRecv modeType = "recv"
)

func main() {
	var (
		tokenPath   string
		tokenInline string
		host        string
		port        int
		serverName  string
		insecureTLS bool
		modeStr     string
		toPeerID    string
		message     string
		timeout     time.Duration
	)

	flag.StringVar(&tokenPath, "token-file", "", "Path to JWT token file")
	flag.StringVar(&tokenInline, "token", "", "JWT token value (overrides token-file if set)")
	flag.StringVar(&host, "host", defaultHost, "Relay host")
	flag.IntVar(&port, "port", defaultPort, "Relay QUIC port")
	flag.StringVar(&serverName, "servername", defaultServerName, "TLS server name")
	flag.BoolVar(&insecureTLS, "insecure", true, "Skip TLS verification")
	flag.StringVar(&modeStr, "mode", string(modeSend), "Mode: send or recv")
	flag.StringVar(&toPeerID, "to", "", "Target peer_id for send mode")
	flag.StringVar(&message, "msg", "hello", "Message payload for send mode")
	flag.DurationVar(&timeout, "timeout", 25*time.Second, "Dial timeout")
	flag.Parse()

	m := modeType(strings.ToLower(modeStr))
	if m != modeSend && m != modeRecv {
		log.Fatalf("invalid mode: %s (expected send|recv)", modeStr)
	}

	// Load token
	token := tokenInline
	if token == "" && tokenPath != "" {
		b, err := os.ReadFile(tokenPath)
		if err != nil {
			log.Fatalf("failed to read token file: %v", err)
		}
		token = strings.TrimSpace(string(b))
	}
	if token == "" {
		log.Fatalf("token is required via --token or --token-file")
	}

	addr := fmt.Sprintf("%s:%d", host, port)
	tlsConf := &tls.Config{
		// ServerName:         serverName, // Отключаем SNI для тестирования
		InsecureSkipVerify: insecureTLS,
		MinVersion:         tls.VersionTLS12,                                             // Пробуем TLS 1.2
		NextProtos:         []string{"cloudbridge-p2p", "h3", "h3-29", "h3-28", "h3-27"}, // Полный список ALPN протоколов
	}
	quicConf := &quic.Config{
		HandshakeIdleTimeout: 30 * time.Second, // Увеличиваем timeout для тестирования
		KeepAlivePeriod:      15 * time.Second,
		MaxIdleTimeout:       30 * time.Second,
	}

	// Dial
	log.Printf("Dialing QUIC %s...", addr)
	hsStart := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	conn, err := quic.DialAddr(ctx, addr, tlsConf, quicConf)
	if err != nil {
		log.Fatalf("dial failed: %v", err)
	}
	defer conn.CloseWithError(0, "bye")
	hsDur := time.Since(hsStart)
	tlsState := conn.ConnectionState().TLS
	alpn := tlsState.NegotiatedProtocol
	log.Printf("✅ Connected: %s -> %s | ALPN=%q | handshake=%s", conn.LocalAddr(), conn.RemoteAddr(), alpn, hsDur)

	// AUTH stream
	log.Printf("🔐 Opening AUTH stream...")
	authStream, err := conn.OpenStreamSync(context.Background())
	if err != nil {
		log.Fatalf("open auth stream failed: %v", err)
	}
	defer authStream.Close()
	log.Printf("✅ AUTH stream opened")

	authLine := authPrefix + token // БЕЗ \n согласно DevOps
	log.Printf("📤 Sending AUTH: %q", strings.TrimSpace(authLine))
	if _, err := authStream.Write([]byte(authLine)); err != nil {
		log.Fatalf("write AUTH failed: %v", err)
	}
	log.Printf("✅ AUTH sent (%d bytes)", len(authLine))

	// Read AUTH response (single line)
	log.Printf("📥 Reading AUTH response...")
	r := bufio.NewReader(authStream)
	resp, err := r.ReadString('\n')
	if err != nil && err != io.EOF {
		log.Fatalf("read AUTH response failed: %v", err)
	}
	resp = strings.TrimSpace(resp)
	log.Printf("📥 AUTH response: %q", resp)
	if resp != authOK { // Точное сравнение без префикса
		log.Fatalf("❌ AUTH not OK: %s", resp)
	}
	log.Printf("✅ AUTH successful!")

	switch m {
	case modeRecv:
		log.Printf("Receiver mode: waiting for incoming streams...")
		for {
			s, err := conn.AcceptStream(context.Background())
			if err != nil {
				log.Fatalf("accept stream failed: %v", err)
			}
			go func(st *quic.Stream) {
				defer st.Close()
				br := bufio.NewReader(st)
				data, rerr := io.ReadAll(br)
				if rerr != nil && rerr != io.EOF {
					log.Printf("stream read error: %v", rerr)
				}
				log.Printf("Incoming stream %d bytes: %s", len(data), sanitize(string(data)))
			}(s)
		}

	case modeSend:
		if toPeerID == "" {
			log.Fatalf("--to peer_id is required in send mode")
		}
		payload := fmt.Sprintf("TO:%s:%s\n", toPeerID, message)
		log.Printf("📤 Opening data stream for TO message...")
		s, err := conn.OpenStreamSync(context.Background())
		if err != nil {
			log.Fatalf("open data stream failed: %v", err)
		}
		defer s.Close()
		log.Printf("✅ Data stream opened")

		log.Printf("📤 Sending TO payload: %q", strings.TrimSpace(payload))
		if _, err := s.Write([]byte(payload)); err != nil {
			log.Fatalf("write payload failed: %v", err)
		}
		log.Printf("✅ TO payload sent: %s", strings.TrimSpace(payload))
		// Try to read optional response with short timeout (non-fatal)
		log.Printf("📥 Waiting for optional response...")
		rctx, rcancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer rcancel()
		if rs, err := conn.AcceptStream(rctx); err == nil {
			log.Printf("✅ Received response stream")
			br := bufio.NewReader(rs)
			data, _ := io.ReadAll(br)
			log.Printf("📥 Response %d bytes: %s", len(data), sanitize(string(data)))
			rs.Close()
		} else {
			log.Printf("ℹ️  No response stream received (expected): %v", err)
		}
	}
}

func sanitize(s string) string {
	s = strings.ReplaceAll(s, "\n", "\\n")
	s = strings.ReplaceAll(s, "\r", "\\r")
	return s
}

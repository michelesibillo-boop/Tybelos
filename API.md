# Tybelos Circle - API Documentation

## Document Information

**Version:** 1.0  
**Last Updated:** January 2026  
**Owner:** Engineering Team  
**API Version:** v1  
**Related Documents:**
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture and technical details
- [PERFORMANCE_METRICS.md](./PERFORMANCE_METRICS.md) - Performance targets and SLAs

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [WebSocket API](#websocket-api)
4. [Voice Streaming Lifecycle](#voice-streaming-lifecycle)
5. [REST API](#rest-api)
6. [AI-to-AI (C2C) Protocol](#ai-to-ai-c2c-protocol)
7. [Error Handling](#error-handling)
8. [Rate Limits](#rate-limits)
9. [SDK Reference](#sdk-reference)

---

## Overview

Tybelos Circle provides real-time voice interaction through WebSocket connections combined with RESTful APIs for non-real-time operations. The API is designed to support:

- **Real-time voice streaming** with sub-2 second latency
- **Bidirectional audio communication** using WebRTC
- **Session management** and state persistence
- **Memory operations** with user consent
- **AI-to-AI communication** for social features

### Base URLs

```
Production:  wss://api.tybelos.com/v1/voice
             https://api.tybelos.com/v1

Staging:     wss://staging-api.tybelos.com/v1/voice
             https://staging-api.tybelos.com/v1

Development: ws://localhost:8080/v1/voice
             http://localhost:8080/v1
```

### API Design Principles

1. **Real-time First**: WebSocket for voice, REST for everything else
2. **Event-Driven**: Server-sent events for async updates
3. **Idempotent**: Safe retry mechanisms for all operations
4. **Versioned**: API version in URL path
5. **Stateless**: JWT tokens carry all auth information

### Performance Targets

From PERFORMANCE_METRICS.md:

- **Response Latency**: <2 seconds (critical: >3s)
- **WebSocket Connection Uptime**: 99.9%
- **API Response Time (p95)**: <200ms (critical: >500ms)
- **Voice Input Success Rate**: 95%+
- **Concurrent Sessions**: 10,000+ supported

---

## Authentication

### JWT Token Authentication

All API requests require JWT authentication via Bearer token.

#### Obtaining Access Token

**Endpoint:** `POST /v1/auth/login`

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123",
  "device_info": {
    "device_id": "uuid-v4",
    "device_type": "ios",
    "app_version": "1.0.0",
    "os_version": "17.0"
  }
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "Bearer",
  "expires_in": 900,
  "user": {
    "id": "user-uuid",
    "email": "user@example.com",
    "circle_id": "circle-uuid",
    "subscription_tier": "plus",
    "created_at": "2026-01-15T10:00:00Z"
  }
}
```

**Token Expiry:**
- Access Token: 15 minutes
- Refresh Token: 30 days

#### Refreshing Access Token

**Endpoint:** `POST /v1/auth/refresh`

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_in": 900
}
```

#### Using Access Token

**HTTP Header:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

**WebSocket Query Parameter:**
```
wss://api.tybelos.com/v1/voice?token=eyJhbGciOiJIUzI1NiIs...
```

#### Token Payload

```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "circle_id": "circle-uuid",
  "subscription_tier": "plus",
  "permissions": [
    "voice_sessions",
    "memory_access",
    "c2c_enabled"
  ],
  "iat": 1706626800,
  "exp": 1706627700
}
```

---

## WebSocket API

### Connection Establishment

#### 1. WebSocket Handshake

**Connect to:** `wss://api.tybelos.com/v1/voice?token={JWT_TOKEN}`

**Client Request:**
```javascript
const ws = new WebSocket('wss://api.tybelos.com/v1/voice?token=' + accessToken);

ws.onopen = function() {
  console.log('WebSocket connected');
};

ws.onmessage = function(event) {
  const message = JSON.parse(event.data);
  handleMessage(message);
};

ws.onerror = function(error) {
  console.error('WebSocket error:', error);
};

ws.onclose = function(event) {
  console.log('WebSocket closed:', event.code, event.reason);
};
```

**Server Response (on successful connection):**
```json
{
  "type": "connection.established",
  "connection_id": "conn-uuid",
  "server_time": "2026-01-30T10:00:00Z",
  "capabilities": {
    "audio_codecs": ["opus", "pcm"],
    "sample_rates": [16000, 48000],
    "max_session_duration": 3600
  }
}
```

#### 2. WebRTC Signaling

After WebSocket connection, establish WebRTC peer connection for audio streaming.

**Client sends SDP Offer:**
```json
{
  "type": "webrtc.offer",
  "sdp": {
    "type": "offer",
    "sdp": "v=0\r\no=- 123456789 2 IN IP4 127.0.0.1\r\n..."
  },
  "audio_config": {
    "codec": "opus",
    "sample_rate": 48000,
    "channels": 1,
    "bitrate": 64000
  }
}
```

**Server responds with SDP Answer:**
```json
{
  "type": "webrtc.answer",
  "sdp": {
    "type": "answer",
    "sdp": "v=0\r\no=- 987654321 2 IN IP4 10.0.0.1\r\n..."
  },
  "ice_servers": [
    {
      "urls": "stun:stun.tybelos.com:3478"
    },
    {
      "urls": "turn:turn.tybelos.com:3478",
      "username": "user123",
      "credential": "pass123"
    }
  ]
}
```

**ICE Candidate Exchange:**
```json
{
  "type": "webrtc.ice_candidate",
  "candidate": {
    "candidate": "candidate:1 1 UDP 2130706431 192.168.1.100 54321 typ host",
    "sdpMid": "0",
    "sdpMLineIndex": 0
  }
}
```

### Session Management

#### Starting a Session

**Client → Server:**
```json
{
  "type": "session.start",
  "session_config": {
    "audio_quality": "high",
    "emotion_detection": true,
    "memory_enabled": true,
    "language": "en-US"
  },
  "user_context": {
    "timezone": "America/Los_Angeles",
    "local_time": "2026-01-30T10:00:00-08:00"
  }
}
```

**Server → Client:**
```json
{
  "type": "session.started",
  "session_id": "session-uuid",
  "circle_id": "circle-uuid",
  "started_at": "2026-01-30T18:00:00Z",
  "session_state": {
    "turn_count": 0,
    "emotional_baseline": null,
    "active_topics": [],
    "memory_consent_level": "full"
  }
}
```

#### Pausing a Session

**Client → Server:**
```json
{
  "type": "session.pause",
  "reason": "phone_call"
}
```

**Server → Client:**
```json
{
  "type": "session.paused",
  "session_id": "session-uuid",
  "paused_at": "2026-01-30T18:15:00Z",
  "state_checkpoint_id": "checkpoint-uuid"
}
```

#### Resuming a Session

**Client → Server:**
```json
{
  "type": "session.resume",
  "state_checkpoint_id": "checkpoint-uuid"
}
```

**Server → Client:**
```json
{
  "type": "session.resumed",
  "session_id": "session-uuid",
  "resumed_at": "2026-01-30T18:16:00Z",
  "context_summary": "We were discussing your work presentation anxiety."
}
```

#### Ending a Session

**Client → Server:**
```json
{
  "type": "session.end",
  "completion_status": "completed"
}
```

**Server → Client:**
```json
{
  "type": "session.ended",
  "session_id": "session-uuid",
  "ended_at": "2026-01-30T18:30:00Z",
  "session_summary": {
    "duration_seconds": 1800,
    "turn_count": 24,
    "topics_discussed": ["work_stress", "presentation_anxiety"],
    "emotions_detected": ["anxious", "relieved"],
    "goals_discussed": [],
    "memories_created": 5
  }
}
```

### Voice Activity Detection (VAD)

#### User Speaking Started

**Server → Client:**
```json
{
  "type": "vad.user_speaking_started",
  "timestamp": "2026-01-30T18:05:00.123Z"
}
```

#### User Speaking Ended

**Server → Client:**
```json
{
  "type": "vad.user_speaking_ended",
  "timestamp": "2026-01-30T18:05:03.456Z",
  "duration_ms": 3333
}
```

#### AI Speaking Started

**Server → Client:**
```json
{
  "type": "vad.ai_speaking_started",
  "timestamp": "2026-01-30T18:05:04.000Z"
}
```

#### AI Speaking Ended

**Server → Client:**
```json
{
  "type": "vad.ai_speaking_ended",
  "timestamp": "2026-01-30T18:05:08.500Z",
  "duration_ms": 4500
}
```

### Transcription Events

#### Interim Transcription

**Server → Client:**
```json
{
  "type": "transcription.interim",
  "text": "I'm feeling really stressed about",
  "confidence": 0.85,
  "is_final": false
}
```

#### Final Transcription

**Server → Client:**
```json
{
  "type": "transcription.final",
  "text": "I'm feeling really stressed about tomorrow's presentation.",
  "confidence": 0.92,
  "is_final": true,
  "timestamp": "2026-01-30T18:05:03.456Z"
}
```

### AI Response Events

#### Response Generation Started

**Server → Client:**
```json
{
  "type": "response.generation_started",
  "request_id": "req-uuid",
  "timestamp": "2026-01-30T18:05:03.500Z"
}
```

#### Response Text Generated

**Server → Client:**
```json
{
  "type": "response.text_generated",
  "request_id": "req-uuid",
  "text": "That sounds really stressful. Tell me more about what's worrying you about it.",
  "emotion_context": {
    "detected_emotion": "anxious",
    "confidence": 0.87,
    "response_tone": "calm_supportive"
  },
  "memories_used": [
    {
      "memory_id": "mem-uuid-1",
      "content": "User has upcoming presentation at work",
      "relevance_score": 0.95
    }
  ]
}
```

#### Audio Chunk Ready

**Server → Client:**
```json
{
  "type": "response.audio_chunk",
  "request_id": "req-uuid",
  "chunk_index": 0,
  "audio_data": "base64-encoded-audio-data",
  "duration_ms": 1500,
  "is_final": false
}
```

#### Response Complete

**Server → Client:**
```json
{
  "type": "response.complete",
  "request_id": "req-uuid",
  "total_duration_ms": 4500,
  "latency_breakdown": {
    "transcription_ms": 450,
    "ai_processing_ms": 850,
    "tts_generation_ms": 1200,
    "total_ms": 2500
  }
}
```

### Emotion Detection Events

**Server → Client:**
```json
{
  "type": "emotion.detected",
  "timestamp": "2026-01-30T18:05:03.456Z",
  "emotion": {
    "primary": "anxious",
    "confidence": 0.87,
    "valence": -0.6,
    "arousal": 0.8,
    "intensity": 0.7,
    "secondary": ["worried", "stressed"]
  },
  "emotional_trajectory": "worsening"
}
```

### Memory Events

#### Memory Extracted

**Server → Client:**
```json
{
  "type": "memory.extracted",
  "memory": {
    "id": "mem-uuid",
    "category": "work_career",
    "content": "User has presentation tomorrow, feeling anxious about it",
    "importance": 0.8,
    "consent_approved": true
  }
}
```

#### Memory Retrieved

**Server → Client:**
```json
{
  "type": "memory.retrieved",
  "memories": [
    {
      "id": "mem-uuid-1",
      "category": "work_career",
      "content": "User works in marketing at tech startup",
      "relevance_score": 0.85
    },
    {
      "id": "mem-uuid-2",
      "category": "goals_aspirations",
      "content": "User set goal to improve work-life balance",
      "relevance_score": 0.72
    }
  ]
}
```

### Interruption Handling

#### User Interrupted AI

**Client → Server:**
```json
{
  "type": "interaction.user_interrupted",
  "timestamp": "2026-01-30T18:05:06.000Z"
}
```

**Server → Client:**
```json
{
  "type": "interaction.ai_stopped",
  "timestamp": "2026-01-30T18:05:06.050Z",
  "partial_response": "I understand, that sounds—"
}
```

### System Status Events

#### Connection Quality Update

**Server → Client:**
```json
{
  "type": "system.connection_quality",
  "quality": "good",
  "metrics": {
    "latency_ms": 45,
    "packet_loss_percent": 0.5,
    "jitter_ms": 10,
    "bandwidth_kbps": 128
  },
  "recommended_action": null
}
```

#### Network Degradation Warning

**Server → Client:**
```json
{
  "type": "system.network_degraded",
  "quality": "poor",
  "metrics": {
    "latency_ms": 350,
    "packet_loss_percent": 8.5,
    "jitter_ms": 150,
    "bandwidth_kbps": 32
  },
  "recommended_action": "reduce_quality"
}
```

#### Server Maintenance Warning

**Server → Client:**
```json
{
  "type": "system.maintenance_warning",
  "maintenance_start": "2026-01-30T22:00:00Z",
  "estimated_duration_minutes": 30,
  "message": "Scheduled maintenance in 10 minutes. Please complete your session."
}
```

### Error Events

**Server → Client:**
```json
{
  "type": "error",
  "error": {
    "code": "ASR_PROCESSING_FAILED",
    "message": "Failed to transcribe audio",
    "details": {
      "reason": "audio_quality_too_low",
      "audio_duration_ms": 100
    },
    "recoverable": true,
    "suggested_action": "Please repeat your message"
  }
}
```

---

## Voice Streaming Lifecycle

### Complete Session Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. CONNECTION PHASE                                                  │
└─────────────────────────────────────────────────────────────────────┘
Client                                    Server
  │                                          │
  ├──── WebSocket Connect (with JWT) ───────>│
  │<─────── connection.established ──────────┤
  │                                          │
  ├──── webrtc.offer (SDP) ─────────────────>│
  │<─────── webrtc.answer (SDP) ─────────────┤
  │                                          │
  ├──── webrtc.ice_candidate ───────────────>│
  │<─────── webrtc.ice_candidate ────────────┤
  │                                          │
  │     [WebRTC Connection Established]      │
  │                                          │

┌─────────────────────────────────────────────────────────────────────┐
│ 2. SESSION INITIALIZATION                                            │
└─────────────────────────────────────────────────────────────────────┘
  │                                          │
  ├──── session.start ───────────────────────>│
  │                                          │
  │                          [Load user profile,
  │                           memory consent,
  │                           emotional baseline]
  │                                          │
  │<─────── session.started ─────────────────┤
  │                                          │

┌─────────────────────────────────────────────────────────────────────┐
│ 3. CONVERSATION LOOP (Repeat)                                        │
└─────────────────────────────────────────────────────────────────────┘
  │                                          │
  │     [User starts speaking]               │
  │                                          │
  │──── Audio Stream (WebRTC) ───────────────>│
  │                                          │
  │<─────── vad.user_speaking_started ───────┤
  │                                          │
  │──── Audio Stream continues ──────────────>│
  │                                          │
  │                          [VAD detects pause]
  │                                          │
  │<─────── vad.user_speaking_ended ─────────┤
  │                                          │
  │<─────── transcription.interim ───────────┤
  │<─────── transcription.interim ───────────┤
  │<─────── transcription.final ─────────────┤
  │                                          │
  │                          [Parallel Processing:
  │                           - Emotion detection
  │                           - Intent classification
  │                           - Memory retrieval
  │                           - Safety check]
  │                                          │
  │<─────── emotion.detected ────────────────┤
  │<─────── memory.retrieved ────────────────┤
  │                                          │
  │<─────── response.generation_started ─────┤
  │                                          │
  │                          [LLM generates response]
  │                                          │
  │<─────── response.text_generated ─────────┤
  │                                          │
  │                          [TTS synthesizes audio]
  │                                          │
  │<─────── vad.ai_speaking_started ─────────┤
  │<─────── Audio Stream (WebRTC) ───────────┤
  │<─────── response.audio_chunk ────────────┤
  │<─────── response.audio_chunk ────────────┤
  │<─────── response.audio_chunk ────────────┤
  │<─────── vad.ai_speaking_ended ───────────┤
  │<─────── response.complete ───────────────┤
  │                                          │
  │                          [Extract and store memory]
  │                                          │
  │<─────── memory.extracted ────────────────┤
  │                                          │
  │     [Repeat conversation loop]           │
  │                                          │

┌─────────────────────────────────────────────────────────────────────┐
│ 4. SESSION TERMINATION                                               │
└─────────────────────────────────────────────────────────────────────┘
  │                                          │
  ├──── session.end ─────────────────────────>│
  │                                          │
  │                          [Generate session summary,
  │                           update metrics,
  │                           save final state]
  │                                          │
  │<─────── session.ended ───────────────────┤
  │                                          │
  │     [WebSocket closes gracefully]        │
  │                                          │
```

### Latency Breakdown (Target: <2s total)

From ARCHITECTURE.md:

```
Component                    Target      Critical
─────────────────────────────────────────────────
VAD + Buffering             <100ms      >200ms
ASR Processing              <500ms      >1000ms
Emotion Detection           <100ms      >200ms
Intent Classification       <100ms      >200ms
Memory Retrieval            <200ms      >400ms
Safety Check                <50ms       >100ms
Context Assembly            <100ms      >200ms
LLM Inference              <1000ms      >2000ms
Response Post-Processing    <100ms      >200ms
TTS Generation (first chunk)<500ms      >1000ms
Network & Audio Latency     <300ms      >500ms
─────────────────────────────────────────────────
TOTAL                       <2000ms      >3000ms
```

### Audio Streaming Specifications

#### Audio Format (Client → Server)

**Preferred: Opus**
```json
{
  "codec": "opus",
  "sample_rate": 48000,
  "channels": 1,
  "bitrate": 64000,
  "frame_size_ms": 20,
  "application": "voip"
}
```

**Alternative: PCM**
```json
{
  "codec": "pcm_s16le",
  "sample_rate": 16000,
  "channels": 1,
  "bit_depth": 16
}
```

#### Audio Format (Server → Client)

**TTS Output:**
```json
{
  "codec": "opus",
  "sample_rate": 48000,
  "channels": 1,
  "bitrate": 64000,
  "frame_size_ms": 20
}
```

#### Adaptive Quality

Server automatically adjusts quality based on network conditions:

| Quality | Sample Rate | Bitrate | Use Case |
|---------|-------------|---------|----------|
| **Ultra** | 48kHz | 64kbps | Excellent connection |
| **High** | 48kHz | 48kbps | Good connection |
| **Standard** | 24kHz | 32kbps | Fair connection |
| **Low** | 16kHz | 24kbps | Poor connection |

**Quality Adjustment Event:**
```json
{
  "type": "system.quality_adjusted",
  "from": "high",
  "to": "standard",
  "reason": "network_degradation"
}
```

### Session Recovery

#### Reconnection After Disconnect

**Client → Server (on reconnect):**
```json
{
  "type": "session.reconnect",
  "session_id": "session-uuid",
  "last_checkpoint_id": "checkpoint-uuid",
  "disconnect_timestamp": "2026-01-30T18:15:30Z"
}
```

**Server → Client:**
```json
{
  "type": "session.reconnected",
  "session_id": "session-uuid",
  "reconnected_at": "2026-01-30T18:16:00Z",
  "state_restored": true,
  "missed_duration_seconds": 30,
  "context_summary": "We were discussing strategies for your presentation."
}
```

#### State Checkpoints

Automatic checkpoints every 10 turns or 2 minutes:

```json
{
  "type": "session.checkpoint_created",
  "checkpoint_id": "checkpoint-uuid",
  "timestamp": "2026-01-30T18:20:00Z",
  "turn_count": 10
}
```

---

## REST API

### User Management

#### Get User Profile

**Endpoint:** `GET /v1/users/me`

**Headers:**
```
Authorization: Bearer {access_token}
```

**Response:**
```json
{
  "id": "user-uuid",
  "email": "user@example.com",
  "circle_id": "circle-uuid",
  "created_at": "2026-01-15T10:00:00Z",
  "subscription": {
    "tier": "plus",
    "status": "active",
    "period_start": "2026-01-01T00:00:00Z",
    "period_end": "2026-02-01T00:00:00Z",
    "auto_renew": true
  },
  "preferences": {
    "language": "en-US",
    "timezone": "America/Los_Angeles",
    "notification_enabled": true,
    "voice_id": "user-cloned-voice-id"
  },
  "usage": {
    "sessions_this_week": 5,
    "sessions_this_month": 18,
    "total_sessions": 127
  }
}
```

#### Update User Preferences

**Endpoint:** `PATCH /v1/users/me/preferences`

**Request:**
```json
{
  "language": "en-US",
  "timezone": "America/New_York",
  "notification_enabled": false
}
```

**Response:**
```json
{
  "id": "user-uuid",
  "preferences": {
    "language": "en-US",
    "timezone": "America/New_York",
    "notification_enabled": false,
    "voice_id": "user-cloned-voice-id"
  },
  "updated_at": "2026-01-30T18:00:00Z"
}
```

### Session Management

#### List Sessions

**Endpoint:** `GET /v1/sessions`

**Query Parameters:**
- `limit` (optional): Number of sessions (default: 20, max: 100)
- `offset` (optional): Pagination offset (default: 0)
- `start_date` (optional): Filter by start date (ISO 8601)
- `end_date` (optional): Filter by end date (ISO 8601)

**Response:**
```json
{
  "sessions": [
    {
      "id": "session-uuid-1",
      "started_at": "2026-01-30T18:00:00Z",
      "ended_at": "2026-01-30T18:30:00Z",
      "duration_seconds": 1800,
      "turn_count": 24,
      "completion_status": "completed",
      "summary": {
        "topics": ["work_stress", "presentation_anxiety"],
        "emotions": ["anxious", "relieved"],
        "mood_shift": {
          "from": "anxious",
          "to": "calmer"
        }
      }
    }
  ],
  "pagination": {
    "total": 127,
    "limit": 20,
    "offset": 0,
    "has_more": true
  }
}
```

#### Get Session Details

**Endpoint:** `GET /v1/sessions/{session_id}`

**Response:**
```json
{
  "id": "session-uuid",
  "started_at": "2026-01-30T18:00:00Z",
  "ended_at": "2026-01-30T18:30:00Z",
  "duration_seconds": 1800,
  "turn_count": 24,
  "completion_status": "completed",
  "summary": {
    "topics": ["work_stress", "presentation_anxiety"],
    "emotions_detected": ["anxious", "worried", "relieved", "confident"],
    "emotional_trajectory": [
      {"time": "00:00", "emotion": "anxious", "valence": -0.6},
      {"time": "15:00", "emotion": "calmer", "valence": -0.2},
      {"time": "30:00", "emotion": "confident", "valence": 0.4}
    ],
    "goals_discussed": [],
    "memories_created": 5,
    "wellbeing_score": 7
  },
  "insights": {
    "key_moments": [
      {
        "timestamp": "2026-01-30T18:05:00Z",
        "description": "Breakthrough: Identified root cause of presentation anxiety"
      }
    ],
    "patterns": [
      "Stress tends to peak on Sunday evenings"
    ]
  }
}
```

### Memory Management

#### List Memories

**Endpoint:** `GET /v1/memories`

**Query Parameters:**
- `category` (optional): Filter by category
- `start_date` (optional): Memories created after this date
- `end_date` (optional): Memories created before this date
- `search` (optional): Semantic search query
- `limit` (optional): Number of memories (default: 50, max: 200)

**Response:**
```json
{
  "memories": [
    {
      "id": "mem-uuid-1",
      "category": "work_career",
      "content": "User works in marketing at tech startup",
      "importance": 0.9,
      "created_at": "2026-01-15T10:00:00Z",
      "last_accessed": "2026-01-30T18:05:00Z",
      "access_count": 15
    },
    {
      "id": "mem-uuid-2",
      "category": "goals_aspirations",
      "content": "User set goal to improve work-life balance",
      "importance": 0.85,
      "created_at": "2026-01-20T14:00:00Z",
      "last_accessed": "2026-01-30T18:10:00Z",
      "access_count": 8
    }
  ],
  "pagination": {
    "total": 247,
    "limit": 50,
    "offset": 0,
    "has_more": true
  }
}
```

#### Get Memory

**Endpoint:** `GET /v1/memories/{memory_id}`

**Response:**
```json
{
  "id": "mem-uuid",
  "category": "work_career",
  "content": "User works in marketing at tech startup, currently preparing for major presentation",
  "importance": 0.9,
  "created_at": "2026-01-15T10:00:00Z",
  "session_id": "session-uuid",
  "context": {
    "conversation_snippet": "I work in marketing at a tech startup...",
    "emotional_context": "neutral"
  },
  "metadata": {
    "tags": ["work", "career", "presentation"],
    "last_accessed": "2026-01-30T18:05:00Z",
    "access_count": 15
  }
}
```

#### Delete Memory

**Endpoint:** `DELETE /v1/memories/{memory_id}`

**Response:**
```json
{
  "id": "mem-uuid",
  "deleted": true,
  "deleted_at": "2026-01-30T18:30:00Z"
}
```

#### Delete Memories by Category

**Endpoint:** `DELETE /v1/memories/category/{category}`

**Response:**
```json
{
  "category": "work_career",
  "deleted_count": 23,
  "deleted_at": "2026-01-30T18:30:00Z"
}
```

#### Delete Memories by Date Range

**Endpoint:** `DELETE /v1/memories/date-range`

**Query Parameters:**
- `start_date` (required): Start date (ISO 8601)
- `end_date` (required): End date (ISO 8601)

**Response:**
```json
{
  "date_range": {
    "start": "2026-01-01T00:00:00Z",
    "end": "2026-01-15T23:59:59Z"
  },
  "deleted_count": 45,
  "deleted_at": "2026-01-30T18:30:00Z"
}
```

### Consent Management

#### Get Consent Settings

**Endpoint:** `GET /v1/consent`

**Response:**
```json
{
  "user_id": "user-uuid",
  "consent_version": "2.0",
  "level": "partial",
  "categories": {
    "personal_facts": true,
    "relationships": true,
    "work_career": true,
    "health_wellbeing": true,
    "goals_aspirations": true,
    "emotions_feelings": true,
    "habits_routines": true,
    "preferences": true,
    "past_conversations": true,
    "sensitive_topics": false
  },
  "time_boundaries": {
    "remember_until": null,
    "auto_delete_after_days": null
  },
  "sharing_consent": {
    "c2c_communication": false,
    "anonymized_analytics": true,
    "research_consent": false
  },
  "granted_at": "2026-01-15T10:00:00Z",
  "updated_at": "2026-01-20T14:00:00Z"
}
```

#### Update Consent Settings

**Endpoint:** `PATCH /v1/consent`

**Request:**
```json
{
  "categories": {
    "health_wellbeing": false,
    "sensitive_topics": true
  },
  "sharing_consent": {
    "c2c_communication": true
  }
}
```

**Response:**
```json
{
  "user_id": "user-uuid",
  "consent_version": "2.0",
  "categories": {
    "personal_facts": true,
    "relationships": true,
    "work_career": true,
    "health_wellbeing": false,
    "goals_aspirations": true,
    "emotions_feelings": true,
    "habits_routines": true,
    "preferences": true,
    "past_conversations": true,
    "sensitive_topics": true
  },
  "sharing_consent": {
    "c2c_communication": true,
    "anonymized_analytics": true,
    "research_consent": false
  },
  "updated_at": "2026-01-30T18:30:00Z"
}
```

### Goals Management

#### List Goals

**Endpoint:** `GET /v1/goals`

**Query Parameters:**
- `status` (optional): active, completed, archived
- `category` (optional): health, career, relationships, habits, personal_growth

**Response:**
```json
{
  "goals": [
    {
      "id": "goal-uuid-1",
      "title": "Exercise 4x per week",
      "category": "health",
      "description": "Go to gym or run 4 times each week",
      "status": "active",
      "progress_percentage": 75,
      "target_date": "2026-03-01",
      "created_at": "2026-01-15T10:00:00Z",
      "last_updated": "2026-01-30T18:00:00Z",
      "check_ins": [
        {
          "date": "2026-01-23",
          "progress": "Completed 4 workouts this week"
        },
        {
          "date": "2026-01-30",
          "progress": "On track - 3 workouts done so far"
        }
      ]
    }
  ]
}
```

#### Create Goal

**Endpoint:** `POST /v1/goals`

**Request:**
```json
{
  "title": "Meditate 10 minutes daily",
  "category": "health",
  "description": "Practice daily meditation for wellbeing",
  "target_date": "2026-06-01",
  "check_in_frequency": "weekly"
}
```

**Response:**
```json
{
  "id": "goal-uuid",
  "title": "Meditate 10 minutes daily",
  "category": "health",
  "description": "Practice daily meditation for wellbeing",
  "status": "active",
  "progress_percentage": 0,
  "target_date": "2026-06-01",
  "check_in_frequency": "weekly",
  "created_at": "2026-01-30T18:30:00Z"
}
```

#### Update Goal Progress

**Endpoint:** `POST /v1/goals/{goal_id}/check-in`

**Request:**
```json
{
  "progress": "Meditated 5 days this week",
  "progress_percentage": 70,
  "notes": "Finding it easier to build the habit"
}
```

**Response:**
```json
{
  "id": "goal-uuid",
  "progress_percentage": 70,
  "last_check_in": {
    "date": "2026-01-30",
    "progress": "Meditated 5 days this week",
    "notes": "Finding it easier to build the habit"
  },
  "updated_at": "2026-01-30T18:30:00Z"
}
```

### Voice Cloning

#### Upload Voice Sample

**Endpoint:** `POST /v1/voice/clone`

**Request:** `multipart/form-data`
```
audio: [audio file, 30+ seconds, WAV/MP3]
consent: true
```

**Response:**
```json
{
  "job_id": "voice-job-uuid",
  "status": "processing",
  "estimated_completion": "2026-01-30T22:00:00Z",
  "created_at": "2026-01-30T18:00:00Z"
}
```

#### Check Voice Cloning Status

**Endpoint:** `GET /v1/voice/clone/{job_id}`

**Response:**
```json
{
  "job_id": "voice-job-uuid",
  "status": "completed",
  "voice_id": "voice-uuid",
  "quality_score": 4.5,
  "completed_at": "2026-01-30T20:30:00Z"
}
```

**Status Values:**
- `processing`: Voice model being trained
- `completed`: Voice cloning successful
- `failed`: Voice cloning failed
- `insufficient_quality`: Audio quality too low

---

## AI-to-AI (C2C) Protocol

### C2C Connection Management

#### List Connections

**Endpoint:** `GET /v1/c2c/connections`

**Response:**
```json
{
  "connections": [
    {
      "connection_id": "conn-uuid",
      "connected_circle_id": "circle-uuid-2",
      "connected_user": {
        "name": "Sarah",
        "circle_name": "Sarah's Circle"
      },
      "connection_type": "moderate",
      "established_at": "2026-01-20T10:00:00Z",
      "last_interaction": "2026-01-29T15:00:00Z",
      "status": "active"
    }
  ]
}
```

#### Request Connection

**Endpoint:** `POST /v1/c2c/connections`

**Request:**
```json
{
  "target_user_id": "user-uuid-2",
  "connection_type": "moderate",
  "message": "I'd like to connect our Circles for mutual support"
}
```

**Response:**
```json
{
  "request_id": "request-uuid",
  "status": "pending",
  "target_user_id": "user-uuid-2",
  "sent_at": "2026-01-30T18:00:00Z"
}
```

#### Accept Connection

**Endpoint:** `POST /v1/c2c/connections/{request_id}/accept`

**Request:**
```json
{
  "connection_type": "moderate",
  "sharing_preferences": {
    "goals": true,
    "progress": true,
    "mood_state": false,
    "achievements": true
  }
}
```

**Response:**
```json
{
  "connection_id": "conn-uuid",
  "status": "active",
  "connected_circle_id": "circle-uuid-2",
  "connection_type": "moderate",
  "established_at": "2026-01-30T18:05:00Z"
}
```

### C2C Communication Protocol

#### C2C Request Format

**WebSocket Event - Client → Server:**
```json
{
  "type": "c2c.send_request",
  "target_circle_id": "circle-uuid-2",
  "request_type": "query",
  "payload": {
    "query": "How is Sarah doing with her running goals?",
    "context": "User asking about friend's progress",
    "requested_fields": ["goals", "progress"]
  }
}
```

**Server validates and forwards to target Circle**

#### C2C Response Format

**WebSocket Event - Server → Client (target Circle):**
```json
{
  "type": "c2c.incoming_request",
  "request_id": "c2c-req-uuid",
  "from_circle_id": "circle-uuid-1",
  "from_user_name": "Alex",
  "request_type": "query",
  "payload": {
    "query": "How is Sarah doing with her running goals?",
    "requested_fields": ["goals", "progress"]
  }
}
```

**Target Circle processes and responds:**

**WebSocket Event - Client → Server:**
```json
{
  "type": "c2c.send_response",
  "request_id": "c2c-req-uuid",
  "status": "success",
  "payload": {
    "goals": [
      {
        "title": "Run 5K",
        "progress_percentage": 85,
        "status": "on_track"
      }
    ],
    "summary": "Sarah completed her first 5K last week and is training for a 10K"
  }
}
```

**Server forwards response to requesting Circle**

**WebSocket Event - Server → Client (original Circle):**
```json
{
  "type": "c2c.response_received",
  "request_id": "c2c-req-uuid",
  "from_circle_id": "circle-uuid-2",
  "from_user_name": "Sarah",
  "status": "success",
  "payload": {
    "goals": [
      {
        "title": "Run 5K",
        "progress_percentage": 85,
        "status": "on_track"
      }
    ],
    "summary": "Sarah completed her first 5K last week and is training for a 10K"
  }
}
```

### C2C Request Types

#### 1. Query Request

**Purpose:** Request information from connected Circle

```json
{
  "request_type": "query",
  "payload": {
    "query": "What goals is Sarah working on?",
    "requested_fields": ["goals", "progress"]
  }
}
```

#### 2. Update Notification

**Purpose:** Share update with connected Circle

```json
{
  "request_type": "update",
  "payload": {
    "update_type": "achievement",
    "content": {
      "achievement": "Completed first 5K run",
      "goal": "Marathon training",
      "emotion": "proud",
      "message": "Alex just completed their first 5K! 🎉"
    }
  }
}
```

#### 3. Support Request

**Purpose:** Request encouragement or support

```json
{
  "request_type": "support",
  "payload": {
    "situation": "motivation_low",
    "context": "User struggling to maintain running routine",
    "request": "Could your user send encouragement?",
    "sensitivity": "moderate"
  }
}
```

### C2C Privacy & Security

#### Privacy Filtering

All C2C responses are filtered based on consent:

```json
{
  "type": "c2c.response_filtered",
  "request_id": "c2c-req-uuid",
  "filtered_fields": ["health_details", "specific_locations"],
  "reason": "consent_restrictions"
}
```

#### Rate Limiting

C2C requests are rate limited per circle:

```json
{
  "type": "c2c.rate_limit_exceeded",
  "limit": "60 requests per hour",
  "current_count": 60,
  "reset_time": "2026-01-30T19:00:00Z"
}
```

#### Audit Logging

All C2C interactions are logged for user review:

**Endpoint:** `GET /v1/c2c/audit-log`

**Response:**
```json
{
  "interactions": [
    {
      "id": "audit-uuid",
      "timestamp": "2026-01-30T18:00:00Z",
      "from_circle_id": "circle-uuid-1",
      "to_circle_id": "circle-uuid-2",
      "request_type": "query",
      "response_status": "success",
      "information_shared": ["goals", "progress"],
      "user_notified": false
    }
  ],
  "pagination": {
    "total": 45,
    "limit": 20,
    "offset": 0
  }
}
```

---

## Error Handling

### Error Response Format

All errors follow a consistent format:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "Additional context"
    },
    "request_id": "req-uuid",
    "timestamp": "2026-01-30T18:00:00Z"
  }
}
```

### HTTP Status Codes

| Code | Meaning | Usage |
|------|---------|-------|
| 200 | OK | Successful request |
| 201 | Created | Resource created successfully |
| 204 | No Content | Successful deletion |
| 400 | Bad Request | Invalid request parameters |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Valid auth but insufficient permissions |
| 404 | Not Found | Resource does not exist |
| 409 | Conflict | Resource conflict (duplicate, etc.) |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Temporary unavailability |

### Common Error Codes

#### Authentication Errors

```json
{
  "code": "AUTH_TOKEN_EXPIRED",
  "message": "Access token has expired",
  "details": {
    "expired_at": "2026-01-30T17:45:00Z"
  }
}
```

```json
{
  "code": "AUTH_TOKEN_INVALID",
  "message": "Access token is invalid or malformed"
}
```

```json
{
  "code": "AUTH_INSUFFICIENT_PERMISSIONS",
  "message": "User does not have required permissions",
  "details": {
    "required_permission": "c2c_enabled",
    "user_tier": "free"
  }
}
```

#### WebSocket Errors

```json
{
  "code": "WS_CONNECTION_FAILED",
  "message": "Failed to establish WebSocket connection",
  "details": {
    "reason": "authentication_failed"
  }
}
```

```json
{
  "code": "WS_SESSION_NOT_FOUND",
  "message": "Session not found or expired",
  "details": {
    "session_id": "session-uuid"
  }
}
```

#### Voice Processing Errors

```json
{
  "code": "ASR_PROCESSING_FAILED",
  "message": "Failed to transcribe audio",
  "details": {
    "reason": "audio_quality_too_low",
    "audio_duration_ms": 100
  }
}
```

```json
{
  "code": "TTS_GENERATION_FAILED",
  "message": "Failed to generate speech",
  "details": {
    "reason": "voice_model_unavailable"
  }
}
```

#### Memory Errors

```json
{
  "code": "MEMORY_CONSENT_REQUIRED",
  "message": "Memory access requires user consent",
  "details": {
    "consent_level": "none",
    "required_level": "partial"
  }
}
```

```json
{
  "code": "MEMORY_NOT_FOUND",
  "message": "Memory not found or already deleted",
  "details": {
    "memory_id": "mem-uuid"
  }
}
```

#### C2C Errors

```json
{
  "code": "C2C_CONNECTION_NOT_FOUND",
  "message": "No active connection with target circle",
  "details": {
    "target_circle_id": "circle-uuid-2"
  }
}
```

```json
{
  "code": "C2C_RATE_LIMIT_EXCEEDED",
  "message": "C2C request rate limit exceeded",
  "details": {
    "limit": "60 per hour",
    "reset_time": "2026-01-30T19:00:00Z"
  }
}
```

### Retry Logic

**Recommended Retry Strategy:**

```javascript
async function retryRequest(requestFn, maxRetries = 3) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await requestFn();
    } catch (error) {
      // Retry on network errors and 5xx server errors
      if (error.code >= 500 || error.code === 'NETWORK_ERROR') {
        const delay = Math.min(1000 * Math.pow(2, attempt), 10000);
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      
      // Don't retry on client errors (4xx)
      throw error;
    }
  }
  
  throw new Error('Max retries exceeded');
}
```

---

## Rate Limits

### Standard Rate Limits

| Endpoint Category | Limit | Window |
|-------------------|-------|--------|
| Authentication | 5 requests | 15 minutes |
| REST API (general) | 1000 requests | 1 hour |
| Memory operations | 100 requests | 1 hour |
| C2C requests | 60 requests | 1 hour |
| Voice sessions | Based on tier | Daily |

### Tier-Based Session Limits

| Tier | Sessions per Week | Sessions per Day |
|------|-------------------|------------------|
| Free | 3 | 1 |
| Plus | Unlimited | Unlimited |
| Premium | Unlimited | Unlimited |

### Rate Limit Headers

All REST API responses include rate limit headers:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 987
X-RateLimit-Reset: 1706634000
```

### Rate Limit Exceeded Response

**HTTP 429 Too Many Requests:**
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded",
    "details": {
      "limit": "1000 requests per hour",
      "reset_time": "2026-01-30T19:00:00Z",
      "retry_after_seconds": 300
    }
  }
}
```

---

## SDK Reference

### JavaScript/TypeScript SDK

#### Installation

```bash
npm install @tybelos/sdk
```

#### Basic Usage

```typescript
import { TybelosClient } from '@tybelos/sdk';

// Initialize client
const client = new TybelosClient({
  apiKey: 'your-api-key',
  environment: 'production' // or 'staging', 'development'
});

// Authenticate
const auth = await client.auth.login({
  email: 'user@example.com',
  password: 'password'
});

// Start voice session
const session = await client.voice.startSession({
  audioQuality: 'high',
  emotionDetection: true,
  memoryEnabled: true
});

// Listen to events
session.on('transcription', (text) => {
  console.log('User said:', text);
});

session.on('response', (response) => {
  console.log('AI responded:', response.text);
});

session.on('emotion', (emotion) => {
  console.log('Detected emotion:', emotion.primary);
});

// Stream audio
await session.streamAudio(audioStream);

// End session
await session.end();
```

#### Voice Session Example

```typescript
import { TybelosClient, VoiceSession } from '@tybelos/sdk';

const client = new TybelosClient({ apiKey: 'your-api-key' });

// Start session
const session: VoiceSession = await client.voice.startSession();

// Handle audio input (from microphone)
navigator.mediaDevices.getUserMedia({ audio: true })
  .then(stream => {
    session.streamAudio(stream);
  });

// Handle events
session.on('ai_speaking_started', () => {
  console.log('AI is speaking...');
});

session.on('ai_speaking_ended', () => {
  console.log('AI finished speaking');
});

session.on('response', (response) => {
  console.log('Response:', response.text);
  console.log('Latency:', response.latency_ms);
});

// End session after 30 minutes
setTimeout(async () => {
  const summary = await session.end();
  console.log('Session summary:', summary);
}, 30 * 60 * 1000);
```

### Python SDK

#### Installation

```bash
pip install tybelos-sdk
```

#### Basic Usage

```python
from tybelos import TybelosClient

# Initialize client
client = TybelosClient(
    api_key='your-api-key',
    environment='production'
)

# Authenticate
auth = client.auth.login(
    email='user@example.com',
    password='password'
)

# List sessions
sessions = client.sessions.list(limit=10)

# Get session details
session = client.sessions.get('session-uuid')

# List memories
memories = client.memories.list(category='work_career')

# Delete memory
client.memories.delete('memory-uuid')

# Get consent settings
consent = client.consent.get()

# Update consent
client.consent.update({
    'categories': {
        'health_wellbeing': False
    }
})
```

### iOS SDK (Swift)

#### Installation (CocoaPods)

```ruby
pod 'TybelosSDK'
```

#### Basic Usage

```swift
import TybelosSDK

// Initialize client
let client = TybelosClient(apiKey: "your-api-key")

// Login
client.auth.login(email: "user@example.com", password: "password") { result in
    switch result {
    case .success(let auth):
        print("Logged in as \(auth.user.email)")
    case .failure(let error):
        print("Login failed: \(error)")
    }
}

// Start voice session
client.voice.startSession { result in
    switch result {
    case .success(let session):
        session.delegate = self
        session.start()
    case .failure(let error):
        print("Failed to start session: \(error)")
    }
}

// VoiceSessionDelegate implementation
extension ViewController: VoiceSessionDelegate {
    func session(_ session: VoiceSession, didReceiveTranscription text: String) {
        print("User said: \(text)")
    }
    
    func session(_ session: VoiceSession, didReceiveResponse response: AIResponse) {
        print("AI responded: \(response.text)")
    }
    
    func session(_ session: VoiceSession, didDetectEmotion emotion: Emotion) {
        print("Detected emotion: \(emotion.primary)")
    }
}
```

### Android SDK (Kotlin)

#### Installation (Gradle)

```kotlin
implementation 'com.tybelos:sdk:1.0.0'
```

#### Basic Usage

```kotlin
import com.tybelos.sdk.TybelosClient
import com.tybelos.sdk.voice.VoiceSession

// Initialize client
val client = TybelosClient(apiKey = "your-api-key")

// Login
client.auth.login("user@example.com", "password") { result ->
    result.onSuccess { auth ->
        println("Logged in as ${auth.user.email}")
    }.onFailure { error ->
        println("Login failed: $error")
    }
}

// Start voice session
client.voice.startSession { result ->
    result.onSuccess { session ->
        session.setListener(object : VoiceSession.Listener {
            override fun onTranscription(text: String) {
                println("User said: $text")
            }
            
            override fun onResponse(response: AIResponse) {
                println("AI responded: ${response.text}")
            }
            
            override fun onEmotion(emotion: Emotion) {
                println("Detected emotion: ${emotion.primary}")
            }
        })
        
        session.start()
    }.onFailure { error ->
        println("Failed to start session: $error")
    }
}
```

---

## Appendix

### WebSocket Message Types Reference

**Client → Server:**
- `session.start` - Start new session
- `session.pause` - Pause current session
- `session.resume` - Resume paused session
- `session.end` - End current session
- `session.reconnect` - Reconnect after disconnect
- `webrtc.offer` - WebRTC SDP offer
- `webrtc.answer` - WebRTC SDP answer
- `webrtc.ice_candidate` - WebRTC ICE candidate
- `interaction.user_interrupted` - User interrupted AI
- `c2c.send_request` - Send C2C request
- `c2c.send_response` - Send C2C response

**Server → Client:**
- `connection.established` - WebSocket connected
- `session.started` - Session started successfully
- `session.paused` - Session paused
- `session.resumed` - Session resumed
- `session.ended` - Session ended
- `session.reconnected` - Session reconnected
- `session.checkpoint_created` - State checkpoint created
- `webrtc.offer` - WebRTC SDP offer
- `webrtc.answer` - WebRTC SDP answer
- `webrtc.ice_candidate` - WebRTC ICE candidate
- `vad.user_speaking_started` - User started speaking
- `vad.user_speaking_ended` - User stopped speaking
- `vad.ai_speaking_started` - AI started speaking
- `vad.ai_speaking_ended` - AI stopped speaking
- `transcription.interim` - Interim transcription result
- `transcription.final` - Final transcription result
- `emotion.detected` - Emotion detected
- `memory.extracted` - Memory extracted from conversation
- `memory.retrieved` - Memory retrieved for context
- `response.generation_started` - AI response generation started
- `response.text_generated` - AI response text ready
- `response.audio_chunk` - Audio chunk ready
- `response.complete` - Response generation complete
- `interaction.ai_stopped` - AI stopped (interrupted)
- `system.connection_quality` - Connection quality update
- `system.network_degraded` - Network quality degraded
- `system.quality_adjusted` - Audio quality adjusted
- `system.maintenance_warning` - Maintenance scheduled
- `c2c.incoming_request` - Incoming C2C request
- `c2c.response_received` - C2C response received
- `c2c.response_filtered` - C2C response filtered
- `c2c.rate_limit_exceeded` - C2C rate limit exceeded
- `error` - Error occurred

### Glossary

- **ASR**: Automatic Speech Recognition - converts speech to text
- **C2C**: Circle-to-Circle - AI-to-AI communication protocol
- **ICE**: Interactive Connectivity Establishment - NAT traversal protocol
- **JWT**: JSON Web Token - authentication token format
- **MOS**: Mean Opinion Score - voice quality metric (1-5 scale)
- **Opus**: Audio codec optimized for voice
- **PCM**: Pulse Code Modulation - uncompressed audio format
- **SDP**: Session Description Protocol - WebRTC negotiation format
- **STUN**: Session Traversal Utilities for NAT - helps establish peer connections
- **TTS**: Text-to-Speech - converts text to speech
- **TURN**: Traversal Using Relays around NAT - relay server for peer connections
- **VAD**: Voice Activity Detection - detects when someone is speaking
- **WebRTC**: Web Real-Time Communication - protocol for audio/video streaming
- **WER**: Word Error Rate - ASR accuracy metric

---

**Document Version:** 1.0  
**Last Updated:** January 2026  
**For API Support:** api-support@tybelos.com  
**For Technical Questions:** engineering@tybelos.com


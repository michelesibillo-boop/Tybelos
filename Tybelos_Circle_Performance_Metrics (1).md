# Tybelos Circle - Performance Metrics & KPIs

## Executive Dashboard (Top-Level Metrics)

### North Star Metrics
| Metric | Target | Critical Threshold | Description |
|--------|--------|-------------------|-------------|
| **Daily Active Users (DAU)** | Growth +15% MoM | -5% decline | Users engaging with voice companion daily |
| **User Wellbeing Score** | 7.5+/10 | <6.5 | Self-reported wellbeing improvement |
| **Session Completion Rate** | 85%+ | <70% | Voice sessions completed vs. abandoned |
| **Net Promoter Score (NPS)** | 50+ | <30 | User recommendation likelihood |

---

## 1. USER ENGAGEMENT METRICS

### Voice Interaction Quality
| KPI | Target | Formula | Frequency |
|-----|--------|---------|-----------|
| **Avg Session Duration** | 8-12 min | Total session time / # sessions | Daily |
| **Sessions per User per Day** | 2.5+ | Total sessions / DAU | Daily |
| **Voice Input Success Rate** | 95%+ | Successful transcriptions / total attempts | Real-time |
| **Response Latency** | <2 sec | Time from user stop speaking → AI response | Real-time |
| **Conversation Turn Depth** | 6+ turns | Avg exchanges per session | Weekly |

### Emotional Connection
| KPI | Target | Measurement Method |
|-----|--------|-------------------|
| **Emotional Resonance Score** | 8+/10 | Post-session survey (sample) |
| **Repeat Usage Rate** | 70%+ | % users returning within 24h |
| **Peak Emotional Moments** | 2+ per session | AI-detected positive emotional peaks |

---

## 2. TECHNICAL PERFORMANCE METRICS

### Infrastructure Health
| Metric | SLA Target | Alert Threshold |
|--------|-----------|-----------------|
| **API Response Time (p95)** | <200ms | >500ms |
| **WebSocket Connection Uptime** | 99.9% | <99.5% |
| **TTS Generation Latency** | <1.5 sec | >3 sec |
| **Database Query Time (p95)** | <100ms | >300ms |

### Voice Pipeline Performance
| Metric | Target | Critical |
|--------|--------|----------|
| **ASR Accuracy (WER)** | <5% | >10% |
| **TTS Quality Score (MOS)** | 4.2+/5 | <3.8 |
| **Audio Dropout Rate** | <0.5% | >2% |
| **Concurrent Voice Sessions** | 10,000+ | Monitor capacity |

### AI/ML Performance
| Metric | Target | Review Cycle |
|--------|--------|--------------|
| **Intent Classification Accuracy** | 92%+ | Weekly |
| **Memory Retrieval Relevance** | 85%+ | Bi-weekly |
| **Emotion Detection Accuracy** | 80%+ | Weekly |
| **Personalization Effectiveness** | 75%+ sessions use memory | Daily |

---

## 3. PRODUCT METRICS

### Feature Adoption
| Feature | Adoption Target | Usage Target |
|---------|----------------|--------------|
| **AI-to-AI Communication (C2C)** | 30% of users | 2x per week |
| **Memory Consent Enabled** | 80%+ | - |
| **Voice Cloning Setup** | 50%+ | - |
| **Journey Tracking** | 60% weekly active | 3+ views per week |
| **Circle (Social Feed)** | 40% engagement | 5+ interactions/week |

### Wellbeing Impact
| Metric | Target | Measurement |
|--------|--------|-------------|
| **Self-Reported Mood Improvement** | 70% positive change | Weekly check-in |
| **Goal Progress Tracking** | 60% users set goals | % with measurable progress |
| **Motivation Boost Sessions** | 40% of all sessions | AI classification |
| **Crisis Prevention Interventions** | Monitor & escalate | AI detection + human review |

---

## 4. BUSINESS METRICS

### Revenue & Growth
| KPI | Target | Period |
|-----|--------|--------|
| **Monthly Recurring Revenue (MRR)** | Growth +20% MoM | Monthly |
| **Customer Acquisition Cost (CAC)** | <$30 | Monthly |
| **Lifetime Value (LTV)** | $200+ | Quarterly |
| **LTV:CAC Ratio** | 6:1+ | Quarterly |
| **Conversion Rate (Free → Paid)** | 15%+ | Monthly |

### Retention
| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| **Day 1 Retention** | 60%+ | <40% |
| **Day 7 Retention** | 45%+ | <30% |
| **Day 30 Retention** | 35%+ | <20% |
| **Churn Rate** | <5% monthly | >8% |
| **Reactivation Rate** | 25% of churned | <15% |

### Subscription Metrics
| KPI | Target | Formula |
|-----|--------|---------|
| **Trial-to-Paid Conversion** | 18%+ | Paid subs / trial starts |
| **Subscription Upgrades** | 10% quarterly | Premium tier adoption |
| **Payment Success Rate** | 98%+ | Successful charges / attempts |

---

## 5. SOCIAL & GROWTH METRICS

### Viral Coefficient
| Metric | Target | Calculation |
|--------|--------|-------------|
| **Referral Rate** | 40% of users | % users who refer others |
| **Referral Conversion** | 25%+ | Referred signups / invites sent |
| **K-Factor (Virality)** | 1.2+ | Referral rate × conversion rate |

### Community Health
| KPI | Target | Frequency |
|-----|--------|-----------|
| **Positive State Sharing** | 30% opt-in | Monthly |
| **Circle Engagement Rate** | 25% weekly | % interacting with Circle feed |
| **AI Connection Requests** | 2+ per active user | Per month |

---

## 6. PRIVACY & TRUST METRICS

### User Control
| Metric | Target | Importance |
|--------|--------|-----------|
| **Consent Update Frequency** | Monitor | Healthy = regular reviews |
| **Data Export Requests** | <5% users | Flag if >10% |
| **Account Deletion Rate** | <3% monthly | Alert if >5% |
| **Privacy Settings Engagement** | 60%+ users customize | Indicates trust |

### Security
| KPI | SLA | Review |
|-----|-----|--------|
| **Zero Security Breaches** | 100% | Continuous |
| **Encryption Coverage** | 100% sensitive data | Audit quarterly |
| **Consent Audit Pass Rate** | 100% | Quarterly |

---

## 7. SUPPORT & SATISFACTION

### Customer Support
| Metric | Target | Alert Threshold |
|--------|--------|----------------|
| **First Response Time** | <2 hours | >6 hours |
| **Resolution Time** | <24 hours | >48 hours |
| **CSAT (Support)** | 4.5+/5 | <4.0 |
| **Support Ticket Volume** | <5% of users/month | >10% |

---

## DASHBOARD REPORTING CADENCE

### Daily Monitoring
- DAU/MAU
- Session metrics
- Technical performance (latency, uptime)
- Critical errors

### Weekly Review
- Engagement trends
- Feature adoption
- AI model performance
- Retention cohorts

### Monthly Business Review
- Revenue metrics
- Churn analysis
- Growth metrics
- Product roadmap alignment

### Quarterly Strategic Review
- North Star metric progress
- LTV:CAC analysis
- Wellbeing impact assessment
- Platform scalability review

---

## ALERT SYSTEM

### Critical (Immediate Action)
- System uptime <99.5%
- Security breach detected
- Payment processing failure >5%
- Crisis intervention needed

### High Priority (Within 4 hours)
- DAU decline >10%
- Session completion rate <70%
- ASR/TTS quality degradation
- Churn spike >2x normal

### Medium Priority (Within 24 hours)
- Feature adoption below target
- NPS decline >5 points
- Support ticket backlog
- Referral rate drop

---

## SUCCESS CRITERIA BY PHASE

### Phase 1: Launch (Months 1-3)
- [ ] 1,000+ DAU
- [ ] 70%+ Day 7 retention
- [ ] <3 sec response latency
- [ ] 10%+ trial conversion

### Phase 2: Growth (Months 4-6)
- [ ] 5,000+ DAU
- [ ] NPS 40+
- [ ] 15%+ trial conversion
- [ ] K-factor >1.0

### Phase 3: Scale (Months 7-12)
- [ ] 20,000+ DAU
- [ ] NPS 50+
- [ ] LTV:CAC ratio 6:1
- [ ] 30%+ feature adoption across board

---

**Document Version:** 1.0  
**Last Updated:** January 2026  
**Owner:** Product & Engineering Teams  
**Review Cycle:** Monthly

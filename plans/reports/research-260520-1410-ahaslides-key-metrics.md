# Research: Chỉ số quan trọng của AhaSlides

**Date:** 2026-05-20
**Author:** em (research session)
**Sources:** Confluence (AhaSlides Atlassian), Mixpanel (eu.mixpanel.com — project 2668743), Notion (workspace AhaSlider)

---

## TL;DR — 3 tầng chỉ số

1. **North Star framework**: **AARRR** (Acquisition → Activation → Revenue → Retention → Referral). Mọi team Growth + Product đều đồng quy về đây (Q1-Q2/2025 Company OKR + Areas of Focus Sep 2024).
2. **3 chỉ số "lớn nhất" công ty đang tracking quý gần nhất** (Q1+Q2 2025):
   - **New gross revenue** (không tính renewal) — Q1 đạt $381K (+41.77% YoY), Q2 đạt $340K (+33.44% YoY)
   - **Total events** (số presentation host live) — Q1 93.75K (+37.52% YoY), Q2 96.79K (+40.92% YoY)
   - **28-day active hosting users** — Q1 13.03K (+50.55%), Q2 11.93K (+53.56%)
3. **Activation rate + Payment rate** là 2 chỉ số gate chính cho health của funnel. Activation rate 2024 avg 5.3% (giảm so với 7.7% năm 2023 nhưng đang gap-close). Payment rate 2024 avg 1.9% (target ~2.2%, đạt peak 3% Dec 2024).

---

## 1. Framework chính — AARRR + Customer Journey 5 stages

### 1.1 AARRR
Nguồn: Areas of Focus (Sep 2024) + Company OKR Q1-Q2/2025.

| Stage | Mục tiêu | Owner chính |
|---|---|---|
| **Acquisition** | Acquire leads, organic traffic, signups | Team Boosters + Marketing |
| **Activation** | New user → meaningful first use (host được 1 event hoặc tạo presentation đầu tiên) | Team Boosters + Product |
| **Revenue** | Free → paid, monthly → yearly, expansion | R.E.O. + Sales |
| **Retention** | Quay lại host thêm event (28-day, MAU) | Boosters + Product |
| **Referral** | Presenter mời presenter mới, participant convert thành presenter | Boosters + Growth |

### 1.2 Customer Journey 5 stages (Miro board chính của Growth)
1. Discovery & Awareness
2. Engagement & Decision
3. Conversion & Use
4. Retention & Loyalty
5. Expansion & Advocacy

→ Growth Team chia OKR theo đúng 5 stages này thay vì chia theo channel.

---

## 2. Top company-level KPIs (theo OKR gần nhất)

### 2.1 Q1-Q2/2025 Company OKR (Dave, Jun 2025)

| Metric | Target Q1 | Actual Q1 | Target Q2 | Actual Q2 |
|---|---|---|---|---|
| New gross revenue (ex-renewal) | $360K (+30% YoY) | **$381K (+41.77%)** | $340K (+35% YoY) | **$340K (+33.44%)** |
| Total events | +40% YoY | **+37.52%** (93.75K) | +45% YoY | **+40.92%** (96.79K) |
| Avg 28-day active hosting users | +20% YoY | **+50.55%** (13.03K) | +55% YoY | **+53.56%** (11.93K) |

### 2.2 Q3-Q4/2024 Company OKR (full year context)

- **Events growth YoY** target 20%+ — actual -2% (298K events full year)
- **Revenue growth YoY** target 20%+ — actual +2% YoY ($2.57M annual revenue)
- **MAU (visiting app twice)** — Mixpanel dashboard 8313696
- **MAU (meaningful action)** — Mixpanel dashboard 8646708
- **Activation rate**: 5.3% avg 2024 (vs 7.7% 2023)
- **Payment rate**: 1.9% avg 2024 (vs 2.2% 2023, đạt 3% Dec 2024)
- **Robustness / CSAT**: "Unhappy event rate" Dec 2024 = 6.8% (users rate 1-2 sao sau event)

---

## 3. Phân cấp metric theo team

### 3.1 Growth Team (Cheryl)
Stage-based OKR — mỗi stage có metric riêng:

- **Discovery & Awareness** (KR 1.1.2): Monthly Organic traffic x 1.5 YoY · Monthly Sign-up x 2 YoY · Monthly Organic activation rate +20%
- **Engagement / Decision / Conversion / Use / Retention** (KR 2.2.x): Rating quality + quantity trên G2, Capterra, Gartner, Microsoft marketplace, Zoom marketplace, Google marketplace · Số AhaSlides-related content shared trên Reddit
- **Expansion & Advocacy**: Số account đạt $5K deal hoặc 100+ licenses (US/above) · Activate rate enterprise teams (target 90%+)

### 3.2 Product Team — "Boosters" sub-team chuyên về AARRR
Quote từ Areas of Focus: *"Boosters' typical concerns: Optimising key product metrics: acquisition rate, activation rate, retention rate, referral rate, revenue (AARRR), MAU. The Landing Site, Template Library, Technical SEO, Growth hacking, A/B testing, multivariate testing, In-app communication"*

### 3.3 Product Team — "Core" sub-team
- **Apdex score** (New Relic) — target = 1
  - `GET /api/presentation/audience-data/:code` Dec 2024: 0.93
  - `GET /api/presentation/detail/:id` Dec 2024: 0.62 (cần cải thiện)
- **Internal shameful bug count**
- **Complaint rate**

### 3.4 Product Team — "R.E.O." (Reports, Enterprise & Ops)
- Checkout / subscription / plan management metric
- Enterprise compliance, enterprise integration
- Post-event reports usage

### 3.5 BI Team (Duke) — meta-metrics + alert metrics
BI OKR Q3/2024 setup ra hệ thống auto-alert hàng ngày cho 5 chỉ số:
- **C1 Traffic** — noteworthy signal trong traffic theo cohort
- **C2 Sign-ups** — auto-alert trong vòng 1 ngày
- **C3 Created presentations** — auto-alert + diagnose direct cause
- **C4 Live events** — auto-alert daily
- **C5 Revenue** — calculate CLV, MRR, revenue retention rate, failed payments

### 3.6 Customer Success (Duke)
- **CS SLA**: First response time + subsequent response time theo channel (Email, Chat, Hotline, WhatsApp, Zoho, Social)
- **Empathy score** (model classify Poor/Fair/Good/Excellent): Q4 2024 Good 90%, Excellent 9%, Fair 1%
- **CSAT post-event** (1-5 sao)

---

## 4. Strategic cohorts (cách BI slice data)

Cohort BI luôn tách riêng khi monitor metrics — nếu anh build dashboard cho AhaSlides thì luôn cần filter theo:

- **By behavior**: Virgin · Returning · Resurrection
- **By profession**: L&D (Trainer / Adult Educator / Coach) — đang là cohort chiến lược, có dashboard riêng "How is the L&D cohort performing?"
- **By geography**: Singaporeans (chiến lược nhánh enterprise)
- **By source**: Organic · Paid · Referral
- **By creation path**: Template-based · AI-assisted · Blank
- **By tier**: Free · Essential · Pro · Enterprise team
- **By account size**: Solo · Self-created team (3+ members) · Enterprise

---

## 5. Mixpanel reference (project + dashboards)

**Region**: eu.mixpanel.com (EU server) — không phải US, query phải qua mcp-eu.mixpanel.com.

| Project | ID | Workspace |
|---|---|---|
| AhaSlides web - prod | 2668743 | 3205947 |
| AhaSlides web - dev | 2656889 | 3194417 |

### Dashboards quan trọng

| Dashboard | ID | Mô tả |
|---|---|---|
| Marketing Report Q1+Q2 2025 | 8323571 | Tổng hợp Growth metrics |
| MAU (visiting twice) | 8313696 | Retention base |
| MAU (meaningful action) | 8646708 | Retention quality |
| Activation rate + Payment rate | 8021883 | Funnel health |
| Total events | report 70988039 | Core volume |
| 28-day active hosting users | report 71225564 | Hosting retention |

### BI dashboards (bi.ahaslide.com — Metabase)
- `/dashboard/423-revenue-not-coming-from-renewal` — new gross revenue
- `/dashboard/357-ahaslides-w...` — robustness
- `/question/2739-unhappy-events-rate-monthly` — CSAT post-event

---

## 6. North Star Hypotheses (2023, vẫn được tham chiếu)

Mei Nguyen viết 4 hypothesis định hướng cho năm 2023, vẫn được tham chiếu trong các OKR sau:

1. **H1**: Participants → potential team members. Nếu facilitate được collaboration giữa presenter và participants thì sẽ tăng self-created teams. *Data backing*: 28.7% returning visitors trong Audience app.
2. **H2**: Teams sẽ host nhiều hơn nếu facilitate collaboration giữa teammates.
3. **H3**: Admin của self-created teams ≥3 members sẵn sàng trả phí để members ở lại trong cùng team.
4. **H4**: Tăng team users nhanh bằng cách integrate với existing team tools (Slack, Teams, Zoom, Google).

→ Đây là logic-tree mà 2024-2025 vẫn dùng để chọn "cái gì đáng đo".

---

## 7. Sticky benchmarks (số liệu thực tế để so sánh)

| Chỉ số | Giá trị |
|---|---|
| Annual revenue 2024 | $2.57M |
| Annual events 2024 | ~298K |
| Activation rate 2024 avg | 5.3% |
| Payment rate 2024 avg | 1.9% (peak 3% Dec) |
| Unhappy event rate Dec 2024 | 6.8% |
| Avg 28-day hosting users Q2 2025 | 11.93K |
| New gross revenue Q1 2025 | $381K |
| Total events Q1 2025 | 93.75K |

---

## 8. Unresolved questions

1. **CLV / MRR / Revenue retention** — BI OKR C5 nói sẽ calculate, em chưa fetch được dashboard cụ thể; cần ping Duke để xác nhận con số gần nhất.
2. **Mixpanel "meaningful action" definition** — có dashboard 8646708 nhưng không có doc public về định nghĩa cụ thể (mở presentation? edit? host?).
3. **Referral metric (H4 / BI3)** — Q3 2024 BI investigate "presenter-to-presenter vs participant-to-presenter referral", chưa thấy kết luận chính thức trong space CO.
4. **Net Promoter Score (NPS)** — có nhắc trong People analytics (Duke) nhưng không thấy treo top-level OKR; có thể đã được replace bằng "unhappy event rate".
5. **Mixpanel EU MCP** — em không truy cập trực tiếp được Mixpanel events từ project này (regional restriction). Nếu anh muốn em lấy list top events thực tế thì cần switch sang `mcp-eu.mixpanel.com`.

---

## 9. Recommendation đọc tiếp

Theo thứ tự ưu tiên:

1. [Company OKR Q1-Q2/2025](https://ahaslides.atlassian.net/wiki/spaces/CO/pages/994017339) — top-level
2. [Growth OKR Q1-Q2/2025](https://ahaslides.atlassian.net/wiki/spaces/CO/pages/966524989) — stage breakdown
3. [Areas of Focus Sep 2024](https://ahaslides.atlassian.net/wiki/spaces/AT/pages/870449154) — phân chia team theo metric ownership
4. [BI OKR Q3/2024](https://ahaslides.atlassian.net/wiki/spaces/CO/pages/792002608) — auto-alert framework
5. [Customer Journey Miro board](https://miro.com/app/board/uXjVLhGMhuE=/) — visual map
6. Mixpanel dashboard 8323571 (Marketing Report Q1+Q2 2025) — live numbers

Public reference: [AhaSlides Reports feature](https://ahaslides.com/features/report-and-analytics/) — describe metrics customer-facing.

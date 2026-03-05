# AWS API Gateway Integration - Executive Summary

**Document Date:** January 20, 2026  
**Project:** Trend Micro Vision One API - AWS Integration  
**Status:** Proposal for Executive Review

---

## Quick Facts

| Item | Value |
|------|-------|
| **Total Effort** | 120-160 man-hours (15-20 days) |
| **Timeline** | 4-6 weeks (1 full-time engineer) |
| **Development Cost** | $12,000 - $16,000 |
| **Monthly AWS Cost** | $4-8/month |
| **Annual AWS Cost** | ~$50/year |
| **Payback Period** | 1.4 years |
| **3-Year ROI** | 115% |
| **Risk Level** | Low-Medium |

---

## The Problem

**Current State:**
- Trend Micro API credentials stored in local files (`config/deployment_config.json`)
- No audit trail of API usage
- No centralized rate limiting or monitoring
- Manual credential rotation across all systems
- Scripts directly coupled to Trend Micro API structure

**Risks:**
- Security: Credentials visible to anyone with file access
- Operational: No visibility into API usage patterns
- Compliance: Limited audit capabilities
- Maintenance: API changes require script updates

---

## The Solution

**Proposed Architecture:**
```
Python Scripts → AWS API Gateway → AWS Lambda → Trend Micro API
                      ↓
                AWS Secrets Manager (credentials)
                      ↓
                CloudWatch + X-Ray (monitoring)
```

**Key Benefits:**
1. **Enhanced Security**
   - No local credential storage
   - Credentials in AWS Secrets Manager (encrypted, access-controlled)
   - Complete audit trail via CloudTrail
   - API key-based access control

2. **Better Observability**
   - Real-time monitoring via CloudWatch
   - Distributed tracing via X-Ray
   - Automated alerts for errors/anomalies
   - Usage metrics per client

3. **Operational Efficiency**
   - Centralized rate limiting (prevent API abuse)
   - Response caching (reduce Trend Micro API calls by 30-50%)
   - Automatic retries and error handling
   - Multi-environment support (dev/test/prod)

4. **Future-Proof**
   - Abstraction layer shields from Trend Micro API changes
   - Easy to add business logic (validation, transformation)
   - Support for multiple regions
   - Foundation for additional integrations

---

## Investment Required

### One-Time Costs

| Item | Cost | Notes |
|------|------|-------|
| Engineer Time | $12,000-$16,000 | 140 hours @ $100/hr blended rate |
| AWS Setup | $200 | One-time account configuration |
| Tools/Licenses | $300 | Development and testing tools |
| **Total** | **$12,500-$16,500** | |

### Ongoing Costs

| Item | Monthly | Annual | Notes |
|------|---------|--------|-------|
| AWS API Gateway | $0.35 | $4 | 100K requests/month |
| AWS Lambda | $1.87 | $22 | 100K invocations |
| Secrets Manager | $0.40 | $5 | 1 secret |
| CloudWatch | $0.80 | $10 | Logs and metrics |
| X-Ray | $0.50 | $6 | Distributed tracing |
| **Total** | **$4** | **$50** | Scales with usage |

---

## Return on Investment

### Annual Benefits

| Category | Annual Savings | Calculation |
|----------|----------------|-------------|
| **Operational Efficiency** | $3,600 | 3 hours/month saved × 12 × $100/hr |
| **Development Efficiency** | $1,800 | 1.5 hours/month saved × 12 × $100/hr |
| **Security Risk Reduction** | $5,000 | Estimated incident cost avoidance |
| **Total Annual Benefit** | **$10,400** | |

### 3-Year Financial Summary

| Year | Investment | AWS Costs | Benefits | Net |
|------|------------|-----------|----------|-----|
| Year 0 | $14,500 | - | - | -$14,500 |
| Year 1 | - | $50 | $10,400 | $10,350 |
| Year 2 | - | $50 | $10,400 | $10,350 |
| Year 3 | - | $50 | $10,400 | $10,350 |
| **Total** | **$14,500** | **$150** | **$31,200** | **$16,550** |

**3-Year ROI:** 115% return on investment

---

## Timeline & Milestones

### Option 1: Full Implementation (Recommended)

**Duration:** 6 weeks, 1 full-time engineer

```
Week 1-2: AWS Infrastructure Setup
├─ AWS account, IAM, Secrets Manager
├─ Lambda proxy function
├─ API Gateway configuration
└─ Monitoring setup

Week 3-4: Code Updates & Testing
├─ Script refactoring
├─ Lambda wrappers
├─ Unit & integration testing
└─ Performance testing

Week 5-6: Documentation & Migration
├─ Technical documentation
├─ Deployment to production
├─ Gradual migration
└─ Final verification
```

### Option 2: MVP Implementation (Quick Win)

**Duration:** 3 weeks, 1 full-time engineer

```
Week 1-2: Core Infrastructure
├─ API Gateway + Lambda proxy only
├─ Secrets Manager setup
└─ Basic monitoring

Week 3: Minimal Updates
├─ Config changes only
├─ Testing
└─ Deployment
```

**Cost:** $8,000 + $50/year AWS  
**Benefits:** 70% of full implementation

---

## Risk Assessment

### Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Lambda cold starts | Low | Medium | Provisioned concurrency |
| API compatibility | Medium | Low | Comprehensive testing |
| Performance issues | Medium | Low | Load testing & tuning |
| AWS service limits | Medium | Low | Request quota increases |

**Overall Technical Risk:** Low

### Organizational Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| AWS expertise gap | Medium | Training or consultant |
| Budget constraints | High | Phased approach (MVP first) |
| Timeline pressure | Medium | Clear milestones, buffer |
| Change resistance | Low | Backward compatibility maintained |

**Overall Organizational Risk:** Medium

### Risk Mitigation Strategy

1. **Backward Compatibility** - Keep direct API access as fallback
2. **Gradual Migration** - Move non-critical systems first
3. **Comprehensive Testing** - 30 hours dedicated to testing
4. **Rollback Plan** - Can revert in 15 minutes
5. **Training Budget** - 18 hours AWS training if needed

---

## Comparison with Current Approach

| Aspect | Current (Direct API) | Proposed (API Gateway) |
|--------|---------------------|----------------------|
| **Credential Storage** | Local files (JSON) | AWS Secrets Manager (encrypted) |
| **Security Audit** | None | CloudTrail logs |
| **API Monitoring** | Manual log review | CloudWatch dashboards |
| **Error Tracking** | Limited | X-Ray distributed tracing |
| **Rate Limiting** | Script-level | Centralized (API Gateway) |
| **Caching** | None | Response caching (30-50% reduction) |
| **Cost** | $0/month | $4/month |
| **Maintenance** | Script updates for API changes | Abstraction layer shields scripts |
| **Multi-Region** | Manual duplication | Built-in support |
| **Compliance** | Limited | AWS compliance certifications |

---

## Decision Options

### Option A: Proceed with Full Implementation ✅

**Timeline:** 6 weeks  
**Cost:** $16,000 + $50/year  
**Risk:** Low  
**Benefits:** 100% of proposed benefits

**Recommendation:** Best long-term value, manageable timeline

---

### Option B: Proceed with MVP

**Timeline:** 3 weeks  
**Cost:** $8,000 + $50/year  
**Risk:** Low  
**Benefits:** 70% of proposed benefits

**Recommendation:** Fastest time to value, prove concept

---

### Option C: Defer Implementation

**Timeline:** N/A  
**Cost:** $0 now  
**Risk:** Medium (security, operational)  
**Benefits:** None

**Recommendation:** Only if budget unavailable or other priorities critical

---

## Success Criteria

**Must Have (MVP):**
- ✅ Credentials removed from local files
- ✅ API Gateway operational for all endpoints
- ✅ Scripts work without code changes (config only)
- ✅ Basic monitoring in CloudWatch

**Should Have (Full):**
- ✅ Response caching enabled
- ✅ X-Ray tracing active
- ✅ CloudWatch alarms configured
- ✅ Complete documentation

**Nice to Have (Future):**
- ⏭ Automatic credential rotation
- ⏭ Multi-region deployment
- ⏭ GraphQL layer
- ⏭ WebSocket support

---

## Resource Requirements

### Personnel

**Primary:** 1 Full-Stack Engineer
- Python experience (3+ years)
- AWS experience (2+ years)
- API integration experience
- Availability: 4-6 weeks full-time

**Supporting (Part-Time):**
- Security review: 4 hours
- Architecture review: 2 hours
- Executive sponsor: 2 hours (decisions/approvals)

### Tools & Access

- AWS account with billing enabled
- AWS IAM admin access
- Python 3.11+ development environment
- Git repository access
- Testing tools (pytest, curl, Postman)

---

## Implementation Approach

### Recommended Phased Approach

**Phase 1: Infrastructure (Weeks 1-2)**
- Deploy AWS resources
- No impact on production
- Risk: Zero

**Phase 2: Parallel Testing (Week 3-4)**
- Run both modes simultaneously
- Validate functionality
- Risk: Low (fallback available)

**Phase 3: Gradual Migration (Week 5)**
- Migrate non-critical scripts
- Monitor for 48 hours
- Migrate remaining scripts
- Risk: Low (staged approach)

**Phase 4: Cleanup (Week 6)**
- Remove old configuration
- Complete documentation
- Knowledge transfer

### Rollback Strategy

If issues arise at any phase:
1. Revert config to direct API mode (15 minutes)
2. Continue using Trend Micro API directly
3. Investigate and fix issues
4. Retry migration

**Rollback Risk:** Very Low (simple config change)

---

## Key Questions for Executives

### Budget Questions

**Q1:** Is $16,000 one-time investment + $50/year acceptable?  
**A1:** ROI positive after 1.4 years, 115% over 3 years

**Q2:** Can we start with MVP ($8K) and upgrade later?  
**A2:** Yes, MVP provides 70% benefits, upgrade path clear

### Resource Questions

**Q3:** Do we have AWS-skilled engineers available?  
**A3:** If no, add 18 hours AWS training to timeline

**Q4:** Can we allocate 1 FTE for 6 weeks?  
**A4:** Required for full implementation; 3 weeks for MVP

### Timeline Questions

**Q5:** Is 6-week timeline acceptable?  
**A5:** Aggressive (4 weeks) or comfortable (6 weeks) options available

**Q6:** What if we need it sooner?  
**A6:** MVP in 3 weeks provides core benefits

### Risk Questions

**Q7:** What if it doesn't work?  
**A7:** Rollback to current approach in 15 minutes

**Q8:** Will it disrupt current operations?  
**A8:** No, parallel testing and gradual migration minimize risk

---

## Recommendation

**Proceed with Full Implementation**

**Rationale:**
1. **Strong ROI:** 115% over 3 years
2. **Low Risk:** Proven technology, rollback plan
3. **Security Critical:** Addresses credential storage concerns
4. **Strategic:** Foundation for future cloud initiatives
5. **Manageable:** 6-week timeline with 1 FTE

**Next Steps (if approved):**
1. Week 0: Assign engineer, setup AWS account
2. Week 1: Begin Phase 1 (Infrastructure)
3. Bi-weekly status updates to executives
4. Go/no-go review before production migration

---

## Appendix: Technical Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Python Scripts                          │
│  (container_vulnerabilities, endpoint_stats, k8s_bootstrap) │
└──────────────────────────┬──────────────────────────────────┘
                           │ API Key in Header
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                  AWS API Gateway (REST)                     │
│  • Authentication (API Key)                                 │
│  • Rate Limiting (100 req/sec)                             │
│  • Response Caching (TTL: 5 min)                           │
│  • Request Routing                                          │
└──────────────────────────┬──────────────────────────────────┘
                           │ All Endpoints
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                AWS Lambda Proxy Function                    │
│  • Python 3.11, 512MB, 30sec timeout                       │
│  • Path mapping (API Gateway → Trend Micro)                │
│  • Error handling & retries                                 │
└───────────┬──────────────────────────┬──────────────────────┘
            │                          │
            ↓                          ↓
┌───────────────────────┐  ┌──────────────────────────────────┐
│  AWS Secrets Manager  │  │    Trend Micro Vision One API    │
│  • API Token          │  │  api.au.xdr.trendmicro.com       │
│  • Encrypted          │  │  • Container Security            │
│  • Access Controlled  │  │  • Endpoint Management           │
└───────────────────────┘  │  • OAT Detections               │
                           └──────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────────────┐
│              Monitoring & Observability                     │
│  • CloudWatch Logs - All Lambda logs                       │
│  • CloudWatch Metrics - Request counts, latency, errors    │
│  • CloudWatch Alarms - Alert on thresholds                 │
│  • AWS X-Ray - Distributed tracing, service map            │
│  • CloudTrail - API audit logs                             │
└─────────────────────────────────────────────────────────────┘
```

---

**Contact for Questions:**
- Technical Lead: [Name]
- Project Manager: [Name]
- Security Team: [Contact]
- Budget Owner: [Name]

**Document Version:** 1.0  
**Last Updated:** January 20, 2026  
**Next Review:** After executive decision

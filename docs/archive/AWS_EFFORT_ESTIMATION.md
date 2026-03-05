# AWS API Gateway Integration - Effort Estimation

**Document Version:** 1.0  
**Date:** January 20, 2026  
**Project:** Trend Micro Vision One API - AWS API Gateway Integration  
**Prepared For:** Executive Review

---

## Executive Summary

**Total Estimated Effort:** 120-160 man-hours (15-20 working days for 1 engineer)

**Timeline:** 4-6 weeks with 1 full-time engineer

**Cost Estimate:**
- **Development Effort:** $12,000 - $16,000 (assuming $100/hour blended rate)
- **AWS Infrastructure (Monthly):** $4-8/month
- **One-time Setup:** $200 (AWS account configuration, if new)

**Risk Level:** Low-Medium
- Proven technology stack (AWS API Gateway, Lambda)
- Well-documented AWS services
- Backward compatibility maintained during migration
- Rollback plan available

---

## Effort Breakdown by Phase

### Phase 1: AWS Infrastructure Setup (40-50 hours)

#### 1.1 AWS Account & IAM Configuration (8-10 hours)

**Tasks:**
- AWS account setup/verification (if needed): 2 hours
- Create IAM users, roles, and policies: 3 hours
- Setup AWS CLI and credentials on development machine: 1 hour
- Configure MFA and security baseline: 2 hours
- Document IAM structure and access patterns: 2 hours

**Deliverables:**
- IAM roles for Lambda execution
- IAM policies for Secrets Manager, CloudWatch, X-Ray
- Security baseline documentation

**Skills Required:** AWS IAM, Security best practices

---

#### 1.2 AWS Secrets Manager Setup (4-6 hours)

**Tasks:**
- Create secret for Trend Micro API token: 2 hours
- Setup access policies and encryption: 2 hours
- Test secret retrieval from Lambda: 1 hour
- Document secret rotation procedures: 1 hour

**Deliverables:**
- Secrets Manager secret configured
- Access documentation
- Rotation procedures (manual initially)

**Skills Required:** AWS Secrets Manager, Python boto3

---

#### 1.3 Lambda Proxy Function Development (12-16 hours)

**Tasks:**
- Write Lambda handler function: 6 hours
- Implement path mapping logic: 3 hours
- Add error handling and retry logic: 2 hours
- Integrate AWS X-Ray tracing: 2 hours
- Create deployment package with dependencies: 2 hours
- Initial testing: 3 hours

**Deliverables:**
- Lambda function code
- requirements.txt with dependencies
- Deployment scripts
- Unit tests

**Skills Required:** Python, AWS Lambda, AWS SDK (boto3), Error handling

---

#### 1.4 API Gateway Configuration (10-12 hours)

**Tasks:**
- Create REST API in API Gateway: 2 hours
- Configure resources and methods (8 endpoints): 4 hours
- Setup Lambda integration for all endpoints: 2 hours
- Configure API keys and usage plans: 2 hours
- Enable caching, throttling, and CORS: 2 hours
- Deploy to prod stage: 1 hour

**Deliverables:**
- Fully configured API Gateway
- API documentation (Swagger/OpenAPI)
- API keys for testing

**Skills Required:** AWS API Gateway, REST API design, API documentation

---

#### 1.5 Monitoring & Observability (6-8 hours)

**Tasks:**
- Configure CloudWatch Log Groups: 1 hour
- Create CloudWatch Dashboard: 3 hours
- Setup CloudWatch Alarms (error rate, latency): 2 hours
- Enable and test X-Ray tracing: 2 hours

**Deliverables:**
- CloudWatch dashboard
- 5-10 CloudWatch alarms
- X-Ray service map
- Monitoring runbook

**Skills Required:** AWS CloudWatch, AWS X-Ray, Monitoring best practices

---

### Phase 2: Configuration & Code Updates (30-40 hours)

#### 2.1 Configuration System Enhancement (10-12 hours)

**Tasks:**
- Create `config/api_gateway.json`: 2 hours
- Extend `lib/config_loader.py` with APIGatewayConfig class: 4 hours
- Add API key retrieval from AWS SSM Parameter Store: 2 hours
- Update `config/environments.json` with API Gateway settings: 2 hours
- Write unit tests for config loader: 2 hours

**Deliverables:**
- Updated configuration files
- Enhanced config_loader.py
- Unit tests (pytest)
- Configuration documentation

**Skills Required:** Python, JSON configuration, Unit testing

---

#### 2.2 Script Refactoring (12-16 hours)

**Tasks:**
- Refactor `get_container_vulnerabilities.py` for API Gateway: 5 hours
- Refactor `get_endpoint_stats.py` for API Gateway: 4 hours
- Refactor automation scripts for API Gateway: 4 hours
- Update all scripts to use new config loader: 2 hours
- Add backward compatibility mode (direct API fallback): 3 hours

**Deliverables:**
- Updated Python scripts
- Backward compatibility maintained
- Migration guide

**Skills Required:** Python, API integration, Refactoring

---

#### 2.3 Lambda Function Wrappers (8-12 hours)

**Tasks:**
- Create Lambda handler for vulnerability scanner: 4 hours
- Create Lambda handler for endpoint stats: 3 hours
- Create Lambda handler for K8s bootstrap: 3 hours
- Package Lambda functions with dependencies: 2 hours

**Deliverables:**
- 3 Lambda function handlers
- Deployment packages
- Lambda-specific documentation

**Skills Required:** Python, AWS Lambda, Serverless patterns

---

### Phase 3: Testing & Validation (25-35 hours)

#### 3.1 Unit Testing (8-10 hours)

**Tasks:**
- Write unit tests for Lambda proxy function: 3 hours
- Write unit tests for config loader updates: 2 hours
- Write unit tests for refactored scripts: 3 hours
- Achieve >80% code coverage: 2 hours

**Deliverables:**
- 50+ unit tests
- Test coverage report
- pytest configuration

**Skills Required:** Python, pytest, mocking (boto3)

---

#### 3.2 Integration Testing (10-14 hours)

**Tasks:**
- Test all API Gateway endpoints manually: 4 hours
- Test Lambda proxy with various request types: 3 hours
- Test error handling and retry logic: 2 hours
- Test caching behavior: 2 hours
- Test rate limiting and throttling: 2 hours
- End-to-end testing with actual Trend Micro API: 3 hours

**Deliverables:**
- Integration test suite
- Test results documentation
- API test scripts (curl/Postman)

**Skills Required:** API testing, curl, Postman, Python requests

---

#### 3.3 Performance & Load Testing (4-6 hours)

**Tasks:**
- Setup load testing tools (Apache JMeter or Locust): 1 hour
- Run load tests (100, 500, 1000 req/min): 2 hours
- Analyze performance metrics: 1 hour
- Tune Lambda memory and timeout settings: 1 hour
- Document performance benchmarks: 1 hour

**Deliverables:**
- Load test results
- Performance tuning recommendations
- Benchmarking report

**Skills Required:** Load testing, Performance analysis

---

#### 3.4 Security Testing (3-5 hours)

**Tasks:**
- Test API key authentication: 1 hour
- Test IAM permissions (least privilege): 1 hour
- Verify Secrets Manager access controls: 1 hour
- Test for common security issues (OWASP): 1 hour
- Document security test results: 1 hour

**Deliverables:**
- Security test report
- Remediation plan (if issues found)
- Security checklist

**Skills Required:** Security testing, AWS security best practices

---

### Phase 4: Documentation & Training (15-20 hours)

#### 4.1 Technical Documentation (8-10 hours)

**Tasks:**
- Write AWS architecture documentation: 3 hours
- Update configuration guide: 2 hours
- Write deployment procedures: 2 hours
- Create troubleshooting guide: 2 hours
- Document rollback procedures: 1 hour

**Deliverables:**
- docs/AWS_API_GATEWAY_GUIDE.md
- docs/DEPLOYMENT.md
- docs/TROUBLESHOOTING.md
- Updated README.md

**Skills Required:** Technical writing, Architecture diagrams

---

#### 4.2 Operational Runbooks (4-6 hours)

**Tasks:**
- Write incident response runbook: 2 hours
- Document monitoring and alerting: 1 hour
- Create disaster recovery plan: 2 hours
- Document cost optimization tips: 1 hour

**Deliverables:**
- Incident response runbook
- Monitoring guide
- DR plan
- Cost optimization guide

**Skills Required:** DevOps, Operational best practices

---

#### 4.3 Training Materials (3-4 hours)

**Tasks:**
- Create getting started guide: 1 hour
- Write migration guide for existing users: 1 hour
- Create FAQ document: 1 hour
- Prepare knowledge transfer presentation: 1 hour

**Deliverables:**
- Getting started guide
- Migration guide
- FAQ document
- Training presentation

**Skills Required:** Documentation, Training

---

### Phase 5: Deployment & Migration (10-15 hours)

#### 5.1 Infrastructure Deployment (4-6 hours)

**Tasks:**
- Deploy Lambda functions to AWS: 1 hour
- Deploy API Gateway configuration: 1 hour
- Configure CloudWatch and X-Ray: 1 hour
- Setup API keys and usage plans: 1 hour
- Verify all components: 2 hours

**Deliverables:**
- Production-ready infrastructure
- Deployment checklist completed
- Smoke test results

**Skills Required:** AWS deployment, DevOps

---

#### 5.2 Parallel Testing (3-4 hours)

**Tasks:**
- Run scripts in both modes (direct + API Gateway): 2 hours
- Compare results for consistency: 1 hour
- Monitor performance and costs: 1 hour

**Deliverables:**
- Comparison report
- Performance metrics
- Cost analysis

**Skills Required:** Testing, Analysis

---

#### 5.3 Gradual Migration (3-5 hours)

**Tasks:**
- Migrate non-critical scripts first: 1 hour
- Monitor for issues (24-48 hours): 1 hour
- Migrate remaining scripts: 1 hour
- Final verification: 1 hour
- Cleanup old configuration: 1 hour

**Deliverables:**
- Fully migrated system
- Migration report
- Lessons learned document

**Skills Required:** Project management, Risk management

---

## Detailed Effort Summary

| Phase | Tasks | Min Hours | Max Hours | Avg Hours |
|-------|-------|-----------|-----------|-----------|
| **Phase 1: Infrastructure** | 5 | 40 | 50 | 45 |
| **Phase 2: Code Updates** | 3 | 30 | 40 | 35 |
| **Phase 3: Testing** | 4 | 25 | 35 | 30 |
| **Phase 4: Documentation** | 3 | 15 | 20 | 18 |
| **Phase 5: Deployment** | 3 | 10 | 15 | 13 |
| **TOTAL** | **18** | **120** | **160** | **140** |

---

## Resource Requirements

### Personnel

**Option 1: Single Full-Stack Engineer (Recommended)**
- **Duration:** 4-6 weeks (full-time)
- **Profile:** 
  - 3+ years Python experience
  - 2+ years AWS experience (Lambda, API Gateway, IAM)
  - Experience with API integration
  - DevOps mindset

**Option 2: Two Engineers (Parallel Execution)**
- **Duration:** 2-3 weeks (full-time for both)
- **Engineer 1:** AWS infrastructure (Phases 1, 4, 5)
- **Engineer 2:** Code development and testing (Phases 2, 3)
- **Note:** Requires coordination, may have idle time

**Option 3: Part-Time Consultant**
- **Duration:** 8-10 weeks (50% time)
- **Profile:** Senior AWS architect with Python skills
- **Benefit:** Knowledge transfer to internal team

---

### Tools & Software Required

**Development Tools:**
- Python 3.11+ (Free)
- AWS CLI (Free)
- Terraform or CloudFormation (Free)
- Git (Free)
- VS Code or PyCharm (Free/Paid)

**Testing Tools:**
- pytest (Free)
- curl (Free)
- Postman or Insomnia (Free tier)
- Apache JMeter or Locust (Free)

**AWS Services:**
- API Gateway ($0.35 per 100K requests)
- Lambda ($0.20 per 1M requests)
- Secrets Manager ($0.40/month per secret)
- CloudWatch ($0.50/GB logs)
- X-Ray ($0.50 per 100K traces)
- SSM Parameter Store (Free for standard parameters)

**Total Tool Costs:** $0-500 (mostly AWS usage, scales with traffic)

---

## Timeline & Milestones

### Aggressive Timeline (4 weeks, 1 FTE)

**Week 1: Infrastructure**
- Days 1-2: AWS setup, IAM, Secrets Manager
- Days 3-5: Lambda proxy development
- Weekend: API Gateway configuration

**Week 2: Code & Testing**
- Days 1-2: Config updates
- Days 3-4: Script refactoring
- Day 5: Unit testing

**Week 3: Integration & Performance**
- Days 1-2: Integration testing
- Days 3-4: Performance testing
- Day 5: Security testing

**Week 4: Documentation & Deployment**
- Days 1-2: Documentation
- Days 3-4: Deployment & migration
- Day 5: Final verification & handoff

### Comfortable Timeline (6 weeks, 1 FTE)

**Weeks 1-2: Infrastructure & Development**
- More time for learning AWS services
- Thorough testing at each step
- Buffer for unexpected issues

**Weeks 3-4: Testing & Refinement**
- Comprehensive test coverage
- Performance tuning
- Security hardening

**Weeks 5-6: Documentation & Migration**
- Detailed documentation
- Gradual, risk-averse migration
- Knowledge transfer sessions

---

## Risk Assessment & Contingencies

### Technical Risks

| Risk | Impact | Probability | Mitigation | Hours Added |
|------|--------|-------------|------------|-------------|
| API Gateway quota limits | Medium | Low | Request quota increase early | +2 hours |
| Lambda cold start issues | Low | Medium | Use provisioned concurrency | +4 hours |
| Secrets Manager access issues | High | Low | Thorough IAM testing | +3 hours |
| Trend Micro API compatibility | Medium | Low | Test all endpoints early | +5 hours |
| Performance degradation | Medium | Low | Load testing and tuning | +6 hours |

**Total Contingency:** +20 hours (already included in max estimates)

### Organizational Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| AWS account delays | High | Start AWS setup immediately |
| Unclear requirements | Medium | This effort estimation document |
| Resistance to change | Medium | Maintain backward compatibility |
| Budget constraints | High | Demonstrate low monthly costs |
| Lack of AWS expertise | Medium | Training or consultant engagement |

---

## Cost-Benefit Analysis

### Development Costs

**One-Time Investment:**
- Engineer time: $12,000 - $16,000 (140 hours @ $100/hr)
- AWS setup: $200
- Tools/licenses: $300
- **Total:** $12,500 - $16,500

### Ongoing Costs

**Monthly AWS Costs (estimated):**
- API Gateway: $0.35 (100K requests)
- Lambda: $1.87 (100K invocations, 2sec avg)
- Secrets Manager: $0.40
- CloudWatch: $0.80
- X-Ray: $0.50
- **Total:** ~$4.00/month

**Annual:** ~$50/year

### Benefits

**Security Improvements:**
- Eliminated local credential storage
- Centralized access control
- Audit trail via CloudTrail
- Automatic credential rotation (future)
- **Value:** High (reduces security incident risk)

**Operational Improvements:**
- Centralized rate limiting
- Response caching (reduces Trend Micro API calls)
- Better monitoring and alerting
- Faster troubleshooting via X-Ray
- **Value:** Medium-High (saves 2-4 hours/month ops time)

**Development Improvements:**
- Abstraction layer shields from API changes
- Easier to add new features
- Consistent error handling
- Support for multiple environments
- **Value:** Medium (saves 1-2 hours/month dev time)

### ROI Calculation

**Annual Cost Savings:**
- Operational time saved: 36 hours × $100/hr = $3,600
- Development time saved: 18 hours × $100/hr = $1,800
- Reduced security incident risk: $5,000 (estimated)
- **Total Annual Benefit:** $10,400

**Payback Period:** 1.4 years ($14,500 investment / $10,400 annual benefit)

**3-Year ROI:** 115% (($31,200 benefit - $14,650 cost) / $14,650)

---

## Recommendations

### Recommended Approach

**Option A: Full Implementation (Recommended)**
- Complete all phases as planned
- Timeline: 6 weeks with 1 FTE
- Budget: $16,000 + $50/year AWS
- Risk: Low
- Benefits: Full security, monitoring, and abstraction

**Option B: MVP Implementation (Quick Win)**
- Phase 1: Infrastructure only (API Gateway + Lambda proxy)
- Phase 2: Minimal script updates (config changes only)
- Skip: Custom Lambda functions for each script
- Timeline: 3 weeks with 1 FTE
- Budget: $8,000 + $50/year AWS
- Risk: Low
- Benefits: 70% of full benefits, faster time to value

**Option C: Deferred Implementation**
- Continue with current direct API approach
- Revisit when:
  - Security requirements mandate credential centralization
  - Multi-region deployment needed
  - Observability becomes critical
- Cost: $0 now, but higher long-term risk

### Decision Criteria

**Proceed with Full Implementation if:**
- Security is a top priority
- Budget allows $16K investment
- 6-week timeline is acceptable
- AWS expertise available or can be acquired
- Long-term ROI is valued

**Proceed with MVP if:**
- Fastest time to value needed
- Budget is $8-10K
- Want to prove concept before full commitment
- Incremental approach preferred

**Defer Implementation if:**
- Current approach meets security requirements
- Budget is unavailable
- Other higher-priority projects exist
- No AWS expertise and can't acquire

---

## Next Steps

### If Decision is "Go"

1. **Week 0 (Preparation):**
   - Assign engineer(s)
   - Setup AWS account (if new)
   - Review and approve architecture
   - Procure any necessary tools

2. **Week 1 (Kickoff):**
   - Architecture review session
   - Begin Phase 1: Infrastructure setup
   - Daily stand-ups for first week

3. **Ongoing:**
   - Weekly status updates
   - Risk review at phase boundaries
   - Go/no-go decision before production migration

### If Decision is "No" or "Defer"

1. **Document decision rationale**
2. **Set review date** (e.g., 6 months, 1 year)
3. **Continue current approach** with enhanced monitoring
4. **Revisit if:**
   - Security requirements change
   - Trend Micro API changes significantly
   - Multi-region deployment needed
   - Budget becomes available

---

## Appendices

### A. Skills Matrix

| Skill | Required Level | Current Team | Gap |
|-------|----------------|--------------|-----|
| Python | Advanced | ✅ | None |
| AWS Lambda | Intermediate | ❓ | Training needed? |
| AWS API Gateway | Intermediate | ❓ | Training needed? |
| AWS IAM | Intermediate | ❓ | Training needed? |
| Infrastructure as Code | Basic | ❓ | Optional |
| DevOps/CI/CD | Basic | ✅ | None |

### B. Training Resources

**If AWS skills gap exists:**
- AWS Lambda Course: 8 hours (LinkedIn Learning / A Cloud Guru)
- API Gateway Course: 6 hours
- AWS IAM Best Practices: 4 hours
- Total training time: 18 hours (add to timeline)

### C. Alternative Architectures Considered

**Alternative 1: AWS AppSync (GraphQL)**
- Pros: Modern API layer, real-time subscriptions
- Cons: Higher complexity, learning curve
- Decision: Deferred for v2.0

**Alternative 2: HTTP API (not REST API)**
- Pros: Lower cost, simpler
- Cons: Fewer features (no caching, usage plans)
- Decision: REST API chosen for features

**Alternative 3: Direct Lambda URLs**
- Pros: Simplest, lowest cost
- Cons: No API Gateway features
- Decision: Not suitable for production

---

## Conclusion

The AWS API Gateway integration represents a solid investment in security, observability, and operational excellence. With an estimated effort of 140 hours and ongoing costs under $5/month, the project delivers significant value through:

1. **Enhanced Security** - Credentials in AWS Secrets Manager, no local storage
2. **Better Monitoring** - CloudWatch + X-Ray visibility
3. **Operational Efficiency** - Centralized rate limiting, caching
4. **Future-Proof Architecture** - Abstraction layer for API changes

**Recommendation:** Proceed with full implementation (6-week timeline, 1 FTE) for maximum benefit and lowest long-term risk.

---

**Document Prepared By:** AI Assistant  
**Review Required:** Technical Lead, Security Team, Finance/Budget Owner  
**Approval Required:** Engineering Manager, CTO/VP Engineering  
**Next Review Date:** After executive decision

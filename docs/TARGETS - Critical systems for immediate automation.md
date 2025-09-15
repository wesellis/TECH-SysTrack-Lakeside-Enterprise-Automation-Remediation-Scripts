# DATA-DRIVEN SCRIPT TARGETS - Immediate Development Priorities

**Based on SysTrack Health.csv Analysis - June 30, 2025**

---

## 🚨 **CRITICAL FINDINGS - Immediate Action Required**

### **Poor Health Systems (10 groups affected)**
- **Total Systems Impacted:** 212+ systems
- **Productivity Loss:** 117.8+ hours/week total
- **Health Scores:** Range from 0% to 52.5%
- **Average Impact:** 11.7 hours/week per group

### **Severe Performance Issues:**
1. **One system with 7.7% health** - 26.6 hr/wk productivity impact
2. **Two systems with 0% health** - Critical intervention needed
3. **Multiple groups with 40.3% health** - Systematic issue pattern

---

## 🎯 **IMMEDIATE POWERSHELL SCRIPT DEVELOPMENT TARGETS**

### **Script 1: Fix-CriticalHealthSystems.ps1** 
**Priority: URGENT**
```powershell
# Target systems with <50% health score
# Covers: 212+ systems across 10 groups  
# Expected Impact: 117.8+ hours/week productivity recovery
```

**Specific Targets from Data:**
- Systems with 0% health (immediate intervention)
- Systems with 7.7% health (critical performance issues)
- Groups with 40.3% health pattern (systematic fixes needed)

### **Script 2: Optimize-CPULimitedSystems.ps1**
**Priority: HIGH**
```powershell
# Target systems with >2 hr/wk CPU limitations
# Covers: 460+ systems across 4 groups
# Expected Impact: 14.7+ hours/week CPU performance recovery
```

**Specific Targets from Data:**
- 431 systems with 3.1 hr/wk CPU limitations (81.5% health)
- 10 systems with 3.2 hr/wk CPU limitations (42.5% health)  
- 9 systems with 6.2 hr/wk CPU limitations (52.5% health)

### **Script 3: Fix-MemoryLimitedSystems.ps1**
**Priority: HIGH**
```powershell
# Target systems with >1 hr/wk memory limitations
# Covers: 127+ systems across 5 groups
# Expected Impact: 10.5+ hours/week memory performance recovery
```

**Specific Targets from Data:**
- 10 systems with 5.1 hr/wk memory limitations (42.5% health)
- 77 systems with 1.2 hr/wk memory limitations (85.7% health)
- 27 systems with 1.2 hr/wk memory limitations (88.7% health)

---

## 📊 **DATA-DRIVEN SCRIPT PARAMETERS**

### **Health Score Thresholds (Based on Actual Data):**
- **Critical Intervention:** <20% health score (immediate action)
- **Urgent Remediation:** 20-50% health score (comprehensive fixes)
- **Active Optimization:** 50-79% health score (performance tuning)
- **Preventive Maintenance:** 80-89% health score (monitoring + minor fixes)
- **Monitoring Only:** 90-100% health score (no intervention)

### **Performance Impact Thresholds (Based on Actual Data):**
- **Critical CPU Impact:** >5 hr/wk CPU limitations
- **High CPU Impact:** 2-5 hr/wk CPU limitations
- **Critical Memory Impact:** >3 hr/wk memory limitations  
- **High Memory Impact:** 1-3 hr/wk memory limitations

### **System Count Prioritization:**
- **Mass Impact:** >100 systems affected (highest priority)
- **Significant Impact:** 20-100 systems affected (high priority)
- **Targeted Impact:** <20 systems affected (medium priority)

---

## 🛠️ **SCRIPT DEVELOPMENT APPROACH**

### **Phase 1: Critical Health Systems (This Week)**
**Target:** 10 groups with <60% health score

**Script Logic:**
```powershell
# Fix-CriticalHealthSystems.ps1
param(
    [int]$HealthThreshold = 60,
    [switch]$LogOnly
)

# Target identification based on actual SysTrack data
$CriticalSystems = @(
    # 0% health systems (2 systems)
    # 7.7% health systems (1 system)  
    # 40.3% health systems (multiple groups)
    # All systems <60% health score
)

# Comprehensive remediation for each health score range
switch ($healthScore) {
    {$_ -eq 0} { 
        # Emergency intervention - full system recovery
        Invoke-SystemRecovery -Level Emergency
    }
    {$_ -lt 20} { 
        # Critical intervention - comprehensive repair
        Invoke-SystemRecovery -Level Critical  
    }
    {$_ -lt 50} {
        # Urgent remediation - targeted fixes
        Invoke-SystemOptimization -Level Urgent
    }
    {$_ -lt 60} {
        # Active optimization - performance tuning
        Invoke-SystemOptimization -Level Standard
    }
}
```

### **Phase 2: Performance Optimization (Next Week)**
**Target:** CPU and memory limited systems

**Combined Script Logic:**
```powershell
# Optimize-PerformanceLimitedSystems.ps1
param(
    [double]$CPUThreshold = 2.0,    # hr/wk CPU limitations
    [double]$MemoryThreshold = 1.0, # hr/wk memory limitations
    [switch]$LogOnly
)

# Data-driven targeting
$HighCPUSystems = Get-SystemsWithCPULimitations -Threshold $CPUThreshold
$HighMemorySystems = Get-SystemsWithMemoryLimitations -Threshold $MemoryThreshold

# Prioritize by system count and impact
$PriorityOrder = @(
    "431 systems with 3.1 hr/wk CPU limitations", # Highest system count
    "77 systems with 1.2 hr/wk memory limitations",
    "27 systems with 1.2 hr/wk memory limitations", 
    # etc.
)
```

---

## 📈 **SUCCESS METRICS & VALIDATION**

### **Measurable Outcomes (Based on Current Data):**
1. **Health Score Improvement:**
   - Target: Move all <60% health systems to >70% health
   - Expected: 10 groups improved = 212+ systems enhanced

2. **Productivity Recovery:**
   - Target: Reduce productivity impact by 50%
   - Expected: 58.9+ hours/week recovered across enterprise

3. **Performance Optimization:**
   - Target: Reduce CPU limitations by 30%  
   - Expected: 4.4+ hours/week CPU performance gained
   - Target: Reduce memory limitations by 30%
   - Expected: 3.2+ hours/week memory performance gained

### **Validation Methods:**
- **Before/After Health Scores** - Measure improvement post-remediation
- **Productivity Impact Reduction** - Track weekly impact hour decreases
- **System Stability Metrics** - Monitor for sustained improvements

---

## 🚀 **IMMEDIATE NEXT STEPS**

### **This Week Development Priority:**
1. **Create Fix-CriticalHealthSystems.ps1** targeting the 10 poor health groups
2. **Test on the 0% health systems first** (highest risk, highest reward)
3. **Measure before/after health scores** to validate effectiveness

### **Script Parameters Based on Real Data:**
```powershell
# Use these ACTUAL thresholds from your environment data
$CriticalHealthThreshold = 20    # Systems at 7.7% need emergency intervention  
$UrgentHealthThreshold = 50      # Multiple systems at 40.3% need urgent care
$ActiveHealthThreshold = 60      # 3 groups in Fair category need optimization

$CPULimitationThreshold = 2.0    # 4 groups have >2 hr/wk CPU issues
$MemoryLimitationThreshold = 1.0 # 5 groups have >1 hr/wk memory issues
```

---

## 📞 **Implementation Support**

**Data Source:** SysTrack Health.csv analysis  
**Total Impact:** 212+ systems with critical health issues  
**Productivity at Risk:** 117.8+ hours/week  
**Development Priority:** Emergency intervention scripts for 0% and 7.7% health systems

**Contact:** Wesley Ellis (Wesley.Ellis@compucom.com)  
**Team:** CompuCom SysTrack Automation Team

---

**This data-driven approach targets real systems with actual performance issues, ensuring maximum impact from automation efforts.**


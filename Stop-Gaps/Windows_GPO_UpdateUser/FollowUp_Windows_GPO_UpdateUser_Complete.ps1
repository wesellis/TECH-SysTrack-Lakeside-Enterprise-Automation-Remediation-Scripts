}

# Main follow-up logic
try {
    Write-FollowUpLog "Starting Windows Group Policy User update follow-up validation..."
    
    $StartTime = Get-Date
    
    # Step 1: Validate current user policy health
    $HealthValidation = Test-UserPolicyHealthPost
    $FollowUpResult.ValidationResults.HealthValidation = $HealthValidation
    $FollowUpResult.HealthScore = $HealthValidation.OverallHealthScore
    
    # Step 2: Test policy application effectiveness
    $EffectivenessTest = Test-PolicyApplicationEffectiveness
    $FollowUpResult.ValidationResults.EffectivenessTest = $EffectivenessTest
    
    # Step 3: Analyze event logs
    $EventLogHealth = Test-EventLogHealth
    $FollowUpResult.ValidationResults.EventLogHealth = $EventLogHealth
    
    # Step 4: Generate health clinic report
    if ($ReportToHealthClinic) {
        $HealthClinicReport = Generate-HealthClinicReport -HealthValidation $HealthValidation -EffectivenessTest $EffectivenessTest -EventLogHealth $EventLogHealth
        $FollowUpResult.HealthClinicData = $HealthClinicReport
    }
    
    # Step 5: Set up automated recheck
    if ($ScheduleRecheck) {
        $RecheckInfo = Set-AutomatedRecheck
        $FollowUpResult.RecheckScheduled = $RecheckInfo.TaskCreated
    }
    
    # Step 6: Generate future recommendations
    $FutureRecommendations = Generate-FutureRecommendations -HealthValidation $HealthValidation -EffectivenessTest $EffectivenessTest -EventLogHealth $EventLogHealth
    $FollowUpResult.FutureRecommendations = $FutureRecommendations
    
    # Determine validation status
    if ($HealthValidation.OverallHealthScore -ge 80) {
        $FollowUpResult.ValidationStatus = "Excellent"
        $FollowUpResult.ImprovementMeasured = $true
    }
    elseif ($HealthValidation.OverallHealthScore -ge 60) {
        $FollowUpResult.ValidationStatus = "Good"
        $FollowUpResult.ImprovementMeasured = $true
    }
    else {
        $FollowUpResult.ValidationStatus = "Fair"
        $FollowUpResult.ImprovementMeasured = $false
    }
    
    $FollowUpResult.CompletedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Output results
    $FollowUpResult | ConvertTo-Json -Depth 15 | Write-Output
    
    Write-FollowUpLog "User Group Policy follow-up validation completed successfully"
    exit 0
}
catch {
    $ErrorMessage = "User Group Policy follow-up validation failed: $($_.Exception.Message)"
    Write-FollowUpLog $ErrorMessage -Level "Error"
    
    $ErrorResult = @{
        ValidationStatus = "Failed"
        HealthScore = 0
        ImprovementMeasured = $false
        Error = $_.Exception.Message
        CompletedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $ErrorResult | ConvertTo-Json -Depth 10 | Write-Output
    exit 1
}

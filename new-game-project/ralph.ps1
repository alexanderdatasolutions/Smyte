# Ralph Wiggum - PowerShell Version
# Usage:
#   .\ralph.ps1              # Build mode, unlimited
#   .\ralph.ps1 20           # Build mode, max 20 iterations
#   .\ralph.ps1 plan         # Plan mode, unlimited
#   .\ralph.ps1 plan 5       # Plan mode, max 5 iterations
#   .\ralph.ps1 cleanup      # Cleanup plan mode (creates CLEANUP_PLAN.md)
#   .\ralph.ps1 cleanup 5    # Cleanup plan mode, max 5 iterations
#   .\ralph.ps1 clean        # Cleanup build mode (executes CLEANUP_PLAN.md)
#   .\ralph.ps1 clean 50     # Cleanup build mode, max 50 iterations

param(
    [string]$Mode = "build",
    [int]$MaxIterations = 0
)

# Parse mode
$PromptFile = "PROMPT_build.md"
$CompletionPromise = "COMPLETE"
$DisplayMode = "build"

switch ($Mode) {
    "plan" {
        $PromptFile = "PROMPT_plan.md"
        $CompletionPromise = "PLAN_COMPLETE"
        $DisplayMode = "plan"
    }
    "cleanup" {
        $PromptFile = "PROMPT_cleanup_plan.md"
        $CompletionPromise = "PLAN_COMPLETE"
        $DisplayMode = "cleanup-plan"
    }
    "clean" {
        $PromptFile = "PROMPT_cleanup_build.md"
        $CompletionPromise = "COMPLETE"
        $DisplayMode = "cleanup-build"
    }
    default {
        # Check if it's a number (iterations for build mode)
        if ($Mode -match '^\d+$') {
            $MaxIterations = [int]$Mode
            $Mode = "build"
        }
    }
}

$CurrentBranch = git branch --show-current

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Mode:    $DisplayMode"
Write-Host "Prompt:  $PromptFile"
Write-Host "Branch:  $CurrentBranch"
Write-Host "Promise: $CompletionPromise"
if ($MaxIterations -gt 0) {
    Write-Host "Max:     $MaxIterations iterations"
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if (-not (Test-Path $PromptFile)) {
    Write-Host "Error: $PromptFile not found" -ForegroundColor Red
    exit 1
}

$Iteration = 0

while ($true) {
    if ($MaxIterations -gt 0 -and $Iteration -ge $MaxIterations) {
        Write-Host "Reached max iterations: $MaxIterations"
        break
    }

    # Run claude
    $PromptContent = Get-Content $PromptFile -Raw
    $Output = $PromptContent | claude -p `
        --dangerously-skip-permissions `
        --output-format=stream-json `
        --model sonnet `
        --verbose 2>&1

    Write-Host $Output

    # Check for completion promise
    if ($Output -match "<promise>$CompletionPromise</promise>") {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        Write-Host "COMPLETED after $($Iteration + 1) iterations!" -ForegroundColor Green
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 0
    }

    # Push to remote
    try {
        git push origin $CurrentBranch 2>$null
    } catch {
        Write-Host "Creating remote branch..."
        git push -u origin $CurrentBranch
    }

    $Iteration++
    Write-Host ""
    Write-Host "======================== LOOP $Iteration ========================"
    Write-Host ""
}

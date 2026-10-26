# =============================================================================
# SCRIPT DE AUTOMATIZACION: VALIDACION, ESCANEO Y DESPLIEGUE EN AWS
# Sistema de Asistencia - CloudFormation Nested Stacks (Modular)
# =============================================================================

[CmdletBinding()]
param(
    [Parameter()]
    [string]$StackName = "stack-asistencia-dev",

    [Parameter()]
    [string]$Region = "us-east-2",

    [Parameter()]
    [string]$S3Bucket = "",

    [Parameter()]
    [switch]$SkipScan,

    [Parameter()]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir      = Split-Path -Parent $ScriptDir
$TemplateDir  = Join-Path $RootDir "plantillas"
$TemplateFile = Join-Path $TemplateDir "main.yaml"
$ParamDir     = Join-Path $RootDir "parametros"
$MergedFile   = Join-Path $env:TEMP "params-merged-$StackName.json"

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Despliegue CloudFormation: Sistema de Asistencia (Modular)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Stack Name : $StackName" -ForegroundColor Yellow
Write-Host "AWS Region : $Region" -ForegroundColor Yellow
Write-Host "Template   : $TemplateFile" -ForegroundColor Yellow
Write-Host "Modulos    : red.yaml, seguridad.yaml, backend.yaml, frontend.yaml, monitoreo.yaml" -ForegroundColor Yellow

# -----------------------------------------------------------------------------
# 0. MERGE DE PARAMETROS (infra + backend + frontend)
# -----------------------------------------------------------------------------
Write-Host "`n[0/3] Fusionando archivos de parametros..." -ForegroundColor Magenta
$infraFile   = Join-Path $ParamDir "infra.json"
$backendFile = Join-Path $ParamDir "backend.json"
$frontFile   = Join-Path $ParamDir "frontend.json"

foreach ($f in @($infraFile, $backendFile, $frontFile)) {
    if (-not (Test-Path $f)) {
        Write-Host "  [ERROR] No se encontro: $f" -ForegroundColor Red
        Write-Host "  Copia los *.example.json y editalos con tus valores." -ForegroundColor Yellow
        exit 1
    }
}

$merged = (Get-Content $infraFile   | ConvertFrom-Json) +
          (Get-Content $backendFile  | ConvertFrom-Json) +
          (Get-Content $frontFile    | ConvertFrom-Json)
$merged | ConvertTo-Json | Set-Content -Encoding UTF8 $MergedFile
Write-Host "  [OK] $($merged.Count) parametros fusionados con exito." -ForegroundColor Green

# -----------------------------------------------------------------------------
# 1. ESCANEO DEVSECOPS
# -----------------------------------------------------------------------------
if (-not $SkipScan) {
    Write-Host "`n[1/3] Analisis estatico de todas las plantillas (cfn-lint)..." -ForegroundColor Magenta
    if (Get-Command cfn-lint -ErrorAction SilentlyContinue) {
        $templates = Get-ChildItem -Path $TemplateDir -Filter "*.yaml"
        $lintFailed = $false
        foreach ($t in $templates) {
            cfn-lint -i W3002 -- $t.FullName
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [FAIL] cfn-lint detecto errores en: $($t.Name)" -ForegroundColor Red
                $lintFailed = $true
            } else {
                Write-Host "  [OK] $($t.Name)" -ForegroundColor Green
            }
        }
        if ($lintFailed) { exit 1 }
    } else { Write-Host "  [INFO] cfn-lint no instalado." -ForegroundColor Yellow }

    Write-Host "`n[2/3] Escaneo de seguridad de modulos (Checkov)..." -ForegroundColor Magenta
    if (Get-Command checkov -ErrorAction SilentlyContinue) {
        checkov -d "$TemplateDir" --output cli --framework cloudformation
        Write-Host "  [OK] Checkov completado." -ForegroundColor Green
    } else { Write-Host "  [INFO] Checkov no disponible." -ForegroundColor Yellow }
} else {
    Write-Host "`n[INFO] Escaneo omitido (-SkipScan)." -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# 2. VALIDACION AWS
# -----------------------------------------------------------------------------
Write-Host "`n[3/3] Validando modulos con AWS CloudFormation API ($Region)..." -ForegroundColor Magenta
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "  [WARN] AWS CLI no encontrado." -ForegroundColor Yellow; exit 0
}

$modulos = @("red.yaml", "seguridad.yaml", "backend.yaml", "frontend.yaml", "monitoreo.yaml", "main.yaml")
foreach ($mod in $modulos) {
    $modPath = Join-Path $TemplateDir $mod
    aws cloudformation validate-template --template-body "file://$modPath" --region "$Region" | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Modulo valido en AWS: $mod" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Error de validacion en: $mod" -ForegroundColor Red
        exit 1
    }
}

if ($DryRun) {
    Write-Host "`n[DRY RUN] Simulacion completada. Todas las plantillas son validas. Sin cambios en AWS." -ForegroundColor Cyan
    Remove-Item $MergedFile -ErrorAction SilentlyContinue
    exit 0
}

# -----------------------------------------------------------------------------
# 3. DETECCION / CONFIGURACION DEL BUCKET S3 PARA PLANTILLAS ANIDADAS
# -----------------------------------------------------------------------------
if (-not $S3Bucket) {
    Write-Host "`nDetectando bucket S3 para plantillas anidadas en $Region..." -ForegroundColor Magenta
    $detected = (aws s3api list-buckets --query "Buckets[?contains(Name, 'cf-templates') && contains(Name, '$Region')].Name | [0]" --output text 2>$null)
    if ($detected -and $detected -ne "None") {
        $S3Bucket = $detected
        Write-Host "  [OK] Bucket S3 detectado automaticamente: $S3Bucket" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] No se detecto bucket automatico en $Region. Buscando cualquier cf-templates..." -ForegroundColor Yellow
        $detectedAny = (aws s3api list-buckets --query "Buckets[?contains(Name, 'cf-templates')].Name | [0]" --output text 2>$null)
        if ($detectedAny -and $detectedAny -ne "None") {
            $S3Bucket = $detectedAny
            Write-Host "  [OK] Usando bucket S3: $S3Bucket" -ForegroundColor Green
        }
    }
}

# -----------------------------------------------------------------------------
# 4. DESPLIEGUE
# -----------------------------------------------------------------------------
Write-Host "`nDesplegando '$StackName' en '$Region'..." -ForegroundColor Cyan

$deployArgs = @(
    "cloudformation", "deploy",
    "--template-file", "$TemplateFile",
    "--stack-name", "$StackName",
    "--region", "$Region",
    "--capabilities", "CAPABILITY_NAMED_IAM", "CAPABILITY_AUTO_EXPAND",
    "--parameter-overrides", "file://$MergedFile"
)

if ($S3Bucket) {
    $deployArgs += @("--s3-bucket", "$S3Bucket")
}

& aws @deployArgs

Remove-Item $MergedFile -ErrorAction SilentlyContinue

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n============================================================" -ForegroundColor Green
    Write-Host "  Despliegue completado con exito!" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    aws cloudformation describe-stacks `
        --stack-name "$StackName" --region "$Region" `
        --query "Stacks[0].Outputs[*].[OutputKey,OutputValue]" `
        --output table
} else {
    Write-Host "`n[ERROR] Fallo el despliegue de '$StackName'." -ForegroundColor Red
    exit $LASTEXITCODE
}

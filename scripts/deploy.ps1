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
    [switch]$DryRun,

    [Parameter()]
    [switch]$NoExecute
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
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($MergedFile, ($merged | ConvertTo-Json -Depth 10), $utf8NoBom)
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

aws sts get-caller-identity | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Tu sesion de AWS ha expirado o no esta autenticada." -ForegroundColor Red
    Write-Host "  Por favor ejecuta 'aws login' en tu terminal para autenticarte y vuelve a intentar." -ForegroundColor Yellow
    Remove-Item $MergedFile -ErrorAction SilentlyContinue
    exit 1
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
        $accId = (aws sts get-caller-identity --query "Account" --output text 2>$null)
        $newBucket = "cf-templates-$accId-$Region"
        Write-Host "  [INFO] No se detecto bucket en $Region. Creando bucket regional: $newBucket..." -ForegroundColor Yellow
        aws s3 mb "s3://$newBucket" --region "$Region" | Out-Null
        $S3Bucket = $newBucket
        Write-Host "  [OK] Bucket S3 regional creado y listo: $S3Bucket" -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------------
# 4. VERIFICACION DE ESTADO DEL STACK PREVIO (ROLLBACK_COMPLETE)
# -----------------------------------------------------------------------------
$stackStatus = (aws cloudformation list-stacks --region "$Region" --query "StackSummaries[?StackName=='$StackName' && StackStatus!='DELETE_COMPLETE'].StackStatus | [0]" --output text)
if ($stackStatus -eq "ROLLBACK_COMPLETE") {
    Write-Host "`n[WARN] El stack '$StackName' esta en estado 'ROLLBACK_COMPLETE' (fallo de despliegue previo)." -ForegroundColor Yellow
    Write-Host "  Eliminando stack en rollback para permitir recreacion limpia..." -ForegroundColor Yellow
    aws cloudformation delete-stack --stack-name "$StackName" --region "$Region"
    aws cloudformation wait stack-delete-complete --stack-name "$StackName" --region "$Region"
    Write-Host "  [OK] Stack previo eliminado con exito." -ForegroundColor Green
}

# Limpieza preventiva de Log Groups huerfanos que podrian causar conflicto de nombres
if (-not $stackStatus -or $stackStatus -eq "None" -or $stackStatus -eq "ROLLBACK_COMPLETE") {
    $orphanLogs = @(
        "/aws/vpc-flow-logs/asistencia-dev",
        "/aws/ec2/asistencia-backend-dev",
        "/aws/ec2/asistencia-frontend-dev"
    )
    foreach ($lg in $orphanLogs) {
        $exists = (aws logs describe-log-groups --log-group-name-prefix "$lg" --region "$Region" --query "logGroups[?logGroupName=='$lg'].logGroupName | [0]" --output text 2>$null)
        if ($exists -and $exists -ne "None") {
            Write-Host "  [INFO] Limpiando Log Group huerfano previo ($lg)..." -ForegroundColor Yellow
            aws logs delete-log-group --log-group-name "$lg" --region "$Region" 2>$null | Out-Null
        }
    }
}

# -----------------------------------------------------------------------------
# 5. EMPAQUETADO DE PLANTILLAS ANIDADAS (aws cloudformation package)
# -----------------------------------------------------------------------------
Write-Host "`nEmpaquetando modulos anidados hacia S3 ($S3Bucket)..." -ForegroundColor Cyan
$PackagedFile = Join-Path $env:TEMP "packaged-$StackName.yaml"
aws cloudformation package `
    --template-file "$TemplateFile" `
    --s3-bucket "$S3Bucket" `
    --output-template-file "$PackagedFile" `
    --region "$Region"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Fallo el empaquetado de las plantillas hacia S3." -ForegroundColor Red
    Remove-Item $MergedFile -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "  [OK] Plantillas anidadas empaquetadas y subidas a S3 con exito." -ForegroundColor Green

# -----------------------------------------------------------------------------
# 6. DESPLIEGUE
# -----------------------------------------------------------------------------
Write-Host "`nDesplegando '$StackName' en '$Region'..." -ForegroundColor Cyan

$mergedUri = "file://" + $MergedFile.Replace('\', '/')
$deployArgs = @(
    "cloudformation", "deploy",
    "--template-file", "$PackagedFile",
    "--stack-name", "$StackName",
    "--region", "$Region",
    "--capabilities", "CAPABILITY_NAMED_IAM", "CAPABILITY_AUTO_EXPAND",
    "--parameter-overrides", "$mergedUri"
)

if ($NoExecute) {
    $deployArgs += "--no-execute-changeset"
}

& aws @deployArgs
$deployExit = $LASTEXITCODE

Remove-Item $MergedFile -ErrorAction SilentlyContinue
Remove-Item $PackagedFile -ErrorAction SilentlyContinue

if ($deployExit -eq 0) {
    if ($NoExecute) {
        Write-Host "`n============================================================" -ForegroundColor Yellow
        Write-Host "  [CHANGE SET CREADO CON EXITO EN AWS CLOUDFORMATION]" -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host "El conjunto de cambios (Change Set) ha sido generado para revision." -ForegroundColor Cyan
        Write-Host "Puedes auditar el impacto en la consola web de AWS (CloudFormation > Stacks > $StackName > Change sets)" -ForegroundColor White
        Write-Host "O ejecutarlo mediante la consola web o 'aws cloudformation execute-change-set'." -ForegroundColor White
        exit 0
    }

    Write-Host "`n============================================================" -ForegroundColor Green
    Write-Host "  ¡DESPLIEGUE COMPLETADO CON EXITO EN AWS!" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green

    $stackJson = (aws cloudformation describe-stacks --stack-name "$StackName" --region "$Region" --output json | ConvertFrom-Json)
    $outputs = $stackJson.Stacks[0].Outputs

    $outMap = @{}
    foreach ($item in $outputs) {
        $outMap[$item.OutputKey] = $item.OutputValue
    }

    Write-Host "`n>> ENDPOINTS PUBLICOS:" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    if ($outMap["FrontendWebUrl"]) {
        Write-Host "  [Frontend Web] : " -NoNewline -ForegroundColor White
        Write-Host $outMap["FrontendWebUrl"] -ForegroundColor Green
    }
    if ($outMap["BackendApiUrl"]) {
        Write-Host "  [Backend API]  : " -NoNewline -ForegroundColor White
        Write-Host $outMap["BackendApiUrl"] -ForegroundColor Green
    }
    if ($outMap["BackendDocsUrl"]) {
        Write-Host "  [Swagger Docs] : " -NoNewline -ForegroundColor White
        Write-Host $outMap["BackendDocsUrl"] -ForegroundColor Green
    }

    Write-Host "`n>> INFRAESTRUCTURA Y SERVIDORES EC2:" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    if ($outMap["FrontendPublicIP"]) {
        Write-Host "  Frontend Elastic IP : " -NoNewline -ForegroundColor White
        Write-Host $outMap["FrontendPublicIP"] -ForegroundColor Yellow
    }
    if ($outMap["FrontendInstanceId"]) {
        Write-Host "  Frontend Instancia  : " -NoNewline -ForegroundColor White
        Write-Host $outMap["FrontendInstanceId"] -ForegroundColor Yellow
    }
    if ($outMap["BackendPublicIP"]) {
        Write-Host "  Backend Elastic IP  : " -NoNewline -ForegroundColor White
        Write-Host $outMap["BackendPublicIP"] -ForegroundColor Yellow
    }
    if ($outMap["BackendInstanceId"]) {
        Write-Host "  Backend Instancia   : " -NoNewline -ForegroundColor White
        Write-Host $outMap["BackendInstanceId"] -ForegroundColor Yellow
    }
    if ($outMap["VpcId"]) {
        Write-Host "  VPC Red ID          : " -NoNewline -ForegroundColor White
        Write-Host $outMap["VpcId"] -ForegroundColor Yellow
    }

    Write-Host "`n>> COMANDOS DE ACCESO (SSH Y AWS SSM):" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    if ($outMap["SSHFrontendCommand"]) {
        Write-Host "  SSH Frontend : " -NoNewline -ForegroundColor White
        Write-Host $outMap["SSHFrontendCommand"] -ForegroundColor Magenta
    }
    if ($outMap["SSHBackendCommand"]) {
        Write-Host "  SSH Backend  : " -NoNewline -ForegroundColor White
        Write-Host $outMap["SSHBackendCommand"] -ForegroundColor Magenta
    }
    if ($outMap["SSMFrontendSessionCommand"]) {
        Write-Host "  SSM Frontend : " -NoNewline -ForegroundColor White
        Write-Host $outMap["SSMFrontendSessionCommand"] -ForegroundColor Magenta
    }
    if ($outMap["SSMBackendSessionCommand"]) {
        Write-Host "  SSM Backend  : " -NoNewline -ForegroundColor White
        Write-Host $outMap["SSMBackendSessionCommand"] -ForegroundColor Magenta
    }

    Write-Host "`n>> TODOS LOS OUTPUTS REGISTRADOS EN CLOUDFORMATION:" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    $outputs | Select-Object @{Name="Output Key"; Expression={$_.OutputKey}}, @{Name="Valor"; Expression={$_.OutputValue}} | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Gray
} else {
    Write-Host "`n[ERROR] Fallo el despliegue de '$StackName'." -ForegroundColor Red
    exit $deployExit
}

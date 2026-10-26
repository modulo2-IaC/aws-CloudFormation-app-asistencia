# =============================================================================
# SCRIPT DE AUTOMATIZACION: DESTRUCCION / ELIMINACION DE INFRAESTRUCTURA
# Sistema de Asistencia - CloudFormation Stack & Nested Stacks
# =============================================================================

[CmdletBinding()]
param(
    [Parameter()]
    [string]$StackName = "stack-asistencia-dev",

    [Parameter()]
    [string]$Region = "us-east-2",

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "`n============================================================" -ForegroundColor Red
Write-Host "  Eliminacion de Stack CloudFormation: $StackName" -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red
Write-Host "Stack Name : $StackName" -ForegroundColor Yellow
Write-Host "AWS Region : $Region" -ForegroundColor Yellow

# 1. Verificar herramientas
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] AWS CLI no esta instalado o no se encuentra en el PATH." -ForegroundColor Red
    exit 1
}

# 2. Verificar si el stack existe en la region
Write-Host "`n[1/4] Verificando existencia del stack en AWS ($Region)..." -ForegroundColor Magenta
$stackStatus = (aws cloudformation describe-stacks --stack-name "$StackName" --region "$Region" --query "Stacks[0].StackStatus" --output text 2>$null)

if (-not $stackStatus -or $stackStatus -eq "None") {
    Write-Host "  [INFO] El stack '$StackName' no existe en la region '$Region'. Nada que eliminar." -ForegroundColor Green
    exit 0
}

Write-Host "  [OK] Stack encontrado con estado actual: $stackStatus" -ForegroundColor Yellow

# 3. Confirmacion de seguridad
if (-not $Force) {
    Write-Host "`n[PELIGRO] Esta accion eliminara TODOS los recursos aprovisionados:" -ForegroundColor Red
    Write-Host "  - Instancias EC2 (Backend NestJS y Frontend Nginx)" -ForegroundColor Red
    Write-Host "  - Direcciones Elastic IP (EIP)" -ForegroundColor Red
    Write-Host "  - Grupos de Seguridad y Roles IAM" -ForegroundColor Red
    Write-Host "  - Red VPC, Subredes, Internet Gateway y Flow Logs" -ForegroundColor Red
    Write-Host "  - Alarmas CloudWatch y Topico SNS" -ForegroundColor Red
    
    $confirm = Read-Host "`n¿Esta completamente seguro de eliminar el stack '$StackName'? (escriba 'ELIMINAR' para confirmar)"
    if ($confirm -cne "ELIMINAR") {
        Write-Host "`n[CANCELADO] Operacion cancelada por el usuario. No se realizo ningun cambio." -ForegroundColor Cyan
        exit 0
    }
}

# 4. Deshabilitar Termination Protection si estuviera activa
Write-Host "`n[2/4] Verificando proteccion contra eliminacion..." -ForegroundColor Magenta
aws cloudformation update-termination-protection `
    --no-enable-termination-protection `
    --stack-name "$StackName" `
    --region "$Region" 2>$null | Out-Null
Write-Host "  [OK] Proteccion contra eliminacion desactivada." -ForegroundColor Green

# 5. Ejecutar la eliminacion del stack raiz (elimina automaticamente los stacks anidados)
Write-Host "`n[3/4] Enviando solicitud de eliminacion a AWS CloudFormation..." -ForegroundColor Magenta
aws cloudformation delete-stack --stack-name "$StackName" --region "$Region"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Fallo el comando de eliminacion en AWS." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "  [OK] Comando de eliminacion aceptado por AWS." -ForegroundColor Green

# 6. Esperar la finalizacion de la eliminacion
Write-Host "`n[4/4] Esperando a que todos los recursos se eliminen (esto puede tardar 2-4 minutos)..." -ForegroundColor Magenta
aws cloudformation wait stack-delete-complete --stack-name "$StackName" --region "$Region"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n============================================================" -ForegroundColor Green
    Write-Host "  Stack '$StackName' y todos sus recursos eliminados con exito!" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Ocurrio un problema esperando la eliminacion. Revisa la consola de CloudFormation." -ForegroundColor Red
    exit $LASTEXITCODE
}

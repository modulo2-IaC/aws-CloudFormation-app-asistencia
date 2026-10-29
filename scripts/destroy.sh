#!/usr/bin/env bash
# =============================================================================
# SCRIPT DE AUTOMATIZACION: DESTRUCCION / ELIMINACION DE INFRAESTRUCTURA (BASH)
# Sistema de Asistencia - CloudFormation Stack & Nested Stacks
# =============================================================================

set -e

STACK_NAME="${1:-stack-asistencia-dev}"
REGION="${2:-us-east-2}"
FORCE="${3:-}"

echo "============================================================"
echo "  Eliminacion de Stack CloudFormation: $STACK_NAME"
echo "============================================================"
echo "Stack Name : $STACK_NAME"
echo "AWS Region : $REGION"

# 1. Verificar herramientas
if ! command -v aws > /dev/null 2>&1; then
    echo "[ERROR] AWS CLI no encontrado."
    exit 1
fi

# 2. Verificar existencia del stack
echo ""
echo "[1/4] Verificando existencia del stack en AWS ($REGION)..."
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query "Stacks[0].StackStatus" --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_STATUS" = "NOT_FOUND" ] || [ -z "$STACK_STATUS" ]; then
    echo "  [INFO] El stack '$STACK_NAME' no existe en la region '$REGION'. Nada que eliminar."
    exit 0
fi

echo "  [OK] Stack encontrado con estado actual: $STACK_STATUS"

# 3. Confirmacion de seguridad
if [ "$FORCE" != "--force" ] && [ "$FORCE" != "-f" ]; then
    echo ""
    echo "[PELIGRO] Esta accion eliminara TODOS los recursos aprovisionados:"
    echo "  - Instancias EC2 (Backend NestJS y Frontend Nginx)"
    echo "  - Direcciones Elastic IP (EIP)"
    echo "  - Grupos de Seguridad y Roles IAM"
    echo "  - Red VPC, Subredes, Internet Gateway y Flow Logs"
    echo "  - Alarmas CloudWatch y Topico SNS"
    echo ""
    read -p "¿Esta seguro de eliminar el stack '$STACK_NAME'? (escriba 'ELIMINAR'): " CONFIRM
    if [ "$CONFIRM" != "ELIMINAR" ]; then
        echo "[CANCELADO] Operacion cancelada por el usuario."
        exit 0
    fi
fi

# 4. Deshabilitar Termination Protection
echo ""
echo "[2/4] Desactivando proteccion contra eliminacion..."
aws cloudformation update-termination-protection \
    --no-enable-termination-protection \
    --stack-name "$STACK_NAME" \
    --region "$REGION" 2>/dev/null || true
echo "  [OK] Proteccion contra eliminacion desactivada."

# 5. Ejecutar eliminacion
echo ""
echo "[3/4] Enviando solicitud de eliminacion a AWS CloudFormation..."
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
echo "  [OK] Solicitud enviada a AWS."

# 6. Esperar eliminacion
echo ""
echo "[4/4] Esperando a que todos los recursos se eliminen..."
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"

echo ""
echo "============================================================"
echo "  Stack '$STACK_NAME' y todos sus recursos eliminados con exito!"
echo "============================================================"

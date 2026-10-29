#!/usr/bin/env bash
# =============================================================================
# SCRIPT DE AUTOMATIZACION: VALIDACION, ESCANEO Y DESPLIEGUE EN AWS (BASH)
# Sistema de Asistencia - CloudFormation Nested Stacks (Modular)
# =============================================================================

set -e

STACK_NAME="${1:-stack-asistencia-dev}"
REGION="${2:-us-east-2}"
S3_BUCKET="${3:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$ROOT_DIR/plantillas"
TEMPLATE_FILE="$TEMPLATE_DIR/main.yaml"
PARAM_DIR="$ROOT_DIR/parametros"
MERGED_FILE="/tmp/params-merged-${STACK_NAME}.json"

echo "============================================================"
echo "  Despliegue CloudFormation: Sistema de Asistencia (Modular)"
echo "============================================================"
echo "Stack Name : $STACK_NAME"
echo "AWS Region : $REGION"
echo "Template   : $TEMPLATE_FILE"
echo "Modulos    : red.yaml, seguridad.yaml, backend.yaml, frontend.yaml, monitoreo.yaml"

# 0. Merge de parametros
echo ""
echo "[0/3] Fusionando archivos de parametros..."
for f in "$PARAM_DIR/infra.json" "$PARAM_DIR/backend.json" "$PARAM_DIR/frontend.json"; do
    if [ ! -f "$f" ]; then
        echo "  [ERROR] No se encontro: $f"
        echo "  Copia los *.example.json y editalos con tus valores."
        exit 1
    fi
done

python3 -c "
import json, sys
files = sys.argv[1:]
merged = []
for f in files:
    merged += json.load(open(f))
print(json.dumps(merged, indent=2))
" "$PARAM_DIR/infra.json" "$PARAM_DIR/backend.json" "$PARAM_DIR/frontend.json" > "$MERGED_FILE"
echo "  [OK] Parametros fusionados: $(python3 -c "import json; print(len(json.load(open('$MERGED_FILE'))))")"

# 1. cfn-lint
echo ""
echo "[1/3] Analisis estatico de modulos (cfn-lint)..."
if command -v cfn-lint > /dev/null 2>&1; then
    for t in "$TEMPLATE_DIR"/*.yaml; do
        cfn-lint -i W3002 -- "$t"
        echo "  [OK] $(basename "$t")"
    done
else
    echo "  [INFO] cfn-lint no encontrado (pip install cfn-lint)."
fi

# 2. Checkov
echo ""
echo "[2/3] Escaneo de seguridad de modulos (Checkov)..."
if command -v checkov > /dev/null 2>&1; then
    checkov -d "$TEMPLATE_DIR" --framework cloudformation --output cli
    echo "  [OK] Checkov completado."
else
    echo "  [INFO] Checkov no encontrado (pip install checkov)."
fi

# 3. Validacion AWS
echo ""
echo "[3/3] Validando modulos con AWS CloudFormation API ($REGION)..."
if command -v aws > /dev/null 2>&1; then
    for mod in red.yaml seguridad.yaml backend.yaml frontend.yaml monitoreo.yaml main.yaml; do
        aws cloudformation validate-template --template-body "file://$TEMPLATE_DIR/$mod" --region "$REGION" > /dev/null
        echo "  [OK] Modulo valido en AWS: $mod"
    done
else
    echo "  [WARN] AWS CLI no encontrado."
    rm -f "$MERGED_FILE"
    exit 0
fi

# 4. Deteccion de S3 Bucket para Nested Stacks
if [ -z "$S3_BUCKET" ]; then
    echo ""
    echo "Detectando bucket S3 para plantillas anidadas en $REGION..."
    S3_BUCKET=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'cf-templates') && contains(Name, '$REGION')].Name | [0]" --output text 2>/dev/null || echo "")
    if [ "$S3_BUCKET" != "None" ] && [ -n "$S3_BUCKET" ]; then
        echo "  [OK] Bucket S3 detectado: $S3_BUCKET"
    else
        ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
        S3_BUCKET="cf-templates-${ACCOUNT_ID}-${REGION}"
        echo "  [INFO] Creando bucket regional: $S3_BUCKET..."
        aws s3 mb "s3://$S3_BUCKET" --region "$REGION" > /dev/null
        echo "  [OK] Bucket regional creado: $S3_BUCKET"
    fi
fi

# 5. Subida de plantillas con nombres claros por Stack
echo ""
echo "Subiendo modulos hacia S3 con identificacion por Stack ($S3_BUCKET/$STACK_NAME/)..."
PACKAGED_FILE="/tmp/packaged-${STACK_NAME}.yaml"
cp "$TEMPLATE_FILE" "$PACKAGED_FILE"

MODULES=("red.yaml:RedStack.yaml" "seguridad.yaml:SeguridadStack.yaml" "backend.yaml:BackendStack.yaml" "frontend.yaml:FrontendStack.yaml" "monitoreo.yaml:MonitoreoStack.yaml")

for item in "${MODULES[@]}"; do
    f="${item%%:*}"
    stack_yaml="${item##*:}"
    aws s3 cp "$TEMPLATE_DIR/$f" "s3://$S3_BUCKET/$STACK_NAME/$stack_yaml" --region "$REGION" > /dev/null
    aws s3 cp "$TEMPLATE_DIR/$f" "s3://$S3_BUCKET/$STACK_NAME/$f" --region "$REGION" > /dev/null
    s3_url="https://${S3_BUCKET}.s3.${REGION}.amazonaws.com/${STACK_NAME}/${stack_yaml}"
    sed -i "s|\./$f|$s3_url|g" "$PACKAGED_FILE"
    sed -i "s|TemplateURL: $f|TemplateURL: $s3_url|g" "$PACKAGED_FILE"
    echo "  [OK] s3://$S3_BUCKET/$STACK_NAME/$stack_yaml"
done

aws s3 cp "$PACKAGED_FILE" "s3://$S3_BUCKET/$STACK_NAME/main.yaml" --region "$REGION" > /dev/null
aws s3 cp "$PACKAGED_FILE" "s3://$S3_BUCKET/$STACK_NAME/${STACK_NAME}.yaml" --region "$REGION" > /dev/null
echo "  [OK] s3://$S3_BUCKET/$STACK_NAME/main.yaml (Orquestador)"

# 6. Despliegue
echo ""
echo "Desplegando '$STACK_NAME' en '$REGION'..."

DEPLOY_CMD=(
    aws cloudformation deploy
    --template-file "$PACKAGED_FILE"
    --stack-name    "$STACK_NAME"
    --region        "$REGION"
    --capabilities  CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND
    --parameter-overrides "file://$MERGED_FILE"
)

"${DEPLOY_CMD[@]}"

rm -f "$MERGED_FILE" "$PACKAGED_FILE"

echo ""
echo "============================================================"
echo "  Despliegue completado con exito!"
echo "============================================================"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region     "$REGION" \
    --query      "Stacks[0].Outputs[*].[OutputKey,OutputValue]" \
    --output     table

# Reportes de Calidad y Seguridad de Infraestructura como Código (IaC)

Este directorio consolida los reportes generados por las herramientas de escaneo estático, seguridad DevSecOps y validación de la API de AWS para las plantillas CloudFormation del **Sistema de Asistencia**.

---

## 📊 Resumen Ejecutivo de Resultados

| Herramienta | Tipo de Análisis | Alcance | Resultado | Reporte Detallado |
|---|---|---|:---:|---|
| **cfn-lint** | Sintaxis y Esquema CloudFormation | 6 plantillas (`plantillas/*.yaml`) | **0 Errores** (100% Válido) | [cfn-lint.md](file:///d:/soe/modulos/DCID-V1E1%20-%2002%20I%20INFRAESTRUCTURA%20COMO%20C%C3%93DIGO%20%28IAC%29/apps/app4/IAC/aws/CloudFormation/recursos-app-asistencia/reportes/cfn-lint.md) |
| **Checkov** | Seguridad DevSecOps y Buenas Prácticas | Todos los recursos IaC | **26 Pasados**, **0 Fallos**, 9 Omitidos (Free Tier) | [checkov.md](file:///d:/soe/modulos/DCID-V1E1%20-%2002%20I%20INFRAESTRUCTURA%20COMO%20C%C3%93DIGO%20%28IAC%29/apps/app4/IAC/aws/CloudFormation/recursos-app-asistencia/reportes/checkov.md) |
| **AWS CLI Validate** | Validación oficial con AWS API (`us-east-2`) | 6 plantillas (`plantillas/*.yaml`) | **Aprobado** (6/6 módulos) | [aws-validate.md](file:///d:/soe/modulos/DCID-V1E1%20-%2002%20I%20INFRAESTRUCTURA%20COMO%20C%C3%93DIGO%20%28IAC%29/apps/app4/IAC/aws/CloudFormation/recursos-app-asistencia/reportes/aws-validate.md) |

---

## 🔍 Detalle Rápido por Herramienta

### 1. [cfn-lint](file:///d:/soe/modulos/DCID-V1E1%20-%2002%20I%20INFRAESTRUCTURA%20COMO%20C%C3%93DIGO%20%28IAC%29/apps/app4/IAC/aws/CloudFormation/recursos-app-asistencia/reportes/cfn-lint.md)
- Valida que la estructura de recursos, referencias (`!Ref`, `!GetAtt`), tipos de datos y parámetros cumplan rigurosamente la especificación de AWS CloudFormation.
- **Estado:** ✅ APROBADO sin advertencias críticas ni errores.

### 2. [Checkov](file:///d:/soe/modulos/DCID-V1E1%20-%2002%20I%20INFRAESTRUCTURA%20COMO%20C%C3%93DIGO%20%28IAC%29/apps/app4/IAC/aws/CloudFormation/recursos-app-asistencia/reportes/checkov.md)
- Escanea vulnerabilidades de seguridad, cumplimiento de CIS AWS Benchmarks y configuraciones riesgosas en IAM, VPC y EC2.
- **0 vulnerabilidades detectadas**. Los 9 checks omitidos cuentan con justificación técnica explícita documentada en el código para operar dentro de la **Capa Gratuita (Free Tier)** de AWS (ej. CloudWatch log encryption estándar sin sobrecostos KMS, EIPs directas para el backend y frontend).
- **Estado:** ✅ APROBADO.

### 3. [AWS CloudFormation Validate Template](file:///d:/soe/modulos/DCID-V1E1%20-%2002%20I%20INFRAESTRUCTURA%20COMO%20C%C3%93DIGO%20%28IAC%29/apps/app4/IAC/aws/CloudFormation/recursos-app-asistencia/reportes/aws-validate.md)
- Validación directa contra el motor oficial de AWS CloudFormation en la región `us-east-2`.
- Confirma que la sintaxis, tipos de parámetros (ej. `AWS::EC2::Image::Id`) y capabilities (`CAPABILITY_NAMED_IAM`, `CAPABILITY_AUTO_EXPAND`) son correctas y listas para producción.
- **Estado:** ✅ APROBADO.

---

## 🚀 Cómo Re-ejecutar los Escaneos

Puedes ejecutar los escaneos de forma automatizada mediante el script:

```powershell
# Ejecución completa con escaneos y despliegue simulado
powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -DryRun
```

O individualmente por herramienta:

```bash
# 1. cfn-lint
cfn-lint plantillas/red.yaml plantillas/seguridad.yaml plantillas/backend.yaml plantillas/frontend.yaml plantillas/monitoreo.yaml
cfn-lint -i W3002 -- plantillas/main.yaml

# 2. Checkov
checkov -d plantillas/ --framework cloudformation

# 3. AWS Validate
aws cloudformation validate-template --template-body file://plantillas/main.yaml --region us-east-2
```

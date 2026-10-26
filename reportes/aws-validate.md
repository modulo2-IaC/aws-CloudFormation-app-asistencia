# Reporte: AWS CloudFormation Validate Template (Arquitectura Modular)

**Herramienta:** AWS CLI — `aws cloudformation validate-template`  
**Region:** `us-east-2`  
**Fecha:** 2026-10-25  

---

## Resultado de Validacion por Modulo

| Modulo / Plantilla | Estado AWS API | Capabilities Detectadas |
|---|:---:|---|
| `plantillas/red.yaml` | VALIDADO ✅ | Ninguna (recursos de red y VPC Flow Logs con IAM estandar) |
| `plantillas/seguridad.yaml` | VALIDADO ✅ | `CAPABILITY_NAMED_IAM` |
| `plantillas/backend.yaml` | VALIDADO ✅ | Ninguna (consume perfil IAM existente) |
| `plantillas/frontend.yaml` | VALIDADO ✅ | Ninguna (consume perfil IAM existente) |
| `plantillas/monitoreo.yaml` | VALIDADO ✅ | Ninguna |
| `plantillas/main.yaml` | VALIDADO ✅ | `CAPABILITY_NAMED_IAM`, `CAPABILITY_AUTO_EXPAND` |

---

## Comando de Validacion

```bash
# Validacion individual de cada modulo:
for mod in red.yaml seguridad.yaml backend.yaml frontend.yaml monitoreo.yaml main.yaml; do
  aws cloudformation validate-template --template-body "file://plantillas/$mod" --region us-east-2
done
```

## Capabilities Requeridas para Despliegue

```
CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND
```

- `CAPABILITY_NAMED_IAM`: Requerida porque `seguridad.yaml` crea roles IAM con nombres explicitos.
- `CAPABILITY_AUTO_EXPAND`: Requerida porque `main.yaml` orquesta recursos anidados `AWS::CloudFormation::Stack`.

---

## Estado: APROBADO ✅

Todos los 6 modulos han sido verificados directamente contra los endpoints de la API de AWS CloudFormation en la region `us-east-2`.

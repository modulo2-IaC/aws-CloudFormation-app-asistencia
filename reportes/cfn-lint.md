# Reporte: cfn-lint (Arquitectura Modular)

**Herramienta:** [cfn-lint](https://github.com/aws-cloudformation/cfn-lint)  
**Plantillas analizadas:**  
- `plantillas/main.yaml` (Orquestador principal)  
- `plantillas/red.yaml` (Modulo de red y subredes)  
- `plantillas/seguridad.yaml` (Modulo de firewalls y roles IAM)  
- `plantillas/backend.yaml` (Modulo de computo backend NestJS)  
- `plantillas/frontend.yaml` (Modulo de computo frontend React/Vite/Nginx)  
- `plantillas/monitoreo.yaml` (Modulo de alarmas CloudWatch y SNS)  
**Fecha:** 2026-10-25  
**Region objetivo:** `us-east-2`  

---

## Resultado por Modulo

| Plantilla | Responsabilidad (Alta Cohesion) | Errores | Advertencias | Estado |
|---|---|:---:|:---:|:---:|
| `red.yaml` | VPC, Subredes, IGW, Rutas, VPC Flow Logs | 0 | 0 | APROBADO ✅ |
| `seguridad.yaml` | Security Groups, IAM Roles, Instance Profiles | 0 | 0 | APROBADO ✅ |
| `backend.yaml` | EC2 Backend, EIP, UserData NestJS/PM2 | 0 | 0 | APROBADO ✅ |
| `frontend.yaml` | EC2 Frontend, EIP, UserData React/Nginx | 0 | 0 | APROBADO ✅ |
| `monitoreo.yaml` | CloudWatch Alarms, SNS Topic, Log Groups | 0 | 0 | APROBADO ✅ |
| `main.yaml` | Orquestador de Stacks Anidados | 0 | 0* | APROBADO ✅ |

*\* W3002 informativo de empaquetado resuelto automaticamente por el script de despliegue mediante el bucket S3 regional.*

---

## Comando de Validacion

```bash
cfn-lint plantillas/red.yaml plantillas/seguridad.yaml plantillas/backend.yaml plantillas/frontend.yaml plantillas/monitoreo.yaml
cfn-lint -i W3002 -- plantillas/main.yaml
```

## Estado: APROBADO ✅

Todas las plantillas modulares cumplen estrictamente con la especificacion y el esquema oficial de AWS CloudFormation Resource Specification.

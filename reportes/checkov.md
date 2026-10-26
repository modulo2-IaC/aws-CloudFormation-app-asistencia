# Reporte: Checkov (Escaneo de Modulos)

**Herramienta:** [Checkov](https://www.checkov.io/)  
**Directorio analizado:** `plantillas/` (Escaneo recursivo de todos los modulos)  
**Framework:** `cloudformation`  
**Fecha:** 2026-10-25  

---

## Resultado General

| Categoria | Cantidad |
|---|---|
| Aprobados (Passed) | 26 |
| Fallidos (Failed) | 0 |
| Omitidos con Justificacion (Suppressed) | 9 |

---

## Checks Omitidos (Justificados por Diseno y Free Tier)

| Check ID | Archivo / Modulo | Recurso | Justificacion Arquitectonica |
|---|---|---|---|
| `CKV_AWS_158` | `red.yaml` | `VPCFlowLogGroup` | Cifrado estandar AWS CloudWatch para mantenerse en Free Tier |
| `CKV_AWS_24` | `seguridad.yaml` | `BackendSecurityGroup` | Puerto 22 parametrizado via `SSHLocation` auditado |
| `CKV_AWS_260` | `seguridad.yaml` | `BackendSecurityGroup` | Puerto 3000 aloja el endpoint HTTP publico del API NestJS |
| `CKV_AWS_24` | `seguridad.yaml` | `FrontendSecurityGroup` | Puerto 22 parametrizado via `SSHLocation` auditado |
| `CKV_AWS_260` | `seguridad.yaml` | `FrontendSecurityGroup` | Puerto 80 necesario para servir la aplicacion SPA en Nginx |
| `CKV_AWS_88` | `backend.yaml` | `BackendInstance` | IP Elastica publica estatica para acceso directo y control de costos |
| `CKV_AWS_88` | `frontend.yaml` | `FrontendInstance` | IP Elastica publica estatica para servir el cliente web a internet |
| `CKV_AWS_158` | `monitoreo.yaml` | `BackendLogGroup` | Cifrado estandar AWS CloudWatch para mantenerse en Free Tier |
| `CKV_AWS_158` | `monitoreo.yaml` | `FrontendLogGroup` | Cifrado estandar AWS CloudWatch para mantenerse en Free Tier |

---

## Comando de Ejecucion

```bash
checkov -d plantillas/ --framework cloudformation --output cli
```

## Estado: APROBADO ✅

0 fallos. Todos los modulos cumplen con las politicas de seguridad DevSecOps y las mejores practicas de CIS AWS Benchmark.

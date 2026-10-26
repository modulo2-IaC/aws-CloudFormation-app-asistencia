# Politica de Proteccion de Recursos

Este documento define que recursos del stack **NO deben eliminarse** aunque
el stack sea actualizado o borrado, y como protegerlos con politicas AWS.

---

## 1. Proteccion contra eliminacion de Stack

Activa **Termination Protection** antes de crear el stack en produccion:

```bash
# Habilitar al crear
aws cloudformation create-stack \
  --stack-name stack-asistencia-dev \
  --enable-termination-protection \
  --region us-east-2

# Habilitar en un stack existente
aws cloudformation update-termination-protection \
  --enable-termination-protection \
  --stack-name stack-asistencia-dev \
  --region us-east-2
```

---

## 2. Recursos con Retain Policy

Los siguientes recursos tienen `DeletionPolicy: Retain` en `plantillas/main.yaml`,
lo que significa que **NO se eliminan** aunque el stack sea destruido:

| Recurso Logico    | Tipo                    | Motivo |
|-------------------|-------------------------|--------|
| `VPC`             | `AWS::EC2::VPC`         | Evitar perdida de configuracion de red |
| `BackendLogGroup` | `AWS::Logs::LogGroup`   | Conservar logs de auditoria |
| `FrontendLogGroup`| `AWS::Logs::LogGroup`   | Conservar logs de auditoria |

> **Nota:** Si la plantilla aun no tiene estos `DeletionPolicy`, agregalos
> en la seccion `Properties` del recurso correspondiente:
> ```yaml
> DeletionPolicy: Retain
> ```

---

## 3. Recursos de Solo Datos (nunca provisionar desde CFN)

Estos recursos viven **fuera** de CloudFormation y no deben gestionarse
como parte del stack:

| Recurso                   | Gestionado por    |
|---------------------------|-------------------|
| Base de datos Neon (Postgres) | Neon Dashboard |
| Secretos JWT / passwords  | Variables locales / AWS Secrets Manager |

---

## 4. IAM — Principio de Minimo Privilegio

El rol `EC2InstanceRole` en la plantilla solo tiene acceso a:
- `AmazonSSMManagedInstanceCore` — conexion via SSM sin SSH
- `CloudWatchAgentServerPolicy` — envio de metricas y logs

**No agregar politicas adicionales** sin revision de seguridad.

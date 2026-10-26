# Sistema de Asistencia — CloudFormation

Infraestructura como Codigo (IaC) en AWS diseñada bajo principios de **Alta Cohesion y Bajo Acoplamiento** para desplegar el **Backend NestJS** y **Frontend React/Vite/Nginx** en instancias EC2 optimizadas para la capa gratuita (Free Tier, region `us-east-2`).

> 📊 **Guia Visual de Arquitectura:** Para consultar diagramas interactivos de red, topologias, grafos de dependencias entre modulos y matrices de recursos, revisa el nuevo documento dedicado [ARQUITECTURA.md](file:///d:/soe/modulos/DCID-V1E1%20-%2002%20I%20INFRAESTRUCTURA%20COMO%20C%C3%93DIGO%20%28IAC%29/apps/app4/IAC/aws/CloudFormation/recursos-app-asistencia/ARQUITECTURA.md).

---

## Estructura Modular del Proyecto

```
recursos-app-asistencia/
├── README.md                            # Documentacion general del sistema
├── ARQUITECTURA.md                      # Diagramas visuales, matrices de relacion y flujo de recursos
├── .gitignore                           # Proteccion contra exposicion de secretos/parametros
├── .github/
│   └── workflows/
│       └── deploy.yml                   # CI/CD: Pipeline de despliegue en GitHub Actions
├── plantillas/                          # Arquitectura Modular (Alta Cohesion / Bajo Acoplamiento)
│   ├── main.yaml                        # Orquestador raiz (Root Stack / Nested Stacks)
│   ├── red.yaml                         # Modulo de Red: VPC, Subredes, Enrutamiento, Flow Logs
│   ├── seguridad.yaml                   # Modulo de Seguridad: Firewalls (SGs) y Roles IAM
│   ├── backend.yaml                     # Modulo Computo Backend: EC2 NestJS, EIP, PM2
│   ├── frontend.yaml                    # Modulo Computo Frontend: EC2 React/Vite, EIP, Nginx
│   └── monitoreo.yaml                   # Modulo Observabilidad: CloudWatch Alarms y SNS Topic
├── parametros/                          # Separacion de parametros por responsabilidad
│   ├── infra.json                       # Parametros de computo, red, acceso y alertas
│   ├── backend.json                     # Parametros de DB Neon, JWT, CORS y repo backend
│   ├── frontend.json                    # Parametros del repositorio frontend
│   └── *.example.json                   # Plantillas de ejemplo para versionado seguro
├── scripts/                             # Automatizacion de pruebas, despliegue y destruccion
│   ├── deploy.ps1                       # Despliegue en Windows (PowerShell)
│   ├── deploy.sh                        # Despliegue en Linux/macOS (Bash)
│   ├── destroy.ps1                      # Eliminacion segura en Windows (PowerShell)
│   └── destroy.sh                       # Eliminacion segura en Linux/macOS (Bash)
├── reportes/                            # Auditoria DevSecOps y analisis de codigo
│   ├── cfn-lint.md                      # Analisis estatico de esquema CloudFormation
│   ├── checkov.md                       # Escaneo de seguridad y cumplimiento CIS AWS
│   └── aws-validate.md                  # Validacion directa contra AWS CloudFormation API
└── politicas/                           # Gobierno y proteccion de infraestructura
    └── proteccion-recursos.md           # Politicas de proteccion de stack y recursos clave
```

---

## Principios Arquitectonicos Aplicados

### 1. Alta Cohesion (Single Responsibility)
Cada plantilla dentro de `plantillas/` agrupa exclusivamente los recursos que comparten el mismo proposito arquitectonico y ciclo de vida:

| Modulo | Responsabilidad Unica | Recursos Gestionados |
|---|---|---|
| `red.yaml` | Topologia de red y conectividad segura | VPC, Internet Gateway, Subredes aisladas, Route Table, VPC Flow Logs |
| `seguridad.yaml` | Perimetro de firewall y control de accesos | Security Groups (NestJS 3000, Web 80/443, SSH 22), Roles IAM con SSM y CloudWatch |
| `backend.yaml` | Servidor de aplicaciones de negocio | EC2 Ubuntu, Elastic IP, UserData automatizado (Node.js 20, NestJS, Prisma, PM2) |
| `frontend.yaml` | Servidor web de presentacion para clientes | EC2 Ubuntu, Elastic IP, Nginx configurado para SPA, build de React/Vite |
| `monitoreo.yaml` | Salud, auditoria y respuesta a incidentes | SNS Topic de alertas, CloudWatch Log Groups (30 dias), alarmas de CPU y Status Checks |
| `main.yaml` | Orquestacion global | Declara los `AWS::CloudFormation::Stack` anidados y expone las salidas consolidadas |

### 2. Bajo Acoplamiento (Loose Coupling)
- **Cero dependencias circulares:** Los modulos hijos no dependen mutuamente.
- **Interfaces limpias:** Cada modulo define sus propios `Parameters` de entrada y `Outputs` de salida.
- **Inyeccion de dependencias via `main.yaml`:** El orquestador enlaza las salidas de un modulo con las entradas del siguiente:
  $$\text{Red} \longrightarrow \text{Seguridad} \longrightarrow \text{Backend} \longrightarrow \text{Frontend} \longrightarrow \text{Monitoreo}$$
- **Independencia operativa:** Cada modulo hijo puede validarse o desplegarse de manera autonoma.

---

## Requisitos Previos

- AWS CLI configurado (`aws configure`)
- Cuenta AWS activa con permisos en CloudFormation, IAM, EC2, CloudWatch y SNS
- Bucket S3 en la region objetivo (detectado automaticamente como `cf-templates-*-{region}`)
- Herramientas recomendadas: `cfn-lint` (`pip install cfn-lint`), `checkov` (`pip install checkov`)

---

## Configuracion de Parametros Locales

Los parametros estan separados por dominio para evitar mezclar secretos de aplicacion con configuraciones de red. Copia los archivos de ejemplo para comenzar:

```bash
cp parametros/infra.example.json    parametros/infra.json
cp parametros/backend.example.json  parametros/backend.json
cp parametros/frontend.example.json parametros/frontend.json
```

---

## Metodos de Despliegue

### Opcion A: Despliegue Local con Scripts

#### Windows (PowerShell)
```powershell
# Validar, fusionar parametros y desplegar en us-east-2:
powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1

# Simulacion previa (Dry-Run sin crear recursos en AWS):
powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1 -DryRun

# Omitir escaneos locales de cfn-lint y Checkov:
powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1 -SkipScan
```

#### Linux / macOS / WSL (Bash)
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh stack-asistencia-dev us-east-2
```

---

### Opcion B: Aprovisionamiento mediante GitHub Actions (CI/CD)

El proyecto incluye el flujo automatizado [deploy.yml](file:///.github/workflows/deploy.yml) que valida DevSecOps y aprovisiona el stack en AWS.

#### 1. Configurar Secrets en GitHub
En tu repositorio de GitHub, navega a **Settings** > **Secrets and variables** > **Actions** > **New repository secret** y registra:

| Secret Name | Descripcion | Ejemplo |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Access Key de un usuario IAM o rol con permisos CloudFormation | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | Secret Key correspondiente de AWS | `wJalrXUtn...` |
| `AWS_REGION` | Region AWS objetivo (opcional, por defecto `us-east-2`) | `us-east-2` |
| `DATABASE_URL` | Cadena de conexion completa a PostgreSQL Neon con SSL | `postgresql://user:pass@host/db?sslmode=require` |
| `JWT_SECRET` | Clave secreta robusta para tokens JWT del Backend | `secreto_super_seguro_jwt_123` |
| `ADMIN_PASSWORD` | Contrasena para el usuario administrador `ubuntu` (opcional) | `TuPassword123!` |
| `ALERT_EMAIL` | Correo electronico para suscripcion de alertas SNS (opcional) | `alertas@tudominio.com` |

#### 2. Variables de Repositorio (Opcionales)
En **Settings** > **Secrets and variables** > **Actions** > pestaña **Variables**:
- `INSTANCE_TYPE`: `t3.micro`
- `SSH_LOCATION`: Tu IP publica `x.x.x.x/32` o `0.0.0.0/0`
- `APP_TIMEZONE`: `America/Caracas`

#### 3. Ejecutar el Workflow
1. Ve a la pestaña **Actions** en tu repositorio de GitHub.
2. Selecciona el workflow **CI/CD CloudFormation - Sistema de Asistencia**.
3. Haz clic en **Run workflow**.
4. Selecciona la accion: `deploy` (desplegar) o `destroy` (eliminar).
5. Selecciona el entorno: `dev`, `qa` o `prod`.
6. Haz clic en **Run workflow**.
7. Al finalizar, la pestaña del job mostrara un **Step Summary** con todas las IPs publicas, URLs y comandos de conexion.

---

### Opcion C: Aprovisionamiento mediante la Consola Web de AWS

Dado que la arquitectura utiliza **Stacks Anidados (Nested Stacks)**, CloudFormation necesita acceder a las plantillas hijas desde un bucket S3.

#### Paso 1: Empaquetar y subir las plantillas a Amazon S3
Ejecuta en tu terminal el comando oficial de empaquetado (usa el bucket predeterminado de CloudFormation de tu region):
```bash
# Empaqueta las plantillas modulares y genera un archivo consolidado listo para la consola:
aws cloudformation package \
  --template-file plantillas/main.yaml \
  --s3-bucket cf-templates-5yh14sa9ef09-us-east-2 \
  --output-template-file template-packaged.yaml
```
*(Tambien puedes subir la carpeta `plantillas/` completa a tu bucket S3 y usar la URL del objeto de `main.yaml`).*

#### Paso 2: Crear el Stack en CloudFormation
1. Inicia sesion en la [Consola de Administracion de AWS](https://console.aws.amazon.com/).
2. Asegurate de estar en la region **us-east-2 (Ohio)** (o tu region objetivo).
3. En la barra de busqueda superior, escribe **CloudFormation** y selecciona el servicio.
4. Haz clic en el boton naranja **Create stack** > **With new resources (standard)**.
5. En la seccion **Prerequisite - Prepare template**, selecciona:
   * **Template is ready**
6. En la seccion **Specify template**, selecciona:
   * **Upload a template file** y pulsa **Choose file**.
   * Selecciona el archivo `template-packaged.yaml` generado en el Paso 1.
7. Haz clic en **Next**.

#### Paso 3: Especificar Detalles del Stack (Parametros)
1. **Stack name:** `stack-asistencia-dev`
2. Configura los parametros organizados por grupos:
   * **1. Configuracion General:**
     * `ProjectName`: `asistencia`
     * `Environment`: `dev`
   * **2. Computo y Acceso Administrativo (EC2):**
     * `InstanceType`: `t3.micro`
     * `AdminUsername`: `ubuntu`
     * `AdminPassword`: *(Opcional o ingresa contrasena deseada)*
     * `SSHLocation`: `0.0.0.0/0` (o tu IP publica `x.x.x.x/32`)
     * `KeyName`: *(Nombre de tu KeyPair EC2 si creaste uno previamente)*
   * **3. Parametros de Backend (NestJS):**
     * `DatabaseUrl`: Tu string de conexion Neon con SSL
     * `JwtSecret`: Clave secreta para JWT
     * `CorsOrigin`: `*`
     * `AppTimezone`: `America/Caracas`
     * `RunMigrations`: `true`
     * `NodeVersion`: `20`
     * `BackendRepoUrl`: `https://github.com/Joandrr/asistencia-back.git`
   * **4. Parametros de Frontend (Vite/React):**
     * `FrontendRepoUrl`: `https://github.com/Joandrr/asistencia-front.git`
   * **5. Observabilidad:**
     * `AlertEmail`: *(Tu email para recibir notificaciones SNS)*
3. Haz clic en **Next**.

#### Paso 4: Opciones de Configuracion del Stack
1. En **Tags**, agrega opcionalmente etiquetas de gestion (ej. `Project = asistencia`).
2. En **Stack failure options**, mantén la opcion recomendada **Roll back all stack resources** para asegurar limpieza automatica ante cualquier fallo.
3. Haz clic en **Next**.

#### Paso 5: Revision y Capacidades (Capabilities Obligatorias)
1. Revisa todos los parametros ingresados.
2. Desplazate hasta el final de la pagina a la caja de advertencia **Capabilities**.
3. Marca obligatoriamente las dos casillas:
   * `[x] I acknowledge that AWS CloudFormation might create IAM resources with custom names.` (`CAPABILITY_NAMED_IAM`)
   * `[x] I acknowledge that AWS CloudFormation might require the following capability: CAPABILITY_AUTO_EXPAND`
4. Haz clic en **Submit**.

#### Paso 6: Seguimiento y Salidas
1. En la pestaña **Events**, podras observar la creacion secuencial y en paralelo del stack raiz y de los 5 stacks anidados (`RedStack`, `SeguridadStack`, `BackendStack`, `FrontendStack`, `MonitoreoStack`).
2. Una vez que el estado sea **CREATE_COMPLETE**, ve a la pestaña **Outputs** para ver las IPs publicas, URLs activas y comandos de administracion.

---

## Eliminacion de los Recursos Creados (Teardown / Destroy)

Para evitar incurrir en costos tras concluir tus pruebas o desarrollo, elimina la infraestructura de forma completa y ordenada mediante cualquiera de las siguientes vias:

### 1. Eliminacion con Script en Windows (PowerShell)
```powershell
# Modo interactivo con confirmacion de seguridad:
powershell -ExecutionPolicy Bypass -File scripts\destroy.ps1

# Modo forzado desatendido (sin confirmacion interactiva):
powershell -ExecutionPolicy Bypass -File scripts\destroy.ps1 -Force
```

### 2. Eliminacion con Script en Linux/macOS (Bash)
```bash
chmod +x scripts/destroy.sh
./scripts/destroy.sh stack-asistencia-dev us-east-2
```

### 3. Eliminacion directa con AWS CLI
```bash
# 1. Desactivar termination protection (en caso de estar activa)
aws cloudformation update-termination-protection \
  --no-enable-termination-protection \
  --stack-name stack-asistencia-dev \
  --region us-east-2

# 2. Solicitar eliminacion del stack raiz (elimina automaticamente todos los stacks anidados)
aws cloudformation delete-stack \
  --stack-name stack-asistencia-dev \
  --region us-east-2

# 3. Esperar a que la eliminacion concluya
aws cloudformation wait stack-delete-complete \
  --stack-name stack-asistencia-dev \
  --region us-east-2
```

### 4. Eliminacion desde la Consola Web de AWS
1. Ingresa a **CloudFormation** en la region `us-east-2`.
2. En la lista de stacks, selecciona el stack raiz `stack-asistencia-dev`.
3. Haz clic en el boton superior **Delete**.
4. En el cuadro de dialogo de confirmacion, pulsa **Delete**.
5. CloudFormation eliminara automaticamente los stacks anidados en orden inverso de dependencias:
   $$\text{Monitoreo} \longrightarrow \text{Frontend} \longrightarrow \text{Backend} \longrightarrow \text{Seguridad} \longrightarrow \text{Red}$$
6. El proceso toma aproximadamente de 2 a 4 minutos.

---

## Publicacion de este Repositorio en GitHub

Para publicar esta infraestructura en tu propia cuenta u organizacion de GitHub:

```bash
# 1. Ubicate en la carpeta del proyecto
cd "IAC/aws/CloudFormation/recursos-app-asistencia"

# 2. Crea un nuevo repositorio vacio en GitHub (ej. asistencia-cloudformation)

# 3. Conecta este repositorio local con tu repositorio remoto
git remote add origin https://github.com/<TU_USUARIO>/<TU_REPOSITORIO>.git

# 4. Asegura la rama principal y publica los cambios
git branch -M main
git push -u origin main
```

> **Nota de Seguridad:** El archivo `.gitignore` configurado en el repositorio evita automaticamente que archivos con contraseñas o URLs de bases de datos reales (`parametros/*.json`) se suban a GitHub. En su lugar, se publican las plantillas seguras `*.example.json`.

---

## Salidas Disponibles tras el Despliegue

Al completarse el despliegue, el stack expone de forma automatica:
- **`BackendPublicIP`** & **`BackendApiUrl`**: URL publica del API NestJS (`http://<IP>:3000/api/v1`).
- **`BackendDocsUrl`**: Documentacion interactiva Swagger (`http://<IP>:3000/api/v1/docs`).
- **`FrontendPublicIP`** & **`FrontendWebUrl`**: URL publica del Frontend React en Nginx (`http://<IP>`).
- **`SSMBackendSessionCommand`** & **`SSMFrontendSessionCommand`**: Acceso shell seguro sin necesidad de llaves SSH ni puertos abiertos via AWS Systems Manager Session Manager.
- **`UploadBackendCommand`** & **`UploadFrontendCommand`**: Comandos listos para transferir el codigo fuente y desplegar.

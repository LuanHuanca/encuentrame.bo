# Estructura de carpetas — Encuéntrame

Documento de referencia para mantener una estructura clara del proyecto: app Flutter, configuración de backend (Amplify) e infraestructura (Terraform).

---

## Vista general del repositorio

```
encuentrame/
├── lib/                    # Código de la app Flutter
├── amplify/                # Backend AWS (Amplify): Auth, API, Lambdas
├── infra/                  # Infraestructura como código (Terraform)
├── docs/                   # Documentación del proyecto
├── assets/                 # Imágenes, fuentes, etc.
├── test/                   # Tests de la app
├── android/
├── ios/
├── pubspec.yaml
└── README.md
```

---

## 1. App Flutter (`lib/`)

Estructura sugerida para pantallas, configuración, servicios AWS y reutilización de código.

```
lib/
├── main.dart                      # Punto de entrada, configuración de Amplify
│
├── app/                           # Configuración de la aplicación
│   ├── app.dart                   # Widget raíz (MaterialApp, tema, rutas)
│   ├── router.dart                # Rutas nombradas / GoRouter
│   └── theme.dart                 # Tema global (colores, tipografía)
│
├── core/                          # Código transversal (no es una feature)
│   ├── config/
│   │   └── amplify_config.dart    # Carga de amplifyconfiguration (dev/prod)
│   ├── constants/
│   │   ├── api_constants.dart     # URLs, endpoints
│   │   └── app_constants.dart     # Strings, keys, valores fijos
│   ├── errors/
│   │   ├── app_exception.dart     # Excepciones propias
│   │   └── error_handler.dart     # Manejo centralizado de errores
│   └── utils/
│       └── validators.dart        # Validadores de formularios, etc.
│
├── features/                      # Módulos por funcionalidad (pantallas + lógica)
│   ├── auth/
│   │   ├── data/                  # Repositorios, fuentes de datos
│   │   ├── domain/                # Modelos de dominio, casos de uso (opcional)
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   │   ├── login_page.dart
│   │   │   │   ├── signup_page.dart
│   │   │   │   └── forgot_password_page.dart
│   │   │   └── widgets/           # Widgets solo de auth
│   │   └── auth_provider.dart     # O state si usan bloc/cubit
│   │
│   ├── home/
│   │   └── presentation/
│   │       └── pages/
│   │           └── home_page.dart
│   │
│   ├── profile/
│   │   └── presentation/
│   │       └── pages/
│   │           └── profile_page.dart
│   │
│   ├── stalls/                    # Ejemplo: puestos / encuentros
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── pages/
│   │       └── widgets/
│   │
│   └── onboarding/                # Ejemplo: bootstrap SELLER/BUYER
│       └── presentation/
│           └── pages/
│               └── role_selection_page.dart
│
├── shared/                        # Compartido entre features
│   ├── models/                    # DTOs, modelos de API
│   │   ├── user_model.dart
│   │   └── stall_model.dart
│   ├── services/                  # Servicios (AWS, API, etc.)
│   │   ├── api/
│   │   │   ├── api_client.dart    # Cliente HTTP / Amplify API
│   │   │   └── encuentrame_api_service.dart
│   │   └── auth/
│   │       └── auth_service.dart  # Wrapper de Amplify Auth
│   └── widgets/                   # Componentes reutilizables
│       ├── buttons/
│       ├── inputs/
│       └── loaders/
│
└── amplifyconfiguration.dart      # JSON de config (o mover a core/config/)
```

### Resumen de `lib/`

| Carpeta      | Uso |
|-------------|-----|
| `app/`      | Configuración global: rutas, tema, `MaterialApp`. |
| `core/`     | Config, constantes, errores, utilidades sin lógica de negocio. |
| `features/` | Una carpeta por flujo (auth, home, profile, stalls, etc.) con sus páginas y opcionalmente data/domain. |
| `shared/`   | Modelos, servicios (API, Auth), widgets que usan varias features. |

---

## 2. Backend Amplify (`amplify/`)

Ya existente. Resumen para ubicar cosas:

```
amplify/
├── .config/                 # Config local del proyecto/entorno
├── backend/
│   ├── api/                 # API Gateway (REST)
│   ├── auth/                # Cognito (User Pool, etc.)
│   ├── function/
│   │   └── encuentrameApi/  # Lambda Node.js (API de usuarios, etc.)
│   │       └── src/
│   │           └── index.js
│   ├── backend-config.json
│   └── amplify-meta.json
├── #current-cloud-backend/  # Copia del backend desplegado
├── team-provider-info.json
├── cli.json
└── hooks/                   # Scripts pre-push, post-push (samples)
```

- **Auth**: configuración en `backend/auth/`.
- **API REST**: en `backend/api/`; la Lambda que responde está en `backend/function/encuentrameApi/`.
- Cambios de backend: `amplify push` (o el flujo que usen en equipo).

---

## 3. Infraestructura Terraform (`infra/`)

Recursos que no gestiona Amplify (p. ej. DynamoDB creadas con Terraform):

```
infra/
└── terraform/
    ├── main.tf              # Definición de recursos (DynamoDB, etc.)
    ├── variables.tf         # Variables (opcional)
    ├── outputs.tf           # Outputs para otros sistemas (opcional)
    ├── .terraform.lock.hcl
    └── terraform.tfstate    # No commitear si es remoto; usar backend remoto
```

Conviene que el equipo acuerde:
- Qué se crea con **Amplify** (Auth, API, Lambdas asociadas).
- Qué se crea con **Terraform** (tablas DynamoDB, etc.) y cómo se pasan nombres/variables a Amplify si hace falta.

---

## 4. Assets y documentación

```
assets/
├── images/
├── icons/
└── fonts/

docs/
├── ESTRUCTURA_PROYECTO.md   # Este documento
├── API.md                   # Endpoints y contratos (opcional)
└── SETUP.md                 # Cómo levantar el proyecto (opcional)
```

---

## 5. Convenciones sugeridas

- **Rutas**: centralizar en `app/router.dart` (rutas nombradas o GoRouter).
- **Configuración AWS**: cargar en `main.dart` desde `core/config/` (usando `amplifyconfiguration.dart`).
- **Llamadas a API**: un servicio en `shared/services/api/` que use el cliente configurado con Amplify.
- **Auth**: un servicio en `shared/services/auth/` que encapsule Amplify Auth; las pantallas solo llaman a ese servicio.
- **Nombres de archivos**: `snake_case` (p. ej. `login_page.dart`, `auth_service.dart`).
- **Features nuevas**: crear carpeta bajo `features/<nombre>/` con al menos `presentation/pages/`.

---

## 6. Próximos pasos posibles

1. Crear las carpetas vacías en `lib/` e ir moviendo/creando archivos según esta estructura.
2. Mover `amplifyconfiguration.dart` a `lib/core/config/` y referenciarlo desde `main.dart`.
3. Definir rutas en `app/router.dart` y pantallas mínimas en `features/auth` y `features/home`.
4. Implementar `auth_service.dart` y `encuentrame_api_service.dart` en `shared/services/` para conectar con Cognito y la API.

Si quieres, en el siguiente paso podemos bajar esto a una lista de tareas concretas (archivos a crear y qué poner en cada uno) para repartir con tu compañero.

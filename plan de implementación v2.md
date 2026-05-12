Como **Principal Software Architect y Lead Developer**, presento el Blueprint Técnico de Arquitectura Empresarial definitivo para el sistema **“Pastelería Pro”**. Este documento consolida la arquitectura limpia, la gestión de estado reactiva mediante Provider, la estrategia visual corporativa y el flujo operativo transaccional, estructurado para un despliegue multiplataforma de nivel productivo.

---

## 🔷 I. STACK DE DEPENDENCIAS & JUSTIFICACIÓN TÉCNICA (`pubspec.yaml`)

La selección de paquetes ha sido curada para garantizar desacoplamiento, rendimiento determinista y mantenibilidad a largo plazo. Cada dependencia cumple un rol específico dentro de la arquitectura definida.

* **Núcleo & Backend:**
  * `firebase_core`, `firebase_auth`: Inicialización segura del ecosistema Firebase, gestión de sesiones y validación de tokens JWT para autenticación empresarial.
  * `cloud_firestore`: Motor de persistencia NoSQL para operaciones en tiempo real, consultas indexadas y transacciones atómicas.
  * `firebase_storage`: Repositorio externo para assets visuales. Garantiza que la base de datos solo almacene referencias URL, optimizando el peso de los documentos.
* **Gestión de Estado & Inyección:**
  * `provider`: Capa reactiva principal para exponer estados de negocio (`ChangeNotifier`) a la UI. Permite escalabilidad mediante `MultiProvider` y escucha selectiva (`Selector`/`context.watch`).
  * `get_it`: Contenedor de inyección de dependencias (Service Locator). Centraliza la instanciación de repositorios, fuentes de datos y casos de uso, eliminando acoplamiento en la capa de presentación.
  * `equatable`: Implementación optimizada de comparación de valores. Esencial para evitar reconstrucciones innecesarias de widgets cuando los estados de `Provider` cambian pero sus datos internos permanecen idénticos.
* **UI, Assets & Formateo:**
  * `cached_network_image`: Carga de imágenes exclusivamente por red con estrategias de caché en memoria y disco. Reduce latencia y consumo de ancho de banda en terminales móviles.
  * `shimmer`: Indicadores de carga progresiva que mejoran la percepción de rendimiento durante la recuperación de imágenes o listas extensas.
  * `flutter_svg`: Renderizado vectorial escalable para iconografía y elementos de diseño que requieren independencia de resolución.
  * `google_fonts`: Tipografías descargables o empaquetadas para garantizar consistencia visual en Android, iOS y Web sin depender de fuentes del sistema.
  * `intl`: Localización y formateo estricto. Crítico para la representación de moneda, fechas y, especialmente, para la validación y renderizado de valores con precisión de **3 decimales** en gramajes.

---

## 🔷 II. BLUEPRINT DE ARQUITECTURA DE DIRECTORIOS (`lib/`)

La estructura sigue estrictamente el principio de **dependencia unidireccional**. Presentation depende de Domain; Domain y Data dependen de Core. Provider reside exclusivamente en Presentation, consumiendo casos de uso puros.

```
lib/
├── core/
│   ├── di/                 # Registro de dependencias (GetIt). Inyección de repositorios, usecases y configuración global.
│   ├── routing/            # GoRouter: configuración declarativa, guards por rol (Admin, Cajero, Pastelero), deep linking y rutas por plataforma.
│   ├── theme/              # Design System: definición de paleta, tipografía, espaciado, curvas y componentes base.
│   ├── errors/             # Jerarquía de fallos tipados (Network, Validation, Auth, Firestore). Traductores a mensajes de UI.
│   ├── constants/          # Rutas de Storage, límites de negocio, umbrales de stock, identificadores de rol.
│   └── utils/              # Validadores, formateadores de precisión, parsers de fechas, helpers de caché.
│
├── domain/
│   ├── entities/           # Modelos puros del negocio (11 entidades). Clases inmutables sin dependencias externas.
│   ├── value_objects/      # Tipos estrictos: Quantity (3 decimales), MonetaryValue, OrderStatus, Role.
│   ├── contracts/          # Interfaces abstractas de repositorios. Definen el contrato Data ↔ Domain.
│   ├── usecases/           # Lógica de negocio atómica: CreateOrder, DeductStock, CalculateRecipeCost, ProcessPayment.
│   └── validators/         # Reglas de validación cruzada (stock suficiente, disponibilidad de producto, márgenes de abono).
│
├── data/
│   ├── dtos/               # Estructuras de serialización que reflejan el esquema exacto de Firestore y Storage URLs.
│   ├── mappers/            # Traductores bidireccionales (DTO ↔ Entity). Aplican redondeo seguro a 3 decimales y validan URLs.
│   ├── repositories/       # Implementaciones concretas de los contratos. Orquestan fuentes remotas y locales.
│   └── datasources/
│       ├── remote/         # Cliente Firestore (colecciones, subcolecciones, batch, transacciones) y Storage (generación de URLs firmadas).
│       └── local/          # Persistencia ligera (Hive/SharedPreferences) para caché de catálogo, cola de pedidos offline y sesión.
│
└── presentation/
    ├── providers/          # ChangeNotifiers organizados por dominio: auth, catalog, inventory, sales, production, ui_local.
    ├── screens/            # Vistas modulares: POS (caja), Production (cocina), Admin (dashboard), Auth (acceso), Client (rastreo).
    ├── widgets/            # UI-Kit Atómico: botones, inputs, tarjetas de estado, grids, tablas, loaders. Stateless y responsivos.
    ├── routes/             # Middlewares de navegación, redirecciones condicionales y manejo de parámetros de ruta.
    └── observers/          # Logging de rendimiento, intercepción de navegación y métricas de renderizado.
```

---

## 🔷 III. IDENTIDAD VISUAL & ESTRATEGIA DE ASSETS (UX/UI)

### 🎨 Paleta Corporativa y Sistema de Diseño
* **Superficie Base:** `#FFFDD0` (Crema) para fondos principales y áreas de trabajo. Proporciona calidez y reduce fatiga visual en jornadas operativas largas.
* **Acento Primario:** `#FADADD` (Rosa suave) para elementos interactivos, bordes sutiles y fondos de módulos de catálogo.
* **Tipografía & Alto Contraste:** `#4B2C20` (Marrón chocolate) para textos principales, iconografía y encabezados. Garantiza legibilidad WCAG AA sobre fondos claros.
* **Indicadores de Estado:**
  * `Pendiente/En Preparación`: `#FFC107` (Ámbar). Comunica espera activa sin generar urgencia innecesaria.
  * `Listo/Entregado`: `#8FBC8F` (Verde pistacho). Señaliza completitud y liberación de inventario.
  * `Error/Stock Crítico`: `#DC3545` (Rojo suave). Reservado exclusivamente para alertas de negocio o fallos de validación.

### 🖼️ Gestión de Imágenes por Red & Optimización
* **Almacenamiento:** Todos los assets (productos, categorías, logos, avatares) residen en **Firebase Storage**. Firestore solo almacena la URL pública o firmada en el campo `image_url`.
* **Carga & Caché:** Implementación de `cached_network_image` con configuración de `CacheManager`. Memoria para accesos rápidos, disco para persistencia entre reinicios. Fallback automático a `shimmer` + placeholder vectorial mientras se resuelve la URL.
* **Seguridad & Optimización:** Reglas de Storage que permiten lectura pública solo a recursos marcados como `is_public: true`. Compresión automática en carga (máx. 800px de ancho, formato WebP) para minimizar latencia en Web y redes móviles.

---

## 🔷 IV. ESTRATEGIA DE BASE DE DATOS (FIRESTORE) & LÓGICA DE PRODUCCIÓN

### 🗃️ Jerarquía de Colecciones y Relaciones NoSQL
La estructura prioriza lecturas eficientes, trazabilidad y consistencia transaccional:
* `employees`: Documento por usuario con `role` (admin, pastry_chef, cashier), `status`, `custom_claims` sincronizados con Auth.
* `clients`: Perfil, historial de contactos, preferencias y volumen de compra.
* `categories` → `products`: `products` referencia `categoryId`. Incluye `is_available`, `base_price`, `preparation_type` (direct_sale / custom), `image_url`.
* `suppliers` → `purchases`: Registro de entradas de insumos. Cada ítem de compra referencia `ingredientId`, `quantity_acquired`, `unit_cost`.
* `ingredients`: `current_stock`, `min_stock`, `unit`, `cost_per_unit`, `last_audit_date`.
* `ingredients_products`: Colección plana de recetas. `documentId` generado de forma determinista: `productId_ingredientId` (simula **Clave Primaria Compuesta**). Contiene `quantity_required` (precisión 3 decimales), `preparation_notes`.
* `orders` (subcolección: `order_items`):
  * `orders`: `type`, `clientRef`, `cashierRef`, `status` (pending, in_progress, ready, delivered), `total_amount`, `created_at`, `scheduled_delivery`.
  * `order_items`: `productRef`, `quantity`, `unit_price_snapshot` (inmutable al momento de creación), `discount_applied`.
* `payments`: Colección independiente vinculada por `orderId`. Registra transacciones múltiples: `amount`, `method`, `type` (advance, partial, full), `timestamp`, `remaining_balance`.

### ⚙️ Lógica de Descuento Automático de Stock
Para evitar condiciones de carrera y garantizar precisión milimétrica, el descuento se ejecuta de forma **server-authoritative** y atómica:
1. **Trigger:** Activado cuando `order.status` transita a `ready` o cuando `payments.remaining_balance ≤ 0` (dependiendo de la política de negocio configurada).
2. **Cálculo de Demanda:** El sistema itera `order_items`, resuelve cada producto en `ingredients_products` y acumula: `cantidad_pedido × quantity_required`.
3. **Transacción Atómica:** Se abre un bloque `runTransaction` en Firestore. Lee los documentos `ingredients` actuales. Valida `current_stock ≥ demanda_acumulada`. Si falla, revierte la operación y notifica al `salesProvider` con un error tipado.
4. **Descuento & Alerta:** Resta la demanda con redondeo seguro a 3 decimales. Evalúa si `new_stock ≤ min_stock`. De cumplirse, genera un documento en `alerts/` asignado al rol de Administrador/Pastelero.
5. **Auditoría:** Registra el movimiento en `inventory_movements` con `orderId`, `ingredientId`, `delta`, `operator_id`, `timestamp`. Garantiza reconciliación contable y trazabilidad completa.

---

## 🔷 V. PLAN DE IMPLEMENTACIÓN POR FASES (ROADMAP CRÍTICO)

### 🟢 Fase 1: Cimentación, Seguridad & Núcleo
* **Objetivo:** Establecer infraestructura, autenticación y gobernanza de acceso.
* **Acciones:** Configuración de Firebase Project, Auth con custom claims, Reglas de Seguridad Firestore granulares (RBAC por documento y campo), setup de `core/` (GoRouter con guards, Design System, Error Handling, GetIt registry), shell de aplicación con navegación declarativa.
* **Hito:** Arquitectura vacía validada por rol. Acceso restringido a rutas y datos sensibles. `providers/` iniciales conectados a mocks.

### 🟢 Fase 2: Inventario Maestro & Trazabilidad de Insumos
* **Objetivo:** Operativizar control de materias primas con precisión industrial.
* **Acciones:** CRUD de `ingredients` y `suppliers`, flujo de `purchases`, validación estricta de 3 decimales en `mappers` y `value_objects`, implementación de `inventoryProvider` con streams en tiempo real, sistema de alertas por umbral, caché local para operaciones offline.
* **Hito:** Capacidad para registrar entradas, calcular costos unitarios, visualizar movimientos y recibir notificaciones de reabastecimiento sin interrupciones.

### 🟢 Fase 3: Ingeniería de Menú & Costeo de Producción
* **Objetivo:** Configurar catálogo productivo y vinculación de recetas.
* **Acciones:** Gestión de `categories` y `products`, carga de imágenes por URL desde Storage con caché optimizada, motor de vinculación `ingredients_products` con IDs compuestos deterministas, cálculo automático de costo base por producto, lógica de márgenes y disponibilidad.
* **Hito:** Catálogo sincronizado, costeo exacto basado en ingredientes actuales, bloqueo automático de productos con stock de receta insuficiente.

### 🟢 Fase 4: Operación de Ventas & Gestión Financiera
* **Objetivo:** Desplegar ciclo transaccional completo y manejo de abonos.
* **Acciones:** Motor de carrito con validación en tiempo real, diferenciación `Venta Directa` vs `Encargo`, captura de `unit_price_snapshot` inmutable, entidad `payments` desacoplada para anticipos y saldos, `salesProvider` con máquina de estados compleja, notificaciones de flujo a cocina.
* **Hito:** POS operativo, historial auditado, gestión de pagos parciales con cálculo automático de pendientes, sincronización bidireccional con panel de producción.

### 🟢 Fase 5: Optimización Multiplataforma & Despliegue
* **Objetivo:** Pulir experiencia, rendimiento y preparación para producción.
* **Acciones:** Layouts adaptativos (grids/paneles para Web Admin, tarjetas/flujos lineales para Mobile POS), estrategia de caché local robusta, deep linking para rastreo público (solo estado), profiling de rendimiento y reducción de rebuilds, pipeline CI/CD para Android, iOS y Web Hosting.
* **Hito:** Aplicación estable, métricas de carga optimizadas, experiencia nativa por plataforma manteniendo base unificada y gestión de estado predecible.

---

### 📌 CIERRE ARQUITECTÓNICO

Este blueprint garantiza que **“Pastelería Pro”** opere como un sistema ERP distribuido, no como una simple aplicación móvil. La separación estricta de capas asegura que la lógica de negocio permanezca pura, mientras que **Provider** actúa como puente reactivo controlado, evitando estados globales contaminados o reconstrucciones excesivas. La estrategia de **imágenes por red + caché**, combinada con la precisión de **3 decimales** y el descuento transaccional de stock, resuelve las fricciones operativas reales de una pastelería profesional.

El roadmap está diseñado para entregas incrementales, validando cada invariante antes de escalar al siguiente módulo, asegurando que el producto final cumpla con los estándares de ingeniería de software empresarial, escalabilidad multiplataforma y resiliencia operativa.
---

### 🔴 PROMPT MAESTRO: ARQUITECTURA EMPRESARIAL "PASTELERÍA PRO" (PROVIDER + CLEAN ARCHITECTURE)

**Rol del Experto:**
Actúa como un **Principal Software Architect** y **Lead Developer** senior. Tu objetivo es diseñar un **Plan de Implementación Integral** y la **Arquitectura de Software** detallada para una solución multiplataforma (Android, iOS y Web) de gestión de pastelería, basada estrictamente en los modelos de datos de los repositorios de GitHub suministrados.

**1. ESPECIFICACIONES DE NEGOCIO Y DATOS (Lógica de GitHub):**
El sistema debe gestionar 11 entidades clave con integridad referencial:

* **Ventas:** `CLIENTE`, `PEDIDO` (Tienda vs. Encargo), `DETALLE_PEDIDO` (Inmutabilidad de precios) y `PAGO` (Independiente para gestionar abonos/anticipos).
* **Catálogo:** `PRODUCTO` y `CATEGORIA`.
* **Producción:** `INGREDIENTE` (Stock Mínimo) e `INGREDIENTE_PRODUCTO` (Recetas con **Clave Primaria Compuesta** y precisión de **3 decimales** `DECIMAL(10,3)` para gramajes).
* **Operación:** `EMPLEADO` (Roles: Admin, Pastelero, Cajero), `PROVEEDOR` y `COMPRA`.

**2. IDENTIDAD VISUAL Y ASSETS (UX/UI):**

* **Paleta de Colores:** Base en tonos pastel (Rosa suave `#FADADD`, Crema `#FFFDD0`), acentos cálidos (Marrón chocolate `#4B2C20` para textos) y colores de estado (Verde pistacho para "Listo", Ámbar para "Pendiente").
* **Manejo de Imágenes:** Todo el contenido visual (productos, categorías) debe ser gestionado **exclusivamente a través de la red** mediante URLs almacenadas en Firestore y archivos en Firebase Storage, utilizando caché optimizada para evitar consumo excesivo de datos.

**3. REQUERIMIENTOS TÉCNICOS Y DEPENDENCIAS (pubspec.yaml):**

* **Arquitectura:** Clean Architecture (Capas: Data, Domain, Presentation, Core).
* **Gestión de Estado:** **Provider + ChangeNotifier**.
* **Navegación:** **GoRouter** (Soporte avanzado para Web y rutas dinámicas).
* **Dependencias Críticas:**
* *Backend:* `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`.
* *Estado & Inyección:* `provider`, `get_it`, `equatable`.
* *Imágenes & UI:* `cached_network_image` (Para carga por red), `flutter_svg`, `google_fonts`, `shimmer`.
* *Formatos:* `intl` (Para moneda y los 3 decimales de ingredientes).



**4. TAREAS DETALLADAS SOLICITADAS (Entregable Extenso sin Código):**

* **A. Estructura de Directorios (Blueprint):** Proporciona la organización jerárquica de la carpeta `lib/` (Data, Domain, Presentation, Core), explicando la responsabilidad única de cada subcarpeta.
* **B. Estrategia de Base de Datos (Firestore):** Esquematiza la jerarquía de colecciones/subcolecciones. Explica la lógica para que, al procesar un pedido, el sistema descuente automáticamente el stock de ingredientes según la receta.
* **C. Plan de Implementación por Fases (Secuencia Lógica):**
1. *Fase 1: Cimentación:* Setup de Firebase, Reglas de Seguridad y Auth por Roles.
2. *Fase 2: Inventario Maestro:* CRUD de ingredientes con precisión de 3 decimales y flujo de proveedores.
3. *Fase 3: Ingeniería de Menú:* Definición de productos con carga de imágenes por URL y vinculación de recetas.
4. *Fase 4: Operación de Ventas:* Flujo de Carrito, Pedidos personalizados y gestión de abonos/pagos parciales.
5. *Fase 5: Optimización Multiplataforma:* Adaptabilidad para Web (Admin) y Mobile (Venta rápida).



**5. RESTRICCIONES DE SALIDA:**

* **NO generar código fuente (Dart/Java/SQL).**
* El lenguaje debe ser estrictamente profesional, técnico y fluido.
* La respuesta debe ser **extensa, detallada y organizada**, enfocándose en la administración de todos los documentos y la jerarquía necesaria para un proyecto de nivel senior.

---

### ¿Por qué este prompt es perfecto?

* **Cubre todo:** Incluye las dependencias, los colores, la carga de imágenes por red y la arquitectura.
* **Respeta tus links:** Obliga a la IA a leer la lógica de los 11 modelos de tus archivos de GitHub.
* **Es profesional:** Al pedir "Clean Architecture" y "Inyección de dependencias", el resultado será una aplicación que no se rompe y es fácil de mantener.

Como **Principal Software Architect**, presento el Blueprint Técnico de Arquitectura Empresarial para el sistema **“Pastelería Pro”**, reconfigurado para integrar **Provider + ChangeNotifier** como mecanismo de gestión de estado, manteniendo la rigurosidad de Clean Architecture, la escalabilidad multiplataforma y la precisión operativa requerida para un entorno de producción real.

---

## 🔷 A. BLUEPRINT DE ADMINISTRACIÓN DE CARPETAS (`lib/`)

La jerarquía de directorios sigue el principio de **dependencia unidireccional** (Presentation → Domain ← Data, con Core transversal). Provider se encapsula estrictamente en la capa de presentación, actuando como puente reactivo entre la UI y los casos de uso del dominio.

```
lib/
├── core/
│   ├── constants/          # Variables inmutables (API keys, límites de negocio, rutas base)
│   ├── design_system/      # Tokens de diseño (tipografía, paleta, espaciado, curvas, sombras)
│   ├── routing/            # Configuración de GoRouter: guards, deep links, rutas declarativas
│   ├── error/              # Jerarquía de fallos tipados, manejadores globales, traducción UI
│   ├── di/                 # Inyección de dependencias y registro de Providers globales
│   └── utils/              # Formateadores, validadores, parsers de precisión numérica
│
├── domain/
│   ├── entities/           # Clases puras del modelo de negocio (11 entidades + Value Objects)
│   ├── contracts/          # Interfaces de repositorios (contratos abstractos por módulo)
│   ├── usecases/           # Casos de uso atómicos (validación, orquestación, reglas de negocio)
│   └── validators/         # Lógica de validación cruzada (stock, disponibilidad, márgenes)
│
├── data/
│   ├── dtos/               # Estructuras de serialización reflejando el esquema Firestore
│   ├── mappers/            # Traductores bidireccionales (DTO ↔ Entity) con control de precisión
│   ├── repositories/       # Implementaciones concretas de los contratos de Domain
│   └── datasources/
│       ├── remote/         # Cliente Firestore (colecciones, subcolecciones, transacciones)
│       └── local/          # Caché ligera para tolerancia offline y sincronización diferida
│
└── presentation/
    ├── providers/          # ChangeNotifiers organizados por dominio y alcance
    │   ├── auth/           # Provider global de sesión, permisos y sincronización de roles
    │   ├── inventory/      # Provider global de stock, alertas y movimientos en tiempo real
    │   ├── sales/          # Provider de carrito, flujo de pedidos y gestión de pagos
    │   └── ui/             # Providers locales para estados efímeros (formularios, toasts, modales)
    ├── screens/            # Vistas modulares por contexto operativo
    │   ├── pos/            # Interfaz de venta rápida (cajeros)
    │   ├── production/     # Panel de preparación y asignación (pasteleros)
    │   ├── admin/          # Dashboard de gestión, reportes y configuración
    │   └── auth/           # Login, recuperación, registro de empleados
    ├── widgets/            # UI-Kit Atómico: componentes stateless, responsivos y accesibles
    ├── routes/             # Middlewares de navegación y redirecciones condicionales
    └── observers/          # Intercepción de navegación, logging de rendimiento y métricas UI
```

### 📌 Responsabilidades Clave por Capa
- **Core**: Centraliza la configuración transversal. `di/` registra los `ChangeNotifierProvider` globales al inicio de la aplicación. `routing/` define la navegación declarativa con `GoRouter`, inyectando guards que validan `authProvider` antes de acceder a rutas protegidas.
- **Domain**: Capa pura, independiente de Flutter y Firebase. Las `entities` incluyen `Value Objects` para garantizar la precisión de 3 decimales en gramajes y la inmutabilidad de precios. Los `usecases` contienen la lógica de negocio y retornan resultados tipados (`Either<Failure, Success>`).
- **Data**: Traduce el modelo relacional-noSQL de Firestore a objetos de dominio. Los `mappers` aplican reglas de redondeo y conversión segura. Los `repositories` orquestan llamadas remotas y locales, manejando reintentos y estados de conectividad.
- **Presentation**: Aquí reside Provider. Los `ChangeNotifiers` consumen `usecases` (inyectados desde Core) y exponen estados a la UI mediante `Consumer`, `Selector` o `context.watch`. Se evita la mutación directa del estado; cada acción dispara un método que actualiza el `ChangeNotifier` y notifica a los listeners correspondientes. Los `providers/ui` manezan estados locales de corta vida para no contaminar el árbol de notificaciones global.

---

## 🔷 B. ESTRATEGIA DE PERSISTENCIA Y LÓGICA DE DESCUENTO DE STOCK

### 🗃️ Jerarquía de Colecciones en Cloud Firestore
La estructura simula integridad referencial mediante `DocumentReference` y subcolecciones, optimizando lecturas y evitando redundancia:

- `employees`: `uid`, `role` (admin, pastry_chef, cashier), `status`, `assigned_branch`.
- `clients`: `contact_info`, `purchase_history_count`, `preferences`.
- `categories` → `products`: `name`, `base_price`, `is_available`, `production_type`, `categoryRef`.
- `suppliers` → `purchases`: `date`, `total_cost`, `status`, `items[]` (referencias a ingredientes adquiridos).
- `ingredients`: `current_stock`, `min_stock`, `unit`, `cost_per_unit`, `last_updated`.
- `ingredients_products`: Colección plana con `documentId` generado como `productId_ingredientId`. Campos: `quantity_required` (3 decimales), `preparation_steps`.
- `orders` (subcolección: `order_items`): 
  - `orders`: `type` (direct_sale / custom_order), `clientRef`, `cashierRef`, `status`, `total_amount`, `created_at`, `scheduled_date`.
  - `order_items`: `productRef`, `quantity`, `unit_price_snapshot` (inmutable), `discount`.
- `payments`: `orderId`, `method`, `amount`, `type` (advance/partial/full), `timestamp`, `pending_balance`.

### ⚙️ Lógica de Descuento Automático de Stock
Para garantizar consistencia en entornos concurrentes (múltiples cajeros/pedidos simultáneos), el descuento **no** se ejecuta en el cliente ni mediante actualizaciones simples. Se implementa un flujo transaccional orquestado por la arquitectura:

1. **Inicio desde UI**: Al confirmar/cerrar un pedido, el `salesProvider` invoca un `usecase` de cierre de transacción.
2. **Validación en Dominio**: El caso de uso lee los `order_items`, cruza cada producto con `ingredients_products`, y calcula la demanda total por ingrediente: `cantidad_pedido × gramaje_receta`.
3. **Ejecución Transaccional**: El repositorio de datos abre una `Firestore Transaction`. Dentro del bloque atómico:
   - Lee el stock actual de cada ingrediente requerido.
   - Valida `current_stock ≥ demanda_total`. Si falla, la transacción se revierte y se retorna un fallo tipado al `ChangeNotifier`.
   - Si es válido, actualiza `current_stock` restando la demanda con precisión de 3 decimales.
   - Evalúa si `new_stock ≤ min_stock`. De ser cierto, crea un documento en `alerts/` para el rol correspondiente.
4. **Consolidación de Pagos**: El documento `payments` se actualiza de forma independiente pero vinculada. El saldo pendiente se recalcula en el dominio y se sincroniza con el estado del `salesProvider`.
5. **Auditoría**: Cada movimiento genera un registro en `inventory_movements` con metadatos de trazabilidad (pedido, operador, delta, timestamp), garantizando reconciliación contable exacta.

Este enfoque mantiene la UI reactiva mediante `Provider`, delega la lógica pesada al dominio, y asegura la consistencia fuerte mediante transacciones atómicas de Firestore, evitando condiciones de carrera y desviaciones de inventario.

---

## 🔷 C. ROADMAP DE IMPLEMENTACIÓN (FASES CRÍTICAS)

### 🟢 Fase 1: Cimentación & Seguridad Operativa
- **Objetivo**: Establecer la infraestructura base, autenticación y gobernanza de acceso.
- **Acciones Clave**: Configuración de proyecto Firebase, integración de Auth con custom claims para mapeo de roles, redacción de Reglas de Seguridad Firestore granulares (RBAC a nivel de documento y campo), implementación del `core/` completo (GoRouter con guards, Design System, manejo de errores, registro de `ChangeNotifierProvider` globales), shell de aplicación con navegación declarativa validada por rol.
- **Hito Técnico**: Arquitectura funcional vacía donde la UI solo se renderiza si el `authProvider` retorna un rol válido. Acceso restringido a rutas y datos sensibles.

### 🟢 Fase 2: Inventario Maestro & Trazabilidad de Insumos
- **Objetivo**: Operativizar el control de materias primas con precisión industrial.
- **Acciones Clave**: CRUD completo de `ingredients` y `suppliers`, flujo de `purchases` para entradas de stock, implementación de `ChangeNotifier` de inventario con streams en tiempo real, validación estricta de precisión de 3 decimales en mapeadores, sistema de alertas automáticas por umbral mínimo, integración de repositorios y casos de uso de auditoría.
- **Hito Técnico**: Capacidad para registrar lotes, calcular costos de adquisición por unidad, y visualizar movimientos de stock con trazabilidad completa y tolerancia a desconexiones.

### 🟢 Fase 3: Ingeniería de Menú & Costeo de Producción
- **Objetivo**: Configurar el catálogo productivo y su vinculación con recetas.
- **Acciones Clave**: Gestión de `categories` y `products` con toggles de disponibilidad y tipo de producción, motor de vinculación `ingredients_products` con claves compuestas deterministas, cálculo automático de costo base por producto según ingredientes actuales, lógica de márgenes y precios de venta, UI administrativa para edición de recetas.
- **Hito Técnico**: El sistema determina el costo real de cada producto, bloquea o marca como "no disponible" automáticamente cuando un ingrediente está por debajo del umbral de receta, y sincroniza catálogos entre plataformas.

### 🟢 Fase 4: Operación de Ventas & Gestión Financiera
- **Objetivo**: Desplegar el ciclo transaccional completo y manejo de abonos.
- **Acciones Clave**: Motor de carrito con validación de stock en tiempo real, diferenciación de flujos `Venta Directa` vs `Encargo` (con priorización y fechas), captura de `unit_price_snapshot` inmutable en `order_items`, entidad `payments` desacoplada para gestionar anticipos, saldos y múltiples métodos de pago, `salesProvider` con manejo de estados complejos (cola de cocina, confirmación, entrega), notificaciones push para cambios de estado.
- **Hito Técnico**: Flujo POS completo para cajeros, historial transaccional auditado, gestión de pagos parciales con cálculo automático de saldos, y sincronización bidireccional con el panel de producción.

### 🟢 Fase 5: Optimización & UX Multiplataforma
- **Objetivo**: Pulir la experiencia, rendimiento y preparación para despliegue.
- **Acciones Clave**: Layouts adaptativos (DataGrids y paneles analíticos para Web Admin, tarjetas táctiles y flujos lineales para Mobile POS), estrategia de caché local para operaciones offline, deep linking para rastreo público de pedidos (solo estado, sin datos sensibles), profiling de rendimiento, optimización de builds por plataforma, pipeline CI/CD para Android, iOS y Web Firebase Hosting.
- **Hito Técnico**: Aplicación estable en producción, métricas de carga y render optimizadas, experiencia nativa en cada plataforma manteniendo una base de código unificada y gestión de estado predecible mediante Provider.

---

### 📌 CONCLUSIONES ARQUITECTÓNICAS

La adopción de **Provider + ChangeNotifier** en este blueprint no compromete la escalabilidad, siempre que se respete la separación de responsabilidades de Clean Architecture. Los `ChangeNotifiers` se limitan a exponer estados y orquestar la ejecución de `usecases`, mientras que el dominio conserva la pureza de la lógica de negocio y la capa de datos aísla la complejidad de Firestore. La navegación con **GoRouter** garantiza una estructura declarativa segura, ideal para Web y Deep Linking.

El modelo de base de datos prioriza la integridad transaccional sobre la simplicidad NoSQL, utilizando transacciones atómicas y claves compuestas simuladas para preservar la precisión de 3 decimales y la inmutabilidad de precios. La estrategia de fases permite una entrega incremental, validando cada módulo antes de escalar al siguiente, lo que reduce riesgos operativos y garantiza un producto alineado con los estándares de ingeniería de software empresarial.

---

### 🔴 PROMPT: ARQUITECTURA SENIOR CON PROVIDER - SISTEMA "PASTELERÍA PRO"

**Rol del Experto:**
Actúa como un **Principal Software Architect** especializado en el ecosistema **Flutter/Firebase**. Tu objetivo es diseñar un **Plan de Implementación Integral y la Arquitectura de Software** detallada para una solución multiplataforma (Android, iOS y Web) de gestión de pastelería profesional, utilizando **Provider** como gestor de estado principal.

**1. ESPECIFICACIONES DE NEGOCIO Y DATOS (Referencia GitHub):**
El sistema debe articular 11 entidades clave bajo una estructura NoSQL optimizada en Firestore:

* **Módulo Transaccional:** `CLIENTE`, `PEDIDO` (Flujos: Venta Directa vs. Por Encargo; Estados: Pendiente, Listo, Entregado), `DETALLE_PEDIDO` (Inmutabilidad de precios al vender) y `PAGO` (Entidad independiente para gestionar abonos, anticipos y múltiples métodos de pago).
* **Módulo de Catálogo:** `PRODUCTO` y `CATEGORIA`.
* **Módulo de Producción (Engine):** `INGREDIENTE` (Stock Mínimo y Alertas) e `INGREDIENTE_PRODUCTO` (Recetas con **Clave Primaria Compuesta** y precisión de **3 decimales** `DECIMAL(10,3)` para gramajes exactos).
* **Módulo Operativo:** `EMPLEADO` (Roles: Admin, Pastelero, Cajero), `PROVEEDOR` y `COMPRA` (Gestión de entradas y costos).

**2. REQUERIMIENTOS TÉCNICOS DE ARQUITECTURA:**

* **Arquitectura:** Implementación de **Clean Architecture** dividida en capas (*Data, Domain, Presentation & Core*) para asegurar que el código sea mantenible y escalable.
* **Gestión de Estado:** Uso exclusivo de **Provider + ChangeNotifier**. Se deben definir Providers globales para la lógica de negocio persistente (Auth, Cart, Inventory) y Providers locales para estados de UI complejos.
* **Navegación:** Implementación de **GoRouter** para garantizar rutas amigables en Web y navegación declarativa en dispositivos móviles.

**3. TAREAS DETALLADAS SOLICITADAS (Entregable Extenso sin Código):**

* **A. Blueprint de Administración de Carpetas:** Proporciona la organización jerárquica de la carpeta `lib/`, explicando la responsabilidad de cada subcarpeta y archivo clave:
* *Data Layer:* DTOs, Mappers (Conversión Firestore -> Entity), Repositorios y fuentes de datos.
* *Domain Layer:* Entidades puras, Interfaces de Repositorios (Contracts) y Casos de Uso (Usecases).
* *Presentation Layer:* Organización de **ChangeNotifiers (Providers)**, Screens modulares y un **UI-Kit Atómico** (Widgets reutilizables).
* *Core Layer:* Temas (Design System), Configuración de Rutas, Errores y Constantes globales.


* **B. Estrategia de Persistencia y Base de Datos:** Esquematiza la jerarquía de colecciones en Firestore. Define la lógica necesaria para que, al cerrar un pedido, el sistema consulte la receta y descuente automáticamente el stock de ingredientes.
* **C. Roadmap de Implementación (Fases Críticas):**
1. *Fase 1: Cimentación:* Setup de Firebase, Roles de Empleados y Reglas de Seguridad.
2. *Fase 2: Inventario Maestro:* CRUD de ingredientes con precisión milimétrica y flujo de proveedores.
3. *Fase 3: Ingeniería de Menú:* Definición de productos y sus recetas de producción vinculadas.
4. *Fase 4: Operación de Ventas:* Flujo de Carrito de compras, pedidos personalizados y gestión de abonos/pagos.
5. *Fase 5: UX Multiplataforma:* Adaptabilidad para Web (Panel Administrativo) y Mobile (Venta rápida).



**4. RESTRICCIONES DE SALIDA:**

* **NO generar código fuente (Dart/Java/SQL).**
* El lenguaje debe ser estrictamente profesional, técnico y fluido.
* La respuesta debe ser **extensa, detallada y organizada**, enfocándose en la administración de documentos y la jerarquía necesaria para un proyecto de nivel profesional.

---

**¿Por qué este prompt es el ideal?**

1. **Vuelve a Provider:** Pero le exige a la IA que lo use de forma ordenada (separando la lógica en la capa de Presentation).
2. **Detalle de GitHub:** Mantiene la precisión de 3 decimales y las claves compuestas, que son los detalles más importantes de tus documentos.
3. **Extenso:** Al pedir un "Blueprint de administración", la IA te dirá exactamente qué poner en cada carpeta del proyecto.

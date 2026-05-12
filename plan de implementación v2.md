Como **Principal Software Architect y Lead Developer**, presento a continuación el Blueprint Técnico de Arquitectura Empresarial para el sistema **“Pastelería Pro”**. Este documento ha sido estructurado bajo los estándares de ingeniería de software distribuida, priorizando la trazabilidad, la consistencia transaccional en entornos NoSQL, la escalabilidad multiplataforma y la estricta aplicación de Clean Architecture, con gestión de estado reactiva basada en **BLoC** y navegación declarativa mediante **GoRouter**.

---

## 🔷 A. ADMINISTRACIÓN Y JERARQUÍA DE DIRECTORIOS (`lib/`)

La estructura de carpetas sigue una segmentación estricta por capas, garantizando la independencia de frameworks, la testabilidad unitaria y la mantenibilidad a largo plazo. Cada capa posee responsabilidades bien delimitadas y flujos de dependencia unidireccionales (Domain ← Data, Domain ← Presentation, Core → All).

### 📁 `core/` (Capa Transversal y de Infraestructura Base)
* **`config/`**: Inicialización de Firebase, variables de entorno compiladas por plataforma y configuración de inyección de dependencias.
* **`routing/`**: Definición declarativa de rutas con **GoRouter**. Incluye guards de autenticación y autorización por roles, deep linking para rastreo de pedidos en Web, y manejo de redirecciones condicionales según el estado de la sesión.
* **`design_system/`**: Tema global unificado (colores, tipografía, espaciado, curvas de animación). Garantiza coherencia visual entre Android, iOS y Web sin duplicación de estilos.
* **`errors/`**: Jerarquía de fallos tipados (`Failure`, `NetworkFailure`, `ValidationFailure`, `FirestoreFailure`). Centraliza el manejo de excepciones y su traducción a estados UI amigables.
* **`utils/`**: Formateadores de moneda, validadores de entrada, parsers de fechas, y algoritmos de precisión numérica para evitar derivas de punto flotante.

### 📁 `domain/` (Capa de Negocio Pura)
* **`entities/`**: Clases Dart puras sin dependencias externas. Representan el modelo inmutable de cada una de las 11 entidades del dominio. Incluyen value objects como `Quantity` (precisión de 3 decimales) y `MonetaryValue` (inmutabilidad de precios).
* **`contracts/`**: Interfaces abstractas de los repositorios. Definen el contrato de interacción con la capa de datos (ej. `IOrderRepository`, `IInventoryRepository`), permitiendo la sustitución de fuentes sin afectar el dominio.
* **`usecases/`**: Casos de uso atómicos y específicos por módulo. Ejemplos: `CreateDirectSaleUseCase`, `ProcessEncargoOrderUseCase`, `DeductIngredientStockUseCase`, `CalculateRecipeCostUseCase`. Cada caso encapsula una regla de negocio, valida insumos y retorna resultados tipados (`Either<Failure, Success>`).
* **`validators/`**: Lógica de validación transversal para reglas de negocio críticas (ej. stock mínimo, disponibilidad de producto, límites de abono).

### 📁 `data/` (Capa de Persistencia y Comunicación)
* **`dtos/`**: Objetos de Transferencia de Datos que reflejan la estructura exacta de los documentos Firestore. Actúan como capa de serialización/deserialización.
* **`mappers/`**: Traductores bidireccionales (`DTO ↔ Entity`). Aíslan la capa de dominio de cualquier cambio en el esquema de la base de datos. Incluyen lógica de conversión de tipos numéricos para preservar la precisión de 3 decimales.
* **`repositories/`**: Implementaciones concretas de los contratos definidos en Domain. Orquestan llamadas a fuentes de datos, manejan reintentos, y aplican caché local cuando corresponde.
* **`datasources/`**: 
  * `remote/`: Interacciones directas con Firestore (colecciones, subcolecciones, transactions, batch writes).
  * `local/`: Persistencia ligera para estados offline (cola de pedidos pendientes, sincronización diferida).
* **`models/`**: Estructuras auxiliares para payloads de Cloud Functions y respuestas de auditoría.

### 📁 `presentation/` (Capa de Interfaz y Gestión de Estado)
* **`state/`**: Módulos **BLoC/Cubit** organizados por funcionalidad (ej. `AuthBloc`, `OrderManagementBloc`, `InventoryStreamBloc`, `PaymentFlowBloc`). Utilizan el patrón Event-State para manejar flujos asíncronos complejos, streams en tiempo real de Firestore y transacciones de inventario. **Provider está estrictamente excluido** para garantizar testabilidad, trazabilidad de eventos y manejo determinista de errores.
* **`screens/`**: Vistas modulares separadas por contexto de uso: `POS/` (punto de venta móvil), `AdminDashboard/` (panel Web), `KitchenDisplay/` (producción/pastelería), `Settings/`.
* **`widgets/` (UI-Kit Atómico)**: Componentes reutilizables y stateless (`Button`, `InputField`, `StatusBadge`, `QuantityPicker`, `OrderCard`, `DataGrid`). Diseñados para escalar responsivamente entre layouts de pantalla pequeña (móvil) y paneles amplios (Web).
* **`observers/`**: Intercepción de navegación, logging de transacciones UI y monitoreo de rendimiento de renderizado.

---

## 🔷 B. ESTRATEGIA DE BASE DE DATOS Y LÓGICA DE NEGOCIO EN FIRESTORE

Firestore es una base de datos NoSQL orientada a documentos, por lo que la integridad referencial se modela mediante **DocumentReferences**, índices compuestos y lógica server-authoritative, evitando duplicación de datos y garantizando consistencia eventual controlada.

### 🗃️ Jerarquía de Colecciones y Relaciones
* `employees`: Documento con `uid`, `role` (admin, pastry_chef, cashier), `status`. Los custom claims en Firebase Auth sincronizan con este documento para RBAC.
* `clients`: Historial de compras, preferencias, trazabilidad de direcciones y contactos.
* `categories` → `products`: `products` referencia `categoryId`. Incluye `is_available`, `base_price`, `preparation_type` (directo/encargo).
* `suppliers` → `purchases`: `purchases` agrupa órdenes de entrada, con `supplierRef`, `total_cost`, `timestamp`, y lista de ítems.
* `ingredients`: Controla `current_stock`, `min_stock`, `unit_of_measure`, `cost_per_unit`. Los valores de stock se almacenan como números nativos, pero se validan y redondean a 3 decimales en la capa de dominio antes de la escritura.
* `ingredients_products`: Colección independiente para mapear recetas. El `documentId` se genera de forma determinista concatenando `productId_ingredientId` para simular una **clave primaria compuesta**. Contiene `quantity_required` (3 decimales) y `preparation_notes`.
* `orders`: Documento maestro con `type` (direct_sale / custom_order), `clientRef`, `cashierRef`, `pastry_chefRef` (asignado durante producción), `status` (pending, in_progress, ready, delivered), `total_amount`, `created_at`.
* `order_items`: Subcolección bajo cada `order`. Registra `productRef`, `quantity`, `unit_price_snapshot` (inmutable, capturado al momento de la creación), `discount_applied`. Garantiza trazabilidad histórica aunque el catálogo cambie.
* `payments`: Colección paralela vinculada por `orderId`. Registra múltiples transacciones (`amount`, `method`, `timestamp`, `type` (advance, installment, full)), calculando automáticamente `pending_balance`.

### ⚙️ Lógica de Descuento de Stock y Precisión Numérica
La deducción de inventario **nunca** debe ejecutarse desde el cliente para evitar condiciones de carrera en terminales simultáneas. Se implementa mediante **Cloud Functions con Firestore Transactions**:

1. **Trigger**: La función se activa cuando un documento en `orders` cambia su estado a `ready` o `delivered`, o cuando un pago alcanza el `100%` del total.
2. **Validación Inicial**: La función lee `order_items`, itera cada referencia a `ingredients_products`, y calcula la demanda total: `cantidad_pedido × cantidad_receta`.
3. **Transacción Atómica**: Dentro de un `runTransaction`, se leen los documentos `ingredients` actuales. Se verifica que `current_stock ≥ demanda`. Si no es suficiente, la función revierte la transacción y devuelve un `Failure` registrado en `order_audit`.
4. **Descuento y Alerta**: Si el stock es suficiente, se actualiza `current_stock` restando la demanda con precisión de 3 decimales. Posteriormente, se evalúa si `new_stock ≤ min_stock`. De ser así, se crea un documento en `alerts/` para notificar al rol de Administrador/Pastelero.
5. **Inmutabilidad y Auditoría**: Cada movimiento genera un registro en `inventory_movements` con `orderId`, `ingredientId`, `delta`, `operator`, y `timestamp`, permitiendo reconciliación contable y trazabilidad completa.

Esta estrategia garantiza consistencia fuerte en entornos distribuidos, respeta la arquitectura reactiva sin bloquear la UI, y mantiene la precisión numérica exigida para el costeo industrial de pastelería.

---

## 🔷 C. ROADMAP DE IMPLEMENTACIÓN (FASES CRÍTICAS)

### 🟢 Fase 1: Cimentación & Security
* **Objetivo**: Establecer la base segura y escalable del sistema.
* **Entregables**: Proyecto Firebase configurado, Auth con roles mediante custom claims, Reglas de Seguridad Firestore granulares (lectura/escritura por rol y documento), Core layer completo (GoRouter con guards, Design System, Error Handling), shell de la aplicación con navegación declarativa.
* **Hito Técnico**: Despliegue de una arquitectura vacía donde la capa de presentación solo puede acceder a datos autenticados y autorizados. Validación de flujos de acceso por rol (Cajero → POS, Pastelero → Producción, Admin → Dashboard completo).

### 🟢 Fase 2: Gestión de Insumos
* **Objetivo**: Operativizar el inventario con precisión industrial.
* **Entregables**: CRUD completo de `ingredients` y `suppliers`, flujo de `purchases` para entradas de stock, validación de precisión de 3 decimales en toda la cadena, sistema de alertas por stock mínimo, integración de mapeadores y repositorios en Data layer, BLoC de inventario con streams en tiempo real.
* **Hito Técnico**: Capacidad para registrar lotes, calcular costos unitarios de adquisición y generar reportes de consumo. Implementación de transacciones atómicas para ajustes manuales de inventario.

### 🟢 Fase 3: Ingeniería de Menú
* **Objetivo**: Configurar el catálogo productivo con costeo exacto.
* **Entregables**: Gestión de `categories` y `products` con toggles de disponibilidad, motor de vinculación de recetas (`ingredients_products`), cálculo automático de costo de producción basado en ingredientes actuales, lógica de precios de venta con márgenes configurables, UI de administración de catálogo.
* **Hito Técnico**: El sistema puede determinar el costo real de un producto, alertar si un ingrediente está agotado para producción, y bloquear la venta o marcar disponibilidad según el stock de recetas.

### 🟢 Fase 4: Operación de Ventas
* **Objetivo**: Desplegar el ciclo transaccional completo y gestión financiera.
* **Entregables**: Motor de carrito con validación de stock en tiempo real, diferenciación de flujos `Venta Directa` vs `Encargo` (con campos de fecha, observaciones y prioridad), captura de precios inmutables en `order_items`, gestión independiente de `payments` (abonos, saldos, métodos de pago), BLoC de ventas con manejo de colas y estados, notificaciones de cambio de estado.
* **Hito Técnico**: Flujo POS completo para cajeros, con historial de pedidos, control de abonos pendientes, y actualización automática del backlog de cocina cuando un encargo es confirmado.

### 🟢 Fase 5: Optimización & UX Multiplataforma
* **Objetivo**: Pulir la experiencia, rendimiento y despliegue final.
* **Entregables**: Layouts adaptativos (grids y tablas para Web Admin, listas y tarjetas táctiles para Mobile), estrategia de caché local para tolerancia a desconexiones temporales, deep linking para rastreo público de pedidos (solo estado, sin datos sensibles), profiling de rendimiento y reducción de builds, pipeline CI/CD para Android, iOS y Web.
* **Hito Técnico**: Aplicación lista para producción con métricas de estabilidad, sincronización confiable en entornos de baja conectividad, y experiencia unificada que respeta las convenciones nativas de cada plataforma.

---

### 📌 CONCLUSIONES ARQUITECTÓNICAS

Este blueprint elimina la dependencia de patrones simples de gestión de estado, adoptando **BLoC** como estándar empresarial para orquestar flujos asíncronos complejos, validar invariantes de negocio y mantener un historial de eventos reproducible. La arquitectura en capas garantiza que la lógica de dominio permanezca aislada de Firebase, permitiendo migraciones futuras sin impacto en la UI. La estrategia de **Cloud Functions + Firestore Transactions** resuelve las limitaciones inherentes de las bases de datos documentales en escenarios de inventario concurrente, asegurando precisión de 3 decimales, inmutabilidad de precios y auditoría completa.

El sistema resultante es escalable, auditado por diseño, y preparado para operar en entornos reales de producción multiplataforma con estándares de ingeniería de software de nivel enterprise.

## promt
### 🔴 PROMPT: BLUEPRINT TÉCNICO DE ARQUITECTURA EMPRESARIAL - SISTEMA "PASTELERÍA "

**Rol del Experto:**
Actúa como un **Principal Software Architect y Lead Developer** con más de 10 años de experiencia en sistemas ERP distribuidos y experto en el ecosistema **Flutter/Firebase**. Tu objetivo es diseñar un **Plan de Implementación Integral y la Arquitectura de Software** para una solución multiplataforma (Android, iOS y Web) de gestión de pastelería profesional.

**1. REQUISITOS TÉCNICOS Y LÓGICA DE NEGOCIO (Basado en Especificaciones de GitHub):**
El sistema debe articular 11 entidades clave bajo el paradigma de integridad referencial, adaptado a la naturaleza NoSQL de Firestore:

* **Módulo Transaccional:** `CLIENTE` (Perfil y trazabilidad), `PEDIDO` (Gestión de flujos: Venta Directa en tienda vs. Pedidos por Encargo; Estados: Pendiente, Listo, Entregado), `DETALLE_PEDIDO` (Inmutabilidad de precios al momento de la venta) y `PAGO` (Entidad independiente vinculada al pedido para gestionar abonos, anticipos y saldos pendientes).
* **Módulo de Catálogo:** `PRODUCTO` (Con atributos de disponibilidad) y `CATEGORIA`.
* **Módulo de Producción (Engine):** `INGREDIENTE` (Gestión de Stock Mínimo y Alertas de reabastecimiento) e `INGREDIENTE_PRODUCTO` (Modelado de recetas con **Clave Primaria Compuesta** y precisión de **3 decimales** `DECIMAL(10,3)` para un costeo exacto de insumos).
* **Módulo Operativo:** `EMPLEADO` (Roles: Administrador, Pastelero, Cajero; Control de responsabilidades por pedido), `PROVEEDOR` y `COMPRA` (Gestión de entradas de inventario y trazabilidad de costos de adquisición).

**2. REQUERIMIENTOS DE ARQUITECTURA Y ESTADO (High-End):**

* **Arquitectura de Software:** Implementación estricta de **Clean Architecture** (Capas: *Data, Domain, Presentation & Core*) para garantizar el desacoplamiento total.
* **Gestión de Estado:** **PROHIBIDO EL USO DE PROVIDER.** Se requiere una arquitectura reactiva basada en **BloC (Business Logic Component)** o **Riverpod (AsyncNotifier)** para manejar flujos de datos asíncronos y estados complejos de inventario en tiempo real.
* **Navegación:** Implementación de **GoRouter** para soportar navegación declarativa, Deep Linking y manejo de URLs amigables en la versión Web.

**3. TAREAS DETALLADAS SOLICITADAS (Entregable Extenso sin Código):**

* **A. Administración y Jerarquía de Carpetas:** Proporciona un diagrama detallado de la estructura de `lib/`, explicando la responsabilidad de cada subcarpeta:
* *Data Layer:* DTOs (Data Transfer Objects), Mappers (Conversión de Firebase a Entidades), Repositorios e Implementaciones.
* *Domain Layer:* Entidades puras (Plain Dart Classes), Interfaces de Repositorios (Contracts) y Casos de Uso (Usecases específicos para ventas y stock).
* *Presentation Layer:* Blocs/State Managers, Screens modulares y un **UI-Kit Atómico** (Widgets reutilizables).
* *Core Layer:* Temas globales (Design System), Configuración de Rutas, Gestión de Errores y Utilidades.


* **B. Estrategia de Base de Datos (Cloud Firestore):** Esquematiza la jerarquía de colecciones y subcolecciones. Define la lógica de **Cloud Functions o Lógica de Negocio** necesaria para que, al procesar un pedido, se descuente automáticamente el stock de ingredientes basándose en la relación `INGREDIENTE_PRODUCTO`.
* **C. Roadmap de Implementación (Fases Críticas):**
1. *Fase 1: Cimentación & Security:* Roles de Empleados, Reglas de Seguridad de Firestore (RBAC) y Auth.
2. *Fase 2: Gestión de Insumos:* CRUD de ingredientes con precisión milimétrica y flujo de Compras a Proveedores.
3. *Fase 3: Ingeniería de Menú:* Configuración de Productos y vinculación de Recetas de producción.
4. *Fase 4: Operación de Ventas:* Flujo de Carrito, Pedidos personalizados, Gestión de Abonos y estados del Pedido.
5. *Fase 5: Optimización & UX Multiplataforma:* Layouts adaptativos para Web (Admin) y Mobile (Ventas), y manejo de caché local.



**4. RESTRICCIONES DE SALIDA:**

* **NO generar código fuente (Dart/Java/SQL).**
* El lenguaje debe ser estrictamente profesional, técnico y fluido.
* La respuesta debe ser **extensa, detallada y organizada**, cubriendo la administración de todos los documentos y carpetas necesarios para un proyecto de nivel senior.

---

**¿Por qué este es el prompt que necesitas?**

1. **Nivel Senior:** Al pedir "Blueprint de directorios", "Mappers" y "Clean Architecture", la IA entiende que el proyecto debe ser escalable.
2. **Precisión en el Inventario:** Se enfatiza la precisión de 3 decimales para los ingredientes, evitando pérdidas de dinero por mal redondeo.
3. **Flujo Operativo:** Incluye la lógica de "Venta Directa vs Encargo", que es la base de una pastelería real.
4. **Sin Provider:** Aseguras que la gestión de estado sea la que se usa en empresas de alto nivel (BloC).

# 📋 Plan de Implementación: Aplicación Multiplataforma "Pastelería"

> 🎯 **Objetivo:** Desarrollar una aplicación Flutter/Dart con Firebase (Auth + Firestore), gestión de estado con Provider, enfoque UI/UX profesional y compatibilidad multiplataforma (iOS, Android, Web).  
> 📝 **Formato:** Procedimiento paso a paso. **Sin código.**

---

## 🛠️ 1. Configuración del Entorno y Herramientas
| Categoría | Herramienta / Requisito |
|-----------|------------------------|
| **SDK & Lenguaje** | Flutter SDK (≥3.19), Dart (≥3.3) |
| **IDE Principal** | Visual Studio Code (extensiones: Flutter, Dart, Error Lens, Pubspec Assist) |
| **IDE Alternativo** | Android Studio (solo para emuladores, gestión de SDK y builds nativos) |
| **Control de Versiones** | Git + GitHub/GitLab |
| **CLI & Empaquetado** | Firebase CLI, `flutter doctor`, `flutterfire` |
| **Diseño UI/UX** | Figma / Adobe XD / Penpot (wireframes, prototipos, design system) |
| **Gestión de Assets** | Ilustrator/Photoshop/Figma para iconos, splash, imágenes de productos |
| **Pruebas Multiplataforma** | Emuladores Android/iOS, Chrome/Edge (Web), dispositivos físicos |

---

## 🎨 2. Flujo de Diseño UI/UX (Antes de Programar)
1. **Investigación y Definición**
   - Mapeo de usuarios: Cliente, Administrador/Pastelero
   - Definición de flujos: Registro → Exploración → Carrito → Pedido → Historial
   - Requisitos de accesibilidad (contrastes, tamaños de fuente, navegación por teclado)

2. **Arquitectura de Información**
   - Diagrama de pantallas: Login, Registro, Home, Catálogo, Detalle Producto, Carrito, Checkout, Perfil, Panel Admin (opcional v1)
   - Definición de rutas y estados vacíos/carga/error

3. **Design System**
   - Paleta cromática (ej. tonos pastel, acentos cálidos)
   - Tipografía (Google Fonts: Inter, Playfair Display, etc.)
   - Componentes reutilizables: Botones, Cards, Inputs, Banners, Bottom Navigation, Snackbars
   - Guidelines despacing y jerarquía visual

4. **Prototipado y Validación**
   - Wireframes de baja fidelidad → Prototipo interactivo en Figma
   - Pruebas de usabilidad con 3-5 usuarios objetivo
   - Iteración y aprobación final antes de desarrollo

---

## 📦 3. Arquitectura y Dependencias (`pubspec.yaml`)
### 🏗️ Patrón Arquitectónico Recomendado
- **Capas:** `presentation` (UI + Provider) → `domain` (modelos + casos de uso) → `data` (repositorios + Firebase) → `core` (constantes, temas, routers, utilidades)
- **Gestión de Estado:** `Provider` + `ChangeNotifier` para flujos globales (auth, carrito, productos, perfil)
- **Navegación:** `go_router` o `auto_route` (declarativo, soporta Web/Mobile)
- **Persistencia Local (opcional):** `shared_preferences` o `flutter_secure_storage` para tokens/flags de sesión

### 📦 Dependencias Principales (Conceptuales)
| Categoría | Paquetes Requeridos |
|-----------|---------------------|
| **Firebase** | `firebase_core`, `firebase_auth`, `cloud_firestore` |
| **Estado** | `provider`, `flutter_hooks` (opcional) |
| **Navegación** | `go_router` |
| **Red & Cache** | `cached_network_image`, `http` (si se requiere API externa) |
| **UI/Utilidades** | `intl`, `flutter_svg`, `google_fonts`, `shimmer` (loaders), `uuid` |
| **Seguridad & Config** | `flutter_dotenv`, `flutter_secure_storage` |
| **Pruebas** | `mockito`, `bloc_test` o `provider_test` |

> ✅ Se recomienda mantener las versiones estables y ejecutar `flutter pub upgrade` antes de iniciar desarrollo activo.

---

## 🔥 4. Configuración de Firebase (Pre-código)
1. **Crear Proyecto en Firebase Console**
   - Nombre: `pasteleria-app`
   - Habilitar Google Analytics (opcional)
   - Registrar apps: Android, iOS, Web

2. **Autenticación**
   - Activar método **Correo electrónico / Contraseña**
   - Configurar verificación de email (opcional)
   - Definir políticas de seguridad: longitud mínima, reintentos, bloqueo por fuerza bruta

3. **Firestore Database**
   - Crear en modo `locked` inicialmente
   - Diseñar estructura de colecciones:
     - `users/{uid}`: perfil, rol, historial
     - `products`: catálogo, categorías, stock, imágenes, precios
     - `orders`: estado, cliente, items, total, timestamps
     - `categories`: metadatos para filtrado
   - Definir reglas de seguridad por colección y rol antes de abrir acceso

4. **Integración en Flutter**
   - Ejecutar `flutterfire configure` (genera `firebase_options.dart`)
   - Descargar y ubicar `google-services.json` y `GoogleService-Info.plist`
   - Validar conexión con `flutter run` en emulador/dispositivo

---

## 🗺️ 5. Plan de Implementación Paso a Paso

### 🔹 Fase 1: Preparación y Arquitectura Base
- [ ] Inicializar proyecto Flutter (`flutter create pasteleria`)
- [ ] Configurar `pubspec.yaml` con dependencias listadas
- [ ] Estructurar directorios según arquitectura por capas
- [ ] Configurar `go_router` con rutas base y placeholders
- [ ] Implementar tema global (colores, tipografía, dark/light mode)
- [ ] Configurar `.env` o `flutter_dotenv` para variables sensibles
- [ ] Validar build en Android, iOS y Web

### 🔹 Fase 2: UI Estática y Componentes Reutilizables
- [ ] Traducir prototipos Figma a widgets Flutter
- [ ] Crear librería de componentes: `CustomButton`, `ProductCard`, `InputField`, `AppBar`, `BottomNav`
- [ ] Implementar pantallas estáticas: Home, Catálogo, Detalle, Carrito, Perfil, Login/Registro
- [ ] Añadir estados de carga, error y vacío con `Shimmer`/placeholders
- [ ] Validar responsividad y adaptabilidad a tablets/Web

### 🔹 Fase 3: Autenticación y Flujo de Sesión
- [ ] Implementar `AuthProvider` con `ChangeNotifier`
- [ ] Conectar formulario de Login/Registro a `FirebaseAuth`
- [ ] Manejar estados: cargando, éxito, error (email no verificado, contraseña inválida)
- [ ] Persistir sesión y redirigir automáticamente según estado auth
- [ ] Implementar Logout y limpieza de estado
- [ ] Validar recuperación de contraseña (reset email flow)

### 🔹 Fase 4: Integración con Firestore y Gestión de Datos
- [ ] Crear repositorios `ProductRepository`, `UserRepository`, `OrderRepository`
- [ ] Implementar streams y futures para lectura de productos/categorías
- [ ] Diseñar modelo de datos (`Product`, `OrderItem`, `User`) con serialización
- [ ] Conectar UI a `Firestore` vía Provider (evitar llamadas directas en widgets)
- [ ] Implementar paginación o lazy loading para catálogo
- [ ] Añadir caché local con `cached_network_image` para optimización

### 🔹 Fase 5: Lógica de Negocio y Estado Global
- [ ] Implementar `CartProvider`: agregar, eliminar, actualizar cantidades, calcular total
- [ ] Validar stock antes de checkout
- [ ] Crear flujo de orden: confirmar → guardar en Firestore → cambiar estado → notificar UI
- [ ] Historial de pedidos y detalle por usuario
- [ ] Validar permisos: cliente vs administrador (rol en Firestore)

### 🔹 Fase 6: Optimización, Multiplataforma y UX
- [ ] Ajustar assets para diferentes densidades (`1x`, `2x`, `3x`)
- [ ] Validar navegación en Web (URLs, back button, resize)
- [ ] Optimizar rendimiento: evitar rebuilds innecesarios, usar `const`, `Provider.of(context, listen: false)`
- [ ] Implementar manejo global de errores y logs
- [ ] Añadir accesibilidad: semántica, contraste, tamaños dinámicos

### 🔹 Fase 7: Pruebas, Seguridad y Preparación para Despliegue
- [ ] Pruebas unitarias: proveedores, repositorios, validaciones
- [ ] Pruebas de widget: pantallas críticas, estados de error/carga
- [ ] Revisión de reglas de Firestore (principio de mínimo privilegio)
- [ ] Validar autenticación contra ataques comunes
- [ ] Ejecutar `flutter analyze` + `flutter test` + `dart fix`
- [ ] Generar builds de prueba: `flutter build apk`, `flutter build ios`, `flutter build web`
- [ ] Documentar arquitectura, flujo de datos y credenciales (en `.gitignore`)

---

## 🧪 6. Criterios de Calidad y Validación
| Área | Criterio |
|------|----------|
| **Funcional** | Auth funciona en los 3 entornos, Firestore responde en <2s, carrito persiste en sesión |
| **UI/UX** | Consistencia visual, transiciones suaves, feedback inmediato en acciones |
| **Seguridad** | Reglas Firestore bloquean acceso no autorizado, contraseñas no se almacenan localmente |
| **Rendimiento** | <60 FPS en scroll de catálogo, memoria estable, sin memory leaks detectados |
| **Multiplataforma** | Comportamiento idéntico o adaptado en Android, iOS, Web (responsive) |

---

## 📌 Notas Importantes para el Desarrollo
1. **No hardcodear credenciales ni URLs de Firebase.** Usa `flutterfire` y `.env` para configuración.
2. **Provider debe ser el único puente entre UI y datos.** Evita llamar a Firebase directamente desde widgets.
3. **Firestore se cobra por lecturas/escrituras.** Diseña consultas precisas, evita `where().get()` masivos, usa `limit()` y paginación.
4. **Mantén la UI desacoplada.** Los `ChangeNotifier` solo exponen estado y métodos, no lógica de renderizado.
5. **Versionado:** Usa ramas por fase (`feat/auth`, `feat/catalog`, `feat/cart`) y PRs con checklist de revisión.

---

✅ **Siguiente paso:** Una vez aprobado este plan, se puede proceder a la generación de código estructurado por fases (empezando por arquitectura + auth + provider). ¿Deseas que profundice en el diagrama de colecciones de Firestore o en el flujo de estados del `CartProvider` antes de pasar a la implementación?

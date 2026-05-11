<img width="1440" height="882" alt="image" src="https://github.com/user-attachments/assets/32c56e11-bb6b-4a59-8e21-9e93208c6120" />

Como DBA del sistema de pastelería, estas son las **10 entidades** esenciales y su justificación:

**Núcleo comercial**
- `CLIENTE` — registra quién compra, historial de pedidos, datos de contacto para seguimiento.
- `PEDIDO` — corazón del sistema; captura fecha, tipo (en tienda vs. por encargo), estado (pendiente, listo, entregado) y empleado responsable.
- `DETALLE_PEDIDO` — tabla pivote que descompone cada pedido en productos individuales con cantidad y precio al momento de la venta.
- `PAGO` — separada del pedido para soportar pagos parciales, anticipos en pedidos por encargo, o diferentes métodos de pago.

**Catálogo**
- `PRODUCTO` — pasteles, panes, bebidas, etc., con precio y disponibilidad.
- `CATEGORIA` — agrupa por tipo (pasteles, galletas, pan dulce) para filtros y reportes de ventas.

**Inventario y producción**
- `INGREDIENTE` — harina, azúcar, mantequilla, etc., con stock actual y mínimo para alertas de reabastecimiento.
- `INGREDIENTE_PRODUCTO` — receta: cuánto de cada ingrediente usa cada producto; permite calcular costos y proyectar producción.

**Operación interna**
- `EMPLEADO` — quién tomó el pedido, quién lo preparó; útil para control de turnos y comisiones.
- `PROVEEDOR` / `COMPRA` — gestión de entradas al inventario, trazabilidad de costos y relación con proveedores.

Con este modelo puedes manejar ventas diarias, pedidos personalizados, control de inventario y análisis de rentabilidad por producto.


<img width="1440" height="6236" alt="image" src="https://github.com/user-attachments/assets/8dd16ec7-98c1-41c3-8787-e60d2bf233d4" />


Ahí tienes las 11 entidades completas con todos sus atributos, tipos de dato, claves y restricción de nulo. Algunos puntos de diseño a destacar:

`INGREDIENTE_PRODUCTO` usa clave primaria compuesta (PK + FK en ambos campos), lo que evita duplicar la misma receta.

Los campos `ENUM` como `estado`, `tipo`, `metodo` y `rol` restringen los valores permitidos directamente en el motor, evitando datos inconsistentes sin necesidad de tablas adicionales de catálogo.

`DECIMAL(10,2)` para precios y `DECIMAL(10,3)` para cantidades de ingredientes — la tercera cifra decimal es importante en recetas (ej. 0.750 kg de harina).


¿Quieres que genere el script SQL `CREATE TABLE` para alguna o todas las entidades?
<img width="1440" height="6236" alt="image" src="https://github.com/user-attachments/assets/8dd16ec7-98c1-41c3-8787-e60d2bf233d4" />





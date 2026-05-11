-- ============================================================
--  BASE DE DATOS: bdpasteleria
--  Sistema de gestión para pastelería
--  Generado por: Administrador de Base de Datos
-- ============================================================

CREATE DATABASE IF NOT EXISTS bdpasteleria
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE bdpasteleria;

-- ============================================================
--  1. CATEGORIA
-- ============================================================
CREATE TABLE categoria (
  id_categoria   INT            NOT NULL AUTO_INCREMENT,
  nombre         VARCHAR(60)    NOT NULL,
  descripcion    TEXT,
  CONSTRAINT pk_categoria PRIMARY KEY (id_categoria)
) ENGINE=InnoDB;

-- ============================================================
--  2. CLIENTE
-- ============================================================
CREATE TABLE cliente (
  id_cliente      INT            NOT NULL AUTO_INCREMENT,
  nombre          VARCHAR(100)   NOT NULL,
  telefono        VARCHAR(20),
  email           VARCHAR(120),
  direccion       TEXT,
  fecha_registro  DATE           NOT NULL DEFAULT (CURRENT_DATE),
  CONSTRAINT pk_cliente PRIMARY KEY (id_cliente)
) ENGINE=InnoDB;

-- ============================================================
--  3. EMPLEADO
-- ============================================================
CREATE TABLE empleado (
  id_empleado    INT            NOT NULL AUTO_INCREMENT,
  nombre         VARCHAR(100)   NOT NULL,
  rol            ENUM('cajero','pastelero','repartidor','admin') NOT NULL,
  telefono       VARCHAR(20),
  fecha_ingreso  DATE           NOT NULL,
  activo         BOOLEAN        NOT NULL DEFAULT TRUE,
  CONSTRAINT pk_empleado PRIMARY KEY (id_empleado)
) ENGINE=InnoDB;

-- ============================================================
--  4. PRODUCTO
-- ============================================================
CREATE TABLE producto (
  id_producto   INT             NOT NULL AUTO_INCREMENT,
  id_categoria  INT             NOT NULL,
  nombre        VARCHAR(100)    NOT NULL,
  descripcion   TEXT,
  precio        DECIMAL(10,2)   NOT NULL,
  disponible    BOOLEAN         NOT NULL DEFAULT TRUE,
  imagen_url    VARCHAR(255),
  CONSTRAINT pk_producto     PRIMARY KEY (id_producto),
  CONSTRAINT fk_prod_cat     FOREIGN KEY (id_categoria)
    REFERENCES categoria (id_categoria)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
--  5. INGREDIENTE
-- ============================================================
CREATE TABLE ingrediente (
  id_ingrediente  INT             NOT NULL AUTO_INCREMENT,
  nombre          VARCHAR(100)    NOT NULL,
  unidad          VARCHAR(20)     NOT NULL COMMENT 'kg, lt, pz, g',
  stock_actual    DECIMAL(10,3)   NOT NULL DEFAULT 0,
  stock_minimo    DECIMAL(10,3)   NOT NULL DEFAULT 0,
  costo_unitario  DECIMAL(10,2),
  CONSTRAINT pk_ingrediente PRIMARY KEY (id_ingrediente)
) ENGINE=InnoDB;

-- ============================================================
--  6. INGREDIENTE_PRODUCTO  (tabla de receta)
-- ============================================================
CREATE TABLE ingrediente_producto (
  id_ingrediente  INT            NOT NULL,
  id_producto     INT            NOT NULL,
  cantidad_usada  DECIMAL(10,3)  NOT NULL COMMENT 'Cantidad del ingrediente por unidad de producto',
  CONSTRAINT pk_ing_prod   PRIMARY KEY (id_ingrediente, id_producto),
  CONSTRAINT fk_ip_ing     FOREIGN KEY (id_ingrediente)
    REFERENCES ingrediente (id_ingrediente)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_ip_prod    FOREIGN KEY (id_producto)
    REFERENCES producto (id_producto)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
--  7. PEDIDO
-- ============================================================
CREATE TABLE pedido (
  id_pedido      INT         NOT NULL AUTO_INCREMENT,
  id_cliente     INT         NOT NULL,
  id_empleado    INT,
  fecha_pedido   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_entrega  DATE,
  estado         ENUM('pendiente','en proceso','listo','entregado','cancelado') NOT NULL DEFAULT 'pendiente',
  tipo           ENUM('en tienda','por encargo','delivery') NOT NULL,
  observaciones  TEXT,
  CONSTRAINT pk_pedido       PRIMARY KEY (id_pedido),
  CONSTRAINT fk_ped_cli      FOREIGN KEY (id_cliente)
    REFERENCES cliente (id_cliente)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_ped_emp      FOREIGN KEY (id_empleado)
    REFERENCES empleado (id_empleado)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
--  8. DETALLE_PEDIDO
-- ============================================================
CREATE TABLE detalle_pedido (
  id_detalle      INT            NOT NULL AUTO_INCREMENT,
  id_pedido       INT            NOT NULL,
  id_producto     INT            NOT NULL,
  cantidad        INT            NOT NULL,
  precio_unitario DECIMAL(10,2)  NOT NULL COMMENT 'Precio al momento de la venta',
  descuento       DECIMAL(5,2)   DEFAULT 0 COMMENT 'Porcentaje de descuento',
  CONSTRAINT pk_detalle      PRIMARY KEY (id_detalle),
  CONSTRAINT fk_det_ped      FOREIGN KEY (id_pedido)
    REFERENCES pedido (id_pedido)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT fk_det_prod     FOREIGN KEY (id_producto)
    REFERENCES producto (id_producto)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
--  9. PAGO
-- ============================================================
CREATE TABLE pago (
  id_pago     INT            NOT NULL AUTO_INCREMENT,
  id_pedido   INT            NOT NULL,
  monto       DECIMAL(10,2)  NOT NULL,
  metodo      ENUM('efectivo','tarjeta','transferencia') NOT NULL,
  fecha_pago  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  referencia  VARCHAR(80)    COMMENT 'Folio o número de comprobante',
  CONSTRAINT pk_pago        PRIMARY KEY (id_pago),
  CONSTRAINT fk_pago_ped    FOREIGN KEY (id_pedido)
    REFERENCES pedido (id_pedido)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
--  10. PROVEEDOR
-- ============================================================
CREATE TABLE proveedor (
  id_proveedor  INT            NOT NULL AUTO_INCREMENT,
  nombre        VARCHAR(120)   NOT NULL,
  contacto      VARCHAR(100),
  telefono      VARCHAR(20),
  email         VARCHAR(120),
  CONSTRAINT pk_proveedor PRIMARY KEY (id_proveedor)
) ENGINE=InnoDB;

-- ============================================================
--  11. COMPRA
-- ============================================================
CREATE TABLE compra (
  id_compra      INT             NOT NULL AUTO_INCREMENT,
  id_proveedor   INT             NOT NULL,
  id_ingrediente INT             NOT NULL,
  fecha_compra   DATE            NOT NULL,
  cantidad       DECIMAL(10,3)   NOT NULL,
  costo_total    DECIMAL(10,2)   NOT NULL,
  factura        VARCHAR(60)     COMMENT 'Número de factura del proveedor',
  CONSTRAINT pk_compra       PRIMARY KEY (id_compra),
  CONSTRAINT fk_comp_prov    FOREIGN KEY (id_proveedor)
    REFERENCES proveedor (id_proveedor)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_comp_ing     FOREIGN KEY (id_ingrediente)
    REFERENCES ingrediente (id_ingrediente)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
--  ÍNDICES ADICIONALES (rendimiento en consultas frecuentes)
-- ============================================================
CREATE INDEX idx_pedido_cliente   ON pedido (id_cliente);
CREATE INDEX idx_pedido_estado    ON pedido (estado);
CREATE INDEX idx_pedido_fecha     ON pedido (fecha_pedido);
CREATE INDEX idx_det_pedido       ON detalle_pedido (id_pedido);
CREATE INDEX idx_producto_cat     ON producto (id_categoria);
CREATE INDEX idx_compra_fecha     ON compra (fecha_compra);
CREATE INDEX idx_pago_pedido      ON pago (id_pedido);

-- ============================================================
--  DATOS DE PRUEBA
-- ============================================================

INSERT INTO categoria (nombre, descripcion) VALUES
  ('Pasteles',    'Pasteles completos para celebraciones'),
  ('Pan dulce',   'Pan tradicional y de temporada'),
  ('Galletas',    'Galletas artesanales variadas'),
  ('Bebidas',     'Café, té y bebidas calientes');

INSERT INTO cliente (nombre, telefono, email, direccion, fecha_registro) VALUES
  ('Ana García',     '6561234567', 'ana@email.com',   'Av. Juárez 100, Col. Centro',  CURRENT_DATE),
  ('Carlos Mendoza', '6569876543', 'carlos@email.com','Calle Roble 45, Col. Jardines', CURRENT_DATE);

INSERT INTO empleado (nombre, rol, telefono, fecha_ingreso, activo) VALUES
  ('Laura Torres',  'cajero',     '6561111111', '2023-01-15', TRUE),
  ('Miguel Ramos',  'pastelero',  '6562222222', '2022-06-01', TRUE),
  ('Sofía Núñez',   'admin',      '6563333333', '2021-03-10', TRUE);

INSERT INTO producto (id_categoria, nombre, descripcion, precio, disponible) VALUES
  (1, 'Pastel de chocolate 1kg', 'Esponjoso pastel con betún de chocolate',  350.00, TRUE),
  (1, 'Pastel de tres leches',   'Clásico tres leches con crema chantilly',  320.00, TRUE),
  (2, 'Concha',                  'Pan de dulce con costra de vainilla',         18.00, TRUE),
  (3, 'Galleta de avena',        'Galleta con avena y pasas',                   22.00, TRUE),
  (4, 'Café americano',          'Café negro preparado al momento',             35.00, TRUE);

INSERT INTO ingrediente (nombre, unidad, stock_actual, stock_minimo, costo_unitario) VALUES
  ('Harina',        'kg',  50.000, 10.000,  14.00),
  ('Azúcar',        'kg',  30.000,  5.000,  18.00),
  ('Mantequilla',   'kg',  15.000,  3.000,  80.00),
  ('Huevo',         'pz', 200.000, 30.000,   3.50),
  ('Cacao en polvo','kg',   8.000,  2.000,  90.00),
  ('Leche',         'lt',  20.000,  5.000,  22.00),
  ('Avena',         'kg',   5.000,  1.000,  25.00);

INSERT INTO ingrediente_producto (id_ingrediente, id_producto, cantidad_usada) VALUES
  (1, 1, 0.500), (2, 1, 0.400), (3, 1, 0.200), (4, 1, 4.000), (5, 1, 0.150),
  (1, 2, 0.400), (2, 2, 0.350), (4, 2, 3.000), (6, 2, 0.500),
  (1, 3, 0.100), (2, 3, 0.050), (3, 3, 0.040), (4, 3, 1.000),
  (7, 4, 0.080), (2, 4, 0.030), (3, 4, 0.020);

INSERT INTO proveedor (nombre, contacto, telefono, email) VALUES
  ('Distribuidora El Molino',  'Pedro López',  '6564444444', 'molino@prov.com'),
  ('Lácteos La Vaca',          'Rosa Herrera', '6565555555', 'lavaca@prov.com');

INSERT INTO compra (id_proveedor, id_ingrediente, fecha_compra, cantidad, costo_total, factura) VALUES
  (1, 1, CURRENT_DATE, 25.000, 350.00, 'FAC-001'),
  (1, 2, CURRENT_DATE, 20.000, 360.00, 'FAC-001'),
  (2, 6, CURRENT_DATE, 10.000, 220.00, 'FAC-002');

INSERT INTO pedido (id_cliente, id_empleado, fecha_pedido, fecha_entrega, estado, tipo, observaciones) VALUES
  (1, 1, NOW(), DATE_ADD(CURRENT_DATE, INTERVAL 2 DAY), 'pendiente',   'por encargo', 'Sin nueces, con mensaje: Feliz cumpleaños'),
  (2, 1, NOW(), CURRENT_DATE,                           'en proceso',  'en tienda',   NULL);

INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario, descuento) VALUES
  (1, 1, 1, 350.00, 0.00),
  (1, 4, 6,  22.00, 0.00),
  (2, 3, 4,  18.00, 0.00),
  (2, 5, 2,  35.00, 0.00);

INSERT INTO pago (id_pedido, monto, metodo, fecha_pago) VALUES
  (1, 132.00, 'efectivo',    NOW()),
  (2, 142.00, 'tarjeta',     NOW());

-- ============================================================
--  FIN DEL SCRIPT  bdpasteleria.sql
-- ============================================================

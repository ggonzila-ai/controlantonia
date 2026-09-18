-- ══════════════════════════════════════════════════════════════════
-- BASE DE DATOS MAESTRA DE PRODUCTOS
-- Fuente: ANTONIA BASE DE DATOS ACTIVA (Drive) — actualizada 2026-09-18
-- 38 productos base · 143 variantes (SKU con código de barras)
--
-- Pegar en Supabase → SQL Editor. Es idempotente: se puede correr de nuevo.
-- ══════════════════════════════════════════════════════════════════

-- ─── TABLAS ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS productos (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre           TEXT NOT NULL,        -- nombre interno: "JOGGER EN LICRA ALGODÓN"
  descripcion      TEXT,                 -- nombre para Feria del Brasier
  referencia_base  TEXT UNIQUE NOT NULL, -- "ANT8062" (sin talla ni proveedor)
  categoria        TEXT NOT NULL,        -- DEPORTIVO | PIJAMERIA | BLUSAS | SALIDAS DE BAÑO | OFERTAS
  precio_venta     BIGINT,               -- PVP con IVA incluido
  estado           TEXT DEFAULT 'activo',
  observaciones    TEXT,
  -- Puente hacia el vocabulario del inventario: bodega, conteos y ventas usan sus
  -- propios nombres de referencia ("JOGGER", "BLUSA 39900 & 49900"), que no son los
  -- del catálogo. NULL = producto nuevo que todavía no entra al inventario.
  referencia_inventario TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE productos ADD COLUMN IF NOT EXISTS referencia_inventario TEXT;

CREATE TABLE IF NOT EXISTS productos_variantes (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  producto_id      UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  referencia       TEXT UNIQUE NOT NULL, -- "ANT8062M2600"
  talla            TEXT NOT NULL,
  codigo_barras    TEXT UNIQUE,
  precio_venta     BIGINT,               -- NULL = hereda el del producto
  estado           TEXT DEFAULT 'activo',
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_variantes_referencia  ON productos_variantes(referencia);
CREATE INDEX IF NOT EXISTS idx_variantes_barcode     ON productos_variantes(codigo_barras) WHERE codigo_barras IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_variantes_producto_id ON productos_variantes(producto_id);
CREATE INDEX IF NOT EXISTS idx_productos_categoria   ON productos(categoria);
CREATE INDEX IF NOT EXISTS idx_productos_referencia  ON productos(referencia_base);

-- La app entra con la clave anon, igual que el resto de tablas del proyecto.
ALTER TABLE productos            ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos_variantes  ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS productos_todo ON productos;
DROP POLICY IF EXISTS productos_variantes_todo ON productos_variantes;
CREATE POLICY productos_todo           ON productos           FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY productos_variantes_todo ON productos_variantes FOR ALL USING (true) WITH CHECK (true);

-- ─── CATÁLOGO ─────────────────────────────────────────────────────
DELETE FROM productos_variantes;
DELETE FROM productos;

INSERT INTO productos (nombre, descripcion, referencia_base, categoria, precio_venta, estado, observaciones)
VALUES
  -- PIJAMERÍA · 13 referencias
  ('PIJAMA CAPRI VERA',           'PIJAMA DE CAPRI VERA',          'ANT5302', 'PIJAMERIA',      52900, 'activo', 'Pantalón estampado, blusa unicolor. Usualmente rosa, azul claro, coral, lila, azul turquí'),
  ('PIJAMA SHORT MIA PLUS',       'PIJAMA DE SHORT MIA PLUS',      'ANT5303', 'PIJAMERIA',      43900, 'activo', 'Short estampado, blusa unicolor. Usualmente rosa, azul claro, coral, lila, azul turquí'),
  ('PIJAMA SHORT SATIN ARI',      'PIJAMA DE SHORT SATIN ARI',     'ANT5305', 'PIJAMERIA',      49900, 'activo', 'Conjunto unicolor. Usualmente vinotinto, rosa, palo de rosa, coral, plata, champaña'),
  ('BATOLA SEÑORERA ELY',         'BATOLA SEÑORERA ELY',           'ANT5304', 'PIJAMERIA',      55900, 'activo', 'Franela estampada, estampados delicados: marfil/blanco con detalles rosa, azul, coral o lila'),
  ('BATOLA SEÑORERA SIZA YARA',   'BATOLA SEÑORERA SIZA YARA',     'ANT5307', 'PIJAMERIA',      47900, 'activo', 'Franela estampada, estampados delicados: marfil/blanco con detalles rosa, azul, coral o lila'),
  ('BATOLA SIZA ZOE CON BOLSILLO','BATOLA SIZA ZOE CON BOLSILLO',  'ANT5301', 'PIJAMERIA',      44900, 'activo', 'Franela estampada, estampados delicados: marfil/blanco con detalles rosa, azul, coral o lila'),
  ('BATOLA EN SATIN IRIS',        'BATOLA EN SATIN IRIS',          'ANT5306', 'PIJAMERIA',      44900, 'activo', 'Satín unicolor con encaje tono a tono. Usualmente rosa, champaña, palo de rosa, coral, vino'),
  ('BATOLA TIRAS',                'BATOLA TIRAS',                  'ANT5110', 'PIJAMERIA',      35900, 'activo', 'Franela estampada, estampados juveniles surtidos'),
  ('CONJUNTO MULTIUSO SHORT',     'CONJUNTO MULTIUSO SHORT',       'ANT5117', 'PIJAMERIA',      37900, 'activo', 'Short estampado, blusa unicolor. Usualmente rosa, azul claro, coral, lila, azul turquí'),
  ('CONJUNTO SHORT',              'CONJUNTO SHORT',                'ANT5015', 'PIJAMERIA',      49900, 'activo', 'Código provisional. Short estampado, blusa unicolor'),
  ('BATOLA DE TIRAS',             'BATOLA DE TIRAS',               'ANT5011', 'PIJAMERIA',      44900, 'activo', 'Código provisional. Franela estampada'),
  ('BATOLA SIZA ALGODON',         'BATOLA SIZA ALGODON',           'ANT5022', 'PIJAMERIA',      49900, 'activo', 'Colores surtidos'),
  ('BATOLA SIZA AURA',            'BATOLA SIZA AURA',              'ANT5020', 'PIJAMERIA',      28900, 'activo', 'Colores surtidos'),

  -- DEPORTIVO · 8 referencias
  ('JOGGER EN LICRA ALGODÓN',     'JOGGER EN LICRA ALGODÓN',       'ANT8062', 'DEPORTIVO',      62900, 'activo', 'Unicolor: gris oscuro, azul jean, azul petróleo, negro, verde militar'),
  ('SHORT BOLSILLO ALGODON',      'SHORT BOLSILLO ALGODON',        'ANT8164', 'DEPORTIVO',      44900, 'activo', 'Unicolor: gris oscuro, azul jean, azul petróleo, negro, verde militar'),
  ('CAPRI LICRA ALGODÓN',         'CAPRI LICRA ALGODÓN',           'ANT8153', 'DEPORTIVO',      52900, 'activo', 'Unicolor: gris oscuro, azul jean, azul petróleo, negro, verde militar'),
  ('CAPRI MULTIUSO LICRA NEGRO',  'CAPRI MULTIUSO LICRA NEGRO',    'ANT8051', 'DEPORTIVO',      32900, 'activo', 'Color negro'),
  ('SHORT MULTIUSO LICRA SURTIDO','SHORT MULTIUSO LICRA SURTIDO',  'ANT8050', 'DEPORTIVO',      29900, 'activo', 'Color negro'),
  ('LEGGIN LICRADO',              'LEGGIN LICRADO',                'ANT8155', 'DEPORTIVO',      39900, 'activo', 'Color negro'),
  ('CONJUNTO DEP CAPRI CON COPA', 'CONJUNTO DEP CAPRI CON COPA',   'ANT8081', 'DEPORTIVO',      74900, 'activo', 'Combinado negro y estampado'),
  ('CONJUNTO DEPORTIVO COPA',     'CONJUNTO DEPORTIVO COPA',       'ANT8099', 'DEPORTIVO',      55900, 'activo', 'Combinado negro y estampado'),

  -- SALIDAS DE BAÑO · 5 referencias
  ('PANTALON BLONDA ENCAJE',      'PANTALON BLONDA ENCAJE SURTIDO','ANT3030', 'SALIDAS DE BAÑO', 48900, 'activo', 'Negro, marfil y blanco'),
  ('VESTIDO SALIDA DE BAÑO',      'VESTIDO SALIDA DE BAÑO',        'ANT3231', 'SALIDAS DE BAÑO', 32900, 'activo', 'Negro y marfil'),
  ('SHORT MALLA SURTIDO',         'SHORT MALLA SURTIDO',           'ANT3035', 'SALIDAS DE BAÑO', 32900, 'activo', 'Negro y marfil'),
  ('KIMONO MALLA VELO',           'KIMONO MALLA VELO SURTIDO',     'ANT3033', 'SALIDAS DE BAÑO', 34900, 'activo', 'Colores surtidos'),
  ('FALDA DE BOLEROS',            'FALDA BOLEROS',                 'ANT3051', 'SALIDAS DE BAÑO', 32900, 'activo', 'Colores surtidos'),

  -- BLUSAS · 4 referencias
  ('BLUSA BASICA ESQUELETO',      'BLUSA BASICA ESQUELETO',        'ANT8297', 'BLUSAS',          29900, 'activo', 'Viscosa, colores surtidos'),
  ('BLUSA GEA EN DURAZNO',        'BLUSA GEA EN DURAZNO',          'ANT6301', 'BLUSAS',          39900, 'activo', 'Durazno unitono. Usualmente blanco, rojo, verde, coral'),
  ('BLUSA JUVENIL VELO',          'BLUSA JUVENIL VELO',            'ANT2001', 'BLUSAS',          49900, 'activo', 'Unitono y estampado'),
  ('BLUSA DE MODA CHALIS HINDU',  'BLUSA DE MODA CHALIS HINDU',    'ANT6215', 'BLUSAS',          39900, 'activo', 'Unitono y estampado'),

  -- OFERTAS · 8 referencias
  ('OFERTA',                      'PRENDA EN OFERTA',              'ANT1201', 'OFERTAS',         28900, 'activo', 'Prenda en oferta'),
  ('OFERTA',                      'PRENDA EN OFERTA',              'ANT1202', 'OFERTAS',         39900, 'activo', 'Prenda en oferta'),
  ('OFERTA',                      'PRENDA EN OFERTA',              'ANT1203', 'OFERTAS',         14900, 'activo', 'Prenda en oferta'),
  ('OFERTA',                      'PRENDA DE OFERTA',              'ANT1209', 'OFERTAS',         19900, 'activo', 'Prenda en oferta'),
  ('OFERTA',                      'OFERTA',                        'ANT1211', 'OFERTAS',          9900, 'activo', 'Prenda en oferta'),
  ('BLUSA JUVENIL VELO OFERTA',   'BLUSA JUVENIL VELO',            'ANT2007', 'OFERTAS',         19900, 'activo', 'Blusa juvenil en oferta'),
  ('BLUSA JUVENIL CHALIS OFERTA', 'BLUSA JUVENIL CHALIS',          'ANT6254', 'OFERTAS',         24900, 'activo', 'Blusa juvenil chalís en oferta'),
  ('TOP DEPORTIVO OFERTA',        'TOP DEPORTIVO',                 'ANT8022', 'OFERTAS',         22900, 'activo', 'Top deportivo en oferta');

INSERT INTO productos_variantes (producto_id, referencia, talla, codigo_barras, precio_venta, estado)
SELECT p.id, v.referencia, v.talla, v.codigo_barras, v.precio_venta, 'activo'
FROM productos p
JOIN (VALUES
  -- PIJAMA CAPRI VERA · ANT5302
  ('ANT5302M2600',   'ANT5302', 'M',    '7706730455433', 52900),
  ('ANT5302L2600',   'ANT5302', 'L',    '7706730908694', 52900),
  ('ANT5302XL2600',  'ANT5302', 'XL',   '7706730240497', 52900),
  ('ANT53022XL2600', 'ANT5302', '2XL',  '7706730112282', 52900),
  ('ANT53023XL2600', 'ANT5302', '3XL',  '7706730825632', 52900),
  ('ANT53024XL2600', 'ANT5302', '4XL',  '7706730642628', 52900),
  -- PIJAMA SHORT MIA PLUS · ANT5303
  ('ANT5303M2600',   'ANT5303', 'M',    '7706730971926', 43900),
  ('ANT5303L2600',   'ANT5303', 'L',    '7706730930077', 43900),
  ('ANT5303XL2600',  'ANT5303', 'XL',   '7706730531878', 43900),
  ('ANT53032XL2600', 'ANT5303', '2XL',  '7706730006659', 43900),
  ('ANT53033XL2600', 'ANT5303', '3XL',  '7706730451947', 43900),
  -- PIJAMA SHORT SATIN ARI · ANT5305
  ('ANT5305M2600',   'ANT5305', 'M',    '7706730292861', 49900),
  ('ANT5305L2600',   'ANT5305', 'L',    '7706730551128', 49900),
  ('ANT5305XL2600',  'ANT5305', 'XL',   '7706730995984', 49900),
  ('ANT53052XL2600', 'ANT5305', '2XL',  '7706730467214', 49900),
  -- BATOLA SEÑORERA ELY · ANT5304
  ('ANT5304M2600',   'ANT5304', 'M',    '7706730279671', 55900),
  ('ANT5304L2600',   'ANT5304', 'L',    '7706730354934', 55900),
  ('ANT5304XL2600',  'ANT5304', 'XL',   '7706730062051', 55900),
  ('ANT53042XL2600', 'ANT5304', '2XL',  '7706730949789', 55900),
  ('ANT53043XL2600', 'ANT5304', '3XL',  '7706730828763', 55900),
  ('ANT53044XL2600', 'ANT5304', '4XL',  '7706730764542', 55900),
  -- BATOLA SEÑORERA SIZA YARA · ANT5307
  ('ANT5307M2600',   'ANT5307', 'M',    '7706730025124', 47900),
  ('ANT5307L2600',   'ANT5307', 'L',    '7706730779805', 47900),
  ('ANT5307XL2600',  'ANT5307', 'XL',   '7706730593678', 47900),
  ('ANT53072XL2600', 'ANT5307', '2XL',  '7706730915173', 47900),
  ('ANT53073XL2600', 'ANT5307', '3XL',  '7706730083711', 47900),
  ('ANT53074XL2600', 'ANT5307', '4XL',  '7706730989167', 47900),
  -- BATOLA SIZA ZOE CON BOLSILLO · ANT5301
  ('ANT5301M2600',   'ANT5301', 'M',    '7706730339757', 44900),
  ('ANT5301L2600',   'ANT5301', 'L',    '7706730839721', 44900),
  ('ANT5301XL2600',  'ANT5301', 'XL',   '7706730034768', 44900),
  ('ANT53012XL2600', 'ANT5301', '2XL',  '7706730803708', 44900),
  ('ANT53013XL2600', 'ANT5301', '3XL',  '7706730632988', 44900),
  ('ANT53014XL2600', 'ANT5301', '4XL',  '7706730796031', 44900),
  -- BATOLA EN SATIN IRIS · ANT5306
  ('ANT5306M2600',   'ANT5306', 'M',    '7706730238746', 44900),
  ('ANT5306L2600',   'ANT5306', 'L',    '7706730074252', 44900),
  ('ANT5306XL2600',  'ANT5306', 'XL',   '7706730774640', 44900),
  ('ANT53062XL2600', 'ANT5306', '2XL',  '7706730223032', 44900),
  -- BATOLA TIRAS · ANT5110
  ('ANT5110S2600',   'ANT5110', 'S',    '7706730232881', 35900),
  ('ANT5110M2600',   'ANT5110', 'M',    '7706730296968', 35900),
  ('ANT5110L2600',   'ANT5110', 'L',    '7706730435466', 35900),
  ('ANT5110XL2600',  'ANT5110', 'XL',   '7706730179742', 35900),
  ('ANT51102XL2600', 'ANT5110', '2XL',  '7706730229966', 35900),
  ('ANT51103XL2600', 'ANT5110', '3XL',  '7706730044835', 35900),
  -- CONJUNTO MULTIUSO SHORT · ANT5117
  ('ANT5117S2600',   'ANT5117', 'S',    '7706730181660', 37900),
  ('ANT5117M2600',   'ANT5117', 'M',    '7706730367736', 37900),
  ('ANT5117L2600',   'ANT5117', 'L',    '7706730625720', 37900),
  ('ANT5117XL2600',  'ANT5117', 'XL',   '7706730174921', 37900),
  -- CONJUNTO SHORT · ANT5015 (código provisional)
  ('ANT5015S2600',   'ANT5015', 'S',    '7706730594033', 49900),
  ('ANT5015M2600',   'ANT5015', 'M',    '7706730180373', 49900),
  ('ANT5015L2600',   'ANT5015', 'L',    '7706730062327', 49900),
  ('ANT5015XL2600',  'ANT5015', 'XL',   '7706730360461', 49900),
  -- BATOLA DE TIRAS · ANT5011 (código provisional)
  ('ANT5011S2600',   'ANT5011', 'S',    '7706730009131', 44900),
  ('ANT5011M2600',   'ANT5011', 'M',    '7706730107721', 44900),
  ('ANT5011L2600',   'ANT5011', 'L',    '7706730378275', 44900),
  ('ANT5011XL2600',  'ANT5011', 'XL',   '7706730375083', 44900),
  ('ANT50112XL2600', 'ANT5011', '2XL',  '7706730572437', 44900),
  ('ANT50113XL2600', 'ANT5011', '3XL',  '7706730541983', 44900),
  -- BATOLA SIZA ALGODON · ANT5022
  ('ANT5022S2600',   'ANT5022', 'S',    '7706730448367', 49900),
  ('ANT5022M2600',   'ANT5022', 'M',    '7706730959313', 49900),
  ('ANT5022L2600',   'ANT5022', 'L',    '7706730344317', 49900),
  ('ANT5022XL2600',  'ANT5022', 'XL',   '7706730534596', 49900),
  ('ANT50222XL2600', 'ANT5022', '2XL',  '7706730261034', 49900),
  ('ANT50223XL2600', 'ANT5022', '3XL',  '7706730243672', 49900),
  -- BATOLA SIZA AURA · ANT5020
  ('ANT5020M2600',   'ANT5020', 'M',    '7706730544489', 28900),
  ('ANT50202XL2600', 'ANT5020', '2XL',  '7706730372297', 28900),
  -- JOGGER EN LICRA ALGODÓN · ANT8062
  ('ANT8062S2600',   'ANT8062', 'S',    '7706730522272', 62900),
  ('ANT8062M2600',   'ANT8062', 'M',    '7706730912288', 62900),
  ('ANT8062L2600',   'ANT8062', 'L',    '7706730615127', 62900),
  ('ANT8062XL2600',  'ANT8062', 'XL',   '7706730056623', 62900),
  ('ANT80622XL2600', 'ANT8062', '2XL',  '7706730673073', 62900),
  -- SHORT BOLSILLO ALGODON · ANT8164
  ('ANT8164S2600',   'ANT8164', 'S',    '7706730393575', 44900),
  ('ANT8164M2600',   'ANT8164', 'M',    '7706730312866', 44900),
  ('ANT8164L2600',   'ANT8164', 'L',    '7706730068046', 44900),
  ('ANT8164XL2600',  'ANT8164', 'XL',   '7706730819075', 44900),
  ('ANT81642XL2600', 'ANT8164', '2XL',  '7706730717517', 44900),
  -- CAPRI LICRA ALGODÓN · ANT8153
  ('ANT8153M2600',   'ANT8153', 'M',    '7706730102603', 52900),
  ('ANT8153L2600',   'ANT8153', 'L',    '7706730049939', 52900),
  ('ANT8153XL2600',  'ANT8153', 'XL',   '7706730917375', 52900),
  ('ANT81532XL2600', 'ANT8153', '2XL',  '7706730660363', 52900),
  ('ANT81533XL2600', 'ANT8153', '3XL',  '7706730573786', 52900),
  -- CAPRI MULTIUSO LICRA NEGRO · ANT8051 (sufijo de proveedor 1200)
  ('ANT8051S1200',   'ANT8051', 'S',    '7706730624686', 32900),
  ('ANT8051M1200',   'ANT8051', 'M',    '7706730292649', 32900),
  ('ANT8051L1200',   'ANT8051', 'L',    '7706730301808', 32900),
  ('ANT8051XL1200',  'ANT8051', 'XL',   '7706730966588', 32900),
  ('ANT80512XL1200', 'ANT8051', '2XL',  '7706730435619', 32900),
  -- SHORT MULTIUSO LICRA SURTIDO · ANT8050
  ('ANT8050S2600',   'ANT8050', 'S',    '7706730041483', 29900),
  ('ANT8050M2600',   'ANT8050', 'M',    '7706730057903', 29900),
  ('ANT8050L2600',   'ANT8050', 'L',    '7706730598833', 29900),
  ('ANT8050XL2600',  'ANT8050', 'XL',   '7706730166346', 29900),
  ('ANT80502XL2600', 'ANT8050', '2XL',  '7706730699196', 29900),
  -- LEGGIN LICRADO · ANT8155
  ('ANT8155S2600',   'ANT8155', 'S',    '7706730193960', 39900),
  ('ANT8155M2600',   'ANT8155', 'M',    '7706730910840', 39900),
  ('ANT8155L2600',   'ANT8155', 'L',    '7706730528212', 39900),
  ('ANT8155XL2600',  'ANT8155', 'XL',   '7706730846903', 39900),
  ('ANT81552XL2600', 'ANT8155', '2XL',  '7706730227078', 39900),
  -- CONJUNTO DEP CAPRI CON COPA · ANT8081
  ('ANT8081M2600',   'ANT8081', 'M',    '7706730414591', 74900),
  ('ANT8081L2600',   'ANT8081', 'L',    '7706730421124', 74900),
  ('ANT8081XL2600',  'ANT8081', 'XL',   '7706730353241', 74900),
  ('ANT80812XL2600', 'ANT8081', '2XL',  '7706730807270', 74900),
  ('ANT80813XL2600', 'ANT8081', '3XL',  '7706730523743', 74900),
  -- CONJUNTO DEPORTIVO COPA · ANT8099
  ('ANT8099L2600',   'ANT8099', 'L',    '7706730991467', 55900),
  ('ANT8099XL2600',  'ANT8099', 'XL',   '7706730751153', 55900),
  ('ANT80992XL2600', 'ANT8099', '2XL',  '7706730093161', 55900),
  ('ANT80993XL2600', 'ANT8099', '3XL',  '7706730635507', 55900),
  -- PANTALON BLONDA ENCAJE · ANT3030
  ('ANT3030U2600',   'ANT3030', 'U',    '7706730219912', 48900),
  ('ANT3030XL2600',  'ANT3030', 'XL',   '7706730255156', 48900),
  -- VESTIDO SALIDA DE BAÑO · ANT3231
  ('ANT3231XL2600',  'ANT3231', 'XL',   '7706730841113', 32900),
  ('ANT3231U2600',   'ANT3231', 'U',    '7706730484204', 32900),
  -- SHORT MALLA SURTIDO · ANT3035
  ('ANT3035S2600',   'ANT3035', 'S',    '7706730918488', 32900),
  ('ANT3035M2600',   'ANT3035', 'M',    '7706730860343', 32900),
  ('ANT3035L2600',   'ANT3035', 'L',    '7706730277523', 32900),
  ('ANT3035XL2600',  'ANT3035', 'XL',   '7706730622972', 32900),
  -- KIMONO MALLA VELO · ANT3033
  ('ANT3033U2600',   'ANT3033', 'U',    '7706730880006', 34900),
  -- FALDA DE BOLEROS · ANT3051
  ('ANT3051U2600',   'ANT3051', 'U',    '7706730044996', 32900),
  -- BLUSA BASICA ESQUELETO · ANT8297
  ('ANT8297U2600',   'ANT8297', 'U',    '7706730950907', 29900),
  ('ANT8297XL2600',  'ANT8297', 'XL',   '7706730068459', 29900),   -- Feria la rotula EXTRA; es XL
  -- BLUSA GEA EN DURAZNO · ANT6301
  ('ANT6301M2600',   'ANT6301', 'M',    '7706730528199', 39900),
  ('ANT6301L2600',   'ANT6301', 'L',    '7706730658308', 39900),
  ('ANT6301XL2600',  'ANT6301', 'XL',   '7706730525907', 39900),
  ('ANT63012XL2600', 'ANT6301', '2XL',  '7706730504391', 39900),
  -- BLUSA JUVENIL VELO · ANT2001
  ('ANT2001S2600',   'ANT2001', 'S',    '7706730897516', 49900),
  ('ANT2001M2600',   'ANT2001', 'M',    '7706730672670', 49900),
  ('ANT2001L2600',   'ANT2001', 'L',    '7706730911335', 49900),
  ('ANT2001XL2600',  'ANT2001', 'XL',   '7706730331706', 49900),
  -- BLUSA DE MODA CHALIS HINDU · ANT6215
  ('ANT6215S2600',   'ANT6215', 'S',    '7706730052359', 39900),
  ('ANT6215M2600',   'ANT6215', 'M',    '7706730911205', 39900),
  ('ANT6215L2600',   'ANT6215', 'L',    '7706730587141', 39900),
  ('ANT6215XL2600',  'ANT6215', 'XL',   '7706730230139', 39900),
  -- OFERTAS
  ('ANT1201L2600',   'ANT1201', 'L',    '7706730309835', 28900),
  ('ANT1202L2600',   'ANT1202', 'L',    '7706730138909', 39900),
  ('ANT1203M2600',   'ANT1203', 'M',    '7706730795614', 14900),
  ('ANT1203L2600',   'ANT1203', 'L',    '7706730899923', 14900),
  ('ANT1203XL2600',  'ANT1203', 'XL',   '7706730440705', 14900),
  ('ANT1209S2600',   'ANT1209', 'S',    '7706730863764', 19900),
  ('ANT1209M2600',   'ANT1209', 'M',    '7706730891996', 19900),
  ('ANT1209L2600',   'ANT1209', 'L',    '7706730288406', 19900),
  ('ANT1209XL2600',  'ANT1209', 'XL',   '7706730652856', 19900),
  ('ANT1211S2600',   'ANT1211', 'S',    '7706730854687',  9900),
  ('ANT2007L2600',   'ANT2007', 'L',    '7706730509792', 19900),
  ('ANT6254S2600',   'ANT6254', 'S',    '7706730138435', 24900),
  ('ANT6254M2600',   'ANT6254', 'M',    '7706730684611', 24900),
  ('ANT8022M2600',   'ANT8022', 'M',    '7706730758824', 22900),
  ('ANT8022XL2600',  'ANT8022', 'XL',   '7706730813493', 22900)
) AS v(referencia, producto_base, talla, codigo_barras, precio_venta)
  ON p.referencia_base = v.producto_base;

-- ─── PUENTE CON EL INVENTARIO ─────────────────────────────────────
-- Derivado de codigos_sku, con dos correcciones que confirman los reportes de Feria:
--   ANT2001 = blusa juvenil velo (no batola señorera ely, que va con ANT5304)
--   ANT5022 = batola siza algodón, producto distinto de la batola siza bolsillo
UPDATE productos p SET referencia_inventario = m.ref
  FROM (VALUES
  ('ANT1201','OFERTAS'),
  ('ANT1202','OFERTAS'),
  ('ANT1203','OFERTAS'),
  ('ANT1209','OFERTAS'),
  ('ANT1211','OFERTAS'),
  ('ANT2001','BLUSA 39900 & 49900'),
  ('ANT2007','OFERTAS'),
  ('ANT3030','PANTALONES DE BAÑO'),
  ('ANT3033','KIMONOS'),
  ('ANT3035','SHORTS DE BAÑO'),
  ('ANT3051','FALDA CORTA DE BAÑO'),
  ('ANT3231','VESTIDO SALIDA DE BAÑO'),
  ('ANT5011','BATOLA TIRAS'),
  ('ANT5020','BATOLA SIZA AURA'),
  ('ANT5022','BATOLA SIZA ALGODON'),
  ('ANT5110','BATOLA TIRAS'),
  ('ANT5117','PIJAMA DE SHORT NOA'),
  ('ANT5301','BATOLA SIZA BOLSILLO'),
  ('ANT5302','PIJAMA CAPRI VERA'),
  ('ANT5303','PIJAMA MÍA PLUS DE SHORT'),
  ('ANT5304','BATOLA SEÑORERA ELY'),
  ('ANT6215','BLUSA 39900 & 49900'),
  ('ANT6254','OFERTAS'),
  ('ANT6301','BLUSA DURAZNO 36900'),
  ('ANT8022','OFERTAS'),
  ('ANT8050','SHORTS EN LICRA'),
  ('ANT8051','CAPRIS EN LICRA'),
  ('ANT8062','JOGGER'),
  ('ANT8081','CONJUNTO DEPORTIVO COPA'),
  ('ANT8099','CONJUNTO DEPORTIVO COPA'),
  ('ANT8153','CAPRI DE BOLSILLO'),
  ('ANT8155','LEGGINS'),
  ('ANT8164','SHORTS DE BOLSILLO'),
  ('ANT8297','BLUSA ESQUELETO VISCOSA UNIF')
  ) AS m(base, ref)
 WHERE p.referencia_base = m.base;

-- ─── VERIFICACIÓN ─────────────────────────────────────────────────
SELECT p.categoria,
       COUNT(DISTINCT p.id) AS productos,
       COUNT(v.id)          AS skus
FROM productos p
LEFT JOIN productos_variantes v ON v.producto_id = p.id
GROUP BY p.categoria
ORDER BY skus DESC;
-- Esperado: PIJAMERIA 13/65 · DEPORTIVO 8/39 · OFERTAS 8/15 · BLUSAS 4/14 · SALIDAS DE BAÑO 5/10
-- Totales: 38 productos · 143 variantes

-- Productos que todavía no existen en el inventario (esperado: 4 referencias nuevas)
SELECT referencia_base, nombre FROM productos WHERE referencia_inventario IS NULL ORDER BY referencia_base;

-- ══════════════════════════════════════════════════════════════════
-- 1 · "BLUSA DURAZNO 36900" pasa a llamarse "BLUSA GEA EN DURAZNO"
-- 2 · La blusa combinada se separa en dos, DE AHORA EN ADELANTE
--
-- Decidido por Laura el 2026-09-29.
--
-- El renombrado es solo la etiqueta: cambia el nombre en todas las tablas que lo
-- guardan, y las cantidades quedan idénticas. Se elige un nombre sin precio adentro
-- para no tener que renombrarlo cada vez que suba el precio (ya pasó: el nombre decía
-- 36900 y la prenda vale 39.900). No hay claves foráneas por nombre, así que el orden
-- de los UPDATE no importa.
--
-- La separación sigue el mismo criterio que las batolas siza: se cambia el mapeo para
-- las ventas futuras y NO se mueve el histórico. Las 131 unidades ya registradas se
-- quedan en "BLUSA 39900 & 49900", que sobrevive como referencia histórica.
--
-- ANT6205 (blusa señorera chalís, 1 unidad) se deja apuntando a la combinada: no está
-- en el catálogo activo y no llegarán ventas nuevas con ese código.
-- ══════════════════════════════════════════════════════════════════

BEGIN;

-- ─── 1 · Renombrar el durazno ─────────────────────────────────────
UPDATE bodega              SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE codigos_sku         SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE conteo_items        SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE despacho_items      SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE inventario_apertura SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE referencia_alias    SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE referencia_costos   SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE referencia_insumos  SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE variantes           SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE ventas              SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE productos           SET referencia_inventario='BLUSA GEA EN DURAZNO' WHERE referencia_inventario='BLUSA DURAZNO 36900';
-- Los respaldo_* se dejan con el nombre viejo a propósito: son fotos del pasado.

-- ─── 2 · Separar las dos blusas, hacia adelante ───────────────────
INSERT INTO bodega (referencia, categoria, stock, costo)
SELECT 'BLUSA JUVENIL VELO', 'BLUSAS', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM bodega WHERE referencia='BLUSA JUVENIL VELO');
INSERT INTO bodega (referencia, categoria, stock, costo)
SELECT 'BLUSA DE MODA CHALIS HINDU', 'BLUSAS', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM bodega WHERE referencia='BLUSA DE MODA CHALIS HINDU');

UPDATE codigos_sku SET referencia='BLUSA JUVENIL VELO'         WHERE codigo='ANT2001';
UPDATE codigos_sku SET referencia='BLUSA DE MODA CHALIS HINDU' WHERE codigo='ANT6215';

-- Sin esto, una fila que diga "BLUSA DE MODA" volvería a caer en la combinada al leerse.
UPDATE referencia_alias SET referencia='BLUSA DE MODA CHALIS HINDU'
 WHERE alias='BLUSA DE MODA' AND referencia='BLUSA 39900 & 49900';

UPDATE productos SET referencia_inventario='BLUSA JUVENIL VELO'         WHERE referencia_base='ANT2001';
UPDATE productos SET referencia_inventario='BLUSA DE MODA CHALIS HINDU' WHERE referencia_base='ANT6215';

-- ─── Comprobación ─────────────────────────────────────────────────
SELECT 'quedan con el nombre viejo' AS control,
       (SELECT count(*) FROM ventas WHERE referencia='BLUSA DURAZNO 36900') AS ventas,
       (SELECT count(*) FROM conteo_items WHERE referencia='BLUSA DURAZNO 36900') AS conteos,
       (SELECT count(*) FROM inventario_apertura WHERE referencia='BLUSA DURAZNO 36900') AS inicial,
       (SELECT count(*) FROM bodega WHERE referencia='BLUSA DURAZNO 36900') AS bodega;
-- Esperado: todo en 0.

SELECT referencia, count(*) filas, coalesce(sum(cantidad),0) uds
  FROM ventas WHERE referencia IN ('BLUSA GEA EN DURAZNO','BLUSA 39900 & 49900',
                                   'BLUSA JUVENIL VELO','BLUSA DE MODA CHALIS HINDU')
 GROUP BY referencia ORDER BY referencia;
-- Esperado: BLUSA GEA EN DURAZNO 96 filas / 102 uds  ·  BLUSA 39900 & 49900 124 / 131
--           las dos nuevas sin ventas todavía (el histórico no se mueve).

SELECT codigo, referencia FROM codigos_sku
 WHERE codigo IN ('ANT2001','ANT6215','ANT6205','ANT6201','ANT6301') ORDER BY codigo;
-- Esperado: ANT2001 → BLUSA JUVENIL VELO · ANT6215 → BLUSA DE MODA CHALIS HINDU
--           ANT6205 → BLUSA 39900 & 49900 (se queda) · ANT6201 y ANT6301 → BLUSA GEA EN DURAZNO

COMMIT;

-- ══════════════════════════════════════════════════════════════════
-- ROLLBACK (deshace ambas cosas):
--   UPDATE bodega SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE codigos_sku SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE conteo_items SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE despacho_items SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE inventario_apertura SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE referencia_alias SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE referencia_costos SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE referencia_insumos SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE variantes SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE ventas SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE productos SET referencia_inventario='BLUSA DURAZNO 36900' WHERE referencia_inventario='BLUSA GEA EN DURAZNO';
--   UPDATE codigos_sku SET referencia='BLUSA 39900 & 49900' WHERE codigo IN ('ANT2001','ANT6215');
--   UPDATE referencia_alias SET referencia='BLUSA 39900 & 49900' WHERE alias='BLUSA DE MODA';
--   UPDATE productos SET referencia_inventario='BLUSA 39900 & 49900' WHERE referencia_base IN ('ANT2001','ANT6215');
--   DELETE FROM bodega WHERE referencia IN ('BLUSA JUVENIL VELO','BLUSA DE MODA CHALIS HINDU') AND stock=0;
-- ══════════════════════════════════════════════════════════════════

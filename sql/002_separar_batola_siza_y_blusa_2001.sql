-- ══════════════════════════════════════════════════════════════════
-- CORRECCIÓN DE DOS REFERENCIAS MAL IMPUTADAS
--
-- Confirmado por Laura el 2026-09-18 y por los propios reportes de Feria
-- (ventas_feria_detalle.desc_item):
--
--   ANT2001 → "BLUSA JUVENIL VELO".  Durante un tiempo esta prenda se despachó
--             bajo el nombre de la batola señorera ely; el error ya se corrigió y
--             la batola se registra con ANT5304. Pero codigos_sku sigue diciendo
--             que ANT2001 es la batola, y por eso 121 unidades de blusa están
--             sumando al inventario de BATOLA SEÑORERA ELY.
--             En el inventario, ANT2001 y ANT6215 se llevan juntas en una sola
--             línea: "BLUSA 39900 & 49900" (dos precios, una inventariada).
--
--   ANT5022 → "BATOLA SIZA ALGODON". Es un producto DISTINTO de la batola siza
--             bolsillo, pese al nombre parecido. En la unificación de agosto se
--             creó un alias que las fusionó; eso estuvo mal. Son 133 unidades.
--
-- Al correrlo cambian saldos históricos de cuatro referencias. Hay respaldo y
-- rollback al final.
-- ══════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Respaldo ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS respaldo_ventas_20260918 AS SELECT * FROM ventas WHERE false;
TRUNCATE respaldo_ventas_20260918;
INSERT INTO respaldo_ventas_20260918
  SELECT * FROM ventas WHERE upper(codigo) LIKE 'ANT2001%' OR upper(codigo) LIKE 'ANT5022%';

CREATE TABLE IF NOT EXISTS respaldo_alias_20260918 AS SELECT * FROM referencia_alias WHERE false;
TRUNCATE respaldo_alias_20260918;
INSERT INTO respaldo_alias_20260918 SELECT * FROM referencia_alias;

-- ─── 1 · La batola siza algodón pasa a ser una referencia propia ──
INSERT INTO bodega (referencia, categoria, stock, costo)
SELECT 'BATOLA SIZA ALGODON', 'PIJAMERIA', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM bodega WHERE referencia = 'BATOLA SIZA ALGODON');

-- El alias que la fusionaba con la de bolsillo se retira.
DELETE FROM referencia_alias
 WHERE alias = 'BATOLA SIZA ALGODON' AND referencia = 'BATOLA SIZA BOLSILLO';

UPDATE codigos_sku SET referencia = 'BATOLA SIZA ALGODON', descripcion = 'BATOLA SIZA ALGODON'
 WHERE codigo = 'ANT5022';

UPDATE ventas SET referencia = 'BATOLA SIZA ALGODON'
 WHERE upper(codigo) LIKE 'ANT5022%';

-- ─── 2 · ANT2001 es blusa, no batola ──────────────────────────────
UPDATE codigos_sku SET referencia = 'BLUSA 39900 & 49900', descripcion = 'BLUSA JUVENIL VELO'
 WHERE codigo = 'ANT2001';

UPDATE ventas SET referencia = 'BLUSA 39900 & 49900'
 WHERE upper(codigo) LIKE 'ANT2001%';

-- ─── Comprobación ─────────────────────────────────────────────────
SELECT 'ANT2001' AS codigo, referencia, SUM(cantidad) AS uds, COUNT(*) AS filas
  FROM ventas WHERE upper(codigo) LIKE 'ANT2001%' GROUP BY referencia
UNION ALL
SELECT 'ANT5022', referencia, SUM(cantidad), COUNT(*)
  FROM ventas WHERE upper(codigo) LIKE 'ANT5022%' GROUP BY referencia;
-- Esperado: ANT2001 → BLUSA 39900 & 49900 · 121 uds / 107 filas
--           ANT5022 → BATOLA SIZA ALGODON · 133 uds / 110 filas

COMMIT;

-- ══════════════════════════════════════════════════════════════════
-- ROLLBACK (si algo no cuadra, correr esto):
--
--   UPDATE ventas v SET referencia = r.referencia
--     FROM respaldo_ventas_20260918 r WHERE r.id = v.id;
--   DELETE FROM referencia_alias;
--   INSERT INTO referencia_alias SELECT * FROM respaldo_alias_20260918;
--   UPDATE codigos_sku SET referencia='BATOLA SEÑORERA ELY'  WHERE codigo='ANT2001';
--   UPDATE codigos_sku SET referencia='BATOLA SIZA BOLSILLO' WHERE codigo='ANT5022';
--   DELETE FROM bodega WHERE referencia='BATOLA SIZA ALGODON' AND stock=0;
-- ══════════════════════════════════════════════════════════════════

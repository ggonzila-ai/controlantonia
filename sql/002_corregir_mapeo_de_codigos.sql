-- ══════════════════════════════════════════════════════════════════
-- CORREGIR EL MAPEO DE DOS CÓDIGOS — SIN TOCAR EL HISTÓRICO
--
-- Decisión de Laura (2026-09-18): los saldos ya registrados se quedan como
-- están. Esto cambia únicamente cómo se imputan las ventas DE AQUÍ EN ADELANTE.
--
-- Qué estaba mal en codigos_sku (su propia columna descripcion ya lo delataba,
-- y ventas_feria_detalle.desc_item lo confirma):
--
--   ANT2001  referencia=BATOLA SEÑORERA ELY   descripcion=BLUSA JUVENIL VELO
--   ANT5022  referencia=BATOLA SIZA BOLSILLO  descripcion=BATOLA SIZA ALGODON
--
-- ANT2001 es la blusa juvenil velo: la batola señorera ely se despachó un tiempo
-- con ese código por error y hoy va con ANT5304. En el inventario la blusa se
-- lleva junto con ANT6215 en una sola línea, "BLUSA 39900 & 49900" — dos
-- referencias de dos precios inventariadas como una.
--
-- ANT5022 es la batola siza algodón, producto distinto de la siza bolsillo
-- (ANT5301) pese al nombre parecido. El alias que las fusionaba se retira.
--
-- NO se tocan: ventas, conteos, inventario_apertura ni despachos. Las 121 uds de
-- blusa que hoy figuran como BATOLA SEÑORERA ELY y las 133 de siza algodón que
-- figuran como BATOLA SIZA BOLSILLO se quedan donde están, a propósito.
--
-- ANT5177 y ANT5277 (batola señorera botones) se dejan igual: se usaron de forma
-- temporal como batola siza bolsillo, esa referencia ya no está activa y no
-- llegarán ventas nuevas con esos códigos.
-- ══════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS respaldo_codigos_sku_20260918 AS SELECT * FROM codigos_sku WHERE false;
TRUNCATE respaldo_codigos_sku_20260918;
INSERT INTO respaldo_codigos_sku_20260918 SELECT * FROM codigos_sku;

CREATE TABLE IF NOT EXISTS respaldo_alias_20260918 AS SELECT * FROM referencia_alias WHERE false;
TRUNCATE respaldo_alias_20260918;
INSERT INTO respaldo_alias_20260918 SELECT * FROM referencia_alias;

-- 1 · La batola siza algodón pasa a ser una referencia propia del inventario.
INSERT INTO bodega (referencia, categoria, stock, costo)
SELECT 'BATOLA SIZA ALGODON', 'PIJAMERIA', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM bodega WHERE referencia = 'BATOLA SIZA ALGODON');

-- Sin borrar este alias, toda venta nueva de ANT5022 volvería a caer en la de
-- bolsillo al leerse. Ninguna fila histórica dice "BATOLA SIZA ALGODON", así que
-- retirarlo no mueve ningún saldo ya registrado.
DELETE FROM referencia_alias
 WHERE alias = 'BATOLA SIZA ALGODON' AND referencia = 'BATOLA SIZA BOLSILLO';

UPDATE codigos_sku SET referencia = 'BATOLA SIZA ALGODON' WHERE codigo = 'ANT5022';

-- 2 · ANT2001 vuelve a blusas.
UPDATE codigos_sku SET referencia = 'BLUSA 39900 & 49900' WHERE codigo = 'ANT2001';

-- ─── Comprobación ─────────────────────────────────────────────────
SELECT codigo, referencia, descripcion FROM codigos_sku
 WHERE codigo IN ('ANT2001','ANT5022','ANT5301','ANT5304','ANT5177') ORDER BY codigo;
-- Esperado: ANT2001 → BLUSA 39900 & 49900 · ANT5022 → BATOLA SIZA ALGODON
--           ANT5301 y ANT5177 → BATOLA SIZA BOLSILLO · ANT5304 → BATOLA SEÑORERA ELY

SELECT 'el histórico no se movió' AS control, referencia, SUM(cantidad) AS uds
  FROM ventas WHERE upper(codigo) LIKE 'ANT2001%' OR upper(codigo) LIKE 'ANT5022%'
 GROUP BY referencia ORDER BY referencia;
-- Esperado (igual que antes): BATOLA SEÑORERA ELY 121 · BATOLA SIZA BOLSILLO 133

COMMIT;

-- ══════════════════════════════════════════════════════════════════
-- CUIDADO A FUTURO: si alguna vez se vuelve a cargar un mes ya cargado
-- (como se recargaron enero–marzo), esas ventas se imputarán con el mapeo NUEVO
-- y entonces sí cambiarán los saldos viejos. Si eso pasa y no se quiere, hay que
-- restaurar codigos_sku desde el respaldo antes de recargar.
--
-- ROLLBACK:
--   DELETE FROM codigos_sku;
--   INSERT INTO codigos_sku SELECT * FROM respaldo_codigos_sku_20260918;
--   DELETE FROM referencia_alias;
--   INSERT INTO referencia_alias SELECT * FROM respaldo_alias_20260918;
--   DELETE FROM bodega WHERE referencia = 'BATOLA SIZA ALGODON' AND stock = 0;
-- ══════════════════════════════════════════════════════════════════

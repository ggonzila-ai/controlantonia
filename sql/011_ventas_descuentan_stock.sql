-- ══════════════════════════════════════════════════════════════════
-- CERRAR EL CICLO: QUE LAS VENTAS SAQUEN MERCANCÍA DEL ALMACÉN
--
-- Hoy el inventario por ubicación solo sabe sumar. Los tipos de movimiento que existen
-- son backfill, ajuste, entrada y traslado: las remisiones meten mercancía a la tienda,
-- pero cuando la tienda vende, nada la saca. Por eso el stock de los almacenes solo
-- crece y la pantalla de remisiones dejó de ser creíble — al 8 de octubre hay 791
-- unidades vendidas que siguen contadas como si estuvieran en el estante.
--
-- Esta función genera los movimientos de venta de un reporte de Feria y descuenta el
-- saldo. Es idempotente: se identifica por (doc_tipo, doc_id), así que volver a
-- correrla sobre el mismo reporte no duplica nada.
--
-- No toca `ventas` ni `ventas_feria_detalle`: solo lee de ahí.
-- ══════════════════════════════════════════════════════════════════

ALTER TABLE public.movimientos_inventario DROP CONSTRAINT IF EXISTS movimientos_inventario_tipo_check;
ALTER TABLE public.movimientos_inventario
  ADD CONSTRAINT movimientos_inventario_tipo_check
  CHECK (tipo IN ('backfill','ajuste','entrada','traslado','venta','devolucion'));

-- ─── Tallas que faltan en `variantes` ─────────────────────────────
-- `variantes` tiene 86 filas para 28 referencias: a muchas les faltan tallas que sí se
-- venden, y sin la fila no hay dónde descontar. Se crean las que aparecen en ventas o en
-- el stock por talla de bodega. Crear una variante no mueve stock: nace en cero.
INSERT INTO public.variantes (referencia, talla)
SELECT DISTINCT x.referencia, x.talla
  FROM (
    SELECT coalesce(sk.referencia, p.referencia_inventario, d.desc_item) AS referencia,
           upper(btrim(d.talla)) AS talla
      FROM ventas_feria_detalle d
      JOIN reportes_ventas_feria r ON r.id = d.reporte_id AND r.estado = 'activo'
      LEFT JOIN codigos_sku sk ON sk.codigo = 'ANT' || upper(btrim(d.referencia_base))
      LEFT JOIN productos   p  ON p.referencia_base = 'ANT' || upper(btrim(d.referencia_base))
     WHERE d.cantidad > 0 AND coalesce(btrim(d.talla),'') <> ''
  ) x
 WHERE EXISTS (SELECT 1 FROM bodega b WHERE b.referencia = x.referencia)
   AND NOT EXISTS (SELECT 1 FROM variantes v
                    WHERE v.referencia = x.referencia AND upper(btrim(v.talla)) = x.talla);

CREATE OR REPLACE FUNCTION public.registrar_ventas_reporte(p_reporte_id uuid, p_usuario text DEFAULT 'sistema')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_mes text; v_desde date; v_hasta date; v_corte date;
  v_ya int; v_mov int := 0; v_uds int := 0;
  v_sin_variante jsonb := '[]'::jsonb;
BEGIN
  SELECT mes, periodo_desde, periodo_hasta INTO v_mes, v_desde, v_hasta
    FROM reportes_ventas_feria WHERE id = p_reporte_id;
  IF v_mes IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'motivo', 'Ese reporte no existe');
  END IF;

  -- El inventario por ubicación se estableció con el backfill: todo lo vendido ANTES de
  -- esa fecha ya está descontado en ese saldo. Descontarlo otra vez lo dejaría corto.
  SELECT coalesce(max(ocurrido_en), '2000-01-01'::date) INTO v_corte
    FROM movimientos_inventario WHERE tipo = 'backfill';

  IF coalesce(v_hasta, current_date) <= v_corte THEN
    RETURN jsonb_build_object('ok', true, 'omitido', true, 'mes', v_mes,
      'motivo', 'Ese reporte es anterior al inventario inicial del ' || v_corte::text ||
                ': sus ventas ya están reflejadas en el saldo');
  END IF;

  SELECT count(*) INTO v_ya FROM movimientos_inventario
   WHERE doc_tipo = 'reporte_feria' AND doc_id = p_reporte_id;
  IF v_ya > 0 THEN
    RETURN jsonb_build_object('ok', true, 'ya_aplicado', true, 'movimientos', v_ya,
      'motivo', 'Las ventas de este reporte ya se habían descontado');
  END IF;

  -- Una venta por almacén y variante. El detalle de Feria trae el almacén corto
  -- ('Malca 2') y el código ANT####; se traducen a ubicación y variante.
  WITH det AS (
    SELECT d.almacen,
           coalesce(sk.referencia, d.desc_item) AS referencia,
           upper(btrim(d.talla))                AS talla,
           sum(d.cantidad)                      AS uds
      FROM ventas_feria_detalle d
      LEFT JOIN codigos_sku sk
             ON sk.codigo = 'ANT' || upper(btrim(d.referencia_base))
     WHERE d.reporte_id = p_reporte_id AND d.cantidad > 0
       AND d.fecha > v_corte          -- lo anterior al backfill ya está en el saldo
     GROUP BY 1,2,3
  ), mapeado AS (
    SELECT det.*, u.id AS ubicacion_id, v.id AS variante_id
      FROM det
      LEFT JOIN almacenes a
             ON a.nombre = 'Feria del Brasier ' ||
                CASE WHEN det.almacen = 'Unicentro' THEN 'Unicentro Cali' ELSE det.almacen END
      LEFT JOIN ubicaciones u ON u.almacen_id = a.id
      LEFT JOIN variantes v
             ON v.referencia = det.referencia AND upper(btrim(v.talla)) = det.talla
  ), insertados AS (
    INSERT INTO movimientos_inventario
      (ocurrido_en, tipo, ubicacion_origen, ubicacion_destino, variante_id, cantidad,
       doc_tipo, doc_id, usuario, nota)
    SELECT coalesce(v_hasta, current_date), 'venta', ubicacion_id, NULL, variante_id, uds,
           'reporte_feria', p_reporte_id, p_usuario,
           'Ventas ' || v_mes || ' · ' || referencia || ' talla ' || talla
      FROM mapeado
     WHERE ubicacion_id IS NOT NULL AND variante_id IS NOT NULL AND uds > 0
    RETURNING cantidad
  )
  SELECT count(*), coalesce(sum(cantidad),0) INTO v_mov, v_uds FROM insertados;

  -- El saldo baja con el movimiento. No hay trigger, así que va aquí mismo para que
  -- movimiento y saldo no puedan separarse.
  UPDATE stock_ubicacion su
     SET cantidad = su.cantidad - m.uds, updated_at = now()
    FROM (SELECT ubicacion_origen AS ubicacion_id, variante_id, sum(cantidad) AS uds
            FROM movimientos_inventario
           WHERE doc_tipo = 'reporte_feria' AND doc_id = p_reporte_id AND tipo = 'venta'
           GROUP BY 1,2) m
   WHERE su.ubicacion_id = m.ubicacion_id AND su.variante_id = m.variante_id;

  -- Lo que no se pudo mapear: se informa, no se inventa.
  SELECT coalesce(jsonb_agg(jsonb_build_object('almacen', almacen, 'referencia', referencia,
                                               'talla', talla, 'uds', uds)), '[]'::jsonb)
    INTO v_sin_variante
    FROM (
      SELECT d.almacen, coalesce(sk.referencia, d.desc_item) AS referencia,
             upper(btrim(d.talla)) AS talla, sum(d.cantidad) AS uds
        FROM ventas_feria_detalle d
        LEFT JOIN codigos_sku sk ON sk.codigo = 'ANT' || upper(btrim(d.referencia_base))
       WHERE d.reporte_id = p_reporte_id AND d.cantidad > 0
       GROUP BY 1,2,3
      ) x
   WHERE NOT EXISTS (
     SELECT 1 FROM variantes v
      WHERE v.referencia = x.referencia AND upper(btrim(v.talla)) = x.talla);

  RETURN jsonb_build_object('ok', true, 'mes', v_mes, 'corte', v_corte::text,
    'movimientos', v_mov, 'unidades_descontadas', v_uds, 'sin_variante', v_sin_variante);
END $fn$;

GRANT EXECUTE ON FUNCTION public.registrar_ventas_reporte(uuid, text) TO anon, authenticated;

-- ─── Qué pasaría si se corriera (simulacro, no escribe) ───────────
-- Solo cuenta lo posterior al inventario inicial.
SELECT r.mes, r.periodo_desde::text || ' → ' || r.periodo_hasta::text AS periodo,
       r.total_unidades AS uds_reporte,
       count(*) FILTER (WHERE v.id IS NOT NULL) AS lineas_mapeadas,
       count(*) FILTER (WHERE v.id IS NULL)     AS lineas_sin_variante
  FROM reportes_ventas_feria r
  JOIN ventas_feria_detalle d ON d.reporte_id = r.id AND d.cantidad > 0
  LEFT JOIN codigos_sku sk ON sk.codigo = 'ANT' || upper(btrim(d.referencia_base))
  LEFT JOIN variantes v ON v.referencia = coalesce(sk.referencia, d.desc_item)
                       AND upper(btrim(v.talla)) = upper(btrim(d.talla))
 WHERE r.estado = 'activo'
 GROUP BY r.mes, r.periodo_desde, r.periodo_hasta, r.total_unidades
 ORDER BY r.mes;

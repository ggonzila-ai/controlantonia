-- ══════════════════════════════════════════════════════════════════
-- FASE 2 · INSIGHTS DE DESPACHOS
--
-- Todo agregado en el servidor y devuelto en un solo JSON. Dos razones:
--   · `ventas` pasa de 4.900 filas y Supabase devuelve máximo 1.000 por consulta.
--   · El historial y los insights tienen que salir de la misma base de cálculo, o dan
--     totales distintos del mismo período.
--
-- Las anuladas quedan fuera de todo. La Ermita (057) está inactiva y no aparece.
-- Solo aditivo: una función nueva, no toca nada existente.
-- ══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.insights_despachos(
  p_desde date, p_hasta date, p_almacen text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_dias    int := greatest(1, (p_hasta - p_desde) + 1);
  v_pdesde  date := p_desde - v_dias;    -- período anterior, del mismo largo
  v_phasta  date := p_desde - 1;
  -- Ventana comparable para "despachado vs vendido": solo donde existen AMBOS datos.
  -- Antes del primer despacho no hay registro de envíos, y después de la última venta
  -- cargada no hay ventas; comparar fuera de esa ventana da relaciones absurdas.
  v_ini     date := greatest(p_desde, (SELECT min(fecha) FROM despachos WHERE estado <> 'anulada'));
  v_fin     date := least(p_hasta, (SELECT max(fecha) FROM ventas));
  v_out     jsonb;
BEGIN
  RETURN jsonb_build_object(

    'periodo', jsonb_build_object('desde', p_desde, 'hasta', p_hasta, 'dias', v_dias,
                                  'ant_desde', v_pdesde, 'ant_hasta', v_phasta),

    -- Desde cuándo hay datos, para que nadie compare contra meses sin registro.
    'primer_despacho', (SELECT min(fecha) FROM despachos WHERE estado <> 'anulada'),
    'ultima_venta',    (SELECT max(fecha) FROM ventas),
    'comparable',      jsonb_build_object('desde', v_ini, 'hasta', v_fin),

    -- Lo despachado dentro de la ventana comparable, por almacén.
    'despachado_cmp', (
      SELECT coalesce(jsonb_agg(x), '[]'::jsonb) FROM (
        SELECT jsonb_build_object('almacen', d.almacen_nombre, 'unidades', sum(i.cantidad)) AS x
          FROM despachos d JOIN despacho_items i ON i.despacho_id = d.id
         WHERE d.estado <> 'anulada' AND d.fecha BETWEEN v_ini AND v_fin
           AND (p_almacen IS NULL OR d.almacen_nombre = p_almacen)
         GROUP BY d.almacen_nombre) t),

    -- ── A · ¿cuánto despaché? ──
    'resumen', (
      SELECT jsonb_build_object(
        'remisiones', count(DISTINCT d.id),
        'unidades',   coalesce(sum(i.cantidad), 0),
        'valor',      coalesce(sum(i.cantidad * i.precio_venta) FILTER (WHERE i.precio_venta IS NOT NULL), 0),
        'uds_sin_precio', coalesce(sum(i.cantidad) FILTER (WHERE i.precio_venta IS NULL), 0))
        FROM despachos d JOIN despacho_items i ON i.despacho_id = d.id
       WHERE d.estado <> 'anulada' AND d.fecha BETWEEN p_desde AND p_hasta
         AND (p_almacen IS NULL OR d.almacen_nombre = p_almacen)),

    'resumen_anterior', (
      SELECT jsonb_build_object(
        'remisiones', count(DISTINCT d.id),
        'unidades',   coalesce(sum(i.cantidad), 0))
        FROM despachos d JOIN despacho_items i ON i.despacho_id = d.id
       WHERE d.estado <> 'anulada' AND d.fecha BETWEEN v_pdesde AND v_phasta
         AND (p_almacen IS NULL OR d.almacen_nombre = p_almacen)),

    'por_mes', (
      SELECT coalesce(jsonb_agg(x ORDER BY x->>'mes'), '[]'::jsonb) FROM (
        SELECT jsonb_build_object('mes', to_char(d.fecha,'YYYY-MM'),
                                  'unidades', sum(i.cantidad)) AS x
          FROM despachos d JOIN despacho_items i ON i.despacho_id = d.id
         WHERE d.estado <> 'anulada' AND d.fecha >= (p_hasta - interval '12 months')::date
           AND (p_almacen IS NULL OR d.almacen_nombre = p_almacen)
         GROUP BY to_char(d.fecha,'YYYY-MM')) t),

    -- ── B · ¿a qué local va? Incluye los activos con cero: ese cero informa. ──
    'almacenes', (
      SELECT coalesce(jsonb_agg(x ORDER BY (x->>'unidades')::int DESC), '[]'::jsonb) FROM (
        SELECT jsonb_build_object(
          'codigo', a.codigo, 'nombre', a.nombre,
          'unidades',   coalesce(sum(i.cantidad), 0),
          'remisiones', count(DISTINCT d.id),
          'ultimo',     max(d.fecha),
          'dias',       CASE WHEN max(d.fecha) IS NULL THEN NULL
                             ELSE (current_date - max(d.fecha)) END) AS x
          FROM almacenes a
          LEFT JOIN despachos d ON d.almacen_nombre = a.nombre
                               AND d.estado <> 'anulada'
                               AND d.fecha BETWEEN p_desde AND p_hasta
          LEFT JOIN despacho_items i ON i.despacho_id = d.id
         WHERE a.activo AND (p_almacen IS NULL OR a.nombre = p_almacen)
         GROUP BY a.codigo, a.nombre) t),

    -- ── C · referencia × almacén ──
    'matriz_ref', (
      SELECT coalesce(jsonb_agg(x), '[]'::jsonb) FROM (
        SELECT jsonb_build_object('referencia', i.referencia, 'almacen', d.almacen_nombre,
                                  'unidades', sum(i.cantidad)) AS x
          FROM despachos d JOIN despacho_items i ON i.despacho_id = d.id
         WHERE d.estado <> 'anulada' AND d.fecha BETWEEN p_desde AND p_hasta
           AND (p_almacen IS NULL OR d.almacen_nombre = p_almacen)
         GROUP BY i.referencia, d.almacen_nombre) t),

    -- ── D · talla × almacén. Lo que no tiene talla va aparte, nunca repartido. ──
    'matriz_talla', (
      SELECT coalesce(jsonb_agg(x), '[]'::jsonb) FROM (
        SELECT jsonb_build_object(
          'talla', CASE WHEN coalesce(btrim(i.talla),'') IN ('','—','-') THEN '(sin talla)'
                        ELSE upper(btrim(i.talla)) END,
          'almacen', d.almacen_nombre, 'unidades', sum(i.cantidad)) AS x
          FROM despachos d JOIN despacho_items i ON i.despacho_id = d.id
         WHERE d.estado <> 'anulada' AND d.fecha BETWEEN p_desde AND p_hasta
           AND (p_almacen IS NULL OR d.almacen_nombre = p_almacen)
         GROUP BY CASE WHEN coalesce(btrim(i.talla),'') IN ('','—','-') THEN '(sin talla)'
                       ELSE upper(btrim(i.talla)) END, d.almacen_nombre) t),

    -- ── E · mezcla por categoría en cada local ──
    'matriz_cat', (
      SELECT coalesce(jsonb_agg(x), '[]'::jsonb) FROM (
        SELECT jsonb_build_object('categoria', coalesce(nullif(btrim(i.categoria),''),'—'),
                                  'almacen', d.almacen_nombre,
                                  'unidades', sum(i.cantidad)) AS x
          FROM despachos d JOIN despacho_items i ON i.despacho_id = d.id
         WHERE d.estado <> 'anulada' AND d.fecha BETWEEN p_desde AND p_hasta
           AND (p_almacen IS NULL OR d.almacen_nombre = p_almacen)
         GROUP BY coalesce(nullif(btrim(i.categoria),''),'—'), d.almacen_nombre) t),

    -- ── F · lo vendido en el mismo período, para comparar ──
    'vendido', (
      SELECT coalesce(jsonb_agg(x), '[]'::jsonb) FROM (
        SELECT jsonb_build_object('almacen', v.almacen_nombre,
                                  'unidades', sum(v.cantidad)) AS x
          FROM ventas v
         WHERE v.fecha BETWEEN v_ini AND v_fin
           AND (p_almacen IS NULL OR v.almacen_nombre = p_almacen)
         GROUP BY v.almacen_nombre) t),

    'vendido_talla', (
      SELECT coalesce(jsonb_agg(x), '[]'::jsonb) FROM (
        SELECT jsonb_build_object(
          'talla', CASE WHEN coalesce(btrim(v.talla),'') IN ('','—','-') THEN '(sin talla)'
                        ELSE upper(btrim(v.talla)) END,
          'almacen', v.almacen_nombre, 'unidades', sum(v.cantidad)) AS x
          FROM ventas v
         WHERE v.fecha BETWEEN v_ini AND v_fin
           AND (p_almacen IS NULL OR v.almacen_nombre = p_almacen)
         GROUP BY CASE WHEN coalesce(btrim(v.talla),'') IN ('','—','-') THEN '(sin talla)'
                       ELSE upper(btrim(v.talla)) END, v.almacen_nombre) t),

    'vendido_ref', (
      SELECT coalesce(jsonb_agg(x), '[]'::jsonb) FROM (
        SELECT jsonb_build_object('referencia', v.referencia, 'almacen', v.almacen_nombre,
                                  'unidades', sum(v.cantidad)) AS x
          FROM ventas v
         WHERE v.fecha BETWEEN v_ini AND v_fin
           AND (p_almacen IS NULL OR v.almacen_nombre = p_almacen)
         GROUP BY v.referencia, v.almacen_nombre) t)
  );
END $fn$;

GRANT EXECUTE ON FUNCTION public.insights_despachos(date, date, text) TO anon, authenticated;

-- ─── Comprobación contra los números de control ───────────────────
SELECT (insights_despachos('2026-01-01','2026-12-31')->'resumen'->>'remisiones')::int AS remisiones_2026,
       (insights_despachos('2026-01-01','2026-12-31')->'resumen'->>'unidades')::int   AS unidades_2026,
       insights_despachos('2026-01-01','2026-12-31')->>'primer_despacho'              AS desde,
       (insights_despachos('2026-08-01','2026-08-31')->'resumen'->>'unidades')::int   AS agosto,
       (insights_despachos('2026-06-01','2026-06-30')->'resumen'->>'unidades')::int   AS junio,
       (insights_despachos('2026-10-01','2026-10-31')->'resumen'->>'unidades')::int   AS octubre;
-- Esperado: 13 · 416 · 2026-06-17 · 343 · 40 · 33

SELECT insights_despachos('2026-01-01','2026-12-31')->'comparable' AS ventana_comparable;
-- Esperado: desde 2026-06-17 hasta la última venta cargada

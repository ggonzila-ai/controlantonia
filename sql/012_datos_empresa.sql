-- ══════════════════════════════════════════════════════════════════
-- DATOS DE LA EMPRESA PARA EL ENCABEZADO DE LA REMISIÓN
--
-- Van en app_config, no incrustados en el código, para que se puedan corregir desde la
-- app sin tocar nada más. La remisión los lee de aquí; lo que esté vacío simplemente no
-- se imprime.
--
-- El teléfono queda pendiente: Laura lo completa desde la pantalla "Datos de la empresa".
-- ══════════════════════════════════════════════════════════════════

BEGIN;

INSERT INTO public.app_config (clave, valor) VALUES
  ('empresa', jsonb_build_object(
     'nombre_comercial', 'Antonia',
     'razon_social',     'INDUSTRIAS GONZAGAR SAS',
     'nit',              '901.955.798-5',
     'direccion',        'Carrera 83A #48-45 A402',
     'ciudad',           'Santiago de Cali',
     'telefono',         '',
     'marca',            'Antonia Sorev'
   ))
ON CONFLICT (clave) DO UPDATE SET valor = EXCLUDED.valor;

SELECT valor->>'razon_social' AS razon_social,
       valor->>'nit'          AS nit,
       valor->>'direccion' || ', ' || (valor->>'ciudad') AS direccion,
       coalesce(nullif(valor->>'telefono',''), '(pendiente)') AS telefono,
       valor->>'marca'        AS marca
  FROM app_config WHERE clave = 'empresa';

COMMIT;

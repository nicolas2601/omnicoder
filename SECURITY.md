# Politica de Seguridad

Gracias por ayudar a mantener OmniCoder seguro. Este documento resume las
versiones soportadas, el canal privado de reporte y el alcance considerado.

## Versiones soportadas

| Version | Estado                     |
|---------|----------------------------|
| 4.x     | Soportada (parches activos)|
| 3.x     | EOL (sin parches)          |
| <= 2.x  | EOL (sin parches)          |

Los reportes que afecten unicamente a ramas EOL no recibiran parche; podemos
documentar mitigaciones si la severidad lo justifica.

## Reportar una vulnerabilidad

**No abras un issue publico.** Envia un correo privado a:

**agenciacreativalab@gmail.com**

Incluye, en la medida de lo posible:

- Version afectada (`omnicoder --version` o hash de commit).
- Sistema operativo y shell (`bash --version`).
- Descripcion del impacto y escenario de explotacion.
- Prueba de concepto minima (script, payload, transcript del hook).
- Cualquier mitigacion temporal conocida.

Si lo prefieres, puedes cifrar el reporte con PGP; solicita la clave por el
mismo correo antes de enviar material sensible.

## Tiempos de respuesta

| Hito                              | SLA                  |
|-----------------------------------|----------------------|
| Acuse de recibo                    | **72 horas**         |
| Valoracion inicial y severidad     | **7 dias naturales** |
| Parche o mitigacion (severidad alta) | Segun acuerdo con el reportante |

Mantendremos comunicacion durante la triage y acordaremos contigo una
ventana de divulgacion coordinada antes de publicar detalles.

## Alcance

**Dentro de alcance** (queremos saber de esto):

- Bugs en hooks que permitan **escalada de privilegios** o ejecucion de
  comandos no previstos (por ejemplo inyeccion via payload JSON del CLI).
- Inyeccion en el **skill-router** (construccion insegura de queries,
  desreferencias de rutas con `../`, parseo laxo del indice cacheado).
- **Exposicion de secretos** en logs, archivos de memoria, stats o en los
  artefactos generados por los hooks (API keys de providers, tokens, env).
- Bypass de las validaciones que aplican los hooks `pre-*` (por ejemplo
  saltarse `provider-failover.sh` o los tracker de uso).
- Instaladores (`scripts/install-*.sh`) que escriban fuera del prefijo
  esperado o que permitan sustitucion de binarios.

**Fuera de alcance**:

- Bugs del Qwen Code CLI upstream (reportalos en su repositorio).
- Vulnerabilidades en providers externos (NVIDIA NIM, Gemini, DeepSeek,
  OpenRouter, MiniMax) que no sean causadas por el uso que hace OmniCoder.
- Debilidades en skills o agentes de terceros instalados por el usuario a
  traves de `npx skills add`; reportalos a su mantenedor.
- Reportes puramente teoricos sin escenario de explotacion.
- Hallazgos que dependen de acceso fisico o de un atacante ya root en la
  maquina del usuario.

## Divulgacion

Tras publicar el parche, se reconocera publicamente al reportante (salvo que
pida anonimato) en las notas de release y en el `CHANGELOG.md` bajo la
seccion **Security**.

---
name: test-gen
description: "Genera tests automaticamente para codigo sin cobertura. Detecta archivos sin tests y crea suites completas."
---

# Test Generator

Genera tests automaticos para codigo sin cobertura.

## Workflow

### 1. Detectar archivos sin tests
Busca archivos fuente que no tienen archivo de test correspondiente:
- `src/foo.ts` sin `tests/foo.test.ts` o `src/foo.spec.ts`
- `src/bar.py` sin `tests/test_bar.py`

### 2. Analizar cada archivo
Para cada archivo sin tests:
- Lee el archivo completo
- Identifica funciones/clases exportadas
- Identifica edge cases y branches

### 3. Generar tests
Para cada funcion/clase:
- **Happy path**: Input normal, output esperado
- **Edge cases**: null, undefined, empty, boundary values
- **Error cases**: Input invalido, excepciones esperadas

### 4. Estructura de tests
```typescript
describe('NombreFuncion', () => {
  it('should [comportamiento esperado] when [condicion]', () => {
    // Arrange
    // Act
    // Assert
  });
});
```

### 5. Ejecutar tests generados
```bash
npm test -- --testPathPattern="[archivo generado]"
```

### 6. Corregir tests que fallen
Si un test falla porque la expectativa era incorrecta, corregir la expectativa basandose en el comportamiento real del codigo.

### 7. Reporte
```
## Tests Generados
- Archivos analizados: N
- Tests creados: N
- Funciones cubiertas: N
- Pass: N | Fail: N
```

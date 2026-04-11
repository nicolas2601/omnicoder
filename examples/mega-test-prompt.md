# MEGA PROMPT DE PRUEBA - Qwen Con Poderes v2

Copia y pega este prompt completo dentro de Qwen Code para probar
todos los componentes: agentes, skills, hooks, commands, y token optimization.

---

## PROMPT (copiar desde aqui):

```
Vamos a construir una aplicacion web completa llamada "TaskFlow" - un gestor de tareas inteligente con AI.
Quiero que uses TODOS tus poderes: agentes, skills, commands y hooks.

### FASE 1: Planificacion (usa /plan y agente engineering-software-architect)

Diseña la arquitectura de TaskFlow con estas features:
- Dashboard con estadisticas de tareas (pendientes, completadas, vencidas)
- CRUD de tareas con prioridad (P0-P3), tags, y due date
- Sistema de autenticacion con JWT
- API REST con Node.js/Express
- Frontend con React + Tailwind CSS
- Base de datos SQLite (simple, sin setup)
- Endpoint de AI que sugiere prioridad automaticamente

### FASE 2: Backend (usa agente engineering-backend-architect)

Crea la estructura del proyecto:
```
taskflow/
├── src/
│   ├── server.js          # Express server
│   ├── routes/
│   │   ├── auth.js        # Login/register
│   │   └── tasks.js       # CRUD tareas
│   ├── middleware/
│   │   └── auth.js        # JWT middleware
│   ├── db/
│   │   └── database.js    # SQLite setup + migrations
│   └── utils/
│       └── ai-priority.js # Sugerir prioridad
├── public/
│   ├── index.html
│   ├── app.js
│   └── styles.css
├── package.json
└── .env.example
```

Requisitos del backend:
- Express con middleware de CORS, JSON parser, rate limiting
- SQLite con better-sqlite3 (sync, rapido, sin setup)
- JWT con jsonwebtoken + bcrypt para passwords
- Validacion de inputs con express-validator
- Error handling centralizado
- El endpoint /api/ai/suggest-priority recibe titulo+descripcion y devuelve P0-P3

### FASE 3: Frontend (usa agente engineering-frontend-developer + design-ui-designer)

Crea el frontend en vanilla JS + Tailwind (via CDN, sin build tools):
- Login/Register con formularios bonitos
- Dashboard con cards de estadisticas (animadas)
- Lista de tareas con filtros (prioridad, estado, busqueda)
- Modal para crear/editar tareas
- Boton "AI Suggest" que llama al endpoint de AI
- Dark mode toggle
- Responsive (mobile-first)
- Colores: slate-900 background, indigo-500 primary, emerald-500 success

### FASE 4: Testing (usa agente testing-api-tester)

Prueba que todo funciona:
- Registrar un usuario de prueba
- Login y obtener JWT
- Crear 5 tareas con diferentes prioridades
- Listar tareas con filtros
- Actualizar una tarea
- Eliminar una tarea
- Probar el endpoint de AI priority

### FASE 5: Review (usa /review)

Ejecuta code review del proyecto completo con checklist P0-P3.

### FASE 6: Auditoria (usa /audit)

Auditoria de seguridad y calidad del proyecto.

### REGLAS IMPORTANTES:
1. Todo en un solo directorio ~/taskflow/
2. Que funcione con `npm install && npm start`
3. NO uses frameworks pesados - vanilla JS + Tailwind CDN para frontend
4. El AI priority endpoint puede usar logica basica (keywords matching)
5. Usa los agentes especializados cuando cambies de fase
6. Usa /review cuando termines el codigo
7. Usa /audit para la auditoria final
8. Si el skill-router te sugiere algo, siguelo
9. Crea un /handoff al final con todo el resumen
```

---

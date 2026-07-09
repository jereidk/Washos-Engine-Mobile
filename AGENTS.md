# Washos Engine Mobile - Soporte ASTC

## Resumen

Este repositorio implementa soporte completo para ASTC (Adaptive Scalable Texture Compression) para dispositivos Android.

## Archivos Creados

### source/mobile/backend/AstcSupport.hx
Detecta si el dispositivo Android soporta la extensión `GL_KHR_texture_compression_astc_ldr`.

### source/mobile/backend/AstcLoader.hx
- Carga archivos de textura ASTC (.astc) directamente a la GPU
- Maneja la recuperación de context-loss automáticamente
- Hace fallback a PNG si ASTC no está disponible
- Mantiene un mapa de recuperación para re-subir texturas después de que el contexto GL se pierde

### source/Init.hx
- Estado de inicialización que se ejecuta al inicio del juego
- Inicializa AstcSupport y AstcLoader antes de cargar cualquier textura

## Archivos Modificados

### source/Main.hx
- Cambiado `initialState` de `TitleState` a `Init`

### source/backend/Paths.hx
- Agregado import de `mobile.backend.AstcLoader`
- Modificada función `image()` para intentar cargar ASTC si está disponible
- Modificada función `clearUnusedMemory()` para limpiar tracking de ASTC

## Herramientas de Conversión

### tools/convert_astc.py
Script Python para convertir imágenes PNG a formato ASTC.

**Uso:**
```bash
# Ver qué se convertiría (dry-run)
python tools/convert_astc.py --input assets/shared/images --dry-run

# Convertir todas las imágenes
python tools/convert_astc.py --input assets/shared/images

# Convertir y eliminar PNGs originales
python tools/convert_astc.py --input assets/shared/images --delete-png

# Forzar re-conversión
python tools/convert_astc.py --input assets/shared/images --force
```

### tools/astc-config.json
Configuración para el script de conversión con:
- Block size predeterminado (12x12)
- Overrides por tipo de asset
- Lista de exclusiones (pixel art, fonts, etc.)

### tools/bin/
Contiene los binarios del codificador ASTC de ARM:
- `astcenc-avx2` - Para CPUs con AVX2
- `astcenc-sse4.1` - Para CPUs con SSE 4.1
- `astcenc-sse2` - Para CPUs con SSE 2

## Cómo Funciona

1. Al iniciar, `Init.hx` detecta si el dispositivo soporta ASTC
2. Cuando `Paths.image()` carga una textura:
   - Primero intenta cargar desde PNG
   - Si no hay PNG o falla, intenta cargar desde .astc
3. Los archivos .astc deben estar junto a los .png correspondientes:
   - `assets/images/characters/bf.png` → `assets/images/characters/bf.astc`
4. Si el contexto GL se pierde (app en background), las texturas ASTC se restauran automáticamente

## Tamaño de Bloques

| Bloque | Calidad | Uso recomendado |
|--------|---------|-----------------|
| 4x4 | Mejor | Note skins, íconos, UI detallada |
| 6x6 | Buena | Sprites de personajes |
| 8x8 | Balance | General |
| 10x10 | Baja | Backgrounds grandes |
| 12x12 | Más baja | Fondos muy grandes y simples |

## Notas Importantes

- **Nunca convertir pixel art a ASTC** - ASTC interpola entre píxeles y destruye los bordes crisp de pixel art
- Los archivos .astc se cargan desde el APK o desde almacenamiento externo (mods)
- El fallback a PNG es automático si ASTC falla o no está soportado

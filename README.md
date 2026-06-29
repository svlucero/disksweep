# DiskSweep

**DiskSweep** es una app nativa de macOS (SwiftUI, macOS 13+) para recuperar
espacio en disco. Escanea tu carpeta personal (`~/`), te muestra qué carpetas
ocupan más espacio, te deja **navegar el árbol hasta el archivo** y **borrar**
lo que no necesites — todo con confirmación.

Sin dependencias externas: solo frameworks de Apple (SwiftUI + Foundation).

---

## ✨ Características

- **Escaneo de tu carpeta personal** (`~/`) a profundidad 2, fuera del hilo
  principal y con barra de progreso, para que la interfaz nunca se congele.
- **Árbol navegable**: cada item se expande con el chevron (▸) y podés bajar
  nivel por nivel —carpetas y archivos— hasta ver exactamente qué se va a
  borrar. Los hijos se calculan **bajo demanda** (lazy) al expandir.
- **Filtro por tamaño configurable**: `10 MB / 50 MB / 100 MB / 500 MB / 1 GB`
  (por defecto 50 MB). El filtro aplica **en todos los niveles del árbol** y
  **re-filtra al instante** sin volver a escanear. Lo que pesa menos que el
  umbral no se muestra.
- **Selección por click**: seleccioná cualquier nodo (carpeta o archivo) para
  marcarlo. Soporta **multi-selección nativa** de macOS (`⌘`-click para sumar,
  `⇧`-click para rangos). Lo seleccionado es lo que se borra.
- **Ruta a la vista**: al seleccionar un único elemento se muestra su ruta
  completa (abreviada con `~`) en la barra inferior, para que sepas qué estás
  por borrar.
- **Resumen de disco en vivo**: `XX% usado · YY GB libres`, con un botón **↻**
  para recalcularlo cuando quieras. Se actualiza solo después de cada borrado.
- **Borrado seguro tras confirmación**: un alert te pide confirmar e indica
  nombre y tamaño antes de eliminar.
- **Ordenado por tamaño** descendente en cada nivel.

> Los textos de la interfaz están en **español**.

---

## ⚠️ Importante: el borrado es permanente

DiskSweep hace un **hard-delete** (equivalente a `rm -rf`) usando
`FileManager.removeItem(at:)`. **No** envía los archivos a la Papelera y **no
hay forma de deshacer**. Siempre hay un alert de confirmación, pero usá la app
con cuidado y revisá el árbol antes de borrar.

---

## 📦 Instalación (binario listo para usar)

1. Descargá `DiskSweep.zip` desde la
   [página de Releases](../../releases/latest).
2. Descomprimílo y arrastrá `DiskSweep.app` a `/Aplicaciones`.
3. La app está firmada de forma **ad-hoc** (no con un Developer ID de Apple),
   así que la primera vez macOS Gatekeeper la va a bloquear. Para abrirla:
   - **Click derecho** sobre `DiskSweep.app` → **Abrir** → **Abrir**, o
   - desde la terminal, quitá la cuarentena:
     ```bash
     xattr -dr com.apple.quarantine /Applications/DiskSweep.app
     ```

---

## 🛠️ Compilar desde el código

### Requisitos

- macOS 13+ y **Xcode 16+**
- [XcodeGen](https://github.com/yonsm/XcodeGen): `brew install xcodegen`

> El archivo `DiskSweep.xcodeproj` **no** está versionado: se genera desde
> `project.yml`, que es la fuente de verdad.

### Con `make` (recomendado)

```bash
make run       # genera el proyecto, compila y abre la app
make build     # compila en modo Release
make test      # corre los tests unitarios
make release   # genera el binario distribuible en dist/DiskSweep.zip
make clean     # limpia artefactos
make help      # lista todos los comandos
```

### Con Xcode

```bash
xcodegen generate
open DiskSweep.xcodeproj   # elegí el scheme "DiskSweep" y dale ▶ (⌘R)
```

---

## 🧭 Cómo se usa

1. Pulsá **Escanear**. Se recorre `~/` y aparecen las carpetas más pesadas.
2. Ajustá **Mostrar > [umbral]** para filtrar por tamaño (se re-filtra al
   instante).
3. Expandí con el **chevron** para navegar dentro de cada carpeta hasta los
   archivos.
4. **Hacé click** para seleccionar lo que querés borrar (`⌘`/`⇧`-click para
   varios). Mirá la ruta y el total seleccionado en la barra inferior.
5. Pulsá **Borrar** y confirmá.

---

## 🏗️ Arquitectura

App de una sola ventana con tres capas:

```
View (SwiftUI)
  └── ViewModel (@MainActor ObservableObject)
        └── DiskScanner (actor)
```

- **`DiskScanner`** (`actor`) — recorre `~/` a profundidad 2 y lista los hijos
  de cualquier carpeta bajo demanda, con sus tamaños, fuera del hilo principal.
- **`DiskSweepViewModel`** (`@MainActor`) — estado del árbol, filtrado por
  umbral, selección (con de-dup de ancestros), borrado y resumen de disco.
- **`FileNode`** — nodo observable del árbol con hijos cargados de forma lazy.
- **Vistas** — `ContentView`, `NodeRow`, `BottomBar`.

```
DiskSweep/
├── DiskSweepApp.swift
├── Models/DiskItem.swift
├── Scanner/DiskScanner.swift
├── ViewModels/
│   ├── DiskSweepViewModel.swift
│   └── FileNode.swift
└── Views/
    ├── ContentView.swift
    ├── ItemRow.swift        # NodeRow
    └── BottomBar.swift
```

El diseño completo está en
[`docs/superpowers/specs/2026-06-27-disksweep-design.md`](docs/superpowers/specs/2026-06-27-disksweep-design.md).
Las convenciones del proyecto, en [`CLAUDE.md`](CLAUDE.md).

---

## 🧪 Tests

```bash
make test
```

Cubren la lógica no-UI: filtrado por umbral (incluyendo hijos del árbol),
formateo de bytes, orden por tamaño y el `DiskScanner` contra fixtures en
directorios temporales (no tocan tu disco real).

---

## 🤝 Contribuir

Es un proyecto abierto: forkealo, probá `make run` y mandá tu PR. Mantené el
estilo de commits convencionales (`feat:`, `fix:`, `docs:`…) y agregá tests
para la lógica nueva.

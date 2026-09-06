# 🌙 Moon Place — Guía completa para Windows (sin Mac)

Moon Place es una interfaz nueva construida **encima** del motor del 3105: no se
tocó nada del exploit ni del sistema de parches, solo se añadió una capa visual
con login por **KeyAuth** y un menú con **MoonV1 / MoonV2**.

---

## 1. Qué se añadió al proyecto

| Archivo | Qué hace |
|---|---|
| `ThreeOneOSFive/moonplace/MoonConfig.swift` | **Edita este**: nombre de la app y Owner ID de KeyAuth |
| `ThreeOneOSFive/moonplace/KeyAuthClient.swift` | Cliente del API 1.3 de keyauth.cc (init / register / login) |
| `ThreeOneOSFive/moonplace/MoonAuthManager.swift` | Sesión, guardado de credenciales en Keychain y auto-login |
| `ThreeOneOSFive/moonplace/MoonLoginView.swift` | Pantalla "Welcome, new user" (registro con key + login) |
| `ThreeOneOSFive/moonplace/MoonPlaceView.swift` | Menú "Welcome to Moon Place" con MoonV1/MoonV2, Apply y Restore Originals |
| `ThreeOneOSFive/moonplace/MoonV2Patches/*.3105` | Tus 4 opciones ya hechas, dentro de la app |
| `.github/workflows/build-moonplace-ipa.yml` | Compila la IPA en la nube (GitHub Actions) — **no necesitas Mac** |

Flujo del usuario: **Login/Registro con key → "Welcome to Moon Place" → MoonV2 →
Install → Apply**. Cada opción instalada tiene su botón **Restore Originals**,
que usa el sistema de respaldo original del 3105. Al volver a abrir la app el
usuario entra solo (auto-login) y ve de nuevo el saludo.

---

## 2. Configurar KeyAuth (5 minutos, desde Windows)

1. Crea cuenta en **https://keyauth.cc** → *Add New Application*.
2. En el panel de tu app copia **Application Name** y **Owner ID**.
3. Abre `ThreeOneOSFive/moonplace/MoonConfig.swift` y rellena:
   ```swift
   static let keyAuthAppName = "elnombredetuapp"
   static let keyAuthOwnerID = "tu_owner_id"
   ```
4. En KeyAuth → *Licenses* → *Add License* crea las keys que venderás/entregarás.
   El usuario las pega al registrarse en la app.

---

## 3. Compilar la IPA SIN Mac (GitHub Actions, gratis)

No se puede compilar una app iOS en Windows directamente (Xcode solo existe en
macOS), pero **GitHub te presta un Mac gratis en la nube**:

1. Crea una cuenta en **https://github.com** y un repositorio nuevo
   (puede ser **privado**).
2. Sube todo el contenido de la carpeta `3105-1.1.1/` (el proyecto ya incluye
   el workflow en `.github/workflows/`):
   - En la web de GitHub: *uploading an existing file* → arrastra la carpeta, o
   - con Git en Windows:
     ```
     cd 3105-1.1.1
     git init
     git add .
     git commit -m "Moon Place"
     git remote add origin https://github.com/TUUSUARIO/TUREPO.git
     git push -u origin main
     ```
   ⚠️ Los parches pesan ~320 MB: si Git se queja, usa `git config http.postBuffer 524288000`.
3. En GitHub: pestaña **Actions** → *Build Moon Place IPA* → **Run workflow**.
4. Espera ~10-15 min → entra a la ejecución → abajo, **Artifacts** →
   descarga **MoonPlace-unsigned-ipa** (es un ZIP con la IPA sin firmar).

## 4. Firmar e instalar desde Windows (Sideloadly)

Una IPA sin firmar no se instala tal cual; se firma con tu Apple ID gratis:

1. Instala **Sideloadly** (https://sideloadly.io) en Windows + iTunes
   (o los drivers de Apple).
2. Abre Sideloadly, arrastra `MoonPlace-unsigned.ipa`.
3. Pon tu **Apple ID** y contraseña → **Start** (con cuenta gratuita firma por
   7 días; con una app instalada a la vez).
4. En el iPhone: *Ajustes → General → VPN y gestión de dispositivos* → confía
   en tu Apple ID.
5. Lista: ya tienes **Moon Place** en el teléfono.

---

## 5. Añadir opciones nuevas más adelante

- **MoonV1 / MoonV2 propios**: exporta tu `.3105` desde 3105 como siempre,
  cópialo en `ThreeOneOSFive/moonplace/MoonV2Patches/` y agrégalo a la lista
  `bundledMoonV2Patches` en `MoonPlaceView.swift` (y regístralo en
  `project.pbxproj` como los otros 4). También puedes importar `.3105`
  directamente en la app desde el apartado MoonV1.

## 6. Notas

- La app pesa ~320 MB porque incluye los 2 parches de wallpapers grandes.
  Si quieres una IPA más ligera, quítalos de `MoonV2Patches` y de la lista.
- El botón **Activate** de arriba activa el acceso total (exploit) antes de
  aplicar parches — es el mismo motor original del 3105, sin cambios.
- Moon Place está ocultando la interfaz original del 3105 por diseño; para
  volver a verla, restaura `App.swift` (git) y quita la carpeta `moonplace/`.
